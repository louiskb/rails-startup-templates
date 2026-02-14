# shared/dev_tools.rb
# Share Dev Tools Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/dev_tools.rb`).

# GUARD 1: Skip entire template if Dev Tools is already installed.
# We treat "devtools fully installed" as:
# - Annotate config initializer exists
# - RuboCop config file exists
if File.exist?("config/initializers/annotate.rb") && File.exist?(".rubocop.yml")
  say "Dev tools already configured (Annotate initializer and RuboCop config found), skipping.", :yellow
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

unless gemfile.match?(/^gem.*['"]annotate['"]/)
  say 'Adding gem "annotate" to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotate"
    RUBY
  end

  missing_gems << "annotate"
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

  inject_into_file "Gemfile", after: "group :development do\n", <<~RUBY
    gem "pry-byebug"
    gem "pry-rails", require: false
  RUBY

  missing_gems << "pry"
end

unless gemfile.match?(/^gem.*['"]awesome_print['"]/)
  say 'Adding "awesome_print" gems to Gemfile (development group)...', :blue

  inject_into_file "Gemfile", after: "group :development do\n", <<~RUBY
    gem "awesome_print", require: false
  RUBY

  missing_gems << "awesome_print"
end

# Run `bundle install` if any gems were added in standalone mode.
if missing_gems.any?
  say "Installing devtools gems (#{missing_gems.join(', ')})...", :blue
  run "bundle install" unless system("bundle check")
else
  say "Devtools gems already present, skipping `bundle install`.", :green
end

# DEV TOOLS GEM SETUP
# 1. Annotate gem setup
unless File.exist?("config/initializers/annotate.rb")
  # Safely installs the `annotate` gem's initializer only if the gem is actually installed and available. Prevents errors when `annotate` is missing or not bundled yet, while being idempotent (safe to re-run).
  # `bundle exec` is a Bundler subcommand that executes any CLI tool (like annotate) in your bundle's context - prioritizes project gems over system-wide ones.
  # `bundle exec annotate --help` runs `annotate --help` via Bundler (which ensures correct gem version with Bundler). `--help` just prints usage, creates no files.
  # `> /dev/null 2>&1` redirects help text and errors to trash and is silent showing no extra text:
    # `> /dev/null` redirects `stdout` (help text) to `/dev/null (trash)` - user sees nothing.
    # `2>&1` redirects `stderr (errors) to `stdout` (which goes to `/dev/null`). Silent even if errors.
  # `system()` runs shell command and returns `true` if exit code is 0 (success). Returns `false` if exit code is not 0 (failure).
  # ** In summary, (1) if `annotate` is not installed then `bundle exec annotate --help` won't work, and (2) `> /dev/null 2>&1` is a way to silence extra text from `--help` and any errors. **
  if system("bundle exec annotate --help > /dev/null 2>&1")
    say "Running `annotate --install` to create initializer and default config...", :blue

    run "bundle exec annotate --install"
  else
    say "Annotate gem not available (bundle exec annotate failed). Skipping annotate install.", :yellow
  end
else
  say "Annotate initializer already exists, skipping annotate install.", :yellow
end

# 2. Rubocop Setup
unless File.exist?(".rubocop.yml")
  say "No `.rubocop.yml` found. Downloading a sensible default config...", :blue
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml -o .rubocop.yml"
else
  say "`.rubocop.yml` already present, leaving it unchanged.", :yellow
end

# 3. Better Errors Setup
# For Better Errors, usually only need the gem but can ensure it's restricted to development environment in `config/environments/development.rb` if desired.
if File.exist?("config/environments/development.rb") && !File.read("config/environments/development.rb").include?("BetterErrors")
  # Non-invasive comment to remind you it's installed.
  inject_into_file "config/environments/development.rb",
  after: "Rails.application.configure do\n",
  text: <<~RUBY

  # Better Errors is enabled by `rails-startup-templates/shared/devtools.rb` (only in development).
  # Configure allowed IPs if you use Docker / VMs:
  # if defined?(BetterErrors)
  #   BetterErrors::Middleware.allow_ip! '0.0.0.0/0'
  # end

  RUBY

  say "Added Better Errors comment block to `config/environments/development.rb`.", :green
end

# 4. Pry Setup
# Pry is a better IRB replacement. `pry-rails` gem replaces rails console with Pry.
# `pry-byebug` adds debugging (step through code).
# Test if Pry is available.
if system("bundle exec rails console --help > /dev/null 2>&1") && system("bundle exec pry --help > /dev/null 2>&1")

  say "Pry gems available. `rails console` now uses Pry.", :green

  # Optional: Add Pry config to `.pryrc` (common aliases)
  unless File.exist?(".pryrc")
    create_file ".pryrc", <<~PRYRC
      # Pry aliases for easier debugging.
      alias s step
      alias n next
      alias c continue
      alias ls ls -M
      alias wt whereis
    PRYRC

    say "Created `.pryrc` with useful Pry aliases.", :green
  end
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

  # Optional: Pry integration (auto-loads `ap` (awesome_print) in console)
  if File.exist?(".pryrc")
    append_file ".pryrc", "\n# Auto-load Awesome Print\nAwesomePrint.irb!"
    say "Added Awesome Print to Pry config.", :green
  end

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
  say "Standalone mode → executing db:migrate...", :blue
  rails_command "db:migrate"
end

say "✅ Dev tools installation complete!", :green
