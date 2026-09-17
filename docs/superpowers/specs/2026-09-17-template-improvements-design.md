# Template improvements: pending fixes, suggestions and two new subsystems

Date: 2026-09-17 · Branch: `feat/template-improvements`

## 1. Scope

Source: the **Pending Ideas** in `~/.claude/notes/rails-template-improvements.md`, the
louisb-portfolio findings (2026-07-04) and the nightjar smoke-test finding (2026-09-17). Plus
bugs found while reading the code, which Louis chose to fix in the same run.

Decisions already taken (2026-09-17):

| Fork | Decision |
|---|---|
| API mode | New `rails-8/api.rb`, Rails 8 only, run with `rails new --api` |
| Claude Code | New `CLAUDE_CODE` module, prompted like the others (on in `-all`, off in `-min`) |
| Conventional commits | README note **and** a versioned `commit-msg` hook, always on |
| Extra bugs | Fix them in this run |

## 2. Baseline (current templates, generated 2026-09-17, Rails 8.1.3.1)

| App | Result |
|---|---|
| `custom.rb`, all modules off | `GET /` → **500** `ArgumentError` |
| `bootstrap.rb`, `TESTING=true` | `GET /` → 500; `rspec` → **0 examples, `NameError: uninitialized constant Post`** |
| `tailwind.rb`, native auth | `pages_controller.rb` is a **syntax error**; `GET /` → 500 |
| `bootstrap.rb`, `NAVBAR=true` | 500; with PagesController patched, `NoMethodError in Pages#home` (Devise helpers) |
| `bootstrap.rb`, Devise + FriendlyId | no `friendly_id` initializer, no `friendly_id_slugs` migration |
| RuboCop (omakase) | 4 / 193 / 15 / 192 / 201 offenses. All "Safe Correctable". `rubocop -a` → 0, and `-A` gives a byte-identical result |

## 3. Part A — bug fixes in existing flows

**A1. PagesController crashes every app without Devise.** All six main templates write
`skip_before_action :authenticate_user!` into PagesController, which raises when the callback
doesn't exist. Fix: main templates write PagesController **without** it. The auth module that
defines the callback adds the matching skip:
- `shared/devise.rb` → `skip_before_action :authenticate_user!, only: :home`
- `shared/authentication.rb` → `allow_unauthenticated_access only: :home`

Each is injected after the full `class PagesController < ApplicationController` line, only if
PagesController exists and doesn't already carry it (standalone-safe).

