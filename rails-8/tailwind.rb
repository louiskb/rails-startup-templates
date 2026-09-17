# rails-8/tailwind.rb
# Rails 8 Tailwind Template

# LOGIC FLOW:
# 1. Setup core styling framework, gems, and setup (non-interactive).
# 2. Interactive: Ask about OPTIONAL gems (devise, etc.).
# 3. `after_bundle`: bundle install ONCE, run generators, and further setup.

# `shared/navbar.rb`removed from optional shared templates.

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# STEP 1: CORE SETUP

# Helper function for ENV vars
def should_install?(feature, prompt)
  env_value = ENV[feature.upcase]

  return true if env_value == 'true'
  return false if env_value == 'false'

  yes?(prompt)
end

# Helper function for local/URL paths
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

# Ruby version pin — uses the current local Ruby version; silences Heroku's "no Ruby version declared" warning.
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

# Gemfile
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "tailwindcss-rails"
    gem "simple_form", github: "heartcombo/simple_form"

  RUBY
end

inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n  gem \"dotenv-rails\""
end

# Flashes (Tailwind)
# The standard "X" close icon from Heroicons https://heroicons.com/ (Tailwind Labs' official icon set).
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="bg-blue-100 border border-blue-400 text-blue-700 px-4 py-3 rounded relative mb-4" role="alert">
      <span class="block sm:inline"><%= notice %></span>
      <span class="absolute top-0 bottom-0 right-0 px-4 py-3">
        <svg class="fill-current h-6 w-6 text-blue-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.819l-2.651 3.029a1.2 1.2 0 1 1-1.697-1.697l2.758-3.15-2.759-3.152a1.2 1.2 0 1 1 1.697-1.697L10 8.183l2.651-3.031a1.2 1.2 0 1 1 1.697 1.697l-2.758 3.152 2.758 3.15a1.2 1.2 0 0 1 0 1.698z"/></svg>
      </span>
    </div>
  <% end %>
  <% if alert %>
    <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded relative mb-4" role="alert">
      <span class="block sm:inline"><%= alert %></span>
      <span class="absolute top-0 bottom-0 right-0 px-4 py-3">
        <svg class="fill-current h-6 w-6 text-yellow-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.819l-2.651 3.029a1.2 1.2 0 1 1-1.697-1.697l2.758-3.15-2.759-3.152a1.2 1.2 0 1 1 1.697-1.697L10 8.183l2.651-3.031a1.2 1.2 0 1 1 1.697 1.697l-2.758 3.152 2.758 3.15a1.2 1.2 0 0 1 0 1.698z"/></svg>
      </span>
    </div>
  <% end %>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# Layout shell: <main> container, footer, Google Fonts <link> tags (shared/layout.rb)
apply_shared("shared/layout.rb")

# README
markdown_readme_content = <<~MARKDOWN
  Rails app generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).
MARKDOWN
file "README.md", markdown_readme_content, force: true

# Generators
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

# STEP 2:# TODO: Add more interactive gems here later:
# User says YES → add gem to Gemfile
# User says NO → skip (don't add gem)

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

# STEP 3: AFTER BUNDLE

