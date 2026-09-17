# shared/bootstrap.rb
# Bootstrap shared template - can be applied to new OR existing Rails apps.

# GUARD 1: Skip if already installed
if File.exist?("app/assets/stylesheets") && Dir.glob("app/assets/stylesheets/*bootstrap*").any?
  say "Bootstrap already installed (stylesheets found), skipping...", :yellow
  exit
end

# STANDALONE SUPPORT: Add gems if missing (existing apps only)
gemfile = File.read("Gemfile")

unless gemfile.match?(/^gem.*['"]bootstrap['"]/)
  say "Adding Bootstrap gems...", :cyan

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

  run "bundle install" unless system("bundle check")
end

# Assets (Le Wagon stylesheets)
run "rm -rf app/assets/stylesheets"
# `vendor/` is NOT removed here (the main bootstrap templates do it in a brand-new app, before
# anything lives there). By now importmap-rails keeps pinned JavaScript in vendor/javascript.
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/rails-8.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-rails-8/README.md"
run "mv app/assets/rails-stylesheets-rails-8 app/assets/stylesheets"

# Sprockets manifest. Never overwrite an existing one: custom.rb writes it before bundling
# and importmap-rails then appends its JavaScript links, which an overwrite would drop
# (every page then raised AssetNotPrecompiledError).
run "mkdir -p app/assets/config"
unless File.exist?("app/assets/config/manifest.js")
  file "app/assets/config/manifest.js", <<~JS
    //= link_tree ../images
    //= link_directory ../stylesheets .css
  JS
end

# importmap serves app/javascript and vendor/javascript through Sprockets.
if File.exist?("config/importmap.rb") && !File.read("app/assets/config/manifest.js").include?("../../javascript")
  run "mkdir -p vendor/javascript"
  append_file "app/assets/config/manifest.js", <<~JS
    //= link_tree ../../javascript .js
    //= link_tree ../../../vendor/javascript .js
  JS
end

# Layout
gsub_file(
  "app/views/layouts/application.html.erb",
  'stylesheet_link_tag :app',
  'stylesheet_link_tag "application"'
)

# Simple Form Bootstrap (test generator availability post-bundle)
if system("bundle exec rails generate simple_form:install --help > /dev/null 2>&1")
  generate("simple_form:install", "--bootstrap")
else
  say "Simple Form Bootstrap generator unavailable. Run `bundle install` first.", :yellow
end

# Bootstrap and Popper
append_file "config/initializers/assets.rb", <<~RUBY
  Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
RUBY

append_file "app/javascript/application.js", <<~JS
  import "@popperjs/core"
  import "bootstrap"
JS

append_file "config/importmap.rb", <<~RUBY
  pin "bootstrap", to: "bootstrap.min.js", preload: true
  pin "@popperjs/core", to: "popper.js", preload: true
RUBY

append_file "app/assets/config/manifest.js", <<~JS
  //= link popper.js
  //= link bootstrap.min.js
JS

# Layout shell: <main> container, footer, Google Fonts <link> tags (sibling shared/layout.rb;
# File.dirname(__FILE__) works for both a local path and a raw GitHub URL).
apply File.join(File.dirname(__FILE__), "layout.rb")

# STANDALONE MIGRATION SUPPORT
main_templates = ["custom.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

say "✅ Bootstrap installation complete!", :green
