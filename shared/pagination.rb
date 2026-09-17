# shared/pagination.rb
# Shared Pagination Template
# Auto-generates Previous/1 2 3 4/Next links

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/pagination.rb`).

gemfile = File.read("Gemfile")
# API-only apps: no stylesheet; pagination travels in response headers.
api_only = File.exist?("config/application.rb") && File.read("config/application.rb").include?("config.api_only = true")

# GUARD 1: Skip entire template if Pagination is already installed.
if gemfile.match?(/^gem.*['"]pagy['"]/) && File.exist?("config/initializers/pagy.rb")
  say "Pagy already configured (gem + initializer), skipping", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
unless gemfile.match?(/^gem.*['"]pagy['"]/)
  say "Adding pagy gem...", :cyan

  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# Create `pagy.rb` initializer - Configure global options and special features. No generator needed.
unless File.exist?("config/initializers/pagy.rb")
  run "curl -L https://raw.githubusercontent.com/ddnexus/pagy/refs/heads/master/gem/config/pagy.rb > config/initializers/pagy.rb"

  say "Added `pagy.rb` initializer.", :green
end

# Integrate the Stylesheets (CSS or Tailwind) into Rails app for native Pagy helpers. No additional CSS file is needed for Bootstrap.
if api_only
  say "API-only app: no pagination stylesheet (JSON responses carry pagination headers).", :yellow
elsif !gemfile.match?(/^gem.*['"]tailwindcss-rails['"]/) && !gemfile.match?(/^gem.*['"]bootstrap['"]/)
  run "curl -L https://raw.githubusercontent.com/ddnexus/pagy/refs/heads/master/gem/stylesheets/pagy.css > app/assets/stylesheets/pagy.css"

  inject_into_file "app/assets/stylesheets/pagy.css", before: ".pagy {" do
    <<~CSS
      /* For reference: `stylesheet_path = Pagy::ROOT.join('stylesheets/pagy.css')`\n */
    CSS
  end

  say "Added `pagy.css` stylesheet.", :green
elsif gemfile.match?(/^gem.*['"]tailwindcss-rails['"]/)
  run "curl -L https://raw.githubusercontent.com/ddnexus/pagy/refs/heads/master/gem/stylesheets/pagy-tailwind.css > app/assets/stylesheets/pagy-tailwind.css"

  inject_into_file "app/assets/stylesheets/pagy-tailwind.css", before: "@tailwind base;" do
    <<~CSS
      /* For reference: `stylesheet_path = Pagy::ROOT.join('stylesheets/pagy-tailwind.css')`\n */
    CSS
  end

  say "Added `pagy-tailwind.css` stylesheet.", :green
end

# API apps: pagination travels in response headers (exposed by config/initializers/cors.rb).
base_controller = "app/controllers/api/v1/base_controller.rb"
if api_only && File.exist?(base_controller) && !File.read(base_controller).include?("Pagy::Method")
  inject_into_file base_controller, after: "    class BaseController < ApplicationController\n" do
    <<~RUBY.indent(6)
      include Pagy::Method

      # In an action: `@pagy, posts = pagy(:offset, Post.order(:id))`. The headers
      # (link, current-page, page-limit, total-pages, total-count) are added here.
      after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }

    RUBY
  end
end

# Docs GitHub = https://github.com/ddnexus/pagy?tab=readme-ov-file
# Docs Pagy = https://ddnexus.github.io/pagy/guides/quick-start/
# Docs Pagy Stylesheets (CSS or Tailwind) = https://ddnexus.github.io/pagy/resources/stylesheets/
#
# Usage (Pagy 43: `Pagy::Backend`, `Pagy::Frontend` and `pagy_bootstrap_nav` no longer exist):
#   Controller:  include Pagy::Method   (e.g. in ApplicationController)
#                @pagy, @records = pagy(:offset, Model.order(:id), limit: 12)
#   View:        <%== @pagy.series_nav(:bootstrap) %>   (Bootstrap)
#                <%== @pagy.series_nav %>               (plain CSS / Tailwind)
#   JSON API:    response.headers.merge!(@pagy.headers_hash)

# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb", "api.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

say "✅ Pagination installation complete!", :green
