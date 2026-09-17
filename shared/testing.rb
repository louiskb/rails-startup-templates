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
  say "Adding `rspec-rails`...", :cyan
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]factory_bot_rails['"]/)
  say "Adding `factory_bot_rails`...", :cyan
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "factory_bot_rails"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]faker['"]/)
  say "Adding `faker`...", :cyan
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "faker"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]shoulda-matchers['"]/)
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
  say "Running `rails generate rspec:install`...", :cyan
  if system("bundle exec rails generate rspec:install --help > /dev/null 2>&1")
    # `bundle exec rails generate rspec:install, verbose: true`, shows exactly what's happening (with `verbose: true`) like creating files such as `create spec/spec_helper.rb`, `create spec/rails_helper.rb`, etc.
    run "bundle exec rails generate rspec:install", verbose: true
  else
    say "RSpec generator unavailable. Run `bundle install` first.", :yellow
  end
else
  say "RSpec `spec_helper.rb` exists.", :yellow
end

# RSpec config — IMPORTANT: do NOT inject these includes into `spec/spec_helper.rb`.
# `.rspec` requires `spec_helper` *before Rails (and therefore the gems) loads*, so
# `FactoryBot` and `Shoulda::Matchers` aren't defined there yet → `NameError` on
# every run the moment a real spec exists. Instead we put config in `spec/support/*`
# files, which are required from `rails_helper` (after Rails boots) — see the
# `Dir[...].each { require }` line appended to `spec/rails_helper.rb` below.

run "mkdir -p spec/support"

# Shoulda Matchers config.
# Shoulda Matchers provide simple one-line RSpec tests for common Rails behaviors
# like validations, associations, and callbacks — they complement FactoryBot.
# Without Shoulda:
  # it { expect(User).to validate_uniqueness_of(:email) }
# With Shoulda ✅:
  # it { should validate_uniqueness_of(:email).case_insensitive }
# NOTE: the `integrate` block below already mixes the matchers into RSpec — we do
# NOT add separate `config.include Shoulda::Matchers::ActiveModel/ActiveRecord`
# lines (they were the other half of the old `spec_helper` NameError crash).
say "Configuring Shoulda Matchers...", :cyan
create_file "spec/support/shoulda_matchers.rb", <<~RUBY
  # Shoulda Matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
RUBY

# FactoryBot syntax methods — lets specs call `build(:post)` instead of
# `FactoryBot.build(:post)`. Lives in a support file (loaded after Rails) for the
# same reason as above.
say "Configuring FactoryBot RSpec syntax...", :cyan
create_file "spec/support/factory_bot.rb", <<~RUBY
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
RUBY

# Devise test helpers + Rails 8 route loading fix.
# Only ship this when Devise is present in the app.
# Rails 8 LAZILY loads routes in the test environment; Devise registers its route
# mappings only when routes are drawn, so calling `sign_in` in a request/system
# spec raises "Could not find a valid mapping" until routes load. Forcing
# `reload_routes_unless_loaded` before those specs run fixes it. We also include
# Warden's helpers so ActiveAdmin (admin_user scope) specs can use
# `login_as(admin, scope: :admin_user)` — Devise's `sign_in` doesn't reliably
# populate a second Warden scope.
if File.exist?("config/initializers/devise.rb") || File.exist?("app/models/user.rb")
  say "Configuring Devise test helpers (Rails 8 lazy-route fix)...", :cyan
  create_file "spec/support/devise.rb", <<~RUBY
    RSpec.configure do |config|
      config.include Devise::Test::IntegrationHelpers, type: :request
      config.include Devise::Test::IntegrationHelpers, type: :system
      config.include Devise::Test::ControllerHelpers, type: :controller

      # Warden helpers for multi-scope login (e.g. ActiveAdmin's :admin_user):
      #   login_as(admin, scope: :admin_user)
      config.include Warden::Test::Helpers
      config.after(:each) { Warden.test_reset! }

      # Rails 8 lazy-loads routes in test; Devise mappings only register once
      # routes are drawn. Force them before request/system specs run.
      # (Rails 7 draws routes eagerly and has no reload_routes_unless_loaded.)
      if Rails.application.respond_to?(:reload_routes_unless_loaded)
        config.before(:each, type: :request) { Rails.application.reload_routes_unless_loaded }
        config.before(:each, type: :system) { Rails.application.reload_routes_unless_loaded }
      end
    end
  RUBY
end

# `Dir[...]` is Ruby's `Dir.glob()` class method (shorthand syntax). Expands glob patterns into an array of matching file paths.
#
# `Rails.root.join('spec', 'support', '**', '*.rb')`:
# `Rails.root`: Root directory of your Rails app (`/path/to/myapp`)
# `.join()`: Pathname method safely joins path segments (`spec/support/**/*.rb`)
# '**': Recursive wildcard - matches any directories/files zero+ levels deep
# '*.rb': Matches files ending in `.rb`
# Result is a full path array: ["/path/to/myapp/spec/support/foo.rb", "/path/to/myapp/spec/support/helpers/bar.rb", "/path/to/myapp/spec/support/matchers/**/*.rb"]
#
append_file "spec/rails_helper.rb", <<~RUBY
  # Auto-load support files: RSpec auto-requires `spec/support/**/*.rb` by default.
  # Usually would need to add e.g. `require "shoulder/matchers"` manually.
  Dir[Rails.root.join("spec", "support", "**", "*.rb")].each { |f| require f } # Dir[] is sorted since Ruby 3.0
RUBY

# FACTORY LOCATION: keep factories in exactly ONE place (spec/factories).
# factory_bot_rails loads BOTH `test/factories` and `spec/factories`. Earlier
# modules (Devise, Admin) run their model generators BEFORE this module, and with
# the default `test_framework :test_unit` config they drop EMPTY factory stubs in
# `test/factories/{users,admin_users}.rb`. The moment the app later adds a real
# `spec/factories/users.rb`, factory_bot loads both and raises
# `FactoryBot::DuplicateDefinitionError: Factory already registered: user`.
#
# Fix part 1 — point generators at RSpec + spec/factories so any future
# `rails g model X` writes its factory to spec/factories (not test/factories).
if File.exist?("config/application.rb")
  say "Pointing generators at RSpec specs + spec/factories...", :cyan
  gsub_file "config/application.rb",
            /^(\s*)generate\.test_framework :test_unit.*$/,
            "\\1generate.test_framework :rspec, fixtures: true, view_specs: false, helper_specs: false, routing_specs: false\n" \
            "\\1generate.fixture_replacement :factory_bot, dir: \"spec/factories\""
end

# Fix part 2 — remove the empty factory stubs already created in test/factories
# by earlier generators. Only delete EMPTY-body factories so a standalone app's
# real test/factories are never touched. Then drop the dir if it's now empty.
if Dir.exist?("test/factories")
  Dir["test/factories/*.rb"].each do |factory_file|
    if File.read(factory_file) =~ /factory\s+[:"'][\w]+["']?\s+do\s*\n\s*end/
      say "Removing empty factory stub: #{factory_file}", :cyan
      remove_file factory_file
    end
  end
  Dir.rmdir("test/factories") if Dir.empty?("test/factories")
end

# EXAMPLE SPECS: only ones that pass on the app as it is right now. (The old version always
# shipped a Post spec, so every fresh app's suite died with `uninitialized constant Post`.)
api_only = File.exist?("config/application.rb") && File.read("config/application.rb").include?("config.api_only = true")
routes = File.exist?("config/routes.rb") ? File.read("config/routes.rb") : ""
schema = File.exist?("db/schema.rb") ? File.read("db/schema.rb") : ""
run "mkdir -p spec/factories spec/requests"

# User factory, for whichever authentication created the User model.
# `<<~'RUBY'` (quoted) keeps `#{n}` literal in the generated factory.
user_model = File.exist?("app/models/user.rb") ? File.read("app/models/user.rb") : ""
if File.exist?("spec/factories/users.rb")
  say "spec/factories/users.rb exists, leaving it unchanged.", :yellow
elsif user_model.include?("devise")
  create_file "spec/factories/users.rb", <<~'RUBY'
    FactoryBot.define do
      factory :user do
        sequence(:email) { |n| "user#{n}@example.com" }
        password { "password123" }
      end
    end
  RUBY
elsif user_model.include?("has_secure_password")
  create_file "spec/factories/users.rb", <<~'RUBY'
    FactoryBot.define do
      factory :user do
        sequence(:email_address) { |n| "user#{n}@example.com" }
        password { "password123" }
      end
    end
  RUBY
end

# Post example: only when the app HAS a Post model with a title column.
posts_table = schema[/create_table "posts".*?^  end/m].to_s
if File.exist?("app/models/post.rb") && posts_table.match?(/t\.\w+ "title"/)
  post_attributes = [ %(title { "Post \#{SecureRandom.hex(3)}" }) ]
  post_attributes << %(content { "Sample post content." }) if posts_table.match?(/t\.\w+ "content"/)
  post_attributes << "slug { nil } # FriendlyId generates it on save" if posts_table.match?(/t\.\w+ "slug"/)

  unless File.exist?("spec/factories/posts.rb")
    create_file "spec/factories/posts.rb", <<~RUBY
      FactoryBot.define do
        factory :post do
      #{post_attributes.map { |line| "    #{line}" }.join("\n")}
        end
      end
    RUBY
  end

  unless File.exist?("spec/models/post_spec.rb")
    run "mkdir -p spec/models"
    create_file "spec/models/post_spec.rb", <<~RUBY
      require "rails_helper"

      RSpec.describe Post, type: :model do
        it "has a valid factory" do
          expect(build(:post)).to be_valid
        end

        # One-line matchers (Shoulda Matchers). Uncomment the ones your model enforces:
        # it { should validate_presence_of(:title) }
        # it { should validate_uniqueness_of(:title).case_insensitive }
      end
    RUBY
  end
end

# Health check: every Rails 7.1+ app (API or not) serves GET /up.
if routes.include?("rails_health_check") && !File.exist?("spec/requests/health_spec.rb")
  create_file "spec/requests/health_spec.rb", <<~RUBY
    require "rails_helper"

    RSpec.describe "Health check", type: :request do
      it "reports that the app boots" do
        get rails_health_check_path

        expect(response).to have_http_status(:ok)
      end
    end
  RUBY
end

# Home page renders for a visitor (would have caught the PagesController crash).
if !api_only && routes.match?(/^\s*root /) && !File.exist?("spec/system/pages_spec.rb")
  run "mkdir -p spec/system"
  create_file "spec/system/pages_spec.rb", <<~RUBY
    require "rails_helper"

    RSpec.describe "Home page", type: :system do
      before do
        driven_by(:rack_test)
      end

      it "renders for a visitor who isn't signed in" do
        visit root_path

        expect(page.status_code).to eq(200)
        expect(page).to have_css("body")
      end
    end
  RUBY
end

# DOCUMENTATION:
# RSpec docs = https://github.com/rspec/rspec-rails
# FactoryBot docs = https://github.com/thoughtbot/factory_bot
# Faker docs = https://github.com/faker-ruby/faker
#
# TESTING (Safe Versions Only):
# ✅ `bundle exec rspec`                           # All tests
# ✅ `bundle exec rspec spec/models/`              # Models
# ✅ `bundle exec rspec spec/models/user_spec.rb`  # Single file
#
# ❌ `rspec`              # ❌ Global versions = crashes
# ❌ `./bin/test`         # ❌ Disabled temporarily unless enabled below - run `bundle exec rspec` as default.
#
# --------------

# ADD: `test` script (OPTIONAL!)
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
# Shebang `#!/usr/bin/env bash` breakdown:
# `#!` = magic bytes → executable script.
# `/usr/bin/env` = finds interpreter in `$PATH` (portable) (i.e. finds bash anywhere in PATH)
# `env` = portable (macOS/Linux/Docker)
# bash = preferred shell (more universal and portable than zsh).
# Even if your default shell is zsh, using `#!/usr/bin/env bash` in your bin/test script works fine.
# Why it works? `/usr/bin/env bash` finds bash via `$PATH` (always available on macOS), ignoring zsh shell. The kernel reads the shebang, runs `env bash script.sh`, and bash executes the script — zsh terminal just launches it.
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
  # `chmod "+x"` was added as a `create_file` argument so that it can run on file creation. As `chmod "+x" "bin/test"` after the heredoc would run before file creation.
#
# USAGE: (same output)
# (1) `bin/test` → `bundle exec rspec`
# (2) `bin/test spec/models` → `bundle exec rspec spec/models/user_spec.rb`
# (3)`bin/test -f doc` → `bundle exec rspec -f documentation`
#
# SUMMARY:
# 1. create_file → Writes bash script to `bin/test` file
# 2. Shebang     → Declares "run me with bash" (finds in $PATH)
# 3. Command     → `bundle exec rspec` + arguments (correct gem versions + forwards args)
# 4. chmod +x    → Makes it RUNNABLE like any CLI tool (with rwx permissions)
# Result: `bin/test spec/models` == `bundle exec rspec spec/models`
#
# `.executable?` checks 2 things: (1) file exists and (2) has execute permission (`x`). `bin/test` exists (`-rw-r--r--`) but no `x` → returns `false`. After `chmod +x`: `-rwxr-xr-x` → returns `true`.
# `.executable?` returns `false` if file missing OR non-executable.
#
#
# UNCOMMENT TO ENABLE `test` SCRIPT!
#
# unless File.executable?("bin/test")
    #
    #
    # Ruby parses arguments positionally before heredoc resolution (i.e. heredoc body ignored during arg parsing - Ruby scans line for args before evaluating heredoc).
    # That's why `chmod: "+x"` is added as an argument right after `<<~BASH` like `<<~BASH, chmod: "+x"` when the heredoc hasn't closed (with `BASH`).
    # {chmod: "+x"} → config (last arg is Hash → config!)
    # Result: Exactly 3 args → create_file(path, data, config)
    # `chmod: "+x"` (i.e. `chmod "+x"` method) is being called as an argument so that `chmod` is applied to the created file `bin/test` during creation. If `chmod "+x", "bin/test"` is run separately, it would run before the file `bin/test` was created, thus creating errors.
    #
    # `run "mkdir -p bin"` ensures bin/ exists in case it does not (defensive).
    # `mkdir -p` will NOT overwrite the folder if it already exists. Silent success if directory already exists - no error, no overwrite.
    #
    #
    # run "mkdir -p bin"

#     create_file "bin/test", <<~BASH, chmod: "+x"
#     #!/usr/bin/env bash
#     bundle exec rspec "$@"
#   BASH

#   say "`bin/test` executable ready", :green
# end

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

say "✅ Testing installation complete!", :green
