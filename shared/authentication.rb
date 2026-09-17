# shared/authentication.rb
# Shared Authentication Template native for Rails 8

# By default, `authentication` creates a User model (with has_secure_password, email_address, password validations) and migration, similar to Devise's core User setup.

gemfile = File.read("Gemfile")

# GUARD 1: Skip entire template if native `authentication` or `devise` is already installed.
if gemfile.match?(/^\s*gem ["']devise["']/) || File.exist?("app/controllers/concerns/authentication.rb") || File.exist?("app/models/session.rb") || File.exist?("app/models/current.rb")
  say "Native Authentication (Rails 8) or Devise is already installed, skipping...", :yellow
  exit
end

# No Standalone Support because native `authentication` does not use a gem. Therefore, no `bundle install` required.

# INSTALLATION PROCESS
# Run generator
rails_command "generate authentication"

# Native `authentication` creates basic login views (`app/views/sessions/new.html.erb`) and password reset views (`app/views/passwords/new.html.erb`), but no registration (signup) views or controller, which must be added manually.
# Add registration (signup)
route "resource :registration, only: [:new, :create]"

# Registration controller
file "app/controllers/registrations_controller.rb", <<~RUBY
  class RegistrationsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        start_new_session_for(@user)
        redirect_to root_path, notice: "Welcome!"
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
  end
RUBY

# Registration new sign-up view (Simple Form). The layout already renders flashes.
# Add navbar link: `link_to "Sign up", new_registration_path`.
# CSS framework detected from the Gemfile: Tailwind 4 has no config/tailwind.config.js,
# and Le Wagon's stylesheets keep bootstrap variables inside config/, so file checks miss both.
button_class = if gemfile.match?(/^\s*gem ["']bootstrap["']/)
  "btn btn-primary my-3"
elsif gemfile.match?(/^\s*gem ["']tailwindcss-rails["']/)
  "my-3 rounded bg-blue-600 px-4 py-2 font-bold text-white hover:bg-blue-700"
end
submit_options = button_class ? %(, class: "#{button_class}") : ""

# `url: registration_path`: `simple_form_for @user` alone would post to `users_path`, which doesn't exist.
file "app/views/registrations/new.html.erb", <<~HTML
  <h1>Sign up</h1>

  <%= simple_form_for @user, url: registration_path do |f| %>
    <%= f.input :email_address %>
    <%= f.input :password %>
    <%= f.input :password_confirmation %>
    <%= f.button :submit, "Sign up"#{submit_options} %>
  <% end %>
HTML

# PagesController#home stays public (see the main templates' PagesController comment).
pages_controller = "app/controllers/pages_controller.rb"
if File.exist?(pages_controller) && !File.read(pages_controller).match?(/^\s*allow_unauthenticated_access/)
  inject_into_file pages_controller, after: "class PagesController < ApplicationController\n" do
    "  allow_unauthenticated_access only: :home\n\n"
  end
end

# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb", "api.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

say "✅ Rails 8 native Authentication installation complete!", :green
