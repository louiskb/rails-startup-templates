# shared/dev_tools.rb
# Share Dev Tools Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/dev_tools.rb`).

# GUARD 1: Skip entire template if Dev Tools is already installed.
# We treat "devtools fully installed" as:
# - AnnotateRb config file exists (.annotaterb.yml)
# - RuboCop config file exists
if File.exist?(".annotaterb.yml") && File.exist?(".rubocop.yml")
  say "Dev tools already configured (AnnotateRb config and RuboCop config found), skipping.", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gemfile = File.read("Gemfile")
missing_gems = []

unless gemfile.match?(/^gem.*['"]better_errors['"]/)
  say 'Adding gem "better_errors" to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do \n" do
    <<~RUBY
      gem "better_errors"
      gem "binding_of_caller"

    RUBY
  end

  missing_gems << "better_errors"
end

# NOTE: use `annotaterb` (the maintained fork), NOT the original `annotate` gem.
# Under Rails 8 / Ruby 3.3 `gem "annotate"` resolves to the ancient 2.6.5 (newer
# annotate requires rails < 7.1) and crashes with `File.exists?` removed.
unless gemfile.match?(/^gem.*['"]annotaterb['"]/)
  say 'Adding gem "annotaterb" to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotaterb"

    RUBY
  end

  missing_gems << "annotaterb"
end

unless gemfile.match?(/^gem.*['"]rubocop['"]/)
  # The main templates curl Le Wagon's `.rubocop.yml` but still need to add the gem for standalone usage.
  say 'Adding gem "rubocop" (with Rails extension) to Gemfile (development, test)...', :blue

  # `require: false` = instructs Bundler to install the gem but prevents it from being automatically loaded when `Bundler.require` is called (which happens in Rails apps during boot).
  # For example, `rubocop-rails` is a code analysis tool run via CLI commands like `bundle exec rubocop`, not something loaded into your Rails app's runtime (controllers, models, etc.).
  # `require: false` only skips auto-loading during app boot (via `Bundler.require`), which is ideal for dev tools to avoid bloat.
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rubocop", require: false
      gem "rubocop-rails", require: false

    RUBY
  end

  missing_gems << "rubocop"
end

unless gemfile.match?(/^gem.*['"]pry-rails['"]/)
  say 'Adding "pry-byebug" and "pry-rails" gems to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "pry-byebug"
      gem "pry-rails", require: false
    RUBY
  end

  missing_gems << "pry"
end

unless gemfile.match?(/^gem.*['"]awesome_print['"]/)
  say 'Adding "awesome_print" gems to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "awesome_print", require: false
    RUBY
  end

  missing_gems << "awesome_print"
end

# Run `bundle install` if any gems were added in standalone mode.
if missing_gems.any?
  say "Installing devtools gems (#{missing_gems.join(', ')})...", :cyan
  run "bundle install" unless system("bundle check")
else
  say "Devtools gems already present, skipping `bundle install`.", :green
end

# DEV TOOLS GEM SETUP
# 1. AnnotateRb gem setup
# AnnotateRb adds schema comments to models/specs/factories/routes.
# `rails g annotate_rb:install` generates the `.annotaterb.yml` config AND a Rake
# hook that re-annotates models automatically after `db:migrate`.
# To annotate manually at any time: `bundle exec annotaterb models`.
unless File.exist?(".annotaterb.yml")
  # Only run the generator if the gem is actually available (idempotent / safe in
  # standalone mode before `bundle install`). `bundle exec annotaterb version`
  # exits 0 when the binary resolves; `> /dev/null 2>&1` silences its output.
  if system("bundle exec annotaterb version > /dev/null 2>&1")
    say "Running `annotate_rb:install` (creates .annotaterb.yml + db:migrate hook)...", :cyan

    generate "annotate_rb:install"
  else
    say "AnnotateRb not available yet (run `bundle install` first). Skipping annotate install.", :yellow
  end
else
  say "AnnotateRb config (.annotaterb.yml) already exists, skipping install.", :yellow
end

# 2. Rubocop Setup
unless File.exist?(".rubocop.yml")
  say "No `.rubocop.yml` found. Downloading a sensible default config...", :cyan
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml -o .rubocop.yml"
else
  say "`.rubocop.yml` already present, leaving it unchanged.", :yellow
end

# 3. Better Errors Setup
# For Better Errors, usually only need the gem but can ensure it's restricted to development environment in `config/environments/development.rb` if desired.
if File.exist?("config/environments/development.rb") && !File.read("config/environments/development.rb").include?("BetterErrors")
  # Non-invasive comment to remind you it's installed.
  inject_into_file "config/environments/development.rb",
  after: "Rails.application.configure do\n" do
    <<~RUBY

    # Better Errors is enabled by `rails-startup-templates/shared/devtools.rb` (only in development).
    # Configure allowed IPs if you use Docker / VMs:
    # if defined?(BetterErrors)
    #   BetterErrors::Middleware.allow_ip! '0.0.0.0/0'
    # end

    RUBY
  end

  say "Added Better Errors comment block to `config/environments/development.rb`.", :green
end

# 4. Pry Setup
# Pry is a better IRB replacement. `pry-rails` gem replaces rails console with Pry.
# `pry-byebug` adds debugging (step through code).
# Test if Pry is available.
if system("bundle exec rails console --help > /dev/null 2>&1") && system("bundle exec pry --help > /dev/null 2>&1")

  say "`rails console` now uses Pry.", :green

  # Optional: Add Pry config to `.pryrc` (common aliases)
  # unless File.exist?(".pryrc")
  #   create_file ".pryrc", <<~PRYRC
  #     # Pry aliases for easier debugging.
  #     alias s step
  #     alias n next
  #     alias c continue
  #     alias ls "ls -M"
  #     alias wt whereis
  #   PRYRC

  #   say "Created `.pryrc` with useful Pry aliases.", :green
  # end
else
  say "Pry gems not yet available (run `bundle install` first). Skipping Pry config.", :yellow
end

# 5. Awesome Print Setup
# Tests if Awesome Print gem is installed and loadable silently before using it.
# `bundle exec` = run via Bundler (correct gem version).
# `ruby -e` =  execute one-liner Ruby code. `-e` flag =  "execute" → run Ruby code directly from terminal (one-liner or semicolon-separated statements).
# `"require 'awesome_print'; puts 'OK'"` = Test script: Load gem → print 'OK' (inline test script to check if gem loads).
# Runs the following Ruby code inside the shell and tries to load the `awesome print` gem. If gem exists → loads successfully and prints 'OK'. If gem is missing → raises LoadError.
# `> /dev/null 2>&1` = silent redirection resulting in no output even if there are errors.
# `system(...)` runs the specified shell command and returns boolean.
if system("bundle exec ruby -e \"require 'awesome_print'; puts 'OK'\" > /dev/null 2>&1")

  # In rails console (Pry)
    # user = User.first
    # ap user # Awesome print `user`
    # ap [1,2,3] # Arrays expanded
    # ap {a: {b: [1,2]}} # Nested hashes expanded with awesome print
  say "Awesome Print available. Use `ap <obj>` instead of `puts <obj>` for pretty printing and debugging!", :green

  # Optional: Pry integration - auto-loads `ap` (awesome_print) in console.
  # if File.exist?(".pryrc")
  #   append_file ".pryrc", "\n# Auto-load Awesome Print\nAwesomePrint.irb!"
  #   say "Added Awesome Print to Pry config.", :green
  # end

else
  say "Awesome Print not available yet (`bundle install` first). Skipping.", :yellow
end

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

say "✅ Dev tools installation complete!", :green
