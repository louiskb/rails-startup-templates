# shared/navbar.rb
# Shared NavBar Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/navbar.rb`).

# STANDALONE SUPPORT: If the `_navbar.html.erb` partial does not exist, create a new one.
# Fresh apps: main template already added NavBar partial → this skips.
if !File.exist?("app/views/shared/_navbar.html.erb")
  run "curl -L https://raw.githubusercontent.com/lewagon/awesome-navbars/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb"
end

# GUARD 1: Skip if navbar is already fully integrated throughout the app.
layouts_application = File.read("app/views/layouts/application.html.erb")
if !layouts_application.include?('<%= render "shared/navbar" %>')
  say "Integrating NavBar throughout the app..."

  inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
    <<~HTML
      <%= render "shared/navbar" %>
    HTML
  end
end

say "✅ NavBar installation complete!", :green
