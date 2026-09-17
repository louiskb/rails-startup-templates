# Template Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the pending template bugs, ship the pending suggestions, and add the `CLAUDE_CODE` module and a Rails 8 API template, each proven in a freshly generated app.

**Architecture:**
- **New shared modules:** `layout.rb`, `navbar.rb` (rewritten), `conventional_commits.rb`, `claude_code.rb`, `devise_jwt.rb`. They follow the repo's dual-mode pattern: called from a main template, or standalone via `rails app:template`.
- **Main templates** gain an autocorrect step and a closing hook step.
- **`rails-8/api.rb`** is a new main template for `rails new --api`. Shared modules detect API apps via `config.api_only = true`.

**Tech Stack:**
- Rails 8.1.3.1 / 7.1.6 app templates (Thor actions), Ruby 3.4.10, PostgreSQL 18
- Devise 5.0.4, devise-jwt 0.13.0, ActiveAdmin 3.5.2
- Pagy 43.6.2, blueprinter 1.3.0, rack-cors 3.0.0, rack-attack 6.8.0
- RSpec, RuboCop (omakase on Rails 8, Le Wagon on Rails 7)

**Spec:** `docs/superpowers/specs/2026-09-17-template-improvements-design.md`

## Global Constraints

- **Style:** double quotes everywhere, in both template Ruby and generated Ruby/ERB/HTML.
  Generated app code uses `ENV.fetch("VAR", nil)` (or `ENV.fetch("VAR") { default }`).
- **No `exit` in NEW shared modules.** `exit` inside an `apply`'d module kills the whole
  `rails new` run. Guard with `if/else`.
- **Idempotency:** every new module checks before writing and never overwrites a file it
  didn't create.
- **Commit messages** (template-generated and ours): Conventional Commits, no Claude
  attribution lines.
- **Rails pins in shell functions:** `_8.1.3.1_` and `_7.1.6_`.
- **API template:** Rails 8 only, run with `--api`. Never offers AUTH, NAVBAR, FRIENDLY_URLS or
  ADMIN.
- **RuboCop autocorrect** is safe mode only (`-a`).
- **Verification** happens in apps generated under the scratchpad
  `/private/tmp/claude-501/-Users-louisbourne-code-louiskb-rails-startup-templates/5dfd19af-9011-4ccd-b37a-26b4cf699875/scratchpad/apps`
  (abbreviated `$A`). Drop their databases when done.
- **Browser proof** for layout work: desktop + 390px screenshots.

---

### Task 1: Generation harness (scratchpad, not committed)

**Files:**
- Create: `$SCRATCH/gen.sh`, where `$SCRATCH` is the scratchpad dir

**Interfaces:**
- Produces:
  - `gen.sh NAME TEMPLATE "ENV=val ..." [STDIN] [EXTRA_RAILS_FLAGS]`: generates `$A/NAME` with
    every module env var defaulted to `false`, then overridden by the given ENV. Log goes to
    `$A/NAME.gen.log`. Prints the exit code and the ✅ line.
  - `probe.sh NAME [PATH]`: `GET PATH` through `Rack::MockRequest` in development. Prints
    status plus any exception name.

- [ ] **Step 1: Write the harness**

```bash
#!/usr/bin/env bash
# gen.sh NAME TEMPLATE "ENV=val ..." [STDIN] [EXTRA_RAILS_FLAGS]
set -u
T=/Users/louisbourne/code/louiskb/rails-startup-templates
A=/private/tmp/claude-501/-Users-louisbourne-code-louiskb-rails-startup-templates/5dfd19af-9011-4ccd-b37a-26b4cf699875/scratchpad/apps
OFF="BOOTSTRAP=false TAILWIND=false DEVISE=false AUTH=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false"
name=$1 tpl=$2 extra=${3:-} input=${4:-} flags=${5:-}
case "$tpl" in rails-7/*) ver=_7.1.6_ ;; *) ver=_8.1.3.1_ ;; esac
cd "$A" && [ -d "$name" ] && (cd "$name" && bin/rails db:drop >/dev/null 2>&1); rm -rf "$A/$name"
( printf "%b" "$input" | env $OFF $extra rails $ver new "$name" -d postgresql $flags -m "$T/$tpl" ) > "$A/$name.gen.log" 2>&1
echo "$name exit=$? :: $(grep -a '✅ Rails' "$A/$name.gen.log" | tail -1)"
```

```bash
#!/usr/bin/env bash
# probe.sh NAME [PATH]
A=/private/tmp/claude-501/-Users-louisbourne-code-louiskb-rails-startup-templates/5dfd19af-9011-4ccd-b37a-26b4cf699875/scratchpad/apps
cd "$A/$1" && bin/rails runner "r = Rack::MockRequest.new(Rails.application).get('${2:-/}', 'HTTP_HOST' => 'localhost'); puts \"GET ${2:-/} => #{r.status}\"; puts r.body[/(ArgumentError|NoMethodError|NameError|SyntaxError|ActionView::Template::Error)[^<]{0,200}/].to_s" 2>&1 | tail -3
```

- [ ] **Step 2: Smoke it** on the unmodified `rails-8/custom.rb` (`gen.sh h1 rails-8/custom.rb`, then `probe.sh h1`).
  Expected: `exit=0`, `GET / => 500` + `ArgumentError`. This is the A1 failing baseline.

---

### Task 2: PagesController + Rails 8 native auth (spec A1, A2)

**Files:**
- Modify: `rails-8/bootstrap.rb`, `rails-8/tailwind.rb`, `rails-8/custom.rb`,
  `rails-7/bootstrap.rb`, `rails-7/tailwind.rb`, `rails-7/custom.rb` (PagesController heredoc)
- Modify: `shared/devise.rb` (inject the Devise skip + guard the ApplicationController inject)
- Modify: `shared/authentication.rb` (rewrite the controller, view and PagesController parts)
- Modify: `shared/tailwind.rb` (guard)

**Interfaces:**
- Produces: PagesController with no auth line. Auth modules own the public-home line.
  - Devise: `skip_before_action :authenticate_user!, only: :home`
  - Native: `allow_unauthenticated_access only: :home`

- [ ] **Step 1: Failing probes (baseline, already observed 2026-09-17):**
  - all-off app: `GET /` 500 `ArgumentError`
  - native-auth app: `ruby -c app/controllers/pages_controller.rb` gives a syntax error

- [ ] **Step 2: Main templates.** In all six files, replace the PagesController `file` heredoc
  (the version with `skip_before_action :authenticate_user!`; custom.rb uses `def home; end`)
  with:

```ruby
  file "app/controllers/pages_controller.rb", <<~RUBY
    # Public pages. Auth modules add their own public-access line here
    # (Devise: skip_before_action; Rails 8 authentication: allow_unauthenticated_access).
    class PagesController < ApplicationController
      def home
      end
    end
  RUBY
```

- [ ] **Step 3: `shared/devise.rb`.** Replace the unguarded ApplicationController inject
  (`# ApplicationController: Add optional global auth` block) with:

```ruby
# ApplicationController: require sign-in everywhere (pages opt out below).
app_controller = "app/controllers/application_controller.rb"
unless File.read(app_controller).include?("authenticate_user!")
  inject_into_file app_controller, after: "class ApplicationController < ActionController::Base\n" do
    <<~RUBY
      before_action :authenticate_user!
    RUBY
  end
end

# PagesController#home stays public. The main templates write PagesController without
# this line because `skip_before_action :authenticate_user!` raises ArgumentError in any
# app where Devise hasn't defined that callback.
pages_controller = "app/controllers/pages_controller.rb"
if File.exist?(pages_controller) && !File.read(pages_controller).include?("authenticate_user!")
  inject_into_file pages_controller, after: "class PagesController < ApplicationController\n" do
    "  skip_before_action :authenticate_user!, only: :home\n\n"
  end
end
```

