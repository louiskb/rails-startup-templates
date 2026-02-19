# shared/authentication.rb
# Shared Authentication Template native for Rails 8

# By default, `authentication` creates a User model (with has_secure_password, email_address, password validations) and migration, similar to Devise's core User setup.

gemfile = File.read("Gemfile")

# GUARD 1: Skip entire template if native `authentication` or `devise` is already installed.
# In Ruby, `Dir.exist?("path/")` returns `true` if the path points to an existing directory, and `false` otherwise.
# if gemfile.include?("devise") || Dir.exist?("app/models/session.rb")
if gemfile.match?(/^gem.*['"]devise['"]/) || File.exist?("app/controllers/concerns/authentication.rb") || File.exist?("app/models/session.rb") || File.exist?("app/models/current.rb")
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
    allow_unauthenticated_access!

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
      params.require(:user).permit(:email, :password, :password_confirmation)
    end
  end
RUBY

# Registration new sign-up view (Simple Form + flashes)
# Dynamically styled depending on selected CSS framework.
# Add navbar link: `link_to "Sign up", new_registration_path`.
if File.exist?("app/assets/stylesheets") && Dir.glob("app/assets/stylesheets/*bootstrap*").any?
  # Bootstrap
  file "app/views/registrations/new.html.erb", <<~HTML
    <%= render "shared/flashes" %>
    <h1>Sign up</h1>
    <%= simple_form_for @user do |f| %>
      <%= f.input :email_address %>
      <%= f.input :password %>
      <%= f.input :password_confirmation %>
      <%= f.button :submit, "Sign up", class: "btn btn-primary my-3" %>
    <% end %>
  HTML
elsif File.exist?("config/tailwind.config.js")
  # Tailwind CSS
  file "app/views/registrations/new.html.erb", <<~HTML
    <%= render "shared/flashes" %>
    <h1>Sign up</h1>
    <%= simple_form_for @user do |f| %>
      <%= f.input :email_address %>
      <%= f.input :password %>
      <%= f.input :password_confirmation %>
      <%= f.button :submit, "Sign up", class: "bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded my-3" %>
    <% end %>
  HTML
else
  # Vanilla CSS
  file "app/views/registrations/new.html.erb", <<~HTML
    <%= render "shared/flashes" %>
    <h1>Sign up</h1>
    <%= simple_form_for @user do |f| %>
      <%= f.input :email_address %>
      <%= f.input :password %>
      <%= f.input :password_confirmation %>
      <%= f.button :submit, "Sign up" %>
    <% end %>
  HTML
end

# Home page skip auth
inject_into_file "app/controllers/pages_controller.rb", after: "class PagesController" do
  "\n  skip_before_action :authenticate_user!, only: :home\n"
end

# rails_command "db:migrate"

# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :blue
  rails_command "db:migrate"
end

say "✅ Rails 8 native Authentication installation complete!", :green
