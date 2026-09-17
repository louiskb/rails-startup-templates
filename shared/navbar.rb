# shared/navbar.rb
# Shared NavBar Template (Bootstrap)
# Writes app/views/shared/_navbar.html.erb: Le Wagon's navbar structure and `navbar-lewagon`
# styles, with auth links for the authentication the app actually has (Devise, Rails 8
# authentication, or none). Le Wagon's own partial calls Devise helpers unconditionally,
# which crashed every page of an app without Devise (NoMethodError in Pages#home).

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (after the auth modules).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/navbar.rb`).

navbar_path = "app/views/shared/_navbar.html.erb"
layout_path = "app/views/layouts/application.html.erb"
routes = File.exist?("config/routes.rb") ? File.read("config/routes.rb") : ""
home_path = routes.match?(/^\s*root /) ? "root_path" : %("/")

nav_item = ->(link) { [ %(<li class="nav-item">), %(  #{link}), "</li>" ] }

# Lines inside <ul class="navbar-nav">, relative indentation only.
items = nav_item.call(%(<%= link_to "Home", #{home_path}, class: "nav-link" %>))

if File.exist?("config/initializers/devise.rb")
  items += [ "<% if user_signed_in? %>" ]
  items += nav_item.call(%(<%= link_to "Log out", destroy_user_session_path, data: { turbo_method: :delete }, class: "nav-link" %>)).map { |line| "  #{line}" }
  items += [ "<% else %>" ]
  items += nav_item.call(%(<%= link_to "Log in", new_user_session_path, class: "nav-link" %>)).map { |line| "  #{line}" }
  items += nav_item.call(%(<%= link_to "Sign up", new_user_registration_path, class: "nav-link" %>)).map { |line| "  #{line}" }
  items += [ "<% end %>" ]
elsif File.exist?("app/controllers/concerns/authentication.rb")
  items += [ "<% if authenticated? %>" ]
  items += nav_item.call(%(<%= link_to "Log out", session_path, data: { turbo_method: :delete }, class: "nav-link" %>)).map { |line| "  #{line}" }
  items += [ "<% else %>" ]
  items += nav_item.call(%(<%= link_to "Log in", new_session_path, class: "nav-link" %>)).map { |line| "  #{line}" }
  if routes.include?("resource :registration")
    items += nav_item.call(%(<%= link_to "Sign up", new_registration_path, class: "nav-link" %>)).map { |line| "  #{line}" }
  end
  items += [ "<% end %>" ]
end

navbar_html = <<~ERB
  <nav class="navbar navbar-expand-sm navbar-lewagon border-bottom">
    <div class="container-fluid">
      <%= link_to Rails.application.class.module_parent_name.underscore.titleize, #{home_path}, class: "navbar-brand" %>

      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>

      <div class="collapse navbar-collapse" id="navbarSupportedContent">
        <ul class="navbar-nav">
  ITEMS
        </ul>
      </div>
    </div>
  </nav>
ERB
navbar_html = navbar_html.sub("ITEMS\n", items.map { |line| "        #{line}\n" }.join)

if !File.exist?(navbar_path) || File.read(navbar_path).start_with?("<%# navbar placeholder")
  create_file navbar_path, navbar_html, force: true
else
  say "Custom navbar partial found, leaving it unchanged.", :yellow
end

# Le Wagon's components/_navbar.scss hardcodes a white background, which ignores
# Bootstrap's data-bs-theme dark mode.
navbar_scss = "app/assets/stylesheets/components/_navbar.scss"
if File.exist?(navbar_scss)
  gsub_file navbar_scss, "background: white;", "background: var(--bs-body-bg); // follows data-bs-theme"
end

# Render it in the layout: replace shared/layout.rb's marker line, or inject after <body>.
if File.exist?(layout_path) && !File.read(layout_path).include?('<%= render "shared/navbar"')
  if File.read(layout_path).match?(/^[ \t]*<%# Navbar:.*%>\n/)
    gsub_file layout_path, /^([ \t]*)<%# Navbar:.*%>\n/, %(\\1<%= render "shared/navbar" %>\n)
  else
    inject_into_file layout_path, %(    <%= render "shared/navbar" %>\n), after: /<body[^>]*>\n/
  end
end

say "✅ NavBar installation complete!", :green
