# shared/navbar.rb
# Shared NavBar Template

inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
  <<~HTML
    <%= render "shared/navbar" %>
  HTML
end
