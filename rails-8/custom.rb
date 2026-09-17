# rails-8/custom.rb
# Rails 8 Custom Template

# LOGIC FLOW:
# 1. Core setup (non-interactive).
# 2. Interactive: Ask about CSS choice (vanilla CSS + optional Bootstrap or Tailwind) and OPTIONAL gems (devise, etc.).
# 3. `after_bundle`: bundle install ONCE, run generators, and further setup.

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# STEP 1: CORE SETUP

# Helper functions
def should_install?(feature, prompt)
  env_value = ENV[feature.upcase]

  return true if env_value == 'true'
  return false if env_value == 'false'

  yes?(prompt)
end

def source_path(file)
  if __FILE__ =~ %r{https?://}
    "https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/#{file}"
  else
    File.expand_path("../#{file}", __dir__)
  end
end

# Apply a shared module. Modules stop with `exit` when their guard finds them already installed,
# which is right standalone (`rails app:template`), but inside `rails new` that `exit` would end
# the whole generation: every later module, the migrations and the final commits skipped, with
# the shell reporting success. A clean exit (status 0) now skips only that module; a failing one
# (`exit 1`, `abort`) still stops the run. A skipped module leaves nothing to commit, and an empty
# `git commit` would abort `rails new` too, so every commit after a module is guarded.
def apply_shared(file)
  padding = shell.padding
  apply source_path(file)
rescue SystemExit => e
  raise unless e.success?

  # Thor's `apply` only restores its output indent when the module runs to the end.
  shell.padding = padding
  say "#{file} exited early (its guard skipped it); continuing with the next step.", :yellow
end

# Ruby version pin
inject_into_file "Gemfile", after: "source \"https://rubygems.org\"\n" do
  "\nruby \"#{RUBY_VERSION}\"\n"
end

# json < 3: json 3.0 (2026-09-07) made JSON.parse options keyword-only, and Rails 8.1.3.1
# still passes them positionally. Decoding the session cookie raises ArgumentError, so
# every sign-up/sign-in POST in a fresh app 500s. Fixed upstream in rails/rails#58601
# (merged, unreleased as of 2026-09-17): remove this pin once the Rails version in
# shell-functions.txt includes it.
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    # Remove once Rails includes rails/rails#58601 (json 3.0 compatibility)
    gem "json", "< 3"

  RUBY
end

# Add simple_form gem
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "simple_form", github: "heartcombo/simple_form"

  RUBY
end

# Gemfile - dotenv only (no CSS gems here)
inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n  gem \"dotenv-rails\""
end

# Vanilla flashes (Tailwind/Bootstrap/vanilla neutral)
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="alert alert-info p-4 rounded mb-4">
      <%= notice %>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning p-4 rounded mb-4">
      <%= alert %>
    </div>
  <% end %>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
markdown_readme_content = <<~MARKDOWN
  Rails app generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).
MARKDOWN
file "README.md", markdown_readme_content, force: true

# Generators
environment <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

# STEP 2: INTERACTIVE OPTIONAL GEMS
# TODO: Add more interactive gems here later:
# User says YES → add gem to Gemfile
# User says NO → skip (don't add gem)

