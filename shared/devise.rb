# shared/devise.rb
# Shared Devise Template

# Before installing Devise, there needs to be a GUARD CLAUSE to check if Devise is installed already before executing installation.

inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "devise"
  RUBY
end

# AFTER BUNDLE
# Would of ran `bundle install` already if this execution of code is inside `after_bundle`.
# If not, then will have to run "bundle install" before executing the following code. This code needs to be flexible and possible to execute while building the app.
# `run "bundle install"`

generate("devise:install")
generate("devise", "User")

# Application controller

inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base" do
  <<~RUBY
    before_action :authenticate_user!
  RUBY
end

# migrate + devise views
rails_command "db:migrate"
generate("devise:views")

link_to = <<~HTML
  <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
HTML
button_to = <<~HTML
  <div class="d-flex align-items-center">
    <div>Unhappy?</div>
    <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
  </div>
HTML
gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)
