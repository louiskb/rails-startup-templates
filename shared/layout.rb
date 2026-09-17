# shared/layout.rb
# Shared Layout Shell Template
# Gives app/views/layouts/application.html.erb a page shell for Bootstrap or Tailwind:
# a <main> container around `yield`, a footer partial, and (Bootstrap with Le Wagon's
# stylesheets) Google Fonts loaded from <link> tags instead of a CSS @import.
#
# WHY: the layout supplies the page container, so views never wrap themselves in one.
# Without it every view adds its own `.container`, and adding a layout container later
# means stripping it back out of every view (hit on g-bakes-vegan, 2026-06-13).

# TWO USE CASES:
# 1. Fresh app: applied by rails-7|8/bootstrap.rb and tailwind.rb (Step 1), and by
#    shared/bootstrap.rb and shared/tailwind.rb (custom.rb).
# 2. Existing app: Standalone - `rails app:template LOCATION=shared/layout.rb`.

layout_path = "app/views/layouts/application.html.erb"
gemfile = File.read("Gemfile")
framework = if gemfile.match?(/^\s*gem ["']bootstrap["']/)
  :bootstrap
elsif gemfile.match?(/^\s*gem ["']tailwindcss-rails["']/)
  :tailwind
end

if !File.exist?(layout_path) || framework.nil?
  say "Layout shell skipped: needs app/views/layouts/application.html.erb and Bootstrap or Tailwind.", :yellow
elsif File.read(layout_path).include?("<main")
  say "Layout already has a <main> element, leaving it unchanged.", :yellow
else
  classes = if framework == :bootstrap
    { body: "d-flex flex-column min-vh-100", main: "container py-4 flex-grow-1" }
  else
    { body: "flex min-h-screen flex-col", main: "container mx-auto grow px-4 py-6" }
  end

  gsub_file layout_path, "<body>", %(<body class="#{classes[:body]}">)

  # The main templates inject flashes at column 0; indent them like the rest of <body>.
  # Bootstrap only: a marker line where shared/navbar.rb puts `render "shared/navbar"`.
  navbar_marker = framework == :bootstrap ? %(    <%# Navbar: shared/navbar.rb replaces this line with render "shared/navbar" %>\n) : ""
  gsub_file layout_path, /^[ \t]*<%= render "shared\/flashes" %>\n/, %(#{navbar_marker}    <%= render "shared/flashes" %>\n)

  gsub_file layout_path, /^[ \t]*<%= yield %>\n/, <<~ERB.indent(4)
    <%# The layout supplies the page container: views must not add their own top-level container. %>
    <main class="#{classes[:main]}">
      <%= yield %>
    </main>
    <%= render "shared/footer" %>
  ERB

  say "Layout shell added (main container + footer).", :green
end

footer_path = "app/views/shared/_footer.html.erb"
if framework && !File.exist?(footer_path)
  if framework == :bootstrap
    create_file footer_path, <<~ERB
      <footer class="border-top py-3 mt-auto">
        <div class="container small text-body-secondary">
          &copy; <%= Date.current.year %> <%= Rails.application.class.module_parent_name.underscore.titleize %>
        </div>
      </footer>
    ERB
  else
    create_file footer_path, <<~ERB
      <footer class="mt-auto border-t border-gray-200 py-4">
        <div class="container mx-auto px-4 text-sm text-gray-500">
          &copy; <%= Date.current.year %> <%= Rails.application.class.module_parent_name.underscore.titleize %>
        </div>
      </footer>
    ERB
  end
end

# Google Fonts: Le Wagon's config/_fonts.scss loads them with a CSS @import, which makes the
# browser fetch the compiled stylesheet before it even discovers the fonts. <link> tags with
# preconnect hints in <head> start that download in parallel (web.dev, "Best practices for
# fonts"). The font variables stay in _fonts.scss.
fonts_path = "app/assets/stylesheets/config/_fonts.scss"
fonts_scss = File.exist?(fonts_path) ? File.read(fonts_path) : ""
google_fonts_url = fonts_scss[/^@import url\(['"]?(https:\/\/fonts\.googleapis\.com[^'")]+)['"]?\);/, 1]

if framework == :bootstrap && google_fonts_url && File.exist?(layout_path)
  # Before Rails' "Includes all stylesheet files" comment when present, else the tag itself.
  inject_into_file layout_path, before: /^[ \t]*(<%# Includes all stylesheet files[^\n]*\n[ \t]*)?<%= stylesheet_link_tag/ do
    <<~ERB.indent(4) + "\n"
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link rel="stylesheet" href="#{google_fonts_url.gsub("&", "&amp;")}">
    ERB
  end

  # Remove the @import only once the <link> tags are really in the layout (a customised layout
  # with no stylesheet_link_tag line gets no injection, and would otherwise lose its fonts).
  if File.read(layout_path).include?("fonts.googleapis.com")
    gsub_file fonts_path, /^\/\/ Import Google fonts\n@import url\(.*\);\n/,
      "// Google Fonts load from <link> tags in app/views/layouts/application.html.erb.\n"
    say "Google Fonts moved from a CSS @import to <link> tags in the layout.", :green
  else
    say "No stylesheet_link_tag in the layout: Google Fonts stay as a CSS @import in config/_fonts.scss.", :yellow
  end
end
