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
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]factory_bot_rails['"]/)
  say "Adding `factory_bot_rails`...", :blue
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "factory_bot_rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]faker['"]/)
  say "Adding `faker`...", :blue
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "faker"

    RUBY
  end

  gems_added = true
end

unless gemfile.include?(/^gem.*['"]shoulda-matchers['"]/)
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "shoulda-matchers"

    RUBY
  end

  gems_added = true
end

if gems_added
  run "bundle install" unless system("bundle check")
end

# RSpec install
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

# Custom RSpec config
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
  # Without Shoulda:
    # it { expect(user.email).to be_present }
    # it { expect(user.email).to be_valid }
    # it { expect(User).to validate_uniqueness_of(:email) }
  # With Shoulda ✅:
    # it { should validate_presence_of(:email) }
    # it { should validate_uniqueness_of(:email).case_insensitive }
  append_file "spec/spec_helper.rb", <<~RUBY
  # Shoulda Matchers
  RSpec.configure do |config|
    config.include Shoulda::Matchers::ActiveModel
    config.include Shoulda::Matchers::ActiveRecord
  end
  RUBY
end

# Shoulda Matchers full config
inject_into_file "spec/rails_helper.rb", before: "RSpec.configure do |config|" do
  <<~RUBY
    # Shoulda Matchers
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY
end

# Example Factory (User)
unless Dir["spec/factories/*.rb"].any?
  say "Creating example User factory", :blue
  # `mkdir_p("spec/factories.rb")` ensures the full path is built recursively—e.g., creates `spec` first if missing, then `spec/factories.rb`—and returns silently on success. Similar to the Unix `mkdir -p` command, where `-p` creates parent directories as needed.
  mkdir_p "spec/factories"
  create_file "spec/factories/users.rb", <<~RUBY
    RSpec.describe User, type: :model do
      it { should validate_presence_of(:email) }
    end

    FactoryBot.define do
      factory :user do
        sequence(:email) { |n| "user#{n}@example.com"}
        password { "password123"}
        password_confirmation { "password123" }
      end
    end
  RUBY
end

# Example Spec
unless File.exist?("spec/models/user_spec.rb")
  create_file "spec/models/user_spec.rb", <<~RUBY
    require "rails_helper"

    RSpec.describe User, type: :model do
      it "has a valid factory" do
        user = FactoryBot.build(:user)
        expect(user.valid?).to eq(true)
      end

      it { should validate_presence_of(:email) }
      it { should validate_uniqueness_of(:email).case_insensitive }
    end
  RUBY
end

# DOCUMENTATION:
# RSpec docs = https://github.com/rspec/rspec-rails
# FactoryBot docs = https://github.com/thoughtbot/factory_bot
# Faker docs = https://github.com/faker-ruby/faker
#
# Testing (RSpec) common commands:
# `rails spec` = all tests
# `rails spec models` = models only (e.g. `rails spec models:user` = test single model)
# `rails spec requests` = feature specs
# With `test` script (see below), `test` = alias for `rspec`.
#
# --------------

# ADD: `test` script
# PURPOSE: the `test` script replaces (shortens) `rspec` and `spec` keyword commands with `bin/test` and forces rspec to use the exact `Gemfile.lock` versions vs defaulting to the rspec system/global gem version.
#
# PURPOSE BREAKDOWN:
# `bin/test`: shell script wrapper creating `test` command → `bundle exec rspec`.
# Purpose: shortens verbose `bundle exec rspec spec/models` → `bin/test spec/models`.
# Forces Gemfile.lock gem versions (vs global/system rspec mismatch).
# Portable across teams/CI/Docker. Industry standard (rails, rake, setup).
# The language used inside the `bin/test` file is shell script.
#
# CODE BREAKDOWN:
# Shebang `#!/usr/bin/env zsh` breakdown:
# `#!` = magic bytes → executable script.
# `/usr/bin/env` = finds interpreter in $PATH (portable) (i.e. finds zsh anywhere in PATH)
# `env` = portable (macOS/Linux/Docker)
# zsh = preferred shell.
#
#`bundle exec rspec "$@"` runs RSpec via Bundler + forwards all args ($@).
#`bundle exec` = exact Gemfile.lock versions.
#`rspec` = RSpec test runner
#`"$@"` = pass-through: forwards all arguments `bin/test spec/models` → `rspec spec/models`.
#
#`chmod "+x", "bin/test"` = makes executable (+x permission).
  #`chmod` (stands for `change mode` unix permissions) is a Ruby template method. Ruby calls `system("chmod +x bin/test")` under the hood.
  # `+x` Add execute permission (x).
  # Result: `./bin/test` now runs as command.
  # Before: `ls -l bin/test` → `-rw-r--r--` (read-only)
  # After: `ls -l bin/test` → `-rwxr-xr-x` (executable rwx = read/write/execute)
#
# USAGE: (same output)
# (1) `bin/test` → `bundle exec rspec`
# (2) `bin/test spec/models` → `bundle exec rspec spec/models/user_spec.rb`
# (3)`bin/test -f doc` → `bundle exec rspec -f documentation`
#
# SUMMARY:
# 1. create_file → Writes Zsh script to `bin/test` file
# 2. Shebang     → Declares "run me with Zsh" (finds in $PATH)
# 3. Command     → `bundle exec rspec` + arguments (correct gem versions + forwards args)
# 4. chmod +x    → Makes it RUNNABLE like any CLI tool (with rwx permissions)
# Result: `bin/test spec/models` == `bundle exec rspec spec/models`

create_file "bin/test", <<~BASH
  #!/usr/bin/env zsh
  bundle exec rspec "$@"
BASH
chmod "+x", "bin/test"

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

say "✅ Testing installation complete!", :green
