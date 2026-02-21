# shared/pagination.rb
# Shared Pagination Template
# Auto-generates Previous/1 2 3 4/Next links

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/pagination.rb`).

gemfile = File.read("Gemfile")

# GUARD 1: Skip entire template if Pagination is already installed.
if gemfile.match?(/^gem.*['"]pagy['"]/) && File.exist?("config/initializers/pagy.rb")
  say "Pagy already configured (gem + initializer), skipping", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
unless gemfile.match?(/^gem.*['"]pagy['"]/)
  say "Adding pagy gem...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# Create initializer (Pagy's only "setup")
unless File.exist?("config/initializers/pagy.rb")

  if File.read("Gemfile").match?(/^gem.*['"]bootstrap['"]/)
    file "config/initializers/pagy.rb", <<~RUBY
      # Pagy INITIALIZER (no generator needed)
      require "pagy/extras/bootstrap" # Bootstrap nav
      require "pagy/extras/arel" # Optional: better SQL
      Pagy::DEFAULT[:items] = 10 # Items per page
    RUBY
    say "Pagy initializer created for Bootstrap in mind.", :green
  else
    file "config/initializers/pagy.rb", <<~RUBY
      # Pagy INITIALIZER (no generator needed)
      require "pagy/extras/arel" # # Optional: better SQL
      Pagy::DEFAULT[:items] = 10 # Items per page
    RUBY
    say "Pagy initializer created.", :green
  end

end

# Docs = https://github.com/ddnexus/pagy?tab=readme-ov-file
#
# Usage in controllers:
# `app/controllers/your_controller.rb`
# include Pagy::Backend  # Backend pagination logic
#
# def index
#   @pagy, @records = pagy(YourModel.all, items: 10)
# end
#
# Usage in views:
# <!-- Views -->
# <%= pagy_nav(@pagy) %>  <!-- Navigation -->
# <% @records.each do |record| %>
#   <%= record.name %>
# <% end %>

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

say "✅ Pagination installation complete!", :green
