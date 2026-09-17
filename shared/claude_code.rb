# shared/claude_code.rb
# Shared Claude Code Setup Template
# Scaffolds Claude Code configuration for the app as it is right now:
#   CLAUDE.md                    project context Claude reads at the start of every session
#   .claude/settings.json        shared permissions: everyday safe commands allowed, secrets denied
#   .claude/rules/*.md           one rules file per installed module (path-scoped where useful)
#   SETUP_NOTES.md (gitignored)  MCP server suggestions + each module's remaining setup steps
#
# Everything is detected from the app's own files (Gemfile, config, models), so it behaves
# the same from a main template and standalone. Existing files are never overwritten.

# TWO USE CASES:
# 1. Fresh app: applied by a main template after every other module (CLAUDE_CODE=true).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/claude_code.rb`).

require "json"

read_file = ->(path) { File.exist?(path) ? File.read(path) : "" }
gemfile = read_file.call("Gemfile")
has_gem = ->(name) { gemfile.match?(/^\s*gem ["']#{Regexp.escape(name)}["']/) }

app_dir = File.basename(Dir.pwd)
rails_version = Rails::VERSION::STRING
rails8 = Rails::VERSION::MAJOR >= 8
api_only = read_file.call("config/application.rb").include?("config.api_only = true")
dev_database = read_file.call("config/database.yml")[/database: (\w+_development)/, 1] || "#{app_dir.tr("-", "_")}_development"

css = if has_gem.call("bootstrap")
  :bootstrap
elsif has_gem.call("tailwindcss-rails")
  :tailwind
end
auth = if has_gem.call("devise-jwt")
  :devise_jwt
elsif has_gem.call("devise")
  :devise
elsif File.exist?("app/controllers/concerns/authentication.rb")
  :native
end
rspec = has_gem.call("rspec-rails")
simple_form = has_gem.call("simple_form")
installed = {
  admin: has_gem.call("activeadmin"),
  pagination: has_gem.call("pagy"),
  friendly_id: has_gem.call("friendly_id"),
  cloudinary: has_gem.call("cloudinary"),
  ruby_llm: has_gem.call("ruby_llm"),
  security: has_gem.call("rack-attack"),
  annotaterb: has_gem.call("annotaterb"),
  blueprinter: has_gem.call("blueprinter")
}

test_command = rspec ? "bundle exec rspec" : "bin/rails test"
lint_command = if File.exist?("bin/rubocop")
  "bin/rubocop"
elsif read_file.call("Gemfile.lock").match?(/^    rubocop \(/)
  "bundle exec rubocop"
end
server_command = File.exist?("bin/dev") ? "bin/dev" : "bin/rails server"

# ---------------------------------------------------------------------------
# .claude/rules/*.md: short, and only facts the templates set up.
# ---------------------------------------------------------------------------
rules = {}

rules["rails.md"] = <<~MARKDOWN
  # Rails

  - Rails #{rails_version} with PostgreSQL#{api_only ? ", API only (no views, sessions or cookies)" : ""}.
  - Strong parameters: #{rails8 ? "`params.expect(post: [ :title, :body ])`" : "`params.require(:post).permit(:title, :body)`"}.
  - Secrets come from ENV: `ENV.fetch("NAME", nil)`, or `ENV.fetch("NAME")` when the app can't run without it. Local values live in `.env` (gitignored); never hardcode a key or commit `.env`, `config/master.key`, or a key inside `.mcp.json`.
  - Rules that must always hold get a database constraint as well as a validation (`null: false`, a unique index): validations alone race under concurrent requests.
  - Index foreign keys and every column you query by. Commit `db/schema.rb` with its migration.
  - Keep `db/seeds.rb` re-runnable (`find_or_create_by!`).
MARKDOWN

if rspec
  helpers = []
  helpers << "- Devise: `sign_in user` in request and system specs (`spec/support/devise.rb`)." if %i[devise devise_jwt].include?(auth)
  helpers << "- ActiveAdmin: `login_as(admin_user, scope: :admin_user)`." if installed[:admin]
  helpers << "- API: `headers: auth_headers_for(user)` signs in through `/api/v1/users/sign_in` and returns the Authorization header." if auth == :devise_jwt
  rules["testing.md"] = <<~MARKDOWN
    ---
    paths:
      - "spec/**/*.rb"
    ---

    # Testing (RSpec)

    - Run everything with `bundle exec rspec`, one file with `bundle exec rspec spec/models/post_spec.rb`.
    - Factories live in `spec/factories/` (`create(:user)`, `build(:post)`). Never add `test/factories/`: factory_bot loads both folders and raises DuplicateDefinitionError.
    - Gem configuration goes in `spec/support/*.rb` (required from `rails_helper.rb`, after Rails boots), never in `spec_helper.rb`, which loads before the gems exist.
    - Shoulda Matchers for one-line model specs: `it { should validate_presence_of(:title) }`.
    - Request specs (`type: :request`) for controllers and JSON#{api_only ? "" : "; system specs (`type: :system`, `driven_by(:rack_test)` unless the page needs JavaScript) for pages"}.
    #{helpers.join("\n")}
  MARKDOWN
end

case auth
when :devise
  rules["devise.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/controllers/**/*.rb"
      - "app/views/devise/**/*"
      - "app/models/user.rb"
      - "config/initializers/devise.rb"
    ---

    # Authentication (Devise)

    - `ApplicationController` requires sign-in for every action (`before_action :authenticate_user!`). Make an action public in its own controller: `skip_before_action :authenticate_user!, only: %i[index show]`.
    - `current_user` / `user_signed_in?` in controllers and views.
    - Devise's views are in `app/views/devise/`; edit them there.
    - Sign-out links need `data: { turbo_method: :delete }`.
    - Extra sign-up fields must be permitted with `devise_parameter_sanitizer` in `ApplicationController`.
    - Password-reset emails use `config.action_mailer.default_url_options`; the production host is still a TODO in `config/environments/production.rb`.
  MARKDOWN
when :native
  rules["authentication.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/controllers/**/*.rb"
      - "app/views/sessions/**/*"
      - "app/views/registrations/**/*"
      - "app/models/user.rb"
    ---

    # Authentication (Rails 8 generator)

    - Every action requires sign-in (`Authentication` concern). Make one public with `allow_unauthenticated_access only: %i[index show]`.
    - `Current.user` is the signed-in user; `authenticated?` works in views.
    - Sign-up: `RegistrationsController` (`resource :registration`). Sign-in/out: `SessionsController`. Password resets: `PasswordsController` (needs a working mailer).
    - Throttle sensitive actions with `rate_limit to: 10, within: 3.minutes, only: :create`, as `SessionsController` does.
  MARKDOWN
end

if api_only
  auth_lines = if auth == :devise_jwt
    <<~MARKDOWN.chomp
      - Authentication (devise-jwt): `BaseController` requires a token (`before_action :authenticate_user!`); make an endpoint public with `skip_before_action :authenticate_user!`.
      - Tokens are issued by POST `/api/v1/users` and POST `/api/v1/users/sign_in` and revoked by DELETE `/api/v1/users/sign_out` (`JwtDenylist`). Renaming or adding those routes means updating `jwt.dispatch_requests` / `jwt.revocation_requests` in `config/initializers/devise.rb`: warden-jwt matches raw paths, so a stale pattern silently stops issuing or revoking tokens.
      - Keep `devise_for :users, skip: :all` at the root of `config/routes.rb`. Inside a namespace Devise renames the mapping and every request 401s.
      - 401s come from `Api::FailureApp` in the same error shape.
    MARKDOWN
  else
    "- No authentication is installed yet."
  end
  rules["api.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/controllers/**/*.rb"
      - "app/blueprints/**/*.rb"
      - "config/routes.rb"
      - "config/initializers/cors.rb"
    ---

    # JSON API

    - Endpoints live under `/api/v1` (`namespace :api, defaults: { format: :json }`) and inherit `Api::V1::BaseController`.
    - Errors always render `{ error:, code:, details: }` through `render_error`; clients branch on `code`. Handle a new exception type with `rescue_from` in `BaseController`, not ad-hoc JSON.
    - Serialize with Blueprinter (`app/blueprints/`): `render json: { post: PostBlueprint.render_as_hash(post) }`. Never `render json: record`: it leaks every column.
    #{auth_lines}
    - CORS (`config/initializers/cors.rb`): browser origins come from `ALLOWED_ORIGINS`; `Authorization` and the pagination headers are exposed.
    #{installed[:pagination] ? "- Pagination: `@pagy, posts = pagy(:offset, Post.order(:id))`; `BaseController` copies the Pagy headers onto the response." : ""}
  MARKDOWN
end

if installed[:admin]
  rules["active_admin.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/admin/**/*.rb"
    ---

    # ActiveAdmin

    - Dashboard at `/admin`. Admins are `AdminUser` records, separate from `User`. The development seed is admin@example.com / password: never create that account in production.
    - Register a model with `bin/rails generate active_admin:resource Post`, then list `permit_params` in `app/admin/posts.rb` (without them every form field is silently dropped).
    - ActiveAdmin controllers skip the app's `authenticate_user!` (`config/initializers/active_admin_authentication.rb`) and use admin sign-in instead.
  MARKDOWN
end

if installed[:pagination]
  rules["pagination.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/controllers/**/*.rb"
      - "app/views/**/*"
    ---

    # Pagination (Pagy 43)

    - `include Pagy::Method` in the controller (or ApplicationController), then `@pagy, @posts = pagy(:offset, Post.order(:id), limit: 12)`.
    #{api_only ? "- JSON: `BaseController` merges `@pagy.headers_hash` into the response headers." : "- Views: `<%== @pagy.series_nav#{css == :bootstrap ? "(:bootstrap)" : ""} %>` (note `<%==`)."}
    - Pagy 43 removed `Pagy::Backend`, `Pagy::Frontend` and `pagy_bootstrap_nav`: older tutorials don't apply.
    - Global options: `config/initializers/pagy.rb` (`Pagy::OPTIONS`).
  MARKDOWN
end

if installed[:friendly_id]
  rules["friendly_id.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/models/**/*.rb"
      - "app/controllers/**/*.rb"
    ---

    # FriendlyId

    - Slug a model by a public attribute: `bin/rails generate migration AddSlugToPosts slug:string:uniq`, then `extend FriendlyId` and `friendly_id :title, use: :slugged`.
    - Look records up with `Post.friendly.find(params[:id])` (slug or id).
    - Never slug by email or anything private: slugs appear in URLs, logs and browser history.
    - Backfill existing rows after adding the column: `Post.find_each(&:save)`.
  MARKDOWN
end

if installed[:cloudinary]
  rules["cloudinary.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/models/**/*.rb"
      - "app/views/**/*"
      - "app/blueprints/**/*.rb"
      - "config/storage.yml"
    ---

    # Images (Active Storage + Cloudinary)

    - Files are stored on Cloudinary in development and production; `CLOUDINARY_URL` must be set in `.env` and in production.
    - Attach with `has_one_attached :photo` / `has_many_attached :photos`, and permit `:photo` / `photos: []`.
    #{api_only ? "- Return URLs from blueprints: `field(:photo_url) { |post| post.photo.attached? ? post.photo.url : nil }`." : "- Forms: `f.input :photo, as: :file`. Display: `cl_image_tag post.photo.key, width: 400, height: 300, crop: :fill` (Cloudinary resizes by URL)."}
  MARKDOWN
end

if installed[:ruby_llm]
  rules["ruby_llm.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/**/*.rb"
      - "config/initializers/ruby_llm.rb"
    ---

    # RubyLLM

    - Configured in `config/initializers/ruby_llm.rb`; API keys come from ENV (`OPENAI_API_KEY`, …).
    - `RubyLLM.chat.ask("…")`; pick a model with `RubyLLM.chat(model: "…")`.
    - LLM calls are slow and fail: make them in a background job, not inside a web request, and rescue `RubyLLM::Error`.
    - Docs: https://rubyllm.com
  MARKDOWN
end

if installed[:security]
  csp_line = api_only ? "" : "- CSP (`config/initializers/content_security_policy.rb`) nonces scripts per request: no inline `<script>` tags or `onclick=` attributes (use Stimulus). A new external host (CDN, analytics, embed) must be added to the matching directive or the browser blocks it silently; check the console.\n"
  rules["security.md"] = <<~MARKDOWN
    ---
    paths:
      - "config/initializers/rack_attack.rb"
      - "config/initializers/secure_headers.rb"
      - "config/initializers/content_security_policy.rb"
      - "config/routes.rb"
    ---

    # Security headers and rate limiting

    #{csp_line}- secure_headers (`config/initializers/secure_headers.rb`) sets HSTS, frame, content-type and referrer headers#{api_only ? "" : "; its CSP is opted out on purpose (Rails owns CSP)"}.
    - Rack::Attack (`config/initializers/rack_attack.rb`) throttles by path. Change a sign-in or sign-up route and the throttle silently stops applying until its path is updated too.
    - Rack::Attack counts in `Rails.cache`: nothing is throttled in development unless `bin/rails dev:cache` is on.
  MARKDOWN
end

case css
when :bootstrap
  rules["bootstrap.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/views/**/*"
      - "app/assets/stylesheets/**/*"
    ---

    # Bootstrap 5.3

    - The layout supplies `<main class="container …">`, the flashes and the footer. Views start with their content: no top-level `.container`, no flash rendering.
    - Stylesheets follow Le Wagon's structure: variables in `config/_bootstrap_variables.scss` (read before `@import "bootstrap"`), reusable pieces in `components/`, page styles in `pages/`. Add each new partial to its folder's `_index.scss`.
    - Fonts load from `<link>` tags in the layout; `config/_fonts.scss` only names the font families.
    - Dark mode: `data-bs-theme` plus theme-aware utilities (`text-body-secondary`, `bg-body-tertiary`), not `.text-dark`, `.navbar-light` or a hardcoded `white`.
    #{simple_form ? "- Forms: `simple_form_for` with `f.input` and `f.button :submit` (Bootstrap wrappers are configured)." : ""}
  MARKDOWN
when :tailwind
  rules["tailwind.md"] = <<~MARKDOWN
    ---
    paths:
      - "app/views/**/*"
      - "app/assets/tailwind/**/*"
    ---

    # Tailwind CSS 4

    - The layout supplies `<main class="container mx-auto …">`, the flashes and the footer. Views start with their content.
    - Styles live in `app/assets/tailwind/application.css` (`@import "tailwindcss";`, customise with `@theme`). Tailwind 4 has no `tailwind.config.js`.
    - Run the app with `bin/dev` so `tailwindcss:watch` rebuilds. A class only exists if it appears whole in a source file: never build class names from strings.
    #{simple_form ? "- Forms: `simple_form_for` with the `:tailwind` wrapper (`config/initializers/simple_form_tailwind.rb`)." : ""}
  MARKDOWN
end

run "mkdir -p .claude/rules"
rules.each do |filename, content|
  path = ".claude/rules/#{filename}"
  if File.exist?(path)
    say "#{path} exists, leaving it unchanged.", :yellow
  else
    # Conditional lines that interpolate to "" leave blank lines: squeeze runs, trim the end.
    create_file path, "#{content.gsub(/\n{3,}/, "\n\n").rstrip}\n"
  end
end

# ---------------------------------------------------------------------------
# .claude/settings.json: allow everyday safe commands, deny secrets and data loss.
# Nothing that publishes, reads production secrets or runs arbitrary SQL/Ruby.
# ---------------------------------------------------------------------------
bash = ->(command) { [ "Bash(#{command})", "Bash(#{command} *)" ] }
allow = []
allow += bash.call("bin/rails routes")
allow += bash.call(test_command)
allow += bash.call(lint_command) if lint_command
allow += bash.call("bin/brakeman") if File.exist?("bin/brakeman")
allow << "Bash(bin/rails db:migrate)"
allow << "Bash(bin/rails db:migrate:status)"
allow += bash.call("bin/rails generate")
allow += bash.call("bundle exec annotaterb") if installed[:annotaterb]
%w[status diff log show].each { |git_command| allow += bash.call("git #{git_command}") }

deny = [
  "Read(./.env)",
  "Read(./.env.*)",
  "Read(./config/master.key)",
  "Read(./config/credentials/*.key)"
]
deny += bash.call("bin/rails db:drop")
deny += bash.call("bin/rails db:reset")
deny << "Bash(git push --force *)"
deny << "Bash(git push -f *)"

settings_path = ".claude/settings.json"
if File.exist?(settings_path)
  say "#{settings_path} exists, leaving it unchanged.", :yellow
else
  settings = {
    "$schema" => "https://json.schemastore.org/claude-code-settings.json",
    "permissions" => { "allow" => allow, "deny" => deny }
  }
  create_file settings_path, "#{JSON.pretty_generate(settings)}\n"
end

# ---------------------------------------------------------------------------
# CLAUDE.md
# ---------------------------------------------------------------------------
auth_label = {
  devise: "Devise",
  devise_jwt: "Devise + devise-jwt (JWT in the Authorization header)",
  native: "Rails 8 authentication generator"
}[auth]
css_label = { bootstrap: "Bootstrap 5.3 (Sprockets + Le Wagon stylesheets)", tailwind: "Tailwind CSS 4 (tailwindcss-rails)" }[css]

stack_rows = [ "| Framework | Rails #{rails_version}#{api_only ? " (API only)" : ""} |", "| Database | PostgreSQL |" ]
stack_rows << "| CSS | #{css_label} |" if css_label
stack_rows << "| Auth | #{auth_label} |" if auth_label
stack_rows << "| Tests | #{rspec ? "RSpec, FactoryBot, Faker, Shoulda Matchers" : "Minitest"} |"
stack_rows << "| JSON | Blueprinter |" if installed[:blueprinter]

conventions = [
  "- Double quotes for Ruby strings.",
  "- ENV via `ENV.fetch(\"NAME\", nil)`; secrets in `.env` (gitignored), never in code."
]
conventions << "- Forms: `simple_form_for` with `f.input` / `f.button :submit`, never `form_with`." if simple_form && !api_only
conventions << "- The layout supplies the page container: views never add their own top-level container." if read_file.call("app/views/layouts/application.html.erb").include?("<main")
conventions << "- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) (`feat(posts): add comments`); `.githooks/commit-msg` rejects anything else once `bin/setup` has run."

commands = [
  "bin/setup                # install gems, prepare the database, enable the commit-msg hook",
  "#{server_command.ljust(24)} # run the app on http://localhost:3000",
  "#{test_command.ljust(24)} # run the tests"
]
commands << "#{lint_command.ljust(24)} # lint (add -a to autocorrect)" if lint_command
commands << "bin/rails db:migrate     # run pending migrations"

claude_md = <<~MARKDOWN
  # CLAUDE.md

  Guidance for Claude Code in this repository.

  ## What this app does

  <!-- Fill in: who uses the app, what it does, and anything a new developer must know first. -->

  ## Stack

  | | |
  |---|---|
  #{stack_rows.join("\n")}

  Generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates).

  ## Commands

  ```bash
  #{commands.join("\n")}
  ```

  ## Conventions

  #{conventions.join("\n")}

  ## Module rules

  `.claude/rules/` holds one file per installed module; path-scoped rules load when Claude works on matching files:
  #{rules.keys.map { |filename| "- `#{filename}`" }.join("\n")}
MARKDOWN

if File.exist?("CLAUDE.md")
  say "CLAUDE.md exists, leaving it unchanged.", :yellow
else
  create_file "CLAUDE.md", claude_md
end

# ---------------------------------------------------------------------------
# SETUP_NOTES.md (gitignored): personal checklist + MCP suggestions.
# MCP facts checked 2026-09-17: @modelcontextprotocol/server-postgres is archived; DBHub,
# rails-mcp-server 2.0, Heroku's remote server, Cloudinary's and Sentry's remote servers are
# maintained. No vendor documents a Claude Code command for rails-mcp-server.
# ---------------------------------------------------------------------------
todo = [ "- [ ] Fill in \"What this app does\" in `CLAUDE.md`." ]
todo << "- [ ] Set the production mailer host in `config/environments/production.rb` (`TODO_PUT_YOUR_DOMAIN_HERE`)." if read_file.call("config/environments/production.rb").include?("TODO_PUT_YOUR_DOMAIN_HERE")
todo << "- [ ] Set `CLOUDINARY_URL=cloudinary://KEY:SECRET@CLOUD_NAME` in `.env` and in production." if installed[:cloudinary]
todo << "- [ ] Set `OPENAI_API_KEY` (or another provider's key) in `.env` and in production." if installed[:ruby_llm]
todo << "- [ ] Create a real production admin (`AdminUser.create!(…)` in a production console); the seed account is development-only." if installed[:admin]
todo << "- [ ] Set `DEVISE_JWT_SECRET_KEY` in production (`bin/rails secret` makes one); without it tokens are signed with `secret_key_base`." if auth == :devise_jwt
todo << "- [ ] Set `ALLOWED_ORIGINS` (comma-separated) to your web clients' origins in production." if api_only

mcp_rows = [
  "| PostgreSQL ([DBHub](https://github.com/bytebase/dbhub)) | Query the development database and inspect the schema | `claude mcp add --transport stdio db -- npx -y @bytebase/dbhub --dsn \"postgresql://localhost:5432/#{dev_database}\"` |",
  "| [Rails MCP Server](https://github.com/maquina-app/rails-mcp-server) | Read-only introspection of routes, models and schema (2.0 removed code execution) | `gem install rails-mcp-server`, register the project with `rails-mcp-config`, then `claude mcp add rails -- rails-mcp-server` (⚠️ no vendor-documented Claude Code command; check the README) |",
  "| [Heroku](https://devcenter.heroku.com/articles/heroku-remote-mcp-server) | Deploys, logs, config vars, Heroku Postgres | `claude mcp add --transport http heroku https://mcp.heroku.com/mcp` (OAuth) |"
]
mcp_rows << "| [Cloudinary](https://cloudinary.com/documentation/cloudinary_llm_mcp) | Browse and manage uploaded assets | `claude mcp add --transport http cloudinary-asset-mgmt https://asset-management.mcp.cloudinary.com/mcp` (OAuth) |" if installed[:cloudinary]
mcp_rows << "| [Sentry](https://mcp.sentry.dev) (optional) | Errors and traces, once Sentry is set up | `claude mcp add --transport http sentry https://mcp.sentry.dev/mcp` (OAuth) |"

setup_notes = <<~MARKDOWN
  # Setup notes: #{app_dir}

  Written by rails-startup-templates (`shared/claude_code.rb`). **Gitignored:** a personal checklist, not project docs. Delete it once everything is done.

  ## Remaining setup

  #{todo.join("\n")}

  ## MCP servers worth adding

  Add servers with `claude mcp add …` (`--scope project` writes a committed `.mcp.json`).
  **Never put a secret in `.mcp.json`:** reference it as `${VAR}` and export the value in your shell. Run `cat .mcp.json` before the first push.
  GitHub, Context7 and Playwright are often installed globally already: `claude mcp list`.

  | Server | Why | Command |
  |---|---|---|
  #{mcp_rows.join("\n")}

  Add `user:password@` to the DSN if your local PostgreSQL needs them. (The original `@modelcontextprotocol/server-postgres` is archived.)
MARKDOWN

if File.exist?("SETUP_NOTES.md")
  say "SETUP_NOTES.md exists, leaving it unchanged.", :yellow
else
  create_file "SETUP_NOTES.md", setup_notes
end

if File.exist?(".gitignore") && !File.read(".gitignore").include?("SETUP_NOTES.md")
  append_to_file ".gitignore", "\n# Personal setup checklist written by shared/claude_code.rb\nSETUP_NOTES.md\n"
end

say "✅ Claude Code setup complete!", :green
