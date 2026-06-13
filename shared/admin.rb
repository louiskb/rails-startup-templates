# shared/admin.rb
# Shared Admin Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/admin.rb`).

gemfile = File.read("Gemfile")
# GUARD 1: Skip entire template if ActiveAdmin is already installed.
if File.exist?("config/initializers/active_admin.rb")
  say "ActiveAdmin already initialized, skipping.", :yellow
  exit
end

# GUARD 2: Check if Devise is installed as a pre-requisite.
if !File.exist?("config/initializers/devise.rb") && !File.exist?("app/models/user.rb")
  say "❌ Devise is required, skipping ActiveAdmin installation.", :yellow
  exit
end

generate "active_admin:install"

# Create AdminUser model with Devise (Devise must be pre-installed)
unless File.exist?("app/models/admin_user.rb")
  generate("devise", "AdminUser")

  # Add to routes if not present
  inject_into_file "config/routes.rb", after: "devise_for :admin_users" do
    <<~RUBY
      devise_for :admin_users, ActiveAdmin::Devise.config
    RUBY
  end
end

# AUTH FIX (Devise + ActiveAdmin combined):
# The Devise module adds `before_action :authenticate_user!` to
# ApplicationController. `ActiveAdmin::BaseController < ApplicationController`, so
# it INHERITS that callback — meaning `/admin` would require BOTH a customer
# session AND an admin session, and an admin signing in at `/admin/login` alone is
# bounced to `/users/sign_in`. The admin literally can't use the panel. (Sneaky:
# invisible in manual QA if you happen to also be logged in as a customer.)
# This initializer removes the inherited callback from ActiveAdmin controllers
# only; admin pages keep their own admin_user auth via `ActiveAdmin::Devise.config`.
unless File.exist?("config/initializers/active_admin_authentication.rb")
  create_file "config/initializers/active_admin_authentication.rb", <<~RUBY
    # Skip the app-wide customer `authenticate_user!` on ActiveAdmin controllers.
    # `raise: false` keeps this safe even if ApplicationController defines no such
    # callback (e.g. Devise wasn't configured to add it).
    Rails.application.config.to_prepare do
      ActiveAdmin::BaseController.skip_before_action :authenticate_user!, raise: false
    end
  RUBY

  say "Shipped ActiveAdmin auth fix (skips inherited authenticate_user!).", :green
end

# rails_command "db:migrate"

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
if !gemfile.match?(/^gem.*['"]activeadmin['"]/)
  say "Adding ActiveAdmin gem to Gemfile...", :cyan

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "activeadmin"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# POST-INSTALL: ActiveAdmin setup remaining:
#   1. Create admin user: AdminUser.create!(email: 'admin@example.com', password: 'password')
#   2. Access dashboard at /admin
#   3. Register models: rails generate active_admin:resource ModelName

# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

# Dashboard ready at `/admin` (login as admin@example.com / password). In development, visit `http//localhost:3000/admin`

say "✅ ActiveAdmin installation complete!", :green
