# shared/admin.rb
# Shared Admin Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/admin.rb`).

# GUARD 1: Skip entire template if ActiveAdmin is already installed.
if File.exist?("config/initializers/active_admin.rb")
  say "ActiveAdmin already initialized, skipping.", :yellow
  exit
end

# GUARD 2: Check if Devise is installed as a pre-requisite.
if !File.exist?("config/initializers/devise.rb") && !File.exist?("app/models/user.rb")
  say "❌ Devise is required, aborting ActiveAdmin installation.", :red
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

# rails_command "db:migrate"

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gemfile = File.read("Gemfile")
if !gemfile.match?(/^gem.*['"]activeadmin['"]/)
  say "Adding ActiveAdmin gem to Gemfile...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "activeadmin"
      
    RUBY
  end

  run "bundle install" unless system("bundle check")
end

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

# Dashboard ready at `/admin` (login as admin@example.com / password). In development, visit `http//localhost:3000/admin`

say "✅ ActiveAdmin installation complete!", :green
