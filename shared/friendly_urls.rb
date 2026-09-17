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
  say "Adding `friendly_id` gem...", :cyan
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "friendly_id"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# FriendlyId initializer + `friendly_id_slugs` table (used by the :history add-on).
if File.exist?("config/initializers/friendly_id.rb")
  say "FriendlyId initializer exists, skipping `rails generate friendly_id`.", :yellow
else
  generate "friendly_id"
end

# No model is slugged automatically. Slugs show up in URLs, logs and browser history, so
# slug a PUBLIC attribute. (This module used to slug User by email, leaking addresses.)
# To slug e.g. Post by its title:
#   1. `rails generate migration AddSlugToPosts slug:string:uniq` then `rails db:migrate`
#   2. In app/models/post.rb:
#        extend FriendlyId
#        friendly_id :title, use: :slugged
#   3. Look records up with `Post.friendly.find(params[:id])` (slug or id both work).
#   4. Backfill existing rows: `Post.find_each(&:save)`.

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

say "✅ Friendly URLs installation complete!", :green
