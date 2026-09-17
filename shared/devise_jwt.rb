# shared/devise_jwt.rb
# JWT authentication for API-only apps (Devise + devise-jwt).
# Applied by shared/devise.rb when `config.api_only = true`, after `devise:install` and the
# User model exist. Also runs standalone on such an app.
#
# Endpoints (JSON):
#   POST   /api/v1/users           sign up   → 201 + Authorization: Bearer <token>
#   POST   /api/v1/users/sign_in   sign in   → 200 + Authorization: Bearer <token>
#   DELETE /api/v1/users/sign_out  sign out  → 204, token revoked (jwt_denylists)
#   GET    /api/v1/me              the signed-in user (example authenticated endpoint)
#
# Devise-in-API gotchas handled here (all hit in production on Vegainz):
# 1. `devise_for` inside a namespace renames the mapping (:api_v1_user) and every request
#    401s silently → `devise_for :users, skip: :all` at the ROOT + routes in `devise_scope`.
# 2. ActionController::API doesn't include Devise's helpers or `respond_to`.
# 3. Devise's RegistrationsController#create signs in through the session, which API apps
#    don't have → set the Warden user with `store: false`.
# 4. Sign-out checks "is anyone signed in?" before the JWT strategy runs → 401 → skip
#    `verify_signed_out_user` and authenticate first.