after_bundle do
  # Generators: db + simple form + pages controller
  # `db:schema:load` is required in Rails 8 to set up secondary databases (Solid Queue, Cache, Cable) whose tables live in schema files (`queue_schema.rb` etc.), not in `db/migrate/`.
  rails_command "db:drop db:create db:schema:load db:migrate"

  # Install Tailwind CSS
  rails_command "tailwindcss:install"

  # Generate Simple Form with Tailwind config
  generate("simple_form:install")

  # Create Tailwind Simple Form initializer
  file "config/initializers/simple_form_tailwind.rb", <<~RUBY
    # Use this setup block to configure all options available in SimpleForm.
    SimpleForm.setup do |config|
      # Tailwind CSS 4 classes (v4 renamed shadow-sm/ring and dropped ring-opacity-*; its reset removes input borders)
      config.wrappers :tailwind, class: "mb-4" do |b|
        b.use :html5
        b.use :placeholder
        b.optional :maxlength
        b.optional :minlength
        b.optional :pattern
        b.optional :min_max
        b.optional :readonly
        b.use :label, class: "block text-sm font-medium text-gray-700 mb-1"
        b.use :input, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-xs focus:border-indigo-300 focus:ring-3 focus:ring-indigo-200/50 focus:outline-hidden", error_class: "border-red-500"
        b.use :error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
        b.use :hint, wrap_with: { tag: "p", class: "mt-2 text-sm text-gray-500" }
      end

      # Checkboxes: a small box beside its label, not the full-width text-input styling above.
      config.wrappers :tailwind_boolean, class: "mb-4" do |b|
        b.use :html5
        b.optional :readonly
        b.wrapper tag: "div", class: "flex items-center gap-2" do |ba|
          ba.use :input, class: "size-4 rounded border-gray-300 accent-indigo-600"
          ba.use :label, class: "text-sm text-gray-700"
        end
        b.use :error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
        b.use :hint, wrap_with: { tag: "p", class: "mt-2 text-sm text-gray-500" }
      end

      config.default_wrapper = :tailwind
      config.wrapper_mappings = { boolean: :tailwind_boolean }
      # Loaded after simple_form.rb (alphabetical), so these override its :nested and "btn" defaults.
      config.boolean_style = :inline
      config.button_class = "rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
    end
  RUBY

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

  # Node version pin for Heroku — silences "Installing a default version of Node.js" warning.
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

  # Initialize Git and make first commit
  git :init
  git add: "."
  git commit: "-m 'chore: initial commit from the Tailwind template'"

  gemfile = File.read("Gemfile")

  # shared/devise.rb
  if gemfile.include?("gem \"devise\"")
    apply_shared("shared/devise.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install devise.'"
  end

  # shared/authentication.rb
  if File.exist?("authentication.txt")
    apply_shared("shared/authentication.rb")
    run "rm -f authentication.txt"

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install rails 8 native authentication.'"
  end

  # shared/admin.rb (Devise required before installation)
  if gemfile.include?('gem "activeadmin"')
    apply_shared("shared/admin.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install active admin.'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "better_errors"') || gemfile.include?('gem "annotaterb"')
    apply_shared("shared/dev_tools.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install dev_tools template gems (annotaterb, better errors, pry, awesome print, rubocop).'"
  end

  # shared/friendly_urls.rb
  if gemfile.include?('gem "friendly_id"')
    apply_shared("shared/friendly_urls.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install friendly id.'"
  end

  # shared/testing.rb
  if gemfile.include?('gem "rspec-rails"')
    apply_shared("shared/testing.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install testing.'"
  end

  # shared/image_upload_cloudinary.rb
  if gemfile.include?('gem "cloudinary"')
    apply_shared("shared/image_upload_cloudinary.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install active storage and cloudinary.'"
  end

  # shared/pagination.rb
  if gemfile.include?('gem "pagy"')
    apply_shared("shared/pagination.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install pagy pagination.'"
  end

  # shared/ruby_llm.rb
  if gemfile.include?("gem \"ruby_llm\"")
    apply_shared("shared/ruby_llm.rb")

    git add: "."
    run "git diff --cached --quiet || git commit -m 'feat: install ruby_llm.'"
  end

  # shared/security.rb
  if gemfile.include?('gem "secure_headers"')
    apply_shared("shared/security.rb")

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

  # Run all migrations towards the end of `after_bundle`
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

  say "✅ Rails 8 Tailwind template installation complete! 🚀🔥", :green
end


# Key Differences from `rails-7/bootstrap.rb` Template:
# 1. No Sprockets/Asset Pipeline Setup: Removed all Bootstrap-specific gems (`sprockets-rails`, `bootstrap`, `autoprefixer-rails`, `font-awesome-sass`, sassc-rails).

# 2. Tailwind CSS Gem: Added gem `tailwindcss-rails` instead of Bootstrap gems.

# 3. Tailwind Installation: Uses `rails_command tailwindcss:install` in `after_bundle` block instead of Bootstrap asset setup.

# 4. No Asset Downloads: Removed Le Wagon stylesheets download (no need for SCSS partials with Tailwind utility classes).

# 5. Removed Bootstrap styled NavBar optional shared template.

# 6. No Sprockets Manifest: Removed `app/assets/config/manifest.js` setup (not needed for Tailwind).

# 7. Tailwind Flashes: Flash messages use Tailwind utility classes instead of Bootstrap classes. Used SVG from https://heroicons.com.

# 8. Simple Form Tailwind Config: Created custom `config/initializers/simple_form_tailwind.rb` with Tailwind wrapper configuration instead of Bootstrap Simple Form install.

# 9. No Bootstrap JS: Removed Popper.js and Bootstrap JavaScript imports.

# 10. Asset Pipeline: Rails 7 with Tailwind uses the default asset pipeline (Import maps or CSS bundling), not Sprockets.

# 11. The template maintains the same structure, ENV variable logic, shared template integration, and Git workflow as your Bootstrap template.
