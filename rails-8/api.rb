# rails-8/api.rb
# Rails 8 API-only Template (a JSON backend for a mobile app or a JavaScript frontend)
# Run with --api:  rails _8.1.3.1_ new my_api --api -d postgresql -m rails-8/api.rb

# LOGIC FLOW:
# 1. Core setup (non-interactive): CORS, Blueprinter, versioned base controller.
# 2. Interactive: OPTIONAL modules (Devise + JWT, testing, ...). Not offered in API mode:
#    AUTH (Rails 8 authentication is cookie-session based), NAVBAR, FRIENDLY_URLS and
#    ADMIN (ActiveAdmin needs the full view stack).
# 3. `after_bundle`: generators, shared modules, git commits, migrations.

unless options[:api]
  say "rails-8/api.rb is for API-only apps. Re-run with --api:", :red
  say "  rails new my_api --api -d postgresql -m rails-8/api.rb", :red
  exit 1
end

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# STEP 1: CORE SETUP

# Helper function for ENV vars (see rails-8/bootstrap.rb for the long explanation)
def should_install?(feature, prompt)
  env_value = ENV[feature.upcase]

  return true if env_value == "true"
  return false if env_value == "false"

  yes?(prompt)
end

# Helper function for local/URL paths (see rails-8/bootstrap.rb for the long explanation)
def source_path(file)
  if __FILE__ =~ %r{https?://}
    "https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/#{file}"
  else
    File.expand_path("../#{file}", __dir__)
  end
end

# Apply a shared module. Modules stop with `exit` when their guard finds them already installed,
# which is right standalone (`rails app:template`), but inside `rails new` that `exit` would end
# the whole generation: every later module, the migrations and the final commits skipped, with
# the shell reporting success. A clean exit (status 0) now skips only that module; a failing one
# (`exit 1`, `abort`) still stops the run. A skipped module leaves nothing to commit, and an empty
# `git commit` would abort `rails new` too, so every commit after a module is guarded.
def apply_shared(file)
  padding = shell.padding
  apply source_path(file)
rescue SystemExit => e
  raise unless e.success?

  # Thor's `apply` only restores its output indent when the module runs to the end.
  shell.padding = padding
  say "#{file} exited early (its guard skipped it); continuing with the next step.", :yellow
end

# Ruby version pin: silences Heroku's "no Ruby version declared" warning.
inject_into_file "Gemfile", after: "source \"https://rubygems.org\"\n" do
  "\nruby \"#{RUBY_VERSION}\"\n"
end

# json < 3: json 3.0 (2026-09-07) made JSON.parse options keyword-only, and Rails 8.1.3.1
# still passes them positionally, so decoding JSON through ActiveSupport raises
# ArgumentError. Fixed upstream in rails/rails#58601 (merged, unreleased as of 2026-09-17):
# remove this pin once the Rails version in shell-functions.txt includes it.
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    # Remove once Rails includes rails/rails#58601 (json 3.0 compatibility)
    gem "json", "< 3"

  RUBY
end

# CORS: Rails ships rack-cors commented out in API apps.
gsub_file "Gemfile", /^# gem "rack-cors"\n/, "gem \"rack-cors\"\n"

# JSON serialization
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    # JSON serializers [https://github.com/procore-oss/blueprinter]
    gem "blueprinter"

  RUBY
end

inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n  gem \"dotenv-rails\""
end

# API Gemfiles have no `group :development do` block (web-console is full-stack only), and the
# Dev Tools and Security modules inject relative to it. Without it their gems silently vanish.
unless File.read("Gemfile").include?("group :development do\n")
  append_to_file "Gemfile", "\ngroup :development do\nend\n"
end

# README
file "README.md", <<~MARKDOWN, force: true
  Rails API generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).

  ## API conventions

  - Endpoints live under `/api/v1` and inherit `Api::V1::BaseController`.
  - Errors: `{ "error": "…", "code": "not_found", "details": {} }`. Clients branch on `code`.
  - Browser origins allowed by CORS: `ALLOWED_ORIGINS` (comma-separated).