# TWO USE CASES:
# 1. Fresh app: applied by shared/devise.rb inside a main template's `after_bundle`.
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/devise_jwt.rb`).

if File.exist?("app/models/jwt_denylist.rb")
  say "JwtDenylist exists: devise-jwt is already set up, skipping.", :yellow
else
  # 2. Devise helpers + respond_to for API controllers
  inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::API\n" do
    <<~RUBY.indent(2)
      include ActionController::MimeResponds
      include Devise::Controllers::Helpers
    RUBY
  end

  # Revoked tokens
  generate "migration", "CreateJwtDenylists jti:string:uniq exp:datetime"
  jwt_migration = Dir["db/migrate/*_create_jwt_denylists.rb"].first
  gsub_file jwt_migration, "t.string :jti", "t.string :jti, null: false"
  gsub_file jwt_migration, "t.datetime :exp", "t.datetime :exp, null: false"

  create_file "app/models/jwt_denylist.rb", <<~RUBY
    # Revoked JWTs: devise-jwt stores a token's jti + expiry here on sign-out and rejects
    # any token whose jti is listed.
    class JwtDenylist < ApplicationRecord
      include Devise::JWT::RevocationStrategies::Denylist
    end
  RUBY

  gsub_file "app/models/user.rb", ":recoverable, :rememberable, :validatable",
    ":recoverable, :rememberable, :validatable,\n         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist"

  create_file "app/lib/api/failure_app.rb", <<~RUBY
    module Api
      # Devise's 401 responses in the API's error shape.
      class FailureApp < Devise::FailureApp
        def http_auth_body
          { error: i18n_message, code: "unauthorized", details: {} }.to_json
        end
      end
    end
  RUBY

  create_file "app/blueprints/user_blueprint.rb", <<~RUBY
    class UserBlueprint < Blueprinter::Base
      identifier :id

      fields :email, :created_at
    end
  RUBY

  # 3. Sign-up
  create_file "app/controllers/api/v1/users/registrations_controller.rb", <<~RUBY
    module Api
      module V1
        module Users
          # POST /api/v1/users: devise-jwt adds the Authorization header on success.
          class RegistrationsController < Devise::RegistrationsController
            def create
              build_resource(sign_up_params)

              if resource.save
                # `store: false` skips the session write Devise's `sign_up` would make (API
                # apps have no session); devise-jwt's after-set-user hook still issues the token.
                warden.set_user(resource, scope: resource_name, store: false)
                render json: { user: UserBlueprint.render_as_hash(resource) }, status: :created
              else
                clean_up_passwords(resource)
                render json: { error: "Sign-up failed", code: "invalid_input", details: resource.errors.as_json },
                       status: :unprocessable_content
              end
            end

            private

            def sign_up_params
              params.expect(user: [ :email, :password, :password_confirmation ])
            end
          end
        end
      end
    end
  RUBY

  # 4. Sign-in / sign-out
  create_file "app/controllers/api/v1/users/sessions_controller.rb", <<~RUBY
    module Api
      module V1
        module Users
          # POST /api/v1/users/sign_in and DELETE /api/v1/users/sign_out.
          class SessionsController < Devise::SessionsController
            # API apps have no session, and the JWT strategy hasn't run when Devise asks
            # "is anyone signed in?", so sign-out would 401 before it happens.
            skip_before_action :verify_signed_out_user, raise: false
            before_action :authenticate_user!, only: :destroy

            def destroy
              sign_out(resource_name)
              head :no_content
            end

            private

            def respond_with(resource, _options = {})
              render json: { user: UserBlueprint.render_as_hash(resource) }, status: :ok
            end
          end
        end
      end
    end
  RUBY

  create_file "app/controllers/api/v1/me_controller.rb", <<~RUBY
    module Api
      module V1
        # GET /api/v1/me: the signed-in user (an example authenticated endpoint).
        class MeController < BaseController
          def show
            render json: { user: UserBlueprint.render_as_hash(current_user) }
          end
        end
      end
    end
  RUBY

  base_controller = "app/controllers/api/v1/base_controller.rb"
  if File.exist?(base_controller) && !File.read(base_controller).match?(/^\s*before_action :authenticate_user!/)
    inject_into_file base_controller, after: "    class BaseController < ApplicationController\n" do
      "      before_action :authenticate_user!\n\n"
    end
  end

  # 1. Routes: mapping at the root, endpoints inside /api/v1.
  gsub_file "config/routes.rb", /^(\s*)devise_for :users\n/, "\\1devise_for :users, skip: :all\n"
  api_routes = <<~RUBY
    devise_scope :user do
      post "users", to: "users/registrations#create"
      post "users/sign_in", to: "users/sessions#create"
      delete "users/sign_out", to: "users/sessions#destroy"
    end
    get "me", to: "me#show"
  RUBY
  if File.read("config/routes.rb").match?(/^\s*namespace :v1 do\n/)
    inject_into_file "config/routes.rb", api_routes.indent(6), after: /^\s*namespace :v1 do\n/
  else
    inject_into_file "config/routes.rb", before: /^end\s*\z/ do
      "  namespace :api, defaults: { format: :json } do\n    namespace :v1 do\n#{api_routes.indent(6)}    end\n  end\n"
    end
  end

  # Devise config LAST: it references Api::FailureApp, and every `rails generate` above boots
  # the app, so the initializer must not name the class before app/lib/api/failure_app.rb exists.
  # No HTML navigation, JSON 401s, JWT dispatch/revocation.
  gsub_file "config/initializers/devise.rb",
    /^  # config\.navigational_formats = .*$/,
    "  # API only: never redirect; failures answer 401 JSON.\n  config.navigational_formats = []"

  inject_into_file "config/initializers/devise.rb", before: /^end\s*\z/ do
    <<~'RUBY'.indent(2)

      # ==> devise-jwt
      # Tokens are dispatched on sign-up and sign-in and revoked on sign-out (JwtDenylist).
      # warden-jwt matches the RAW path, so each pattern also accepts a `.json` suffix:
      # without it `DELETE /api/v1/users/sign_out.json` answered 204 and left the token valid.
      config.jwt do |jwt|
        jwt.secret = ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }
        json_suffix = /(\.json)?/
        jwt.dispatch_requests = [
          [ "POST", %r{^/api/v1/users/sign_in#{json_suffix}$} ],
          [ "POST", %r{^/api/v1/users#{json_suffix}$} ]
        ]
        jwt.revocation_requests = [
          [ "DELETE", %r{^/api/v1/users/sign_out#{json_suffix}$} ]
        ]
        jwt.expiration_time = 24.hours.to_i
      end

      # 401s in the API's error shape ({ error, code, details }).
      config.warden do |manager|
        manager.failure_app = Api::FailureApp
      end
    RUBY
  end


  say "✅ devise-jwt API authentication installed!", :green
end
