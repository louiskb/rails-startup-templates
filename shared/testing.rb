# shared/testing.rb
# Shared Testing Template
# RSpec + FactoryBot + Faker
# Complete testing: `rails spec` (RSpec)
# Factories: FactoryBot.create(:user)
# Fake data: Faker::Internet.email

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/testing.rb`).

gemfile = File.read("Gemfile")

# GUARD 1: Skip if Testing Template is already installed.
# ** special wildcard that means "match all directories recursively", digging into every folder and subfolder under spec/ to find matching files.
if gemfile.match?(/^gem.*['"]rspec-rails['"]/) && Dir["spec/**/*"].any? && File.exist?("spec/spec_helper.rb")
  say "RSpec + specs directory + spec_helper.rb found, skipping", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gems_added = false

unless gemfile.match?(/^gem.*['"]rspec-rails['"]/)
  say "Adding `rspec-rails`...", :blue
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]factory_bot_rails['"]/)
  say "Adding `factory_bot_rails`...", :blue
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "factory_bot_rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]faker['"]/)
  say "Adding `faker`...", :blue
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "faker"

    RUBY
  end

  gems_added = true
end

if gems_added
  run "bundle install" unless system("bundle check")
end

# RSpec Install
unless File.exist?("spec/spec_helper.rb")
  say "Running `rails generate rspec:install`...", :blue
  if system("bundle exec rails generate rspec:install --help > /dev/null 2>&1")
    run "bundle exec rails generate rspec:install"
  else
    say "RSpec generator unavailable. Run `bundle install` first.", :yellow
  end
else
  say "RSpec `spec_helper.rb` exists.", :yellow
end

# Custom RSpec Config
if File.exist?("spec/spec_helper.rb")
  say "Customizing RSpec config...", :blue

  # FactoryBot in Rails
  inject_into_file "spec/spec_helper.rb", before: "RSpec.configure do |config|" do
    <<~RUBY
      RSpec.configure do |config|
        config.include FactoryBot::Syntax::Methods
      end
    RUBY
  end

  # Shoulda Matchers (optional)
  # Shoulda Matchers are a Ruby gem that provides simple, one-line RSpec tests for common Rails behaviors like model validations, associations, and callbacks—they complement FactoryBot perfectly by letting you test those models you create with factories.
  append_file "spec/spec_helper.rb", <<~RUBY
  # Shoulda Matchers
  RSpec.configure do |config|
    config.include Shoulda::Matchers::ActiveModel
    config.include Shoulda::Matchers::ActiveRecord
  end
  RUBY
end

# Example Factory (User)



# STANDALONE MIGRATION SUPPORT
# Detect if shared template is called from standalone (`rails app:template`) vs from main template (`after_bundle` or e.g. `bootstrap.rb`).


say "✅ Testing installation complete!", :green
