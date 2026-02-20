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

# Layout
gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Flashes
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

# Authentication choice (first interactive prompt)
if should_install?("auth", "Install authentication? (y/n)")

  auth_choice = ask("Choose authentication? (d = devise, r = rails 8 native, n = none)", limited_to: %w[d r n]).downcase

  # Add appropriate gems first (if any) and `apply` shared templates (`shared/bootstrap.rb` or `shared/tailwind.rb`) inside `after_bundle` after running `bundle install` with the correct gems already added.
  case auth_choice
  when "d"
    # devise
    if should_install?("devise", "Install Devise? (y/n)")
      # Add devise gem to Gemfile (before `bundle install`)
      # Note the blank line inside the heredoc to keep "Gemfile" formatting clean.

      # Default to Devise v4.9 if `DEVISE=true` (ENV variable set in shell functions) (non-interactive).
      if ENV.fetch("DEVISE", "") == "true"
        inject_into_file "Gemfile", before: "group :development, :test do" do
          <<~RUBY
            gem "devise", "~> 4.9"

          RUBY
        end
        say("`DEVISE=true` detected: Installing Devise v4.9 for Active Admin compatibility.", :green)
      else
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
      end
    end
  when "r"
    say "Rails 8 native Authentication installing...", :blue
    # Rails 8 native `authentication` does not have a gem.
  else
    say "No Authentication installed.", :yellow
  end
end

# admin (devise v4.9 required before installation) - an admin dashboard for CRUD operations on models.
if File.read("Gemfile").include?('gem "devise", "~> 4.9"')
  if should_install?("admin", "Install Active Admin (devise required)? (y/n)")
    inject_into_file "Gemfile", before: "group :development, :test do" do
      <<~RUBY
        gem "activeadmin"

      RUBY
    end
  end
end

# dev_tools
if should_install?("dev_tools", "Install dev tools ('Better Errors', 'Annotate', 'Rubocop')? (y/n)")
  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotate"
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

# image_upload_cloudinary
if should_install?("image_uploading_cloudinary", "Install image uploading with Cloudinary? (y/n)")
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

# STEP 3: AFTER BUNDLE

after_bundle do
  # Generators: db + simple form + pages controller
  rails_command "db:drop db:create db:migrate"

  # Install Tailwind CSS
  rails_command "tailwindcss:install"

  # Generate Simple Form with Tailwind config
  generate("simple_form:install")

  # Create Tailwind Simple Form initializer
  file "config/initializers/simple_form_tailwind.rb", <<~RUBY
    # Use this setup block to configure all options available in SimpleForm.
    SimpleForm.setup do |config|
      # Tailwind CSS configuration
      config.wrappers :tailwind, class: 'mb-4' do |b|
        b.use :html5
        b.use :placeholder
        b.optional :maxlength
        b.optional :minlength
        b.optional :pattern
        b.optional :min_max
        b.optional :readonly
        b.use :label, class: 'block text-sm font-medium text-gray-700 mb-1'
        b.use :input, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50', error_class: 'border-red-500'
        b.use :error, wrap_with: { tag: 'p', class: 'mt-2 text-sm text-red-600' }
        b.use :hint, wrap_with: { tag: 'p', class: 'mt-2 text-sm text-gray-500' }
      end

      config.default_wrapper = :tailwind
    end
  RUBY

  # Generate Pages Controller
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Pages Controller
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Routes
  route 'root to: "pages#home"'

  # Gitignore
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*

    # Ignore Mac and Linux files system files
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

  # Dotenv
  run "touch '.env'"

  # Rubocop
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml"

  # Initialize Git and make first commit
  git :init
  git add: "."
  git commit: "-m 'initial commit: new rails app setup with Tailwind template.'"

  # APPLY shared templates ONLY if their gems were added during interactive setup.
  # TODO: Add more conditional gem checks for each new shared template:
  # File.read() checks if gem was added in Step 2.
  gemfile = File.read("Gemfile")

  # shared/devise.rb
  if gemfile.include?("gem \"devise\"")
    apply source_path("shared/devise.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install devise.'"
  end

  # shared/authentication.rb
  if auth_choice == "r"
    # Rails 8 native `authentication` has no gem, so checks for `auth_choice` value (chosen by user) inside interactive (authentication)`case` conditional.
    apply source_path("shared/authentication")

    # Git
    git add: "."
    git commit: "-m 'feat: install rails 8 native authentication.'"
  end

  # shared/admin.rb (Devise required before installation)
  if gemfile.include?('gem "activeadmin"')
    apply source_path("shared/admin.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install active admin.'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "better_errors"') || gemfile.include?('gem "annotate"')
    apply source_path("shared/dev_tools.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install dev_tools template gems (annotate, better errors, pry, awesome print, rubocop).'"
  end

  # shared/friendly_urls.rb
  if gemfile.include?('gem "friendly_id"')
    apply source_path("shared/friendly_urls.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install friendly id.'"
  end

  # shared/image_upload_cloudinary.rb
  if gemfile.include?('gem "cloudinary"')
    apply source_path("shared/image_upload_cloudinary.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install active storage and cloudinary.'"
  end

  # shared/pagination.rb
  if gemfile.include?('gem "pagy"')
    apply source_path("shared/pagination.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install pagy pagination.'"
  end

  # shared/ruby_llm.rb
  if gemfile.include?("gem \"ruby_llm\"")
    apply source_path("shared/ruby_llm.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install ruby_llm.'"
  end

  # shared/security.rb
  if gemfile.include?('gem "secure_headers"')
    apply source_path("shared/security.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install security.'"
  end

  # shared/testing.rb
  if gemfile.include?('gem "rspec-rails"')
    apply source_path("shared/testing.rb")

    git add: "."
    git commit: "-m 'feat: install testing.'"
  end

  # Run all migrations towards the end of `after_bundle`
  rails_command "db:migrate db:seed"

  # Git
  git add: "."
  git commit: "-m 'feat: add migration after initial setup.'"

  say "✅ Rails 8 Tailwind template installation complete!", :green
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
