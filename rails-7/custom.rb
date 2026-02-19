# rails-7/custom.rb
# Rails 7 Custom Template

# LOGIC FLOW:
# 1. Core setup (non-interactive).
# 2. Interactive: Ask about CSS choice (vanilla CSS + optional Bootstrap or Tailwind) and OPTIONAL gems (devise, etc.).
# 3. `after_bundle`: bundle install ONCE, run generators, and further setup.

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

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

# Gemfile - dotenv only (no CSS gems here)
inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n  gem \"dotenv-rails\""
end

# Layout viewport (works for all)
gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device=device-width, initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

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
file "README.md", <<~MARKDOWN
  Rails app generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).
MARKDOWN

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
css_choice = ask("Choose CSS framework? (b = bootstrap, t = tailwind, v = vanilla/none): ", limited_to: "b t v n").downcase

# Add appropriate gems first and `apply` shared templates (`shared/bootstrap.rb` or `shared/tailwind.rb`) inside `after_bundle` after running `bundle install` with the correct gems already added.
case css_choice
when "b"
  # Core Bootstrap gems
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "sprockets-rails"
      gem "bootstrap", "~> 5.3"
      gem "autoprefixer-rails"
      gem "font-awesome-sass", "~> 6.1"
      gem "simple_form", github: "heartcombo/simple_form"
      gem "sassc-rails"

    RUBY
  end

  # Replace Propshaft with Sprockets if present
  gsub_file("Gemfile", /^gem "propshaft".*\n/, "")

when "t"
  # Tailwind gem
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "tailwindcss-rails"
      gem "simple_form", github: "heartcombo/simple_form"

    RUBY
  end

else
  say "Vanilla CSS - no framework installed.", :yellow
end

# devise
if should_install?("devise", "Install Devise? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
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

# admin (devise required before installation)
if should_install?("admin", "Install Active Admin - a dashboard for CRUD operations on models? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "activeadmin"

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

# navbar (only asks if Bootstrap is added)
if File.read("Gemfile").include?('gem "bootstrap"')
  if should_install?("navbar", "Install NavBar? (y/n)")
    run "curl -L https://raw.githubusercontent.com/lewagon/awesome-navbars/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb"
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

# STEP 3: after_bundle (same structure)
after_bundle do
  # Generators: db + pages controller (Simple Form already done by CSS shared templates)
  rails_command "db:drop db:create db:migrate"

  gemfile = File.read("Gemfile")

  unless gemfile.include?('gem "bootstrap"') || gemfile.include?('gem "tailwindcss-rails"')
    generate("simple_form:install")
  end

  # Generate Pages Controller
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Pages Controller
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]
      def home; end
    end
  RUBY

  # Routes
  route 'root to: "pages#home"'

  # Gitignore + common setup
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*
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
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > rubocop.yml"

  # Initialize Git and make first commit.
  git :init
  git add: "."
  git commit: "-m 'initial commit: new rails app setup with Custom template.'"

  # APPLY shared templates ONLY if their gems were added during interactive setup.
  # TODO: Add more conditional gem checks for each new shared template:
  # File.read() checks if gem was added in Step 2.

  # shared/bootstrap.rb
  if gemfile.include?('gem "bootstrap"')
    apply source_path("shared/bootstrap.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install bootstrap.'"
  end

  # shared/tailwind.rb
  if gemfile.include?('gem "tailwindcss-rails"')
    apply source_path("shared/tailwind.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install tailwind.'"
  end

  # shared/devise.rb
  if gemfile.include?("gem \"devise\"")
    # Gem was added → run shared/devise.rb shared template setup.
    apply source_path("shared/devise.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install devise.'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "better_errors"') || gemfile.include?('gem "annotate"')
    apply source_path("shared/dev_tools.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install dev_tools template gems (annotate, better errors, pry, awesome print, rubocop).'"
  end

  # shared/admin.rb (Devise required before installation)
  if gemfile.include?('gem "activeadmin"')
    apply source_path("shared/admin.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: install active admin.'"
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

  # shared/navbar.rb
  if File.exist?("app/views/shared/_navbar.html.erb")
    apply source_path("shared/navbar.rb")

    # Git
    git add: "."
    git commit: "-m 'feat: add navbar.'"
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
    # Gem was added → run shared/ruby_llm.rb shared template setup.
    apply source_path("shared/ruby_llm.rb")

    # Git
    git add: "."
    git commit "-m 'feat: install ruby_llm.'"
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

    # Git
    git add: "."
    git commit: "-m 'feat: install testing.'"
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate"

  # Git
  git add: "."
  git commit: "-m 'feat: add migration after initial setup.'"
end


# Key features:
# 1. Interactive CSS choice first: `b` → `shared/bootstrap.rb, t` → `shared/tailwind.rb`, `v`/`n` → `vanilla`.

# 2. No overlap: Shared templates check for existing files before installing.

# 3. Standalone shared templates: Can run on existing apps via `rails app:template LOCATION=shared/bootstrap.rb` or `rails app:template LOCATION=shared/tailwind.rb`.

# 4. Vanilla base: Pure Rails 7, no CSS framework unless chosen.

# 5. Neutral flashes: Generic classes that work with vanilla/Bootstrap/Tailwind.
