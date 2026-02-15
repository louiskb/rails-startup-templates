# shared/friendly_urls.rb
# Shared Friendly URLs Template (SEO friendly URLs)
# Converts /posts/123 → /posts/how-to-build-rails-apps
# Supports both slugs AND IDs: Post.find("slug") or Post.find(123)

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/friendly_urls.rb`).

gemfile = File.read("Gemfile")

# GUARD 1: Skip entire template if Friendly URLs is already installed.
if gemfile.match?(/^gem.*['"]friendly_id['"]/) && File.exist?("config/initializers/friendly_id.rb")
  say "`friendly_id` already configured (gem + initializer), skipping.", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
unless gemfile.match?(/^gem.*['"]friendly_id['"]/)
  say "Adding `friendly_id` gem...", :blue
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "friendly_id"

    RUBY
  end

  run "bundle_install" unless system("bundle check")
end

# Add slug column migration (only if Devise is already installed)
# Check if User model exists before continuing.

if File.exist?("app/models/user.rb") && !File.read("app/models/user.rb").include?("extend FriendlyId")
  say "Adding FriendlyId to User model (uses :slug column)...", :blue

  inject_into_file "app/models/user.rb", after: "class User < ApplicationRecord\n" do
    <<~RUBY
      extend FriendlyId
      friendly_id :email, use: :slugged # Use email as slug (unique)
    RUBY
  end

  # Add slug column migration (if Devise is present)
  unless Dir["db/migrate/*_add_slug_to_users.rb"].any?
    generate "migration", "AddSlugToUsers slug:string:index:uniq"
    # rails_command "db:migrate"
  end
else
  say "User model exists or already has FriendlyId, skipping.", :yellow
end

# Routes comment (optional guidance)
inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
  <<~RUBY
    # FriendlyId: `/users/john@example.com` works alongside `/users/1`
  RUBY
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

say "✅ Friendly URLs installation complete!", :green
