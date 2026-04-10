# shared/devise.rb
# Shared Devise Template

# TODO after Devise added to project:
# 1) Configure Mailer in Rails app and Devise.
# 2) Adding optional attributes to User e.g. `first_name` and `last_name` inside `app/controllers/application_controller.rb` with ability to create new and edit (see docs = `https://github.com/heartcombo/devise#strong-parameters`).
# 3) Add Login and Logout to navbar and views. Configure `app/views/layouts/application.html.erb` and `app/views/shared/_navbar.html.erb`
# 4) Add alerts/flashes to views `app/views/layouts/application.html.erb` and (optional) `app/views/shared/_flashes.html.erb`.

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/devise.rb`).

# GUARD 1: Check if Devise is fully installed (config + model exist).
# Skip entire template if Devise is already complete.
if File.exist?("config/initializers/devise.rb") && File.exist?("app/models/user.rb") || File.exist?("app/controllers/concerns/authentication.rb") || File.exist?("app/models/session.rb") || File.exist?("app/models/current.rb")
  say "Devise or native authentication (Rails 8) is already installed, skipping.", :yellow
  exit # Early exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gemfile = File.read("Gemfile")

unless gemfile.match?(/^gem.*['"]devise['"]/)
  # Interactive version choice - choose Devise v4.9 for Active Admin or the latest version.
  devise_choice = ask("Use Devise v4.9 for Active Admin? (y = yes, n = latest version)", limited_to: %w[y n]).downcase

  gem_line = if devise_choice == "y"
    'gem "devise", "~> 4.9"'
  else
    'gem "devise"'
  end

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      #{gem_line}

    RUBY
  end

  say("Devise #{devise_choice == 'y' ? 'v4.9' : 'latest version'} added.", :green)

  # `bundle install` ONLY if it's needed (bundle check fails → bundle install).
  # `bundle check` compares Gemfile vs Gemfile.lock to see if they're the same.
  # `system()` method runs shell command and returns true/false. Returns `true` if exit code 0 (success), `false` otherwise. `system()` always preferred for conditionals (e.g. unless system(...)) as it returns boolean.
  # `run` method typically runs shell command, prints output, continues. If it runs a shell command that returns a success code (shell exits 0 → returns empty string ("") = truthy vs shell exits 1 → returns nil = falsy), ultimately returning true/false, then `run` can be used in conditionals too. However, `system()` is the preferred method for conditional logic as by default it returns a boolean.
  # For reference, the line's logic below is the same as `run "bundle check" || run "bundle install"`
  run "bundle install" unless system("bundle check")
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
inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do
  <<~RUBY
    before_action :authenticate_user!
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

# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).
# Logic stored inside `in_main_template` variable:
# `caller_locations` is a Ruby built-in method that returns an array of callstack frames which has reference to "who called this code?".
# The chained `any?` method returns `true` or `false`, depending if any of the iterated callstack frames inside the `caller_locations` array meet the criteria set inside the inline block. Returns `true` if any iteration returns truthy.
# This specific block iterates over caller_locations (array), taking `loc` as a block parameter and returning `true` if any location matches the conditions.
# The block checks `loc.label` that matches the calling method `after_bundle` or `loc.path`(regex match for "bootstrap.rb" or other main template file names).
# `any?` short-circuits on the first truthy block result.
# `Regexp.union` builds one Regexp from multiple patterns by joining them with `|` (regex alternation), so it matches any of the inputs. `|` acts as logical OR—tries left-to-right, takes first match. `Regexp.union` inputs could be strings, Regexps, or an array.
# `Regexp.union(['bootstrap.rb', 'custom.rb', 'tailwind.rb'])` → /bootstrap\.rb|custom\.rb|tailwind\.rb/
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

# Note: With Turbo, sign out links need: data: { turbo_method: :delete }

say "✅ Devise installation complete!", :green