**A2. `shared/authentication.rb` (Rails 8 native auth).**
- Injects after `"class PagesController"`, splitting the class line → syntax error. Fixed by A1.
- `allow_unauthenticated_access!` → `allow_unauthenticated_access only: %i[new create]`.
- `permit(:email, …)` → `params.expect(user: [ :email_address, :password, :password_confirmation ])`.
- CSS detection uses `*bootstrap*` stylesheets (never matches Le Wagon's layout) and
  `config/tailwind.config.js` (Tailwind 4 doesn't create it). Detect from the Gemfile instead.
  `shared/tailwind.rb`'s "already installed" guard has the same `tailwind.config.js` blind spot
  (a re-run re-installs). It also checks `app/assets/tailwind/application.css`.
- The sign-up view renders `shared/flashes`, which the layout already renders → drop it.

**A3. `shared/friendly_urls.rb`.**
- `run "bundle_install"` → `bundle install`.
- It never runs `rails generate friendly_id`, so there's no initializer and no slugs table, and
  the guard can never be satisfied. Run the generator unless the initializer exists.
- The "User model exists…, skipping" message prints when there is **no** User model. Fix the
  wording.
- The routes comment is injected on every run. Guard it.
- The injected `extend FriendlyId` lines land at column 0. Indent them.

**A4. Navbar calls Devise helpers without Devise.** The Le Wagon partial uses `user_signed_in?`,
`new_user_session_path` and `destroy_user_session_path`. Fix: `shared/navbar.rb` writes its own
partial, keeping Le Wagon's structure and `navbar-lewagon` class, with one auth branch chosen at
install time:
- **Devise:** the current links.
- **Native auth:** `authenticated?`, `new_session_path`, `session_path` with
  `turbo_method: :delete`.
- **None:** brand plus a Home link.

It drops `navbar-light` (deprecated in Bootstrap 5.2, and ignores `data-bs-theme`), which covers
the louisb-portfolio `.text-dark` note for template-emitted markup. Main templates write a
placeholder partial as the "navbar chosen" flag. `navbar.rb` replaces a placeholder or a
missing file, and never a customised one. Since `<body>` gains classes (B1), injection matches
`/<body[^>]*>\n/`.

**A5. Dead viewport `gsub`s.** Rails 7.1 and 8.1 both generate
`content="width=device-width,initial-scale=1"` with no space. The bootstrap and tailwind gsubs
(with a space) never match, and the custom ones also have a `device=device-width` typo.
`shrink-to-fit=no` has been obsolete since iOS 9.3. Fix: remove the gsub from all six templates.

**A6. README and `shell-functions.txt` URLs 404.**
- README Quick Start uses `/main/` → `/refs/heads/master/` (verified: `main` 404s, `master` 200s).
- `RAILS_TEMPLATES_BASE` example lacks the branch → add `/refs/heads/master`.
- Rails pins `_8.1.2_` → `_8.1.3.1_`, matching the installed versions and the workbench zshrc.

**A7. `shared/dev_tools.rb`** injects `better_errors` after `"group :development do \n"` (stray
space), so standalone installs silently skip it. Remove the space.

**A8. Testing module: green `rspec` out of the box** (the pending "Testing module" note).
- The Post factory and spec are generated only when `app/models/post.rb` exists and
  `db/schema.rb` has a `posts` table with a `title` column. `slug { nil }` is added only when that
  table has a `slug` column. Validation matchers ship commented out, as examples (they assert
  validations the app may not have).
- `spec/system/pages_spec.rb` is created only for a non-API app whose routes define `root`. It
  asserts the page renders (status 200, a `body`), not a "Welcome" string no template writes.
- New `spec/requests/health_spec.rb`: `GET /up` → 200 (Rails 7.1+ and API apps both have it).
- New `spec/factories/users.rb` when a User model exists: `email` for Devise, `email_address`
  for native auth. The API users spec (D) needs it.
- Single quotes in the `spec/support` require line → double (omakase).

## 4. Part B — suggestions on existing flows

**B1. Layout shell (Bootstrap; Tailwind too, see open question Q3).** The layout supplies the
page container, so views never add their own:

```erb
<body class="d-flex flex-column min-vh-100">
  <%= render "shared/navbar" %>     <%# only when the Navbar module is installed %>
  <%= render "shared/flashes" %>
  <%# The layout supplies the page container: views must not add their own top-level .container. %>
  <main class="container py-4 flex-grow-1">
    <%= yield %>
  </main>
  <%= render "shared/footer" %>
</body>
```

- `shared/_footer.html.erb`: `border-top`, `text-body-secondary`, © year + app name. Those
  classes follow `data-bs-theme`, so the footer works in dark mode.
- Without the Navbar module, a one-line ERB comment marks where `render "shared/navbar"` goes.
- Applied in `rails-7/bootstrap.rb`, `rails-8/bootstrap.rb` and `shared/bootstrap.rb`
  (custom + Bootstrap).

**B2. Google Fonts via `<link>`, not CSS `@import`.**
- After unzipping Le Wagon's stylesheets, remove the `@import url(…)` line from
  `config/_fonts.scss` and leave a comment saying where fonts load. The font variables stay.
- Inject into the layout `<head>`, before the stylesheet tag: preconnect to
  `fonts.googleapis.com`, preconnect to `fonts.gstatic.com` with `crossorigin`, then the css2
  stylesheet link for the same two families (Nunito, Work Sans 400/700).
- The Security module's CSP already allows both hosts.
- Source: web.dev *Best practices for fonts*: `<link>` includes a preconnect hint, so the
  stylesheet arrives faster than with `@import`.

**B3. `_body.scss` dark-theme trap: no change, false premise.** Le Wagon's rails-8 stylesheets
contain no `_body.scss`. louisb-portfolio's `components/_body.scss` was added in that repo
(`ba6e475`, 2025-11-14). Correct the note instead of the template.

**B4. `.gitignore` awareness.** All seven main templates append:
```
# Secrets: never commit these. Before a first push, also check .mcp.json:
# MCP configs can embed API keys. Reference them as ${VAR} instead.
# (Rails already ignores config/master.key and config/credentials/*.key.)
.env*
!.env.example

# Claude Code: personal machine-local settings (.claude/settings.json IS shared and committed)
.claude/settings.local.json

# Editor and OS files
*.swp
.DS_Store
```

**B5. Fresh apps pass their own RuboCop.**
- Template-authored heredocs use double quotes and omakase spacing. That covers
  `simple_form_tailwind.rb`, the testing support files, and the injected snippets.
- Near the end of `after_bundle`, every main template autocorrects generator output it doesn't
  control:
  - **Rails 8:** `bin/rubocop -a` when `bin/rubocop` exists.
  - **Rails 7:** `bundle exec rubocop -a` when RuboCop is in the bundle; Rails 7.1 generates
    none, so this means DEV_TOOLS.
- Commit: `style: autocorrect RuboCop offenses in generated code`, guarded against an empty
  commit.
- Safe `-a` only; `-A` changed nothing more in the baseline.

**B6. Conventional commits.** New dual-mode module `shared/conventional_commits.rb`, applied last
by every main template:
- `.githooks/commit-msg` (bash, executable) accepts
  `^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\(scope\))?!?: .+` and lets
  git's own `Merge` / `Revert` / `fixup!` / `squash!` / `amend!` messages through. Anything else
  is rejected with the format and two examples.
- `git config core.hooksPath .githooks` (no global hooksPath exists to override).
- `bin/setup` also sets it, so fresh clones get the hook.
- The generated README gains a short "Commit messages" section.
- The template's own non-conventional messages are renamed:
  - `initial commit: …` → `chore: initial commit from the <X> template`
  - `feat: add migration after initial setup.` → `chore(db): run migrations after module setup`
- The hook is installed **after** all template commits, then committed as
  `chore: enforce conventional commits with a commit-msg hook`, a commit that passes it.
- Guard: skip if `.githooks/commit-msg` exists.

## 5. Part C — new: Claude Code setup module (`CLAUDE_CODE`)

`shared/claude_code.rb`, dual-mode and idempotent: each file is written only if absent.

- **Invocation:** main templates ask
  `should_install?("claude_code", "Set up Claude Code (CLAUDE.md, .claude/ rules and settings)? (y/n)")`
  in Step 2. The answer is kept in a local variable, which the `after_bundle` block closes over,
  so no marker file gets committed. The module is applied after every other module, so it can
  see what's installed.
- **Detection:** everything is read from the app itself, not template variables, so standalone
  mode works the same:
  - Rails version
  - API mode (`config.api_only = true`)
  - CSS: `bootstrap` or `tailwindcss-rails` gem
  - Auth: Devise, devise-jwt, or native (`app/controllers/concerns/authentication.rb`)
  - Gems for each module: `rspec-rails`, `activeadmin`, `pagy`, `friendly_id`, `cloudinary`,
    `ruby_llm`, `rack-attack`, `annotaterb`, `blueprinter`, `rack-cors`
- **Writes:**
  - **`CLAUDE.md`** (under 200 lines):
    - a "What this app does" section for the owner to fill in
    - a stack table
    - commands: `bin/setup`, `bin/dev`, the test command, `bin/rubocop`, db
    - conventions: `simple_form_for` when present, double quotes, `ENV.fetch("X", nil)`, the
      layout supplies the container, Conventional Commits enforced by hook
    - the list of installed modules, pointing at `.claude/rules/`
  - **`.claude/settings.json`:**
    - `$schema` (`https://json.schemastore.org/claude-code-settings.json`)
    - **allow**, space-wildcard syntax: `bin/rails routes`, `bin/rails test`, `bundle exec rspec`,
      `bin/rubocop` and `bin/brakeman` (each only when the binstub exists; Rails 7.1 has
      neither), `bin/rails db:migrate`, `bin/rails db:migrate:status`,
      `bin/rails generate`, `git status` / `diff` / `log` / `show`, and `bundle exec annotaterb`
      when installed
    - **deny:** `Read(./.env)`, `Read(./.env.*)`, `Read(./config/master.key)`,
      `Read(./config/credentials/*.key)`, `Bash(bin/rails db:drop *)`,
      `Bash(bin/rails db:reset *)`, `Bash(git push --force *)`
    - Nothing that publishes, touches production secrets, or runs arbitrary SQL or Ruby
      (matches the 2026-09-17 Vegainz prune).
  - **`.claude/rules/*.md`**, each under ~40 lines, with `paths:` frontmatter where the rule is
    file-specific, one per installed module:
    - `rails.md` (always)
    - `testing.md` (`spec/**`)
    - `devise.md` or `authentication.md`
    - `api.md` (`app/controllers/api/**`, `app/blueprints/**`)
    - `active_admin.md` (`app/admin/**`)
    - `pagination.md`, `friendly_id.md`, `cloudinary.md`, `ruby_llm.md`
    - `security.md` (the three security initializers)
    - `bootstrap.md` or `tailwind.md` (`app/views/**`, stylesheets)

    Content states what the templates actually set up, e.g.:
    - CSP nonces mean no inline `<script>`
    - Rack::Attack paths must follow route changes
    - JWT dispatch regexes must match the session routes
    - Pagy 43 API (`include Pagy::Method`, `pagy(:offset, …)`, `@pagy.series_nav(:bootstrap)`,
      `@pagy.headers_hash`)
  - **`SETUP_NOTES.md`**, gitignored, appended to `.gitignore`:
    1. **MCP suggestions** for the detected stack, each with a `claude mcp add` command, a
       maintenance note, and an "unverified command" flag where no vendor documents one:
       - Postgres: `@bytebase/dbhub`, or Postgres MCP Pro in restricted mode
       - Rails: `rails-mcp-server` 2.0
       - Heroku: the remote `https://mcp.heroku.com/mcp`
       - Cloudinary: the remote asset-management server, `--transport http`, when Cloudinary is
         installed
       - Sentry: optional
       - The note says GitHub / Context7 / Playwright are usually global plugins already.
    2. The `.mcp.json` secrets reminder (use `${VAR}`; check before first push).
    3. Each installed module's post-install steps, gathered from the `# POST-INSTALL` comments
       (Cloudinary URL, OpenAI key, admin user, `DEVISE_JWT_SECRET_KEY`, `ALLOWED_ORIGINS`, …).
- **Commit:** `chore: add Claude Code project setup`.

## 6. Part D — new: API-only template (`rails-8/api.rb`)

Modeled on the Vegainz API (Rails 8.1.3.1, devise 5.0.4, devise-jwt 0.13.0, blueprinter 1.3.0,
rack-cors 3.0.0, rack-attack 6.8), minus its app-specific code.

**Invocation:** `rails _8.1.3.1_ new app --api -d postgresql -m rails-8/api.rb`. The template
aborts with a clear message if `options[:api]` is false. Shell functions: `rails8-api`
(interactive), `rails8-api-all`, `rails8-api-min`.

**Core (always):**
- ruby pin, `dotenv-rails`, `rack-cors`, `blueprinter`
- generators config
- README with an API section
- `.gitignore` block (B4)
- `config/initializers/cors.rb`: origins from `ENV.fetch("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:5173,http://localhost:8081")`,
  split and stripped; `resource "*"`, `headers: :any`, all methods,
  `expose: %w[Authorization link current-page page-limit total-pages total-count]`,
  `max_age: 600`
- `Api::V1::BaseController < ApplicationController`:
  - `wrap_parameters false`
  - one error shape `{ error, code, details }` via `render_error`
  - `rescue_from` `ActiveRecord::RecordNotFound` → 404 `not_found`,
    `ActionController::ParameterMissing` → 400 `parameter_missing`,
    `ActiveRecord::RecordInvalid` → 422 `invalid_input` with `record.errors`
- `routes.rb`: `namespace :api, defaults: { format: :json } { namespace :v1 { … } }`

**Prompts:** DEVISE, TESTING, DEV_TOOLS, SECURITY, PAGINATION, IMAGE_UPLOAD_CLOUDINARY, RUBY_LLM,
CLAUDE_CODE.
- Not offered: AUTH (native auth is cookie-session based), NAVBAR, FRIENDLY_URLS, ADMIN
  (ActiveAdmin needs the full view stack).
- Devise is the latest version: the 4.9 pin exists only for ActiveAdmin.

**API branches in shared modules** (detected via `config.api_only = true`):
- **`devise.rb`:**
  - Gems: `devise` + `devise-jwt`. No `devise:views`.
  - `ApplicationController` includes `ActionController::MimeResponds` and
    `Devise::Controllers::Helpers` (Vegainz gotcha 2).
  - BaseController gains `before_action :authenticate_user!`.
  - `devise.rb` gets `navigational_formats = []` and a `jwt` block:
    - secret `ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }`
    - dispatch on POST `/api/v1/users/sign_in` and POST `/api/v1/users`
    - revoke on DELETE `/api/v1/users/sign_out`
    - each regex with the optional `(\.json)?` suffix (Vegainz audit M1)
    - 24h expiry
  - `JwtDenylist` model + migration (unique `jti`, `exp`).
  - User gets `:jwt_authenticatable, jwt_revocation_strategy: JwtDenylist`.
  - Routes: `devise_for :users, skip: :all` at the root, plus `devise_scope :user` routes inside
    `api/v1` (gotcha 1).
  - `Api::V1::Users::SessionsController`: `respond_with` renders the user;
    `skip_before_action :verify_signed_out_user, raise: false`; `authenticate_user!` on destroy;
    `head :no_content` (gotcha 4).
  - `Api::V1::Users::RegistrationsController#create`:
    `warden.set_user(resource, scope: :user, store: false)` (gotcha 3), 201 + user, or 422 in the
    error shape.
  - `UserBlueprint` (`id`, `email`, `created_at`).
  - Example authenticated endpoint `GET /api/v1/me` → `Api::V1::MeController`.
- **`testing.rb`:**
  - No system spec.
  - `spec/support/api_auth.rb` provides `auth_headers_for(user)` (real sign-in, reuses the
    header, as in Vegainz).
  - `spec/requests/api/v1/users_spec.rb` covers:
    - sign-up returns 201 + `Authorization`
    - sign-in returns the header
    - `/me` with token → 200; without → 401
    - sign-out → 204
    - the revoked token → 401
- **`security.rb`:**
  - Skip the Rails CSP initializer (no HTML).
  - Rack::Attack throttles POST `/api/v1/users/sign_in` (10/min/IP), POST `/api/v1/users`
    (10/hour/IP), `/api/` (600/5 min/IP).
  - JSON 429 responder in the error shape.
- **`pagination.rb`:**
  - No stylesheet download.
  - BaseController `include Pagy::Method` plus
    `after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }`.
  - While in this file, fix the stale POST-INSTALL comments (`Pagy::Backend` / `Pagy::Frontend`
    / `pagy_bootstrap_nav` are gone in Pagy 43).
- **`dev_tools.rb`:** skip `better_errors` / `binding_of_caller` (HTML error pages). Keep the rest.

## 7. After-bundle order (all main templates)

1. db prep → generators → PagesController (no auth skip) → root route
2. `.gitignore`, mailer, framework assets, Heroku/Node pins, `.env`
3. `git init` → `chore: initial commit from the <X> template`
4. Modules, in the current order, then `claude_code` (if chosen)
5. `db:migrate db:seed` → `chore(db): run migrations after module setup` (guarded)
6. RuboCop autocorrect → `style: …` (guarded)
7. `conventional_commits` → hook commit
8. Completion message

## 8. Verification

Every app is generated with the real template in the scratchpad; test DBs are dropped afterwards.

| App | Proof |
|---|---|
| Rails 8 `custom.rb`, all off | exit 0 + completion message; `GET /` 200; `bin/rubocop` 0 offenses; clean tree; `git log` all conventional; hook rejects `bad message`, accepts `fix: x` |
| Rails 8 `bootstrap.rb`, all off | Browser, desktop + 390px: container main, footer at the bottom, no navbar; Network shows Google Fonts CSS + woff2 200; computed body font is Work Sans |
| Rails 8 `bootstrap.rb` `-all` + `CLAUDE_CODE` | `rspec` green; browser: Devise navbar logged out → sign up → logged in → sign out; CSP nonce header matches importmap tag; `.claude/` + CLAUDE.md contents reviewed; `SETUP_NOTES.md` ignored; 0 offenses |
| Rails 8 `tailwind.rb` `-all` | `rspec` green; 0 offenses; browser screenshot |
| Rails 8 `tailwind.rb`, native auth + TESTING | browser: home logged out 200, sign-up creates a user and signs in, sign-out; `rspec` green |
| Rails 8 `bootstrap.rb`, NAVBAR only | browser: navbar with brand + Home, no crash |
| Rails 8 `custom.rb` + Bootstrap | layout shell present (via `shared/bootstrap.rb`) |
| Rails 8 `api.rb` `-all` | `rspec` green (users spec); curl: sign-up → `Authorization`; `/me` 200 with token, 401 JSON without; sign-out 204; revoked token 401; CORS preflight exposes `Authorization`; 0 offenses |
| Rails 8 `api.rb` `-min` | exit 0; `/up` 200; 0 offenses |
| Rails 7 `custom.rb` all off, `bootstrap.rb` `-all`, `tailwind.rb` all off | exit 0; `GET /` 200; `-all` `rspec` green and RuboCop clean |
| Standalone: `claude_code.rb`, `friendly_urls.rb`, `navbar.rb`, `conventional_commits.rb` on an existing app | installs; a second run changes nothing |

## 9. Docs

- README: API template, `CLAUDE_CODE` row, conventional-commits behaviour, fixed URLs, shell
  functions (19 names).
- `shell-functions.txt`.
- Repo `CLAUDE.md`: ENV list, structure.
- `folder-structure.txt`.
- `~/.claude/notes/rails-template-improvements.md`: move items to Implemented, correct the
  `_body.scss` note, log the out-of-scope findings (§11).

## 10. Open questions for Louis (recommendation first)

- **Q1. Drop the Devise `~> 4.9` pin?**
  - ActiveAdmin 3.5.0+ supports Devise 5 (`DEVISE = ">= 4.0", "< 6"`), and Devise 5.0.4 carries a
    security fix.
  - **Recommend:** remove the pin, the "v4.9 for Active Admin?" prompt and the ADMIN gate's
    4.9 check, *after* proving `-all` with Devise 5 + ActiveAdmin 3.5 generates, boots and signs
    an admin in.
  - Alternative: leave as-is and log it.
- **Q2. FriendlyId slugs Users by `email`.** That puts email addresses in URLs, which is a
  privacy leak.
  - **Recommend:** keep the generator setup, but stop adding `friendly_id :email` to User. Leave
    a commented example for a public field.
  - Alternative: leave behaviour, log it.
- **Q3. Apply the B1 layout shell to Tailwind too?** tailwindcss-rails 4.6 no longer wraps
  `yield`, so Tailwind apps have the same bare layout.
  - **Recommend:** yes (`<main class="container mx-auto px-4 py-6 grow">` + footer).
- **Q4. Add the three `rails8-api*` functions to your workbench `zshrc`?** That's a commit in
  the workbench repo, outside this one.
  - **Recommend:** yes, as its own workbench commit, after the API template is verified.
- **Q5. Landing:** local commits on `feat/template-improvements`, then (a) push + PR +
  `/self-review`, or (b) fast-forward `master` and push directly, as on 2026-09-17.
  - **Recommend:** (a).

## 11. Out of scope (logged, not fixed)

- **Pagination with Tailwind 4:** it downloads `pagy-tailwind.css` into
  `app/assets/stylesheets/`, where Tailwind 4 never processes it, and injects before
  `@tailwind base;`, a line the v4 file doesn't have.
- **`simple_form_tailwind.rb`:** uses Tailwind 3-era utilities (`focus:ring-opacity-50`).
- **Rails 7 API template.**