MARKDOWN

# Generators
environment <<~RUBY
  config.generators do |generate|
    generate.test_framework :test_unit, fixture: false
  end
RUBY

# STEP 2: INTERACTIVE OPTIONAL MODULES
# User says YES → add gem to Gemfile
# User says NO → skip (don't add gem)

# devise (API: latest Devise + devise-jwt. No version pin: ActiveAdmin isn't offered here.)
if should_install?("devise", "Install Devise with JWT authentication (devise + devise-jwt)? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"
      gem "devise-jwt"

    RUBY
  end
end

# dev_tools (no Better Errors: it renders HTML error pages, which an API never serves)
if should_install?("dev_tools", "Install dev tools ('AnnotateRb', 'Pry', 'Rubocop')? (y/n)")
  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotaterb"
      gem "pry-byebug"
      gem "pry-rails", require: false
      gem "awesome_print", require: false

    RUBY
  end

  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rubocop", require: false
      gem "rubocop-rails", require: false

    RUBY
  end
end

# testing
if should_install?("testing", "Install testing? (y/n)")
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"
      gem "factory_bot_rails"
      gem "faker"
      gem "shoulda-matchers"

    RUBY
  end
end

# image_upload_cloudinary
if should_install?("image_upload_cloudinary", "Install image uploading with Cloudinary? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "cloudinary"

    RUBY
  end
end

# pagination (JSON: pagination travels in response headers)
if should_install?("pagination", "Install Pagy pagination? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end
end

# ruby_llm
if should_install?("ruby_llm", "Install ruby_llm? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "ruby_llm"

    RUBY
  end
end

# security
if should_install?("security", "Install security (secure_headers + Rack::Attack)? (y/n)")
  inject_into_file "Gemfile", before: "group :development do\n" do
    <<~RUBY
      gem "secure_headers"
      gem "rack-attack"

    RUBY
  end
end

# claude_code: no gem. The answer is kept in a local variable, which the `after_bundle`
# block below closes over, so no marker file ends up in the initial commit.
install_claude_code = should_install?("claude_code", "Set up Claude Code (CLAUDE.md, .claude/ settings and rules)? (y/n)")

# STEP 3: AFTER BUNDLE

after_bundle do
  # `db:schema:load` sets up the Solid Queue/Cache/Cable databases (their tables live in schema files).
  rails_command "db:drop db:create db:schema:load db:migrate"

  # Versioned base controller: every endpoint inherits its error handling.
  file "app/controllers/api/v1/base_controller.rb", <<~RUBY
    module Api
      module V1
        # Parent of every /api/v1 controller. Errors always render as
        # { error:, code:, details: } so clients can branch on `code`.
        class BaseController < ApplicationController
          wrap_parameters false

          rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
          rescue_from ActiveRecord::RecordInvalid, with: :render_invalid
          rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

          private

          def render_error(error:, code:, status:, details: {})
            render json: { error: error, code: code, details: details }, status: status
          end

          def render_not_found(_exception)
            render_error(error: "Resource not found", code: "not_found", status: :not_found)
          end

          def render_invalid(exception)
            render_error(error: exception.message, code: "invalid_input", status: :unprocessable_content,
                         details: exception.record.errors.as_json)
          end

          def render_parameter_missing(exception)
            render_error(error: exception.message, code: "parameter_missing", status: :bad_request)
          end
        end
      end
    end
  RUBY

  # Routes: JSON only, versioned. The format constraint makes `.xml` (or any non-JSON suffix)
  # a 404: Rack::Attack throttles and devise-jwt's token paths only account for `.json`, so
  # `POST /api/v1/users/sign_in.xml` would otherwise dodge the login throttle and
  # `DELETE /api/v1/users/sign_out.xml` would answer 204 without revoking the token.
  route <<~RUBY
    namespace :api, defaults: { format: :json }, constraints: { format: "json" } do
      namespace :v1 do
        # /api/v1 endpoints (controllers inherit Api::V1::BaseController)
      end
    end
  RUBY

  # CORS
  file "config/initializers/cors.rb", <<~RUBY, force: true
    # Cross-Origin Resource Sharing: which BROWSER origins may call this API.
    # Set ALLOWED_ORIGINS (comma-separated) per environment, e.g.
    #   ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
    # Native mobile apps send no Origin header, so CORS doesn't restrict them.
    # Production gets no default: an unset ALLOWED_ORIGINS allows no browser origins.
    default_origins = Rails.env.production? ? "" : "http://localhost:3000,http://localhost:5173,http://localhost:8081"
    allowed_origins = ENV.fetch("ALLOWED_ORIGINS", default_origins)
      .split(",").map { |origin| origin.strip.delete_suffix("/") }.reject(&:empty?)

    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(*allowed_origins)

        resource "*",
          headers: :any,
          methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
          # Clients read the JWT from Authorization and pagination from Pagy's headers.
          expose: %w[Authorization link current-page page-limit total-pages total-count],
          max_age: 600
      end
    end
  RUBY

  # Gitignore
  append_file ".gitignore", <<~TXT

    # Secrets: never commit these. Before a first push, also check .mcp.json: MCP configs
    # can embed API keys. Reference them as ${VAR} instead.
    # (Rails already ignores config/master.key and config/credentials/*.key.)
    .env*
    !.env.example

    # Claude Code: personal machine-local settings (.claude/settings.json IS shared and committed)
    .claude/settings.local.json

    # Editor and OS files
    *.swp
    .DS_Store
  TXT

  # Action Mailer URLs (Devise password-reset emails)
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Heroku
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  run "touch '.env'"

  # Initialize Git and make first commit.
  git :init
  git add: "."
  git commit: "-m 'chore: initial commit from the API template'"

  gemfile = File.read("Gemfile")

  # shared/devise.rb (API apps: it applies shared/devise_jwt.rb)
  if gemfile.match?(/^\s*gem "devise"$/)
    apply_shared("shared/devise.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install devise with JWT authentication'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "annotaterb"')
    apply_shared("shared/dev_tools.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install dev tools (annotaterb, pry, awesome print, rubocop)'"
  end

  # shared/testing.rb
  if gemfile.include?('gem "rspec-rails"')
    apply_shared("shared/testing.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install testing'"
  end

  # shared/image_upload_cloudinary.rb
  if gemfile.include?('gem "cloudinary"')
    apply_shared("shared/image_upload_cloudinary.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install active storage and cloudinary'"
  end

  # shared/pagination.rb
  if gemfile.include?('gem "pagy"')
    apply_shared("shared/pagination.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install pagy pagination'"
  end

  # shared/ruby_llm.rb
  if gemfile.include?('gem "ruby_llm"')
    apply_shared("shared/ruby_llm.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install ruby_llm'"
  end

  # shared/security.rb
  if gemfile.include?('gem "secure_headers"')
    apply_shared("shared/security.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install security'"
  end

  # shared/claude_code.rb: last module, so it can see everything installed above.
  if install_claude_code
    apply_shared("shared/claude_code.rb")
    git add: "."
    run "git diff --cached --quiet || git commit -m 'chore: add Claude Code project setup'"
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate db:seed"

  # Git. Guarded: with no modules there may be nothing new to commit, and an empty
  # `git commit` exits 1 and aborts the template before the final message.
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore(db): run migrations after module setup'"

  # RuboCop: autocorrect generator output (safe corrections only).
  if File.exist?("bin/rubocop")
    run "bin/rubocop -a > /dev/null || true"
    git add: "."
    run "git diff --cached --quiet || git commit -m 'style: autocorrect RuboCop offenses in generated code'"
  end

  # Conventional commits: commit-msg hook + README section (shared/conventional_commits.rb).
  # Last on purpose: every commit above is made before the hook exists.
  apply_shared("shared/conventional_commits.rb")
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore: enforce conventional commits with a commit-msg hook'"

  say "✅ Rails 8 API template installation complete! 🚀🔥", :green
end
