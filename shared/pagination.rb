# shared/pagination.rb
# Shared Pagination Template
# Auto-generates Previous/1 2 3 4/Next links

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/pagination.rb`).

gemfile = File.read("Gemfile")

# GUARD 1: Skip entire template if Pagination is already installed.
if gemfile.include?(/^gem.*['"]pagy['"]/) && File.exist?("config/initializers/pagy.rb")
  say "Pagy already configured (gem + initializer), skipping", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
unless gemfile.include?(/^gem.*['"]pagy['"]/)
  say "Adding pagy gem...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# Install generator
unless File.exist?("config/initializers/pagy.rb")
  say "Running `rails generate pagy:install`...", :blue

  # Tests if `rails generate pagy:install` command exists/works before running it. If so, run it and if not, skip it and tell the user why.
  # `bundle install` installs pagy gem + generators. Thus, making the Pagy generator available to run. Having a guard clause to test if the command exists means it's safe to run and that `bundle install` was a success.
  #
  # `bundle exec` → correct gem version.
  # `rails generate pagy:install --help` → Test Pagy's generator (prints usage, no side effects).
  # `> /dev/null 2>&1` = silent output (no terminal "spam").
  # `system()` returns boolean if command was successful (true) or failed (false). In this case if `true`, generator exists → run it. If `false`, gem is missing → skip gracefully.
  if system("bundle exec rails generate pagy:install --help > /dev/null 2>&1")
    run "bundle exec rails generate pagy:install"
  else
    say "Pagy generator unavailable. Run `bundle install` first.", :yellow
  end

else
  say "Pagy initializer exists, skipping.", :yellow
end

# Docs = https://github.com/ddnexus/pagy?tab=readme-ov-file

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

say "✅ Pagination installation complete!", :green
