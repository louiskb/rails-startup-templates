# rails-7/bootstrap.rb
# Rails 7 Bootstrap Template

# LOGIC FLOW:
# 1. Setup core styling framework, gems, and setup (non-interactive).
# 2. Interactive: Ask about OPTIONAL gems (devise, etc.).
# 3. `after_bundle`: bundle install ONCE, run generators, and further setup.

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# STEP 1: CORE SETUP

# Helper function for ENV vars
def should_install?(feature, prompt)
  # `ENV[feature.upcase]` finds the VALUE ('true' or 'false') of the ENV var that is set in the /.zshrc functions.
  # Remember, when you set DEVISE=true in the shell (i.e. in the /.zshrc functions), Ruby receives it as the string 'true', not the boolean true.
  env_value = ENV[feature.upcase]

  # Explicit ENV var set to 'true' - install without asking
  # Returns true, exits function
  return true if env_value == 'true'

  # Explicit ENV var set to 'false' - skip without asking
  # Returns false, exits function
  return false if env_value == 'false'

  # ENV var not set (nil) - ask user interactively
  # Returns true if user types 'y', false if 'n'
  yes?(prompt)
end

# Helper function for local/URL paths.
# Depending how the template was installed (either locally or remotely via GitHub) into the new rails app upon execution, the `source_path` method knows how to return the correct file path when combined with the `apply` method to install the correctly specified shared template during execution of the new Rails app.
def source_path(file)
  if __FILE__ =~ %r{https?://}
    "https://raw.githubusercontent.com/louiskb/rails-templates/main/#{file}"
  else
    "#{__dir__}/#{file}"
  end
end

# Gemfile
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

inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n gem \"dotenv-rails\""
end

# Replace Propshaft with Sprockets
gsub_file("Gemfile", /^gem "propshaft".*\n/, "")

# Assets
run "rm -rf app/assets/stylesheets"
run "rm -rf vendor"
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/rails-8.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-rails-8/README.md"

# Sprockets manifest (required for Rails 8)
run "mkdir -p app/assets/config"
file "app/assets/config/manifest.js", <<~JS
  //= link_tree ../images
  //= link_directory ../stylesheets .css
JS

# Layout
gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

gsub_file(
  "app/views/layouts/application.html.erb",
  'stylesheet_link_tag :app',
  'stylesheet_link_tag "application"'
)

# Flashes
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
markdown_readme_content = <<~MARKDOWN
  Rails app generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).
MARKDOWN
file "README.md", markdown_readme_content, force: true

# Generators (SHOULD THIS BE OPTIONAL?)
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

# STEP 2: INTERACTIVE SETUP - Add optional gems to Gemfile
# TODO: Add more interactive gems here later:
# User says YES → add gem to Gemfile
# User says NO → skip (don't add gem)

# devise
if should_install?('devise', "install Devise? (y/n)")
  # Add devise gem to Gemfile (before `bundle install`)
  # Note the blank line inside the heredoc to keep Gemfile formatting clean.
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
end

# STEP 3: AFTER BUNDLE
# Single `bundle install` and further setup including optional shared templates

after_bundle do
  # Generators: db + simple form + pages controller
  rails_command "db:drop db:create db:migrate"
  generate("simple_form:install", "--bootstrap")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

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

  # Pages Controller
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments for Action Mailer
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000 }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "https://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Bootstrap and Popper
  append_file "config/initializers/assets.rb", <<~RUBY
    # `Rails.application.config.assets.precompile` is the Sprockets precompile array (e.g. precompile = ["application.js", "application.css"])
    # `+=` append to existing array
    # `%w(bootstrap.min.js popper.js)` == ["bootstrap.min.js", "popper.js"]
    # Final result after `+=` is e.g. precompile += %w(bootstrap.min.js popper.js) == ["application.js", "application.css", "bootstrap.min.js", "popper.js"]
    Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
  RUBY

  append_file "app/javascript/application.js", <<~JS
    import "@popperjs/core"
    import "bootstrap"
  JS

  append_file "app/assets/config/manifest.js", <<~JS
    //= link popper.js
    //= link bootstrap.min.js
  JS

  # Heroku
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  run "touch '.env'"

  # Rubocop
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > rubocop.yml"

  # APPLY shared templates ONLY if we added their gems during interactive setup.
  # TODO: Add more conditional gem checks for each new shared template:
  # File.read() checks if gem was added in Step 2.

  # shared/devise.rb
  if File.read("Gemfile").include?("gem \"devise\"")
    # Gem was added → run shared/devise.rb shared template setup.
    apply source_path("shared/devise.rb")
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate"

  # Git
  git :init
  git add: "."
  git commit: "-m 'Initial commit and new rails app setup with Bootstrap template.'"
end


# TODO:
#
# EXTRA TODO:
# - Generators (SHOULD THIS BE OPTIONAL?) - inside `bootstrap.rb`.
#
# 1. Build out all the shared templates first before building the main templates.
# 2. After finishing the primary code for the specific main template, add shared templates for interactive mode.
# 3. Once all the templates are completed, create the shell functions inside /.zshrc