- [ ] **Step 4: `shared/authentication.rb`.**
  - Replace the `file "app/controllers/registrations_controller.rb"` heredoc, the three-branch
    view block, and the `# Home page skip auth` inject with the code below.
  - Change GUARD 1's regex to `/^\s*gem ["']devise["']/`.

```ruby
# Registration controller
file "app/controllers/registrations_controller.rb", <<~RUBY
  class RegistrationsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        start_new_session_for(@user)
        redirect_to root_path, notice: "Welcome!"
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
  end
RUBY

# Registration new sign-up view (Simple Form). The layout already renders flashes.
# CSS framework detected from the Gemfile: Tailwind 4 has no config/tailwind.config.js,
# and Le Wagon's stylesheets keep bootstrap variables inside config/, so file checks miss both.
button_class = if gemfile.match?(/^\s*gem ["']bootstrap["']/)
  "btn btn-primary my-3"
elsif gemfile.match?(/^\s*gem ["']tailwindcss-rails["']/)
  "my-3 rounded bg-blue-600 px-4 py-2 font-bold text-white hover:bg-blue-700"
end
submit_options = button_class ? %(, class: "#{button_class}") : ""

file "app/views/registrations/new.html.erb", <<~HTML
  <h1>Sign up</h1>

  <%= simple_form_for @user, url: registration_path do |f| %>
    <%= f.input :email_address %>
    <%= f.input :password %>
    <%= f.input :password_confirmation %>
    <%= f.button :submit, "Sign up"#{submit_options} %>
  <% end %>
HTML

# PagesController#home stays public (see the main templates' PagesController comment).
pages_controller = "app/controllers/pages_controller.rb"
if File.exist?(pages_controller) && !File.read(pages_controller).include?("allow_unauthenticated_access")
  inject_into_file pages_controller, after: "class PagesController < ApplicationController\n" do
    "  allow_unauthenticated_access only: :home\n\n"
  end
end
```

- [ ] **Step 5: `shared/tailwind.rb` GUARD 1:**
  `if File.exist?("config/tailwind.config.js") || File.exist?("app/assets/tailwind/application.css")`,
  with the message `"Tailwind already installed, skipping..."`.

- [ ] **Step 6: Passing probes.**
  - `gen.sh t2min rails-8/custom.rb` + `probe.sh t2min` → `GET / => 200`.
  - `gen.sh t2auth rails-8/tailwind.rb "AUTH=true" "r\n"`, then:
    - `ruby -c app/controllers/pages_controller.rb` → `Syntax OK`
    - `probe.sh t2auth` → 200
    - `probe.sh t2auth /registration/new` → 200
    - This runner script (`$SCRATCH/signup_probe.rb`) must print `302 1`:

```ruby
ActionController::Base.allow_forgery_protection = false
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"
session.post "/registration", params: { user: { email_address: "probe@example.com", password: "password123", password_confirmation: "password123" } }
puts "#{session.response.status} #{User.count}"
User.destroy_all
```
  - `gen.sh t2dev rails-8/bootstrap.rb "DEVISE=true"` + `probe.sh t2dev` → 200.

- [ ] **Step 7: Commit** `fix(templates): stop PagesController crashing apps without Devise` (A1, including devise.rb), then `fix(authentication): repair the Rails 8 native auth module` (A2, including tailwind.rb guard). Stage files per commit.

---

### Task 3: Dead code: viewport gsubs and the dev_tools typo (spec A5, A7)

**Files:**
- Modify: all six main templates (delete the viewport `gsub_file(...)` block and its comment line)
- Modify: `shared/dev_tools.rb:26` (`"group :development do \n"` → `"group :development do\n"`)

- [ ] **Step 1: Failing check:**
  `grep -n "shrink-to-fit" rails-*/*.rb` → 6 hits;
  `grep -n 'do \\n' shared/dev_tools.rb` → 1 hit.
- [ ] **Step 2: Delete** each block:
  - `# Layout` / `# Layout viewport (works for all)` comment
  - `gsub_file(` … `shrink-to-fit=no">'` … `)`
  - In bootstrap.rb, keep the separate `stylesheet_link_tag` gsub (and its `# Layout` comment).
  - Then fix the typo.
- [ ] **Step 3: Passing check:** both greps return nothing; `ruby -c` on every edited file → `Syntax OK`.
- [ ] **Step 4: Commit** `refactor(templates): remove viewport gsubs that never matched` and `fix(dev_tools): inject better_errors in standalone mode`.

---

### Task 4: Layout shell, footer, Google Fonts links (spec B1, B2, Q3)

**Files:**
- Create: `shared/layout.rb`
- Modify: `rails-8/bootstrap.rb`, `rails-7/bootstrap.rb`, `rails-8/tailwind.rb`, `rails-7/tailwind.rb`: after the flashes inject, `apply source_path("shared/layout.rb")`
- Modify: `shared/bootstrap.rb`, `shared/tailwind.rb`: before STANDALONE MIGRATION SUPPORT, `apply File.join(File.dirname(__FILE__), "layout.rb")`

**Interfaces:**
- Produces:
  - A layout with `<main class="container …">` wrapping `yield`.
  - `render "shared/footer"`.
  - Bootstrap only: the comment line `<%# Navbar: shared/navbar.rb replaces this line with render "shared/navbar" %>`, which Task 5 replaces.

- [ ] **Step 1: Failing probe.** On baseline apps b2test (bootstrap) and b3auth (tailwind),
  `grep -c "<main" app/views/layouts/application.html.erb` → 0.

- [ ] **Step 2: Create `shared/layout.rb`:**

```ruby
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
# 2. Existing app: `rails app:template LOCATION=shared/layout.rb`.

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

  # Flashes are injected at column 0 by the main templates; indent them like the rest.
  gsub_file layout_path, /^\s*<%= render "shared\/flashes" %>\n/, %(    <%= render "shared/flashes" %>\n)

  navbar_marker = if framework == :bootstrap
    %(    <%# Navbar: shared/navbar.rb replaces this line with render "shared/navbar" %>\n)
  else
    ""
  end
  gsub_file layout_path, %(    <%= render "shared/flashes" %>\n), navbar_marker + %(    <%= render "shared/flashes" %>\n)

  gsub_file layout_path, /^\s*<%= yield %>\n/, <<~ERB.indent(4)
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

# Google Fonts: Le Wagon's config/_fonts.scss loads them with a CSS @import, which makes
# the browser fetch the compiled stylesheet before it even discovers the fonts. <link>
# tags with preconnect hints in <head> start that download in parallel (web.dev,
# "Best practices for fonts"). The font variables stay in _fonts.scss.
fonts_path = "app/assets/stylesheets/config/_fonts.scss"
fonts_scss = File.exist?(fonts_path) ? File.read(fonts_path) : ""
google_fonts_url = fonts_scss[/^@import url\(['"]?(https:\/\/fonts\.googleapis\.com[^'")]+)['"]?\);/, 1]

if framework == :bootstrap && google_fonts_url && File.exist?(layout_path)
  gsub_file fonts_path, /^\/\/ Import Google fonts\n@import url\(.*\);\n/,
    "// Google Fonts load from <link> tags in app/views/layouts/application.html.erb.\n"

  inject_into_file layout_path, before: /^\s*<%= stylesheet_link_tag/ do
    <<~ERB.indent(4)
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link rel="stylesheet" href="#{google_fonts_url.gsub("&", "&amp;")}">
    ERB
  end

  say "Google Fonts moved from a CSS @import to <link> tags in the layout.", :green
end
```

- [ ] **Step 3: Wire it in.**
  - In rails-8/bootstrap.rb and rails-7/bootstrap.rb, directly after the flashes
    `inject_into_file … end` block, add:
    ```ruby
    # Layout shell: <main> container, footer, Google Fonts <link> tags (shared/layout.rb)
    apply source_path("shared/layout.rb")
    ```
    It must come after the Le Wagon stylesheet unzip, which is earlier in Step 1.
  - Add the same lines after the flashes inject in rails-8/tailwind.rb and rails-7/tailwind.rb.
  - In shared/bootstrap.rb and shared/tailwind.rb, add
    `apply File.join(File.dirname(__FILE__), "layout.rb")` right before
    `# STANDALONE MIGRATION SUPPORT`.
  - The Bootstrap main templates' Step 1 already has the Gemfile bootstrap gem when
    layout.rb runs; Tailwind's has tailwindcss-rails.

- [ ] **Step 4: Passing probe.**
  - `gen.sh t4bs rails-8/bootstrap.rb`, `gen.sh t4tw rails-8/tailwind.rb`,
    `gen.sh t4cb rails-8/custom.rb "TAILWIND=true BOOTSTRAP=true" "b\n"`.
  - Each layout contains `<main class=`, `render "shared/footer"`, and the footer file exists.
  - t4bs also has both preconnect links and no `@import url` in `config/_fonts.scss`.
  - `probe.sh` on each → 200, and the body contains `<footer`.

- [ ] **Step 5: Commit** `feat(layout): give Bootstrap and Tailwind layouts a container shell and footer`.

---

### Task 5: Navbar that matches the app's auth (spec A4)

**Files:**
- Modify: `shared/navbar.rb` (rewrite)
- Modify: `rails-8/bootstrap.rb`, `rails-7/bootstrap.rb`, `rails-8/custom.rb`, `rails-7/custom.rb`: replace the navbar `curl` line with the placeholder `file`

**Interfaces:**
- Consumes: the Task 4 navbar comment line; Task 2 auth modules (applied before navbar.rb in `after_bundle`)
- Produces: the placeholder string `<%# navbar placeholder: shared/navbar.rb replaces this file %>`

- [ ] **Step 1: Failing probe (baseline b4nav):** with PagesController patched, `NoMethodError in Pages#home`.

- [ ] **Step 2: Main templates.** Replace
  `run "curl -L https://raw.githubusercontent.com/lewagon/awesome-navbars/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb"`
  in the four files with:

```ruby
  # Placeholder = "navbar chosen" flag. shared/navbar.rb (in `after_bundle`, after the auth
  # modules) replaces it with links for whichever auth the app ended up with.
  file "app/views/shared/_navbar.html.erb", "<%# navbar placeholder: shared/navbar.rb replaces this file %>\n"
```

- [ ] **Step 3: Rewrite `shared/navbar.rb`:**

```ruby
# shared/navbar.rb
# Shared NavBar Template (Bootstrap)
# Writes app/views/shared/_navbar.html.erb: Le Wagon's navbar structure and `navbar-lewagon`
# styles, with auth links for the authentication the app actually has (Devise, Rails 8
# authentication, or none). Le Wagon's own partial calls Devise helpers unconditionally,
# which crashed every page of an app without Devise.

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (after the auth modules).
# 2. Existing app: Standalone - `rails app:template LOCATION=shared/navbar.rb`.

navbar_path = "app/views/shared/_navbar.html.erb"
layout_path = "app/views/layouts/application.html.erb"
routes = File.exist?("config/routes.rb") ? File.read("config/routes.rb") : ""
home_path = routes.match?(/^\s*root /) ? "root_path" : %("/")

auth_links = if File.exist?("config/initializers/devise.rb")
  <<~ERB
    <% if user_signed_in? %>
      <li class="nav-item">
        <%= link_to "Log out", destroy_user_session_path, data: { turbo_method: :delete }, class: "nav-link" %>
      </li>
    <% else %>
      <li class="nav-item">
        <%= link_to "Log in", new_user_session_path, class: "nav-link" %>
      </li>
      <li class="nav-item">
        <%= link_to "Sign up", new_user_registration_path, class: "nav-link" %>
      </li>
    <% end %>
  ERB
elsif File.exist?("app/controllers/concerns/authentication.rb")
  sign_up = if routes.include?("resource :registration")
    <<~ERB
      <li class="nav-item">
        <%= link_to "Sign up", new_registration_path, class: "nav-link" %>
      </li>
    ERB
  else
    ""
  end
  <<~ERB
    <% if authenticated? %>
      <li class="nav-item">
        <%= link_to "Log out", session_path, data: { turbo_method: :delete }, class: "nav-link" %>
      </li>
    <% else %>
      <li class="nav-item">
        <%= link_to "Log in", new_session_path, class: "nav-link" %>
      </li>
    #{sign_up.indent(2).chomp}
    <% end %>
  ERB
else
  ""
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
          <li class="nav-item">
            <%= link_to "Home", #{home_path}, class: "nav-link" %>
          </li>
  #{auth_links.indent(6).chomp}
        </ul>
      </div>
    </div>
  </nav>
ERB
navbar_html = navbar_html.gsub(/^\s*\n(?=\s*<\/ul>)/, "")

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
if File.exist?(layout_path) && !File.read(layout_path).include?('render "shared/navbar"')
  if File.read(layout_path).match?(/^\s*<%# Navbar:.*%>\n/)
    gsub_file layout_path, /^(\s*)<%# Navbar:.*%>\n/, %(\\1<%= render "shared/navbar" %>\n)
  else
    inject_into_file layout_path, %(    <%= render "shared/navbar" %>\n), after: /<body[^>]*>\n/
  end
end

say "✅ NavBar installation complete!", :green
```

- [ ] **Step 4: Passing probes.**
  - `gen.sh t5nav rails-8/bootstrap.rb "NAVBAR=true"` → `probe.sh t5nav` 200, and the body
    contains `navbar-lewagon` and `>Home<`.
  - `gen.sh t5dev rails-8/bootstrap.rb "NAVBAR=true DEVISE=true"` → 200, body contains `Log in`.
  - Native: `gen.sh t5nat rails-8/bootstrap.rb "NAVBAR=true AUTH=true" "r\n"` → 200, body
    contains `Sign up`.
  - The rendered `ul` has no blank-line gap: `grep -c "^\s*$"` inside `_navbar.html.erb`
    matches the template.

- [ ] **Step 5: Commit** `fix(navbar): write a navbar whose links match the app's authentication`.

---

### Task 6: FriendlyId module (spec A3, Q2)

**Files:**
- Modify: `shared/friendly_urls.rb` (replace everything between the gem block and STANDALONE MIGRATION SUPPORT)

- [ ] **Step 1: Failing probe (baseline b5fid):** `ls config/initializers | grep friendly` → nothing; `app/models/user.rb` contains `friendly_id :email`.

- [ ] **Step 2: Edit.**
  - `run "bundle_install"` → `run "bundle install"`.
  - Replace the whole "Add slug column migration … else … end" section and the
    `# Routes comment` inject with:

```ruby
# FriendlyId initializer + `friendly_id_slugs` table (used by the :history add-on).
if File.exist?("config/initializers/friendly_id.rb")
  say "FriendlyId initializer exists, skipping `rails generate friendly_id`.", :yellow
else
  generate "friendly_id"
end

# No model is slugged automatically. Slugs show up in URLs, logs and browser history, so
# slug a PUBLIC attribute. (This module used to slug User by email, leaking addresses.)
# To slug e.g. Post by its title:
#   1. `rails generate migration AddSlugToPosts slug:string:uniq` then `rails db:migrate`
#   2. In app/models/post.rb:
#        extend FriendlyId
#        friendly_id :title, use: :slugged
#   3. Look records up with `Post.friendly.find(params[:id])` (slug or id both work).
#   4. Backfill existing rows: `Post.find_each(&:save)`.
```

- [ ] **Step 3: Passing probe.**
  - `gen.sh t6fid rails-8/bootstrap.rb "DEVISE=true FRIENDLY_URLS=true"`:
    - `config/initializers/friendly_id.rb` exists
    - `db/migrate/*_create_friendly_id_slugs.rb` exists and is migrated
      (`bin/rails db:migrate:status | grep -c friendly` → 1 up)
    - `grep -c FriendlyId app/models/user.rb` → 0
    - `probe.sh` → 200
  - Standalone re-run: `bin/rails app:template LOCATION=$T/shared/friendly_urls.rb` → prints
    the skip message, `git status --short` empty.

- [ ] **Step 4: Commit** `fix(friendly_urls): run the FriendlyId generator and stop slugging users by email`.

---

### Task 7: Drop the Devise ~> 4.9 pin, if proven (spec Q1)

**Files:**
- Modify: `rails-8/bootstrap.rb`, `rails-8/tailwind.rb`, `rails-8/custom.rb` (DEVISE=true block, the `when "d"` branch, ADMIN gate)
- Modify: `rails-7/bootstrap.rb`, `rails-7/tailwind.rb`, `rails-7/custom.rb` (devise block, ADMIN gate)
- Modify: `shared/devise.rb` (standalone gem add: no version prompt)

- [ ] **Step 1: Edit the Rails 8 templates.** Replace the `# Default to Devise v4.9 if DEVISE=true` block with:

```ruby
# Devise without prompts when `DEVISE=true` (the `-all` shell functions). No version pin:
# ActiveAdmin 3.5+ supports Devise 5 (`DEVISE = ">= 4.0", "< 6"` in its dependency check).
if ENV.fetch("DEVISE", "") == "true"
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
  say("`DEVISE=true` detected: installing Devise.", :green)
end
```

  Replace the `when "d"` branch body with:

```ruby
  when "d"
    # devise (skipped if DEVISE=true already added it above)
    unless File.read("Gemfile").match?(/^\s*gem ["']devise["']/)
      inject_into_file "Gemfile", before: "group :development, :test do" do
        <<~RUBY
          gem "devise"

        RUBY
      end
      say("Devise added.", :green)
    end
```

  Replace the admin gate condition and prompt:

```ruby
# admin (requires Devise) - an admin dashboard for CRUD operations on models.
if File.read("Gemfile").match?(/^\s*gem ["']devise["']/)
  if should_install?("admin", "Install Active Admin (uses Devise)? (y/n)")
```

- [ ] **Step 2: Edit the Rails 7 templates.** Replace the whole `# devise` `if should_install?("devise", …)` block with:

```ruby
# devise (no version pin: ActiveAdmin 3.5+ supports Devise 5)
if should_install?("devise", "Install Devise? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
end
```

  Then apply the same admin gate as Step 1.

- [ ] **Step 3: `shared/devise.rb` standalone gem block.** Replace the version prompt
  (`devise_choice = ask(…)` through the `say`) with:

```ruby
unless gemfile.match?(/^\s*gem ["']devise["']/)
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"

    RUBY
  end
  say("Devise added.", :green)
```
  Keep the existing `run "bundle install" unless system("bundle check")` and `end`.

- [ ] **Step 4: Proof.** `gen.sh t7all rails-8/bootstrap.rb "DEVISE=true ADMIN=true"`:
  - exit 0
  - `Gemfile.lock` has `devise (5.` and `activeadmin (3.5`
  - `probe.sh t7all /admin/login` → 200
  - This runner script (`$SCRATCH/admin_probe.rb`) must print `login 303 /admin 200`:

```ruby
ActionController::Base.allow_forgery_protection = false
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"
session.post "/admin/login", params: { admin_user: { email: "admin@example.com", password: "password" } }
status = session.response.status
session.follow_redirect!
puts "login #{status} #{session.path} #{session.response.status}"
```

  **If any check fails:** `git checkout` the Task 7 files, log the failure in the notes file,
  and skip to Task 8.

- [ ] **Step 5: Rails 7 proof.** `gen.sh t7r7 rails-7/bootstrap.rb "DEVISE=true ADMIN=true"`: exit 0, `/admin/login` 200.

- [ ] **Step 6: Commit** `feat(devise)!: install the latest Devise now that ActiveAdmin supports Devise 5`. The body notes that the "v4.9 for Active Admin?" prompt is gone.

---

### Task 8: Testing module is green out of the box (spec A8)

**Files:**
- Modify: `shared/testing.rb` (replace the commented User examples, the Post factory/spec block and the pages system spec block; fix the support require quotes)

**Interfaces:**
- Produces:
  - `spec/factories/users.rb` (`factory :user`, password `"password123"`)
  - `spec/requests/health_spec.rb`
  - `spec/system/pages_spec.rb` (non-API with root)
- Task 13 extends this with the API users spec.

- [ ] **Step 1: Failing probe (baseline b2test):** `bundle exec rspec` → `NameError: uninitialized constant Post`, 0 examples.

- [ ] **Step 2: Edit.**
  - In the `append_file "spec/rails_helper.rb"` heredoc, use
    `Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }`.
  - Delete everything from `# Example Factory (User)` down to (not including) `# DOCUMENTATION:`.
    That's the commented User examples, the Post factory, the Post spec, and pages_spec.
  - Insert:

```ruby
# EXAMPLE SPECS: only ones that pass on the app as it is right now.
api_only = File.exist?("config/application.rb") && File.read("config/application.rb").include?("config.api_only = true")
routes = File.exist?("config/routes.rb") ? File.read("config/routes.rb") : ""
schema = File.exist?("db/schema.rb") ? File.read("db/schema.rb") : ""
run "mkdir -p spec/factories spec/requests"

# User factory, for whichever authentication created the User model.
# (`<<~'RUBY'` keeps `#{n}` literal for the generated factory.)
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

# Post example: only when the app HAS a Post model with a title column. (The old version
# always shipped it, so every fresh app's suite died with `uninitialized constant Post`.)
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
```

  Note: the Post factory heredoc is interpolating (`<<~RUBY`) because it inserts
  `post_attributes`. The title's `\#{SecureRandom.hex(3)}` is escaped inside `%(...)`, so the
  generated factory keeps a literal `#{…}` and gives every post a fresh title.

- [ ] **Step 3: Passing probes.**
  - `gen.sh t8t rails-8/bootstrap.rb "TESTING=true"` → `bundle exec rspec` shows 2 examples,
    0 failures.
  - `gen.sh t8d rails-8/bootstrap.rb "TESTING=true DEVISE=true"` → 2 examples, 0 failures,
    and `spec/factories/users.rb` exists.
  - Plant a Post: in t8t run `bin/rails g model Post title:string content:text slug:string && bin/rails db:migrate`,
    delete `spec/factories/posts.rb` and `spec/models/post_spec.rb` if the model generator
    made them, re-apply `shared/testing.rb` standalone, then `rspec spec/models/post_spec.rb`
    → 1 example, 0 failures.
    - The GUARD 1 `exit` fires because specs exist. So for this check, temporarily run the
      block via a copy with GUARD 1 removed (scratchpad), not the repo file.

- [ ] **Step 4: Commit** `fix(testing): ship only example specs that pass on a fresh app`.

---

### Task 9: .gitignore block, conventional commits, commit-msg hook (spec B4, B6)

**Files:**
- Create: `shared/conventional_commits.rb`
- Modify: all six main templates (gitignore heredoc, commit message renames, final hook step)

**Interfaces:**
- Produces:
  - `.githooks/commit-msg`
  - `core.hooksPath=.githooks`
  - a `bin/setup` line
  - a README "## Commit messages" section

- [ ] **Step 1: Failing probe (baseline b1min):**
  - `git log --format=%s` includes `initial commit: new rails app setup with Custom template.`
  - `git check-ignore .claude/settings.local.json` → exit 1 (not ignored)

- [ ] **Step 2: Create `shared/conventional_commits.rb`:**

```ruby
# shared/conventional_commits.rb
# Shared Conventional Commits Template
# Enforces https://www.conventionalcommits.org/en/v1.0.0/ commit messages with a versioned
# commit-msg hook, and documents the convention in the README.
#
# `.githooks/` is committed, but git only runs hooks from it once `core.hooksPath` points
# there, and that setting lives in each clone's local config. So it's set here for this
# clone AND added to bin/setup for fresh clones.

# TWO USE CASES:
# 1. Fresh app: applied LAST by every main template, after the template's own commits.
# 2. Existing app: Standalone - `rails app:template LOCATION=shared/conventional_commits.rb`.

hook_path = ".githooks/commit-msg"

if File.exist?(hook_path)
  say "Commit-msg hook already present (#{hook_path}), skipping.", :yellow
else
  create_file hook_path, <<~'BASH'
    #!/usr/bin/env bash
    # Rejects commit messages that don't follow Conventional Commits:
    #   <type>(<optional scope>)!: <description>
    # https://www.conventionalcommits.org/en/v1.0.0/
    # Enabled per clone with: git config core.hooksPath .githooks (bin/setup does this)

    first_line=$(head -n 1 "$1")

    # Messages git writes itself (merges, reverts, autosquash) pass through.
    if [[ "$first_line" =~ ^(Merge|Revert|fixup!|squash!|amend!) ]]; then
      exit 0
    fi

    pattern='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9._/-]+\))?!?: .+'
    if [[ "$first_line" =~ $pattern ]]; then
      exit 0
    fi

    {
      echo "✖ Commit message doesn't follow Conventional Commits:"
      echo "    $first_line"
      echo ""
      echo "  Format: <type>(<optional scope>): <description>"
      echo "  Types:  build chore ci docs feat fix perf refactor revert style test"
      echo "  e.g.    feat(posts): add comment threads"
      echo "          fix: redirect to login when the session expires"
    } >&2
    exit 1
  BASH
  chmod hook_path, 0o755
end

# This clone
run "git config core.hooksPath .githooks" if File.directory?(".git")

# Fresh clones: bin/setup turns the hook on. `system` (not `system!`) so a copy without
# .git (e.g. a downloaded zip) still sets up.
if File.exist?("bin/setup") && !File.read("bin/setup").include?("core.hooksPath")
  inject_into_file "bin/setup", after: /^\s*system\("bundle check"\) \|\| system!\("bundle install"\)\n/ do
    <<~RUBY.indent(2)

      puts "\\n== Enabling the commit-msg hook =="
      system("git config core.hooksPath .githooks")
    RUBY
  end
end

if File.exist?("README.md") && !File.read("README.md").include?("## Commit messages")
  append_to_file "README.md", <<~MARKDOWN

    ## Commit messages

    This repo follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
    `<type>(<optional scope>): <description>`, e.g. `feat(posts): add comment threads` or
    `fix: redirect to login when the session expires`.

    Types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.
    Add `!` after the type (`feat!:`) for a breaking change.

    `.githooks/commit-msg` rejects anything else. `bin/setup` enables it in a fresh clone
    (`git config core.hooksPath .githooks`).
  MARKDOWN
end

say "✅ Conventional commits hook installed!", :green
```

- [ ] **Step 3: Main templates.**
  - Replace each `append_file ".gitignore", <<~TXT … TXT` with:

```ruby
  # Gitignore
  append_file ".gitignore", <<~TXT

    # Secrets: never commit these. Before a first push, also check .mcp.json: MCP configs
    # can embed API keys. Reference them as ${VAR} instead.
    # (Rails already ignores config/master.key and config/credentials/*.key.)
    .env*
    !.env.example

    # Claude Code: personal machine-local settings (.claude/settings.json IS shared and committed)
    .claude/settings.local.json

    # Editor and OS files
    *.swp
    .DS_Store
  TXT
```

  - Rename the initial commit message:
    `git commit: "-m 'chore: initial commit from the Bootstrap template'"`. Use Tailwind or
    Custom in the other files.
  - Replace the final migration commit:
    - Rails 8 (bare `git add`/`git commit`) → the guarded form
    - Rails 7 (already guarded) → just the message

```ruby
  # Git. Guarded: with no modules there may be nothing new to commit, and an empty
  # `git commit` exits 1 and aborts the template before the final message.
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore(db): run migrations after module setup'"
```

  - Directly before the final `say "✅ …"`, add:

```ruby
  # Conventional commits: commit-msg hook + README section (shared/conventional_commits.rb).
  # Last on purpose: every commit above is made before the hook exists.
  apply source_path("shared/conventional_commits.rb")
  git add: "."
  git commit: "-m 'chore: enforce conventional commits with a commit-msg hook'"
```

- [ ] **Step 4: Passing probe.** `gen.sh t9 rails-8/custom.rb`:
  - `git log --format=%s` → every subject matches the hook regex
    (`git log --format=%s | grep -Ev '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\(.+\))?!?: '`
    prints nothing)
  - `git config core.hooksPath` → `.githooks`
  - `git commit --allow-empty -m "bad message"` → exit 1 with the ✖ text
  - `git commit --allow-empty -m "fix: x"` → exit 0, then `git reset -q --hard HEAD~1`
  - `git check-ignore -q .claude/settings.local.json` → exit 0
  - `touch .env.example && git check-ignore -q .env.example` → exit 1
  - `grep hooksPath bin/setup` → 1 line
  - `git status --short` → empty

- [ ] **Step 5: Commit** `feat(templates): enforce conventional commits and document ignored secrets`.

---

### Task 10: Fresh apps pass their own RuboCop (spec B5)

**Files:**
- Modify: all six main templates (autocorrect step after the migration commit; single-quoted heredocs)
- Modify: `rails-8/tailwind.rb`, `rails-7/tailwind.rb`, `shared/tailwind.rb` (`simple_form_tailwind.rb` heredoc → double quotes)

- [ ] **Step 1: Failing probe:** baseline RuboCop counts: b1min 4, b2test 193.

- [ ] **Step 2: Rails 8 templates.** After the migration commit, before the conventional-commits apply:

```ruby
  # RuboCop: autocorrect generator output the template doesn't write (simple_form and
  # Devise initializers, …) so a new app passes its own `bin/rubocop` and CI lint job.
  # Safe corrections only (`-a`): every offense in a fresh app is marked safe.
  if File.exist?("bin/rubocop")
    run "bin/rubocop -a > /dev/null || true"
    git add: "."
    run "git diff --cached --quiet || git commit -m 'style: autocorrect RuboCop offenses in generated code'"
  end
```

- [ ] **Step 3: Rails 7 templates.** Same position:

```ruby
  # RuboCop: autocorrect generator output so the app passes its own lint. Rails 7.1 has no
  # bin/rubocop, and RuboCop is only in the bundle with the Dev Tools module.
  if File.read("Gemfile.lock").match?(/^    rubocop \(/)
    run "bundle exec rubocop -a > /dev/null || true"
    git add: "."
    run "git diff --cached --quiet || git commit -m 'style: autocorrect RuboCop offenses in generated code'"
  end
```

- [ ] **Step 4: Double quotes** in the Tailwind simple_form initializer heredocs: every
  `'mb-4'`, `'block text-sm …'`, `'p'`, `class:` string → `"…"`.

- [ ] **Step 5: Passing probe:** `bin/rubocop` → `no offenses detected` in:
  - `gen.sh t10min rails-8/custom.rb`
  - `gen.sh t10bs rails-8/bootstrap.rb "DEVISE=true TESTING=true"`
  - `gen.sh t10tw rails-8/tailwind.rb`

  Also `git status --short` is empty in each.

- [ ] **Step 6: Commit** `fix(templates): autocorrect RuboCop offenses so fresh apps lint clean`.

---

### Task 11: Claude Code setup module (spec C)

**Files:**
- Create: `shared/claude_code.rb`
- Modify: all six main templates (Step 2 prompt stored in `install_claude_code`, `after_bundle` apply after `shared/security.rb`)

**Interfaces:**
- Consumes: installed gems/files only (standalone-safe)
- Produces: `CLAUDE.md`, `.claude/settings.json`, `.claude/rules/*.md`, `SETUP_NOTES.md`, `.gitignore` entry

- [ ] **Step 1: Failing probe:** `gen.sh t11 rails-8/bootstrap.rb "CLAUDE_CODE=true"` on current code → no `.claude/` dir.

- [ ] **Step 2: Main templates.**
  - At the end of Step 2 (before `# STEP 3`), add:

```ruby
# claude_code: no gem. The answer is kept in a local variable, which the `after_bundle`
# block below closes over, so no marker file ends up in the initial commit.
install_claude_code = should_install?("claude_code", "Set up Claude Code (CLAUDE.md, .claude/ settings and rules)? (y/n)")
```

  - In `after_bundle`, after the `shared/security.rb` block, add:

```ruby
  # shared/claude_code.rb: last module, so it can see everything installed above.
  if install_claude_code
    apply source_path("shared/claude_code.rb")

    # Git
    git add: "."
    git commit: "-m 'chore: add Claude Code project setup'"
  end
```

- [ ] **Step 3: Create `shared/claude_code.rb`.** Full code:

```ruby
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
# 2. Existing app: Standalone - `rails app:template LOCATION=shared/claude_code.rb`.

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
# .claude/rules/*.md: short, and only facts this template set up.
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
  helpers << "- Devise: `sign_in user` in request and system specs (`spec/support/devise.rb` loads routes first; Rails 8 lazy-loads them)." if %i[devise devise_jwt].include?(auth)
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
      - Tokens are issued by POST `/api/v1/users` and POST `/api/v1/users/sign_in` and revoked by DELETE `/api/v1/users/sign_out` (`JwtDenylist`). Renaming or adding those routes means updating `jwt.dispatch_requests` / `jwt.revocation_requests` in `config/initializers/devise.rb`: warden-jwt matches raw paths, so a stale regex silently stops issuing or revoking tokens.
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
# MCP facts checked 2026-09-17 (see the spec, §5).
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
```

  Every conditional `#{…}` line in the rules heredocs sits at the end of its list, so an empty
  one only leaves trailing blank lines, which the write loop trims. Step 4 checks this: no rule
  file has a blank line between two bullets.

- [ ] **Step 4: Passing probes.**
  - `gen.sh t11bs rails-8/bootstrap.rb "CLAUDE_CODE=true DEVISE=true ADMIN=true TESTING=true SECURITY=true PAGINATION=true FRIENDLY_URLS=true IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true DEV_TOOLS=true NAVBAR=true"`:
    - `ruby -rjson -e 'JSON.parse(File.read(".claude/settings.json"))'` exits 0
    - `ls .claude/rules` → rails, testing, devise, active_admin, pagination, friendly_id,
      cloudinary, ruby_llm, security, bootstrap
    - `git check-ignore -q SETUP_NOTES.md` → 0
    - `git ls-files CLAUDE.md .claude` lists them
    - read CLAUDE.md, one rule and SETUP_NOTES.md in full: no empty bullets, no stray
      `#{`, correct DB name
  - Standalone idempotency: `bin/rails app:template LOCATION=$T/shared/claude_code.rb` →
    every file reports "exists", `git status --short` empty.
  - `gen.sh t11min rails-8/custom.rb "CLAUDE_CODE=true"` → rules = rails only (no CSS, no
    auth), CLAUDE.md has no CSS/Auth rows.

- [ ] **Step 5: Commit** `feat(claude_code): scaffold CLAUDE.md, settings, rules and MCP setup notes`.

---

### Task 12: API template core + API branches in dev_tools, security, pagination (spec D, part 1)

**Files:**
- Create: `rails-8/api.rb`
- Modify: `shared/dev_tools.rb` (skip better_errors in API apps)
- Modify: `shared/security.rb` (skip CSP; API Rack::Attack)
- Modify: `shared/pagination.rb` (API branch; Pagy 43 comments)

**Interfaces:**
- Produces:
  - `Api::V1::BaseController` with `render_error(error:, code:, status:, details: {})`
  - the literal line `    class BaseController < ApplicationController\n` (4 spaces), which
    Tasks 12 and 13 inject after
  - routes block `namespace :api, defaults: { format: :json } do` / `namespace :v1 do`, with a
    comment line inside

- [ ] **Step 1: Failing probe:** `rails-8/api.rb` doesn't exist.

- [ ] **Step 2: Create `rails-8/api.rb`:**

```ruby
# rails-8/api.rb
# Rails 8 API-only Template (JSON backend for a mobile app or JS frontend)
# Run with --api:  rails _8.1.3.1_ new my_api --api -d postgresql -m rails-8/api.rb

# LOGIC FLOW:
# 1. Core setup (non-interactive): CORS, Blueprinter, versioned base controller.
# 2. Interactive: OPTIONAL modules (Devise + JWT, testing, …). Not offered in API mode:
#    AUTH (Rails 8 authentication is cookie-session based), NAVBAR, FRIENDLY_URLS and
#    ADMIN (ActiveAdmin needs the full view stack).
# 3. `after_bundle`: generators, shared modules, git commits, migrations.

unless options[:api]
  say "rails-8/api.rb is for API-only apps. Re-run with --api:", :red
  say "  rails new my_api --api -d postgresql -m rails-8/api.rb", :red
  exit 1
end

# Kill Spring if running (macOS)
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# STEP 1: CORE SETUP

def should_install?(feature, prompt)
  env_value = ENV[feature.upcase]

  return true if env_value == "true"
  return false if env_value == "false"

  yes?(prompt)
end

def source_path(file)
  if __FILE__ =~ %r{https?://}
    "https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/#{file}"
  else
    File.expand_path("../#{file}", __dir__)
  end
end

# Ruby version pin: silences Heroku's "no Ruby version declared" warning.
inject_into_file "Gemfile", after: "source \"https://rubygems.org\"\n" do
  "\nruby \"#{RUBY_VERSION}\"\n"
end

# CORS: Rails ships rack-cors commented out in API apps.
gsub_file "Gemfile", /^# gem "rack-cors"\n/, "gem \"rack-cors\"\n"

# JSON serialization
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    # JSON serializers [https://github.com/procore-oss/blueprinter]
    gem "blueprinter"

  RUBY
end

inject_into_file "Gemfile", after: "group :development, :test do" do
  "\n  gem \"dotenv-rails\""
end

# README
file "README.md", <<~MARKDOWN, force: true
  Rails API generated with [louiskb/rails-startup-templates](https://github.com/louiskb/rails-startup-templates), created by [Louis Bourne](https://louisbourne.me).

  ## API conventions

  - Endpoints live under `/api/v1` and inherit `Api::V1::BaseController`.
  - Errors: `{ "error": "…", "code": "not_found", "details": {} }`. Clients branch on `code`.
  - Browser origins allowed by CORS: `ALLOWED_ORIGINS` (comma-separated).
MARKDOWN

# Generators
environment <<~RUBY
  config.generators do |generate|
    generate.test_framework :test_unit, fixture: false
  end
RUBY

# STEP 2: INTERACTIVE OPTIONAL MODULES

# devise (API: latest Devise + devise-jwt. No version pin: ActiveAdmin isn't offered here.)
if should_install?("devise", "Install Devise with JWT authentication (devise + devise-jwt)? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "devise"
      gem "devise-jwt"

    RUBY
  end
end

# dev_tools (no Better Errors: it renders HTML error pages, which an API never serves)
if should_install?("dev_tools", "Install dev tools ('AnnotateRb', 'Pry', 'Rubocop')? (y/n)")
  inject_into_file "Gemfile", after: "group :development do\n" do
    <<~RUBY
      gem "annotaterb"
      gem "pry-byebug"
      gem "pry-rails", require: false
      gem "awesome_print", require: false

    RUBY
  end

  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rubocop", require: false
      gem "rubocop-rails", require: false

    RUBY
  end
end

# testing
if should_install?("testing", "Install testing? (y/n)")
  inject_into_file "Gemfile", after: "group :development, :test do\n" do
    <<~RUBY
      gem "rspec-rails"
      gem "factory_bot_rails"
      gem "faker"
      gem "shoulda-matchers"

    RUBY
  end
end

# image_upload_cloudinary
if should_install?("image_upload_cloudinary", "Install image uploading with Cloudinary? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "cloudinary"

    RUBY
  end
end

# pagination (JSON: pagination travels in response headers)
if should_install?("pagination", "Install Pagy pagination? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do\n" do
    <<~RUBY
      gem "pagy"

    RUBY
  end
end

# ruby_llm
if should_install?("ruby_llm", "Install ruby_llm? (y/n)")
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "ruby_llm"

    RUBY
  end
end

# security
if should_install?("security", "Install security (secure_headers + Rack::Attack)? (y/n)")
  inject_into_file "Gemfile", before: "group :development do\n" do
    <<~RUBY
      gem "secure_headers"
      gem "rack-attack"

    RUBY
  end
end

# claude_code: no gem; the `after_bundle` block closes over this variable.
install_claude_code = should_install?("claude_code", "Set up Claude Code (CLAUDE.md, .claude/ settings and rules)? (y/n)")

# STEP 3: AFTER BUNDLE

after_bundle do
  # `db:schema:load` sets up the Solid Queue/Cache/Cable databases (their tables live in schema files).
  rails_command "db:drop db:create db:schema:load db:migrate"

  # Versioned base controller: every endpoint inherits its error handling.
  file "app/controllers/api/v1/base_controller.rb", <<~RUBY
    module Api
      module V1
        # Parent of every /api/v1 controller. Errors always render as
        # { error:, code:, details: } so clients can branch on `code`.
        class BaseController < ApplicationController
          wrap_parameters false

          rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
          rescue_from ActiveRecord::RecordInvalid, with: :render_invalid
          rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

          private

          def render_error(error:, code:, status:, details: {})
            render json: { error: error, code: code, details: details }, status: status
          end

          def render_not_found(_exception)
            render_error(error: "Resource not found", code: "not_found", status: :not_found)
          end

          def render_invalid(exception)
            render_error(error: exception.message, code: "invalid_input", status: :unprocessable_content,
                         details: exception.record.errors.as_json)
          end

          def render_parameter_missing(exception)
            render_error(error: exception.message, code: "parameter_missing", status: :bad_request)
          end
        end
      end
    end
  RUBY

  # Routes: JSON by default, versioned.
  route <<~RUBY
    namespace :api, defaults: { format: :json } do
      namespace :v1 do
        # /api/v1 endpoints (controllers inherit Api::V1::BaseController)
      end
    end
  RUBY

  # CORS
  file "config/initializers/cors.rb", <<~RUBY, force: true
    # Cross-Origin Resource Sharing: which BROWSER origins may call this API.
    # Set ALLOWED_ORIGINS (comma-separated) per environment, e.g.
    #   ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
    # Native mobile apps send no Origin header, so CORS doesn't restrict them.
    allowed_origins = ENV.fetch("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:5173,http://localhost:8081")
      .split(",").map { |origin| origin.strip.delete_suffix("/") }

    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(*allowed_origins)

        resource "*",
          headers: :any,
          methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
          # Clients read the JWT from Authorization and pagination from Pagy's headers.
          expose: %w[Authorization link current-page page-limit total-pages total-count],
          max_age: 600
      end
    end
  RUBY

  # Gitignore
  append_file ".gitignore", <<~TXT

    # Secrets: never commit these. Before a first push, also check .mcp.json: MCP configs
    # can embed API keys. Reference them as ${VAR} instead.
    # (Rails already ignores config/master.key and config/credentials/*.key.)
    .env*
    !.env.example

    # Claude Code: personal machine-local settings (.claude/settings.json IS shared and committed)
    .claude/settings.local.json

    # Editor and OS files
    *.swp
    .DS_Store
  TXT

  # Action Mailer URLs (Devise password-reset emails)
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Heroku
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  run "touch '.env'"

  # Initialize Git and make first commit.
  git :init
  git add: "."
  git commit: "-m 'chore: initial commit from the API template'"

  gemfile = File.read("Gemfile")

  # shared/devise.rb (API apps: applies shared/devise_jwt.rb)
  if gemfile.match?(/^\s*gem "devise"/)
    apply source_path("shared/devise.rb")
    git add: "."
    git commit: "-m 'feat: install devise with JWT authentication'"
  end

  # shared/dev_tools.rb
  if gemfile.include?('gem "annotaterb"')
    apply source_path("shared/dev_tools.rb")
    git add: "."
    git commit: "-m 'feat: install dev tools (annotaterb, pry, awesome print, rubocop)'"
  end

  # shared/testing.rb
  if gemfile.include?('gem "rspec-rails"')
    apply source_path("shared/testing.rb")
    git add: "."
    git commit: "-m 'feat: install testing'"
  end

  # shared/image_upload_cloudinary.rb
  if gemfile.include?('gem "cloudinary"')
    apply source_path("shared/image_upload_cloudinary.rb")
    git add: "."
    git commit: "-m 'feat: install active storage and cloudinary'"
  end

  # shared/pagination.rb
  if gemfile.include?('gem "pagy"')
    apply source_path("shared/pagination.rb")
    git add: "."
    git commit: "-m 'feat: install pagy pagination'"
  end

  # shared/ruby_llm.rb
  if gemfile.include?('gem "ruby_llm"')
    apply source_path("shared/ruby_llm.rb")
    git add: "."
    git commit: "-m 'feat: install ruby_llm'"
  end

  # shared/security.rb
  if gemfile.include?('gem "secure_headers"')
    apply source_path("shared/security.rb")
    git add: "."
    git commit: "-m 'feat: install security'"
  end

  # shared/claude_code.rb: last module, so it can see everything installed above.
  if install_claude_code
    apply source_path("shared/claude_code.rb")
    git add: "."
    git commit: "-m 'chore: add Claude Code project setup'"
  end

  # Run all migrations towards the end of `after_bundle`.
  rails_command "db:migrate db:seed"

  # Git. Guarded: with no modules there may be nothing new to commit.
  git add: "."
  run "git diff --cached --quiet || git commit -m 'chore(db): run migrations after module setup'"

  # RuboCop: autocorrect generator output (safe corrections only).
  if File.exist?("bin/rubocop")
    run "bin/rubocop -a > /dev/null || true"
    git add: "."
    run "git diff --cached --quiet || git commit -m 'style: autocorrect RuboCop offenses in generated code'"
  end

  # Conventional commits hook. Last on purpose: every commit above is made before it exists.
  apply source_path("shared/conventional_commits.rb")
  git add: "."
  git commit: "-m 'chore: enforce conventional commits with a commit-msg hook'"

  say "✅ Rails 8 API template installation complete! 🚀🔥", :green
end
```

- [ ] **Step 3: `shared/dev_tools.rb`.**
  - After `gemfile = File.read("Gemfile")`, add
    `api_only = File.exist?("config/application.rb") && File.read("config/application.rb").include?("config.api_only = true")`.
  - Change `unless gemfile.match?(/^gem.*['"]better_errors['"]/)` to
    `unless api_only || gemfile.match?(/^gem.*['"]better_errors['"]/)`.
  - Change the Better Errors setup condition to
    `if !api_only && File.exist?("config/environments/development.rb") && …`.

- [ ] **Step 4: `shared/security.rb`.**
  - Add `api_only = …` (same expression) after `gemfile = File.read("Gemfile")`.
  - Wrap the CSP block: `if api_only` → `say "API-only app: skipping the Content Security Policy (it governs HTML pages).", :yellow`, `elsif` the existing condition.
  - In the rack_attack section, write this when `api_only`, else the existing file:

```ruby
    create_file "config/initializers/rack_attack.rb", <<~RUBY
      # Rate limiting. Throttled requests get a 429 in the API error shape.
      # Rack::Attack counts in Rails.cache: development's :null_store never throttles
      # unless `bin/rails dev:cache` is on.
      class Rack::Attack
        # Brute-force protection on sign-in
        throttle("logins/ip", limit: 10, period: 1.minute) do |req|
          req.ip if req.post? && req.path.delete_suffix(".json") == "/api/v1/users/sign_in"
        end

        # Sign-up spam
        throttle("signups/ip", limit: 10, period: 1.hour) do |req|
          req.ip if req.post? && req.path.delete_suffix(".json") == "/api/v1/users"
        end

        # Everything else under /api
        throttle("api/ip", limit: 600, period: 5.minutes) do |req|
          req.ip if req.path.start_with?("/api/")
        end

        self.throttled_responder = lambda do |request|
          retry_after = request.env["rack.attack.match_data"].to_h[:period].to_i
          body = { error: "Too many requests. Please retry later.", code: "rate_limited", details: {} }.to_json
          [ 429, { "content-type" => "application/json", "retry-after" => retry_after.to_s }, [ body ] ]
        end
      end
    RUBY
```

- [ ] **Step 5: `shared/pagination.rb`.**
  - Add `api_only = …`.
  - Wrap the stylesheet `if/elsif` in `unless api_only`.
  - Add:

```ruby
# API apps: pagination travels in response headers (exposed by config/initializers/cors.rb).
base_controller = "app/controllers/api/v1/base_controller.rb"
if api_only && File.exist?(base_controller) && !File.read(base_controller).include?("Pagy::Method")
  inject_into_file base_controller, after: "    class BaseController < ApplicationController\n" do
    <<~RUBY.indent(6)
      include Pagy::Method

      # In an action: `@pagy, posts = pagy(:offset, Post.order(:id))`. The headers
      # (link, current-page, page-limit, total-pages, total-count) are added here.
      after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }

    RUBY
  end
end
```

  - Replace the usage comments and `# POST-INSTALL` block with the Pagy 43 API:

```ruby
# Usage (Pagy 43: `Pagy::Backend`, `Pagy::Frontend` and `pagy_bootstrap_nav` no longer exist):
#   Controller:  include Pagy::Method   (e.g. in ApplicationController)
#                @pagy, @records = pagy(:offset, Model.order(:id), limit: 12)
#   View:        <%== @pagy.series_nav(:bootstrap) %>   (Bootstrap)
#                <%== @pagy.series_nav %>               (plain CSS / Tailwind)
#   JSON API:    response.headers.merge!(@pagy.headers_hash)
```

- [ ] **Step 6: Passing probes.**
  - `gen.sh t12min rails-8/api.rb "" "" --api`:
    - exit 0
    - `probe.sh t12min /up` → 200
    - `bin/rubocop` → no offenses
    - `git log --format=%s` all conventional
  - Without `--api`: `gen.sh t12no rails-8/api.rb` → log contains `Re-run with --api`, and the
    app is not created fully.
  - `gen.sh t12sec rails-8/api.rb "SECURITY=true PAGINATION=true" "" --api`:
    - `ls config/initializers/content_security_policy.rb` → absent
    - runner: memory cache store, 11 POSTs to `/api/v1/users/sign_in` from one IP → the 11th
      is 429 with `"code":"rate_limited"`
    - This runner script (`$SCRATCH/pagy_probe.rb`, run with `bin/rails runner`) must print
      `index 200 total-count=25` and `show 404 not_found`:

```ruby
ActiveRecord::Base.connection.create_table(:things, force: true) { |t| t.string :name }
Thing = Class.new(ApplicationRecord) { self.table_name = "things" }
25.times { |i| Thing.create!(name: "t#{i}") }
Api::V1.const_set(:ThingsController, Class.new(Api::V1::BaseController) {
  define_method(:index) { @pagy, things = pagy(:offset, Thing.order(:id)); render json: { things: things.map(&:name) } }
  define_method(:show) { render json: Thing.find(params[:id]) }
})
Rails.application.routes.draw do
  namespace(:api, defaults: { format: :json }) { namespace(:v1) { resources :things, only: %i[index show] } }
end
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"
session.get "/api/v1/things"
puts "index #{session.response.status} total-count=#{session.response.headers["total-count"]}"
session.get "/api/v1/things/999"
puts "show #{session.response.status} #{session.response.parsed_body["code"]}"
ActiveRecord::Base.connection.drop_table(:things)
```

- [ ] **Step 7: Commit** `feat(api): add a Rails 8 API-only template` (api.rb plus the dev_tools, security and pagination branches).

---

### Task 13: Devise + JWT for the API template (spec D, part 2)

**Files:**
- Create: `shared/devise_jwt.rb`
- Modify: `shared/devise.rb` (gem block adds devise-jwt for API apps; API apps apply devise_jwt.rb instead of views/ApplicationController/PagesController)
- Modify: `shared/testing.rb` (API auth helper + users request spec)

**Interfaces:**
- Consumes: Task 12 `BaseController` class line, `namespace :v1 do` route block
- Produces: `Api::V1::Users::SessionsController`, `Api::V1::Users::RegistrationsController`, `Api::V1::MeController`, `UserBlueprint`, `JwtDenylist`, `Api::FailureApp`

- [ ] **Step 1: Failing probe:** `gen.sh t13 rails-8/api.rb "DEVISE=true TESTING=true" "" --api` on current code:
  - `probe.sh t13 /api/v1/me` → 404 (no route)
  - `app/controllers/application_controller.rb` gains no Devise include

- [ ] **Step 2: `shared/devise.rb`.**
  - After the gem block, compute `api_only` (same expression) and add devise-jwt when missing:

```ruby
if api_only && !File.read("Gemfile").match?(/^\s*gem ["']devise-jwt["']/)
  inject_into_file "Gemfile", after: /^\s*gem ["']devise["'].*\n/ do
    "gem \"devise-jwt\"\n"
  end
  run "bundle install" unless system("bundle check")
end
```

  - Wrap everything from the ApplicationController block through the Bootstrap cancel-button
    block in `if api_only … else … end`. The `if` branch is:

```ruby
if api_only
  # API apps: JWT authentication instead of views, sessions and redirects.
  apply File.join(File.dirname(__FILE__), "devise_jwt.rb")
else
```

- [ ] **Step 3: Create `shared/devise_jwt.rb`:**

```ruby
# shared/devise_jwt.rb
# JWT authentication for API-only apps (Devise + devise-jwt).
# Applied by shared/devise.rb when `config.api_only = true`, after `devise:install` and the
# User model exist. Also runs standalone on such an app.
#
# Endpoints (JSON):
#   POST   /api/v1/users           sign up   → 201 + Authorization: Bearer <token>
#   POST   /api/v1/users/sign_in   sign in   → 200 + Authorization: Bearer <token>
#   DELETE /api/v1/users/sign_out  sign out  → 204, token revoked (jwt_denylists)
#   GET    /api/v1/me              the signed-in user (example authenticated endpoint)
#
# Devise-in-API gotchas handled here (all hit in production on Vegainz):
# 1. `devise_for` inside a namespace renames the mapping (:api_v1_user) and every request
#    401s silently → `devise_for :users, skip: :all` at the ROOT + routes in `devise_scope`.
# 2. ActionController::API doesn't include Devise's helpers or `respond_to`.
# 3. Devise's RegistrationsController#create signs in through the session, which API apps
#    don't have → set the Warden user with `store: false`.
# 4. Sign-out checks "is anyone signed in?" before the JWT strategy runs → 401 → skip
#    `verify_signed_out_user` and authenticate first.

if File.exist?("app/models/jwt_denylist.rb")
  say "JwtDenylist exists: devise-jwt is already set up, skipping.", :yellow
else
  # 2. Devise helpers + respond_to for API controllers
  inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::API\n" do
    <<~RUBY.indent(2)
      include ActionController::MimeResponds
      include Devise::Controllers::Helpers
    RUBY
  end

  # Devise config: no HTML navigation, JSON 401s, JWT dispatch/revocation.
  gsub_file "config/initializers/devise.rb",
    /^  # config\.navigational_formats = .*$/,
    "  # API only: never redirect; failures answer 401 JSON.\n  config.navigational_formats = []"

  inject_into_file "config/initializers/devise.rb", before: /^end\s*\z/ do
    <<~'RUBY'.indent(2)

      # ==> devise-jwt
      # Tokens are dispatched on sign-up and sign-in and revoked on sign-out (JwtDenylist).
      # warden-jwt matches the RAW path, so each pattern also accepts a `.json` suffix:
      # without it `DELETE /api/v1/users/sign_out.json` answered 204 and left the token valid.
      config.jwt do |jwt|
        jwt.secret = ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }
        json_suffix = /(\.json)?/
        jwt.dispatch_requests = [
          [ "POST", %r{^/api/v1/users/sign_in#{json_suffix}$} ],
          [ "POST", %r{^/api/v1/users#{json_suffix}$} ]
        ]
        jwt.revocation_requests = [
          [ "DELETE", %r{^/api/v1/users/sign_out#{json_suffix}$} ]
        ]
        jwt.expiration_time = 24.hours.to_i
      end

      # 401s in the API's error shape ({ error, code, details }).
      config.warden do |manager|
        manager.failure_app = Api::FailureApp
      end
    RUBY
  end

  # Revoked tokens
  generate "migration", "CreateJwtDenylists jti:string:uniq exp:datetime"
  jwt_migration = Dir["db/migrate/*_create_jwt_denylists.rb"].first
  gsub_file jwt_migration, "t.string :jti", "t.string :jti, null: false"
  gsub_file jwt_migration, "t.datetime :exp", "t.datetime :exp, null: false"

  create_file "app/models/jwt_denylist.rb", <<~RUBY
    # Revoked JWTs: devise-jwt stores a token's jti + expiry here on sign-out and rejects
    # any token whose jti is listed.
    class JwtDenylist < ApplicationRecord
      include Devise::JWT::RevocationStrategies::Denylist
    end
  RUBY

  gsub_file "app/models/user.rb", ":recoverable, :rememberable, :validatable",
    ":recoverable, :rememberable, :validatable,\n         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist"

  create_file "app/lib/api/failure_app.rb", <<~RUBY
    module Api
      # Devise's 401 responses in the API's error shape.
      class FailureApp < Devise::FailureApp
        def http_auth_body
          { error: i18n_message, code: "unauthorized", details: {} }.to_json
        end
      end
    end
  RUBY

  create_file "app/blueprints/user_blueprint.rb", <<~RUBY
    class UserBlueprint < Blueprinter::Base
      identifier :id

      fields :email, :created_at
    end
  RUBY

  # 3. Sign-up
  create_file "app/controllers/api/v1/users/registrations_controller.rb", <<~RUBY
    module Api
      module V1
        module Users
          # POST /api/v1/users: devise-jwt adds the Authorization header on success.
          class RegistrationsController < Devise::RegistrationsController
            def create
              build_resource(sign_up_params)

              if resource.save
                # `store: false` skips the session write Devise's `sign_up` would make (API
                # apps have no session); devise-jwt's after-set-user hook still issues the token.
                warden.set_user(resource, scope: resource_name, store: false)
                render json: { user: UserBlueprint.render_as_hash(resource) }, status: :created
              else
                clean_up_passwords(resource)
                render json: { error: "Sign-up failed", code: "invalid_input", details: resource.errors.as_json },
                       status: :unprocessable_content
              end
            end

            private

            def sign_up_params
              params.expect(user: [ :email, :password, :password_confirmation ])
            end
          end
        end
      end
    end
  RUBY

  # 4. Sign-in / sign-out
  create_file "app/controllers/api/v1/users/sessions_controller.rb", <<~RUBY
    module Api
      module V1
        module Users
          # POST /api/v1/users/sign_in and DELETE /api/v1/users/sign_out.
          class SessionsController < Devise::SessionsController
            # API apps have no session, and the JWT strategy hasn't run when Devise asks
            # "is anyone signed in?", so sign-out would 401 before it happens.
            skip_before_action :verify_signed_out_user, raise: false
            before_action :authenticate_user!, only: :destroy

            def destroy
              sign_out(resource_name)
              head :no_content
            end

            private

            def respond_with(resource, _options = {})
              render json: { user: UserBlueprint.render_as_hash(resource) }, status: :ok
            end
          end
        end
      end
    end
  RUBY

  create_file "app/controllers/api/v1/me_controller.rb", <<~RUBY
    module Api
      module V1
        # GET /api/v1/me: the signed-in user (an example authenticated endpoint).
        class MeController < BaseController
          def show
            render json: { user: UserBlueprint.render_as_hash(current_user) }
          end
        end
      end
    end
  RUBY

  base_controller = "app/controllers/api/v1/base_controller.rb"
  if File.exist?(base_controller) && !File.read(base_controller).include?("authenticate_user!")
    inject_into_file base_controller, after: "    class BaseController < ApplicationController\n" do
      "      before_action :authenticate_user!\n\n"
    end
  end

  # 1. Routes: mapping at the root, endpoints inside /api/v1.
  gsub_file "config/routes.rb", /^(\s*)devise_for :users\n/, "\\1devise_for :users, skip: :all\n"
  api_routes = <<~RUBY
    devise_scope :user do
      post "users", to: "users/registrations#create"
      post "users/sign_in", to: "users/sessions#create"
      delete "users/sign_out", to: "users/sessions#destroy"
    end
    get "me", to: "me#show"
  RUBY
  if File.read("config/routes.rb").match?(/^\s*namespace :v1 do\n/)
    inject_into_file "config/routes.rb", api_routes.indent(6), after: /^\s*namespace :v1 do\n/
  else
    inject_into_file "config/routes.rb", before: /^end\s*\z/ do
      "  namespace :api, defaults: { format: :json } do\n    namespace :v1 do\n#{api_routes.indent(6)}    end\n  end\n"
    end
  end

  say "✅ devise-jwt API authentication installed!", :green
end
```

- [ ] **Step 4: `shared/testing.rb`.** After the pages system-spec block, add:

```ruby
# API apps with devise-jwt: sign-in helper + the auth flow end to end.
if File.exist?("app/models/jwt_denylist.rb")
  unless File.exist?("spec/support/api_auth.rb")
    create_file "spec/support/api_auth.rb", <<~RUBY
      # Signs in through the real endpoint and returns the headers a client would send:
      #   get "/api/v1/me", headers: auth_headers_for(user)
      module ApiAuthHelpers
        def auth_headers_for(user, password: "password123")
          post "/api/v1/users/sign_in", params: { user: { email: user.email, password: password } }, as: :json
          { "Authorization" => response.headers["Authorization"] }
        end
      end

      RSpec.configure do |config|
        config.include ApiAuthHelpers, type: :request
      end
    RUBY
  end

  unless File.exist?("spec/requests/api/v1/users_spec.rb")
    run "mkdir -p spec/requests/api/v1"
    create_file "spec/requests/api/v1/users_spec.rb", <<~RUBY
      require "rails_helper"

      RSpec.describe "API v1 authentication", type: :request do
        let(:user) { create(:user) }

        it "signs up and returns a token" do
          post "/api/v1/users",
               params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } },
               as: :json

          expect(response).to have_http_status(:created)
          expect(response.headers["Authorization"]).to start_with("Bearer ")
          expect(response.parsed_body.dig("user", "email")).to eq("new@example.com")
        end

        it "rejects an invalid sign-up in the API error shape" do
          post "/api/v1/users", params: { user: { email: "not-an-email", password: "short" } }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body).to include("code" => "invalid_input")
        end

        it "signs in and returns a token" do
          post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "password123" } }, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.headers["Authorization"]).to start_with("Bearer ")
        end

        it "returns the signed-in user for a valid token" do
          get "/api/v1/me", headers: auth_headers_for(user)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body.dig("user", "id")).to eq(user.id)
        end

        it "answers 401 in the API error shape without a token" do
          get "/api/v1/me"

          expect(response).to have_http_status(:unauthorized)
          expect(response.parsed_body).to include("code" => "unauthorized")
        end

        it "revokes the token on sign-out" do
          headers = auth_headers_for(user)

          delete "/api/v1/users/sign_out", headers: headers
          expect(response).to have_http_status(:no_content)

          get "/api/v1/me", headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    RUBY
  end
end
```

- [ ] **Step 5: Passing probes.** `gen.sh t13 rails-8/api.rb "DEVISE=true TESTING=true SECURITY=true PAGINATION=true DEV_TOOLS=true" "" --api`:
  - exit 0
  - `bundle exec rspec` → 7 examples (health + 6 users), 0 failures
  - `bin/rubocop` → no offenses
  - `bin/rails server -p 3055 -d`, then curl:
    1. `POST /api/v1/users` (JSON) → 201 + `authorization: Bearer`
    2. `GET /api/v1/me` with it → 200
    3. without it → 401 `{"error":…,"code":"unauthorized"…}`
    4. `DELETE /api/v1/users/sign_out` → 204
    5. `GET /api/v1/me` with the old token → 401
    6. `OPTIONS /api/v1/me` with `Origin: http://localhost:5173` and
       `Access-Control-Request-Method: GET` → `access-control-expose-headers` includes
       `Authorization`
  - Kill the server by PID (`kill $(cat tmp/pids/server.pid)`), then `lsof -i :3055` is empty.
  - **If sign-in raises `DisabledSessionError`:** set
    `config.skip_session_storage = [ :http_auth, :params_auth ]` in the devise_jwt.rb gsub,
    regenerate, re-verify.

- [ ] **Step 6: Commit** `feat(api): add devise-jwt authentication to the API template`.

---

### Task 14: Rails 7 regression pass

- [ ] **Step 1:** Generate:
  - `gen.sh t14min rails-7/custom.rb`
  - `gen.sh t14bs rails-7/bootstrap.rb "DEVISE=true ADMIN=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true FRIENDLY_URLS=true NAVBAR=true RUBY_LLM=true IMAGE_UPLOAD_CLOUDINARY=true CLAUDE_CODE=true"`
  - `gen.sh t14tw rails-7/tailwind.rb`
- [ ] **Step 2: Expect:**
  - all exit 0 with the ✅ line
  - `probe.sh` → 200 on each
  - t14bs: `bundle exec rspec` 0 failures, `bundle exec rubocop` no offenses, `git status`
    clean, all commit subjects conventional
  - Fix and re-run until true. Each fix is its own `fix(rails-7): …` commit.

---

### Task 15: Docs

**Files:**
- Modify: `README.md`, `shell-functions.txt`, `CLAUDE.md`, `folder-structure.txt`
- Modify (workbench repo): `~/.claude/notes/rails-template-improvements.md`

- [ ] **Step 1: `shell-functions.txt`.**
  - Base URL → `https://raw.githubusercontent.com/YOUR_USERNAME/rails-startup-templates/refs/heads/master`.
  - Pins `_8.1.2_` → `_8.1.3.1_`.
  - Add `CLAUDE_CODE=true` to both `-all` functions and `CLAUDE_CODE=false` to every `-min`
    function (Rails 7 and 8).
  - Replace the "defaults to Devise v4.9" comment.
  - Add to the quick-reference list and a new `# RAILS 8 - API only` section:

```bash
rails8-api() {
  # JSON API + asks for extras
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}

rails8-api-all() {
  # JSON API + all extras (Devise + JWT, testing, dev tools, security, pagination, Cloudinary, RubyLLM, Claude Code)
  DEVISE=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true CLAUDE_CODE=true \
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}

rails8-api-min() {
  # JSON API only (no extras)
  DEVISE=false TESTING=false DEV_TOOLS=false SECURITY=false PAGINATION=false IMAGE_UPLOAD_CLOUDINARY=false RUBY_LLM=false CLAUDE_CODE=false \
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}
```

- [ ] **Step 2: `README.md`.**
  - Quick Start URLs `/main/` → `/refs/heads/master/`.
  - Add "Rails 8 API (JSON only)" to Quick Start.
  - "What's Included" core list: layout shell, conventional-commits hook, lint-clean.
  - Module table:
    - add the `CLAUDE_CODE` row
    - Admin notes (no Devise version limit)
    - fix the Authentication row (`AUTH=true`, choose `r`)
  - Update the embedded shell-function copy so it matches `shell-functions.txt` exactly (diff
    the two blocks).
  - Shared modules list: add `layout.rb`, `conventional_commits.rb`, `claude_code.rb`,
    `devise_jwt.rb`.
  - "Rails 8 Templates Specifics": replace the false "Propshaft … Bootstrap via
    importmap or CDN" claim with what bootstrap.rb actually does (Sprockets + gem).
  - Add an "API template" section: endpoints, error shape, env vars.
- [ ] **Step 3: Repo `CLAUDE.md`.** ENV var list gains `CLAUDE_CODE`; structure mentions `rails-8/api.rb`; a Key Pattern note says "new shared modules never `exit`" and "`after_bundle` closes over Step 2 locals".
- [ ] **Step 4: `folder-structure.txt`** lists the real files.
- [ ] **Step 5: Verify docs** against the code:
  - `grep -n "main/rails\|_8.1.2_\|v4.9\|4\.9" README.md shell-functions.txt CLAUDE.md` →
    only intentional history mentions
  - every ENV name in the README table appears in a template (`grep -l`)
- [ ] **Step 6: Commit** `docs: document the API template, Claude Code module and fixed URLs`.
- [ ] **Step 7: Notes file (workbench).**
  - Move the implemented items to **Implemented** with commit hashes.
  - Correct the `_body.scss` note (false premise).
  - Log the out-of-scope findings:
    - pagy-tailwind with Tailwind 4
    - Tailwind 3-era simple_form classes
    - existing shared-module `exit` guards abort a main template run
  - Commit in `~/code/louiskb/workbench`:
    `docs(notes): record the 2026-09-17 template improvements`.

---

### Task 16: Full verification matrix, then PR

- [ ] **Step 1:** Regenerate the spec §8 matrix from the final branch. Browser checks with
  Playwright MCP against `bin/rails server -p <port>`:
  - bootstrap-min: desktop 1280 + mobile 390 screenshots; `document.fonts.check("16px 'Work Sans'")` → true; network shows the fonts.googleapis.com CSS 200
  - bootstrap-all: sign up → navbar shows Log out → sign out; `/admin/login` sign-in as admin@example.com → dashboard; CSP header nonce equals the importmap script nonce
  - tailwind-all: home + 390 screenshot
  - tailwind + native auth: sign up → home, Log out
  - Look at every screenshot; fix and re-run anything wrong.
- [ ] **Step 2:** Drop every scratch app's databases (`bin/rails db:drop`) and stop every server (`lsof -i :<port>` empty).
- [ ] **Step 3:** `git push -u origin feat/template-improvements`, then `gh pr create`: title `feat: template improvements, Claude Code module and Rails 8 API template`, body = summary + verification evidence, no attribution lines.
- [ ] **Step 4:** Ask Louis about Q4 (the `rails8-api*` functions in the workbench zshrc) and offer `/self-review`.
