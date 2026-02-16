# shared/friendly_urls.rb
# Shared Friendly URLs Template (SEO friendly URLs)
# Converts /posts/123 → /posts/how-to-build-rails-apps
# Supports both slugs AND IDs: Post.find("slug") or Post.find(123).

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
#
# To use a model attribute like `:title` as the URL slug for eg. Post model or any other model:
  # 1. Create a migration `generate "migration", "AddSlugToPosts slug:string:index:uniq"` (i.e. run in the terminal `rails generate migration AddSlugToPosts slug:string:index:uniq`)
  # 2. add `extend FriendlyId\n` `friendly_id :title, use: :slugged` to the Post model.
  # This will use `title` as a slug for the id, which reflects in the URL eg. URL `/posts/1` → `/posts/my-post-title` (SEO friendly + cleaner URLs). Also applies to wherever ids are used eg. `Post.find(123)` or `Post.find("slug")`.
  # Apply the same process to any other model.
#
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
  # Check if slug migration for `User` already exists before generating a new one.
  # Dir["db/migrate/*_add_slug_to_users.rb"] returns array of matching migration files (glob pattern).
  #
  # SHORT CODE EXPLANATION
  # `Dir.[]` == `Dir.glob()`: `*` = wildcard, matches any filename ending `_add_slug_to_users.rb`.
  # `Dir` = directory helper class.
  # `Dir["pattern"]` = give me all files matching this pattern as an array.
  # `.any?` = is that array non-empty? (true / false)
  #
  # LONG CODE EXPLANATION
  # `Dir[...]` is Ruby's glob shortcut: it returns an array of paths match a pattern.
  # `Dir`is the Ruby class for dealing with directories (listing files, etc.). The `[...]` here is not an array literal; it’s calling Dir.[] (a class method), which is equivalent to `Dir.glob`.
  # `Dir[...]` calls the [] method on `Dir`, which is defined to behave like `Dir.glob("pattern")`.
  # There is a `Dir.glob("pattern")`, but `Dir["pattern"]` is just a shorter, idiomatic form.
  # `Dir.glob("db/migrate/*.rb")` = (same as) `Dir["db/migrate/*.rb"]` (glob, returns array of filenames).
  # `Dir[]` accepts a glob pattern as it's argument inside `[...]`. `Dir["db/migrate/*_add_slug_to_users.rb"]` returns an array like `["db/migrate/20260215010101_add_slug_to_users.rb"]` or [] it none exist.
  # The glob pattern `"db/migrate/*_add_slug_to_users.rb"` searches in the directory `db/migrate`. `*` wildcard accepts any characters.
  # `_add_to_slug_users.rb` is the exact suffix so it matches any file in `db/migrate` whose filename ends with `add_to_slug_users.rb` eg. `20260215010101_add_slug_to_users.rb`.
  # If one or more exist, the results is an array of those paths. If no such file exists, the result is [] (empty array).
  #
  # `.any?` → true if ≥1 file exists inside [] (migration exists), false if [] (empty).
  # `unless` → generate migration only if NO matching migration file found (idempotent = safe to re-run multiple times).
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