# CSS framework choice (first interactive prompt)
if should_install?("tailwind", "Install CSS framework? (y/n)")

  css_choice = ask("Choose CSS framework? (b = bootstrap, t = tailwind, v = vanilla/none)", limited_to: %w[b t v n]).downcase

  # Add appropriate gems first and `apply` shared templates (`shared/bootstrap.rb` or `shared/tailwind.rb`) inside `after_bundle` after running `bundle install` with the correct gems already added.
  case css_choice
  when "b"
    if should_install?("bootstrap", "Install Bootstrap? (y/n)")
      say "Bootstrap installing...", :cyan
      # Core Bootstrap gems
      inject_into_file "Gemfile", before: "group :development, :test do" do
        <<~RUBY
          gem "sprockets-rails"
          gem "bootstrap", "~> 5.3"
          gem "autoprefixer-rails"
          gem "font-awesome-sass", "~> 6.1"
          gem "sassc-rails"

        RUBY
      end

      # Replace Propshaft with Sprockets if present
      gsub_file("Gemfile", /^gem "propshaft".*\n/, "")

      # Sprockets refuses to boot without a manifest, and `after_bundle` runs `rails db:*`
      # before shared/bootstrap.rb exists to write one (ManifestNeededError aborted every
      # custom + Bootstrap app). Same content shared/bootstrap.rb writes, so it's identical there.
      run "mkdir -p app/assets/config"
      file "app/assets/config/manifest.js", <<~JS
        //= link_tree ../images
        //= link_directory ../stylesheets .css
      JS
    end

  when "t"
    say "Tailwind installing...", :cyan
    # Tailwind gem
    inject_into_file "Gemfile", before: "group :development, :test do" do
      <<~RUBY
        gem "tailwindcss-rails"

      RUBY
    end

  else
    say "Vanilla CSS - no framework installed.", :yellow
  end
end

# Devise without prompts when `DEVISE=true` (the `-all` shell functions). No version pin:
# ActiveAdmin 3.5+ supports Devise 5 (`DEVISE = ">= 4.0", "< 6"` in its dependency check).
if ENV.fetch("DEVISE", "") == "true"
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
  say("`DEVISE=true` detected: installing Devise.", :green)
end

