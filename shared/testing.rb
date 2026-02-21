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
  say "Running `rails generate rspec:install`...", :blue
  if system("bundle exec rails generate rspec:install --help > /dev/null 2>&1")
    # `bundle exec rails generate rspec:install, verbose: true`, shows exactly what's happening (with `verbose: true`) like creating files such as `create spec/spec_helper.rb`, `create spec/rails_helper.rb`, etc.
    run "bundle exec rails generate rspec:install", verbose: true
  else
    say "RSpec generator unavailable. Run `bundle install` first.", :yellow
  end
else
  say "RSpec `spec_helper.rb` exists.", :yellow
end

# Custom RSpec config
if File.exist?("spec/spec_helper.rb")
  say "Customizing RSpec config...", :blue

  # FactoryBot in Rails + Shoulda Matchers (optional) config.
  # Shoulda Matchers are a Ruby gem that provides simple, one-line RSpec tests for common Rails behaviors like model validations, associations, and callbacks—they complement FactoryBot perfectly by letting you test those models you create with factories.
  # Without Shoulda:
    # it { expect(user.email).to be_present }
    # it { expect(user.email).to be_valid }
    # it { expect(User).to validate_uniqueness_of(:email) }
  # With Shoulda ✅:
    # it { should validate_presence_of(:email) }
    # it { should validate_uniqueness_of(:email).case_insensitive }
  inject_into_file "spec/spec_helper.rb", after: "RSpec.configure do |config|\n" do
    <<~RUBY
      # FactoryBot in Rails
      config.include FactoryBot::Syntax::Methods
      # Shoulda Matchers
      config.include Shoulda::Matchers::ActiveModel
      config.include Shoulda::Matchers::ActiveRecord
    RUBY
  end
end

# Shoulda Matchers full config
say "Configuring Shoulda Matchers...", :blue
run "mkdir -p spec/support"
create_file "spec/support/shoulda_matchers.rb", <<~RUBY
  # Shoulda Matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
RUBY

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
  Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }
RUBY

# Example Factory (User)
unless Dir["spec/factories/*.rb"].any?
  say "Creating example User factory", :blue
  # `mkdir -p`: `mkdir` creates a new directory (folder), `-p` creates parent directories as needed and ensures the full path is built recursively e.g., creates `spec` first if missing, then `spec/factories.rb` and returns silently on success.
  run "mkdir -p spec/factories"

  # `create_file` == (same as) `file` method.
  # `SecureRandom.hex(4)` generates unique 8-char hexadecimal strings (e.g. `a1b2c3d4@example.com`), ensuring FactoryBot creates distinct emails without needing `sequence` (e.g. `sequence(:email) { |n| "user#{n}@example.com" }`).
  # `SecureRandom.hex(4)` generates unique random values each time, never the same chars twice.
  # `SecureRandom.hex` takes a byte length parameter. It generates that many random bytes, then converts each byte to two hex characters (since one byte = 2 hex digits). Key details:
    # Parameter `4` = 4 bytes of randomness
    # Output = 8 hex characters (4 bytes x 2 chars/byte)
    # Each hex char is 0-9 or a-f (16 possible values)
    # Example email = "user_a1b2c3d4@example.com"
  #
  # Rails model attribute block syntax = `password { "password123" }`. In this case, creates unique emails, same password: `user1 = create(:user)  # password123, user_a1b2c3d4@example.com`.
  # {} = block, which become Procs in this context because FactoryBot auto-converts them to run dynamically.
  #
  # Procs capture executable code (like { "password123" }) as a Proc object, turning static assignment into dynamic evaluation each time it's called.
  # Proc: Code block → reusable object. Runs FRESH each call (vs static assignment). Procs are created by: { code } or Proc.new { code }).
  # Static assignment: `password = "password123"` (always same value).
  # Dynamic Proc: `password { "password123" }` (fresh object each time - evaluated fresh per factory) or `email { SecureRandom.hex(4) + "@example.com" }` (runs `SecureRandom` on every user).
  # FactoryBot: email { SecureRandom.hex(4) + "@example.com" } → unique emails per user!
  # Call: `.call()` or `[]` — dynamic evaluation every time
    # FactoryBot proc examples - call with [] or .call():
      # `email_proc = proc { SecureRandom.hex(4) + "@example.com" }`
    # Method 1: .call()
      # `user.email = email_proc.call`  # => "a1b2c3d4@example.com" (fresh!)
    # Method 2: [] (array syntax)
      # `user.email = email_proc[""]`   # => "e5f6g7h8@example.com" (fresh!). [""] = empty strings for argument. If Proc uses args this is where it is added e.g. `name_proc = proc { |name| "#{name}@example.com" }` call later with `name_proc["bob"]` # => "bob@example.com"
    # Why fresh? Proc re-runs SecureRandom each call → always unique emails.
    # Static would repeat same hex forever.
  create_file "spec/factories/users.rb", <<~RUBY
    FactoryBot.define do
      factory :user do
        email { "user_#{SecureRandom.hex(4)}@example.com" }
        password { "password123"}
        password_confirmation { "password123" }
      end
    end
  RUBY
end

# Create example (model) Spec
unless File.exist?("spec/models/user_spec.rb")
  say "Creating example User model spec", :blue
  run "mkdir -p spec/models"
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
main_templates = ["bootstrap.rb", "custom.rb", "tailwind.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :blue
  rails_command "db:migrate"
end

say "✅ Testing installation complete!", :green
