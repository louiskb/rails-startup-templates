# shared/active_storage.rb
# Shared Image Upload with Cloudinary Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/image_upload_cloudinary.rb`).

# GUARD 1: Skip if Active Storage is already installed and `gem "cloudinary"` exists in the `Gemfile`.
# The following checks fully verify if Active Storage and cloudinary were installed and not just partially installed by checking that all the following exist together:
# 1. Checks if `config/storage.yml` exists, which is created by `rails active_storage:install`.
# 2. Checks if Rails migrations directory exists which is always true for any Rails app with migrations (redundant but ensures basic Rails structure).
# 3. Checks if any Active Storage migrations occurred. `Dir.glob(pattern)` method finds all files matching the pattern ("db/migrate/*_create_active_storage_tables*.rb"). Matches for example `20260213010234_create_active_storage_tables.rb`. `.any?` returns true if 1+ migration files are found, false if none.
# `*` (wildcard) matches zero or more characters (any text, characters (including dots, underscores, numbers), length). Basically anything.
# 4. Checks if the `gem "cloudinary"` exists inside the `Gemfile`.
if File.exist?("config/storage.yml") && File.exist?("db/migrate") && Dir.glob("db?migrate/*_create_active_storage_tables*.rb").any? && File.read("Gemfile").include?('gem "cloudinary"')
  say "Active Storage already installed (storage.yml + migration exist), skipping.", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
# Regex pattern for reference: `^` start of line anchor (must be at line start before any text), `gem` = literal "gem", `^` (line start) + `gem` literal ensures it's a gem declaration and not commented code etc., `.*` = wildcard in regex (zero+ any characters) `['"]` = starting single or double quote, `devise` = literal "devise", `['"]` = closing single or double quote. Useful to use regex for Gemfile detection and sometimes less code to do the same thing.
# `.match?` with regex works for files with multi-line code.
gemfile = File.read("Gemfile")
if !gemfile.match?(/^gem.*['"]cloudinary['"]/)
  say "Adding Cloudinary gem to Gemfile...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "cloudinary"
    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# Set cloudinary ENV variable
append_file ".env", <<~RUBY
  # CLOUDINARY_URL=replace_with_your_cloudinary_api_key
RUBY

# Install active storage
rails_command "active_storage:install"
# rails_command "db:migrate"

# Config
append_file "config/storage.yml", <<~YML
  cloudinary:
    service: Cloudinary
    folder: <%= Rails.env %>
YML

# Config in development environment
gsub_file(
  "config/environments/development.rb",
  "config.active_storage.service = :local",
  "config.active_storage.service = :cloudinary"
)

# Config in production environment
gsub_file(
  "config/environments/production.rb",
  "config.active_storage.service = :local",
  "config.active_storage.service = :cloudinary"
)

# Post-template setup steps:
# 

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

say "✅ Image upload with cloudinary installation complete!", :green
