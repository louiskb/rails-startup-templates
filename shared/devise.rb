# shared/devise.rb
# Shared Devise Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/devise.rb`).

# GUARD 1: Fully installed? (config + model exist).
# Skip entire template if Devise is already complete.
if File.exist?("config/initializers/devise.rb") && File.exist?("app/models/user.rb")
  say "Devise fully installed (config + User exist), skipping.", :yellow
  exit # Early exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Fresh apps: main template already added gem → this skips.
gemfile = File.read("Gemfile")
if !gemfile.include?('gem "devise"') && !gemfile.include?("gem 'devise'")
  say "Adding Devise gem to Gemfile...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do" do
    # Note the blank line inside the heredoc to keep Gemfile formatting clean.
    <<~RUBY
      gem "devise"

    RUBY
  end

  # `bundle install` ONLY if it's needed (bundle check fails → bundle install).
  # `bundle check` compares Gemfile vs Gemfile.lock to see if they're the same.
  run "bundle check" || run "bundle install"
end

# Devise:install generator
# GUARD 2: Skip if config already exists (idempotent - Doing it multiple times = same result as once (safe to re-run).
if File.exist?("config/initializers/devise.rb")
  say "Devise config exists, skipping `devise:install`.", :yellow
else
  generate("devise:install")
end

# User model generator
# GUARD 3: Skip if model exists
if File.exist?("app/models/user.rb")
  say "User model exists, skipping `rails generate devise User`.", :yellow
else
  generate("devise", "User")
end

# ApplicationController: Add optional global auth
inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base" do
  <<~RUBY
    # Uncomment the line below so that login is required on ALL pages:
    # before_action :authenticate_user!
  RUBY
end

# Devise views
generate("devise:views")

# Style cancel account link → Bootstrap button (only works if Bootstrap is installed)
if File.exist?("app/views/devise/registrations/edit.html.erb") && File.read("Gemfile").include?("gem \"bootstrap\"")
  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML

  button_to = <<~HTML
    <div class="d-flex align-items-center">
      <div>Unhappy?</div>
      <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
    </div>
  HTML

  gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)
  say "Updated Devise cancel button to Bootstrap style.", :green
end

# STANDALONE MIGRATE SUPPORT
# Detect if shared template is called from standalone vs from main template.
if __FILE__ =~ %r{shared/devise.rb$} # Standalone call. Regex with escaping /shared\/devise\.rb$/ for reference. `$` = end anchor, matches only if string ends with "shared/devise.rb".
  say "Standalone install → running migrations...", :blue
  rails_command "db:migrate"
else
  say "Main template mode → migrations handled by main template", :blue
end

say "✅ Devise installation complete!", :green