# Authentication choice (first interactive prompt)
if should_install?("auth", "Install authentication? (y/n)")

  auth_choice = ask("Choose authentication? (d = devise, r = rails 8 native, n = none)", limited_to: %w[d r n]).downcase

  # Add appropriate gems first (if any) and `apply` shared templates (`shared/bootstrap.rb` or `shared/tailwind.rb`) inside `after_bundle` after running `bundle install` with the correct gems already added.
  case auth_choice
  when "d"
    # devise (skipped when DEVISE=true already added it above)
    unless File.read("Gemfile").match?(/^\s*gem ["']devise["']/)
      inject_into_file "Gemfile", before: "group :development, :test do" do
        <<~RUBY
          gem "devise"

        RUBY
      end
      say("Devise added.", :green)
    end
  when "r"
    say "Rails 8 native Authentication installing...", :cyan

    # Rails 8 native `authentication` does not have a gem.
    # Create a `.txt` file to use later inside `after_bundle` as reference to `apply_shared("shared/authentication.rb")`.
    if File.read("Gemfile").match?(/^\s*gem ["']devise["']/)
      # DEVISE=true already added Devise. shared/authentication.rb would see it and `exit`,
      # which silently ends `rails new` partway through `after_bundle`.
      say "Devise is already being installed (DEVISE=true): skipping Rails 8 authentication.", :yellow
    else
      file "authentication.txt", "confirm"
    end
  else
    say "No Authentication installed.", :yellow
  end
end

# admin (requires Devise) - an admin dashboard for CRUD operations on models.
if File.read("Gemfile").match?(/^\s*gem ["']devise["']/)
  if should_install?("admin", "Install Active Admin (uses Devise)? (y/n)")
    inject_into_file "Gemfile", before: "group :development, :test do" do
      <<~RUBY
        gem "activeadmin"

      RUBY
    end
  end
end

# dev_tools
if should_install?("dev_tools", "Install dev tools ('Better Errors', 'AnnotateRb', 'Rubocop')? (y/n)")
  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotaterb"
      gem "better_errors"
      gem "binding_of_caller"
      gem "pry-byebug"
      gem "pry-rails", require: false
      gem "awesome_print", require: false

    RUBY
  end

  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rubocop", require: false
      gem "rubocop-rails", require: false

    RUBY
  end
end

# friendly_urls
if should_install?("friendly_urls", "Install Friendly URLs (FriendlyId)? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "friendly_id"

    RUBY
  end
end

# testing
if should_install?("testing", "Install testing? (y/n)")
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"
      gem "factory_bot_rails"
      gem "faker"
      gem "shoulda-matchers"

    RUBY
  end
end

# image_upload_cloudinary
if should_install?("image_upload_cloudinary", "Install image uploading with Cloudinary? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "cloudinary"

    RUBY
  end
end

# navbar (only asks if Bootstrap is added)
if File.read("Gemfile").include?('gem "bootstrap"')
  if should_install?("navbar", "Install NavBar? (y/n)")
    # Placeholder = "navbar chosen" flag. shared/navbar.rb (in `after_bundle`, after the auth
    # modules) replaces it with links for whichever auth the app ended up with.
    file "app/views/shared/_navbar.html.erb", "<%# navbar placeholder: shared/navbar.rb replaces this file %>\n"
  end
end

# pagination
if should_install?("pagination", "Install Pagy pagination? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end
end

# ruby_llm
if should_install?("ruby_llm", "Install ruby_llm? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "ruby_llm"

    RUBY
  end
end

# security
if should_install?("security", "Install security? (y/n)")
  inject_into_file "Gemfile", before: "group :development do\n" do
    <<~RUBY
      gem "secure_headers"
      gem "rack-attack"

    RUBY
  end
end

# claude_code: no gem. The answer is kept in a local variable, which the `after_bundle`
# block below closes over, so no marker file ends up in the initial commit.
install_claude_code = should_install?("claude_code", "Set up Claude Code (CLAUDE.md, .claude/ settings and rules)? (y/n)")

# STEP 3: after_bundle (same structure)

after_bundle do
 # Generators: db + simple form + pages controller
  # `db:schema:load` is required in Rails 8 to set up secondary databases (Solid Queue, Cache, Cable) whose tables live in schema files (`queue_schema.rb` etc.), not in `db/migrate/`.
  rails_command "db:drop db:create db:schema:load db:migrate"

  gemfile = File.read("Gemfile")

  unless gemfile.include?('gem "bootstrap"') || gemfile.include?('gem "tailwindcss-rails"')
    generate("simple_form:install")
  end

  # Generate Pages Controller
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Pages Controller
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    # Public pages. Auth modules add their own public-access line here
    # (Devise: skip_before_action; Rails 8 authentication: allow_unauthenticated_access).
    class PagesController < ApplicationController
      def home
      end
    end
  RUBY

  # Routes
  route 'root to: "pages#home"'

  # Gitignore
  append_file ".gitignore", <<~TXT

    # Secrets: never commit these. Before a first push, also check .mcp.json: MCP configs
    # can embed API keys. Reference them as ${VAR} instead.
    # (Rails already ignores config/master.key and config/credentials/*.key.)
    .env*
    !.env.example

    # Claude Code: personal machine-local settings (.claude/settings.json IS shared and committed)
    .claude/settings.local.json

    # Editor and OS files
    *.swp
    .DS_Store
  TXT

  # Environments for Action Mailer
  mailer_development = <<~RUBY
    config.action_mailer.default_url_options = { host: "http://localhost:3000" }
  RUBY

  mailer_production = <<~RUBY
    config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }
  RUBY

  environment mailer_development, env: "development"
  environment mailer_production, env: "production"

  # Heroku
  run "bundle lock --add-platform x86_64-linux"

  # Node version pin (for Heroku)
  file "package.json", <<~JSON
    {
      "engines": {
        "node": "22.x"
      }
    }
  JSON

  # Dotenv
  run "touch '.env'"

  # RuboCop: keep the .rubocop.yml Rails 8 generates (rubocop-rails-omakase).

  # Initialize Git and make first commit.
  git :init
  git add: "."
  git commit: "-m 'chore: initial commit from the Custom template'"

  # APPLY shared templates ONLY if their gems were added during interactive setup.
  # TODO: Add more conditional gem checks for each new shared template:
  # File.read() checks if gem was added in Step 2.

  # shared/bootstrap.rb
  if gemfile.include?('gem "bootstrap"')
    apply_shared("shared/bootstrap.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install bootstrap.'"
  end

  # shared/tailwind.rb
  if gemfile.include?('gem "tailwindcss-rails"')
    apply_shared("shared/tailwind.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install tailwind.'"
  end

  # shared/devise.rb
  if gemfile.include?("gem \"devise\"")
    # Gem was added → run shared/devise.rb shared template setup.
    apply_shared("shared/devise.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install devise.'"
  end

  # shared/authentication.rb
  if File.exist?("authentication.txt")
    # Rails 8 native `authentication` has no gem, so checks for `authentication.txt` file created before `after_bundle` to confirm user choice. After applying `shared/authentication.rb`, `authentication.txt` is deleted.
    apply_shared("shared/authentication.rb")
    run "rm -f authentication.txt"

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install rails 8 native authentication.'"
  end

  # shared/admin.rb (Devise required before installation)
  if gemfile.include?('gem "activeadmin"')
    apply_shared("shared/admin.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install active admin.'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "better_errors"') || gemfile.include?('gem "annotaterb"')
    apply_shared("shared/dev_tools.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install dev_tools template gems (annotaterb, better errors, pry, awesome print, rubocop).'"
  end

  # shared/friendly_urls.rb
  if gemfile.include?('gem "friendly_id"')
    apply_shared("shared/friendly_urls.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install friendly id.'"
  end

  # shared/testing.rb
  if gemfile.include?('gem "rspec-rails"')
    apply_shared("shared/testing.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install testing.'"
  end

  # shared/image_upload_cloudinary.rb
  if gemfile.include?('gem "cloudinary"')
    apply_shared("shared/image_upload_cloudinary.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install active storage and cloudinary.'"
  end

  # shared/navbar.rb
  if File.exist?("app/views/shared/_navbar.html.erb")
    apply_shared("shared/navbar.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: add navbar.'"
  end

  # shared/pagination.rb
  if gemfile.include?('gem "pagy"')
    apply_shared("shared/pagination.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install pagy pagination.'"
  end

  # shared/ruby_llm.rb
  if gemfile.include?("gem \"ruby_llm\"")
    # Gem was added → run shared/ruby_llm.rb shared template setup.
    apply_shared("shared/ruby_llm.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install ruby_llm.'"
  end

  # shared/security.rb
  if gemfile.include?('gem "secure_headers"')
    apply_shared("shared/security.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install security.'"
  end

  # shared/claude_code.rb: last module, so it can see everything installed above.
  if install_claude_code
    apply_shared("shared/claude_code.rb")

    # Git
    git add: "."
    run "git diff --cached --quiet || git commit -m 'chore: add Claude Code project setup'"
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate db:seed"

  # Git. Guarded: with no modules there may be nothing new to commit, and an empty
  # `git commit` exits 1 and aborts the template before the final message.
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore(db): run migrations after module setup'"

  # RuboCop: autocorrect generator output the template doesn't write (simple_form and
  # Devise initializers, …) so a new app passes its own `bin/rubocop` and CI lint job.
  # Safe corrections only (`-a`): every offense in a fresh app is marked safe.
  if File.exist?("bin/rubocop")
    run "bin/rubocop -a > /dev/null || true"
    git add: "."
    run "git diff --cached --quiet || git commit -m 'style: autocorrect RuboCop offenses in generated code'"
  end

  # Conventional commits: commit-msg hook + README section (shared/conventional_commits.rb).
  # Last on purpose: every commit above is made before the hook exists.
  apply_shared("shared/conventional_commits.rb")
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore: enforce conventional commits with a commit-msg hook'"

  say "✅ Rails 8 Custom template installation complete! 🚀🔥", :green
end


# Key features:
# 1. Interactive CSS choice first: `b` → `shared/bootstrap.rb, t` → `shared/tailwind.rb`, `v`/`n` → `vanilla`.

# 2. No overlap: Shared templates check for existing files before installing.

# 3. Standalone shared templates: Can run on existing apps via `rails app:template LOCATION=shared/bootstrap.rb` or `rails app:template LOCATION=shared/tailwind.rb`.

# 4. Vanilla base: Pure Rails 7, no CSS framework unless chosen.

# 5. Neutral flashes: Generic classes that work with vanilla/Bootstrap/Tailwind.
