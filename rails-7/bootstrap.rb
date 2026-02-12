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
  # `yes?()` returns true if user types 'y' / 'yes' / 'Y' / 'YES', false if 'n' / 'no' / 'N' / 'NO'. If user hits [Enter] without an answer or inputs anything else = false and defaults to 'no'.
  yes?(prompt)
end

# Helper function for local/URL paths.
# Depending how the template was installed (either locally or remotely via GitHub) into the new rails app upon execution, the `source_path` method knows how to return the correct file path when combined with the `apply` method to install the correctly specified shared template during execution of the new Rails app.
def source_path(file)
  if __FILE__ =~ %r{https?://}
    "https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/#{file}"
  else
    # `File.expand_path` converts a relative path name (short paths like `../foo.rb`) into an absolute path name (full paths like `/home/user/project/foo.rb`). It ignores where your terminal is and uses a safe starting point.
    # Accepts 1-2 string arguments `File.expand_path(file_name, dir_string) → string.`
    # `file_name` (required): The path to expand (relative or absolute). Defaults to empty string if omitted (returns dir_string).
    # `dir_string` (optional): Base directory for relative `file_name`. Defaults to Dir.pwd (current working directory). The base directory (i.e. `__dir__`) is the folder containing the current Ruby template file (e.g. `bootstrap.rb`).
    # Order matters: unlike `File.join`, the base comes second (File.expand_path('foo', '/bar') → '/bar/foo').
    # 2nd argument: __dir__ = `/rails-startup-templates/rails-7` (bootstrap.rb's folder).
    # 1st argument: `../#{file}` = `../devise.rb` (up one from rails-7 → rails-startup-templates, then → `devise.rb`).
    # It does not reach `shared/devise.rb` with the pure `../#{file}` as that stops at the root + `file` BUT the argument value passed into `file` is `shared/devise.rb`. Therefore, the result is the full path from `rails-startup-template/rails-7/devise.rb` to `rails-startup-templates/shared/devise.rb` in the sibling folder.
    File.expand_path("../#{file}", __dir__)
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
run "mv app/assets/rails-stylesheets-rails-8 app/assets/stylesheets"

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

# STEP 2: INTERACTIVE SETUP - Add optional gems to Gemfile
# TODO: Add more interactive gems here later:
# User says YES → add gem to Gemfile
# User says NO → skip (don't add gem)

# devise
if should_install?("devise", "install Devise? (y/n)")
  # Add devise gem to Gemfile (before `bundle install`)
  # Note the blank line inside the heredoc to keep Gemfile formatting clean.
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
end

# image_uploading_cloudinary
if should_install?("image_uploading_cloudinary", "install image uploading with Cloudinary? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "cloudinary"

    RUBY
  end
end

# navbar
if should_install?("navbar", "install NavBar? (y/n)")
  run "curl -L https://raw.githubusercontent.com/lewagon/awesome-navbars/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb"
end

# ruby_llm
if should_install?("ruby_llm", "install ruby_llm? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "ruby_llm"

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
  mailer_development = <<~RUBY
    config.action_mailer.default_url_options = { host: "http://localhost:3000" }
  RUBY

  mailer_production = <<~RUBY
    config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }
  RUBY

  environment mailer_development, env: "development"
  environment mailer_production, env: "production"

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

  # Initialize Git and make first commit.
  git :init
  git add: "."
  git commit: "-m 'initial commit: new rails app setup with Bootstrap template.'"

  # APPLY shared templates ONLY if we added their gems during interactive setup.
  # TODO: Add more conditional gem checks for each new shared template:
  # File.read() checks if gem was added in Step 2.

  # shared/devise.rb
  if File.read("Gemfile").include?("gem \"devise\"")
    # Gem was added → run shared/devise.rb shared template setup.
    apply source_path("shared/devise.rb")
    git add: "."
    git commit: "-m 'feat: install devise.'"
  end

  if File.read("Gemfile").include?('gem "cloudinary"')
    apply source_path("shared/image_upload_cloudinary.rb")
    git add: "."
    git commit: "-m 'feat: install active storage and cloudinary.'"
  end

  # shared/navbar.rb
  if File.exist?("app/views/shared/_navbar.html.erb")
    apply source_path("shared/navbar.rb")
    git add: "."
    git commit: "-m 'feat: add NavBar."
  end

  # shared/ruby_llm.rb
  if File.read("Gemfile").include?("gem \"ruby_llm\"")
    # Gem was added → run shared/ruby_llm.rb shared template setup.
    apply source_path("shared/ruby_llm.rb")
    git add: "."
    git commit "-m 'feat: install ruby_llm.'"
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate"

  # Git
  git add: "."
  git commit: "-m 'feat: add migration after initial setup.'"
end


# TODO:
#
# Fix devise `db:migrate` conditional. Devised shared template does not detect if being called from standalone or main template.
#
# 1. Build out all the shared templates first before building the main templates.
# 2. After finishing the primary code for the specific main template, add shared templates for interactive mode.
# 3. Once all the templates are completed, create the shell functions inside /.zshrc
