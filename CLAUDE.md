# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Rails application templates for rapid project scaffolding. Three variants per Rails version (7 and 8): `bootstrap.rb`, `tailwind.rb`, and `custom.rb`, plus a Rails 8 API-only template, `rails-8/api.rb`. Based on Le Wagon bootcamp templates with extensive production-ready additions.

Templates are used via `rails new my_app -d postgresql -m <template_url>` (`rails new my_api --api -d postgresql -m .../rails-8/api.rb` for the API template, which refuses to run without `--api`).

## Repository Structure

```
rails-8/                  # Main templates for Rails 8 (incl. api.rb)
rails-7/                  # Main templates for Rails 7
shared/                   # Modular, composable feature templates
shell-functions.txt       # Copy-paste shell shortcuts for ~/.zshrc
docs/superpowers/         # Design specs and implementation plans (point-in-time)
```

**Main templates** (`bootstrap.rb`, `tailwind.rb`, `custom.rb`, `api.rb`) run in 3 phases:
1. Core setup (gems, config, flash partials, layout shell) — non-interactive
2. Interactive module selection (or ENV var overrides) — prompts user
3. `after_bundle` — generators, shared module application, git commits, migrations, then `rubocop -a` (so the app lints clean) and `shared/conventional_commits.rb` (the commit-msg hook, installed after every template commit)

**Shared modules** (`shared/*.rb`) are dual-mode:
- Called from main templates (inside `after_bundle`, migrations deferred)
- Standalone via `rails app:template LOCATION=shared/xyz.rb` (self-contained, runs own migrations)

Detection uses `caller_locations` to check if running inside a main template's `after_bundle` block.

## Key Architectural Patterns

### ENV Variable Module Control

All optional features use `should_install?` which checks ENV vars before falling back to interactive prompts. This enables CI/non-interactive usage:

```bash
DEVISE=true TESTING=true SECURITY=true rails new app -d postgresql -m rails-8/bootstrap.rb
```

ENV var names: `AUTH`, `DEVISE`, `ADMIN`, `DEV_TOOLS`, `TESTING`, `SECURITY`, `PAGINATION`, `FRIENDLY_URLS`, `IMAGE_UPLOAD_CLOUDINARY`, `NAVBAR`, `RUBY_LLM`, `CLAUDE_CODE`, `BOOTSTRAP`, `TAILWIND`.

A Step 2 answer with no gem to detect later (e.g. `CLAUDE_CODE`) is kept in a local variable: the `after_bundle` block closes over it, so no marker file lands in the initial commit.

### Idempotency Guards

Every shared module checks if it's already installed before proceeding (e.g., checks for `config/initializers/devise.rb`). Safe to run multiple times.

- **Guards match code, not substrings.** A comment that mentions `allow_unauthenticated_access` or `render "shared/navbar"` satisfies an `include?` check and silently skips the inject (hit twice on 2026-09-17). Match the code line: `/^\s*allow_unauthenticated_access/`, `'<%= render "shared/navbar"'`.
- **New shared modules never `exit`.** `exit` inside an `apply`'d module ends the whole `rails new` run. Guard with `if/else` (older modules still use `exit`).
- **Shared modules detect API apps** with `File.read("config/application.rb").include?("config.api_only = true")` and branch (no views, CSP or Better Errors; JWT instead of sessions).
- **Main-template detection** (`caller_locations` against `["bootstrap.rb", "custom.rb", "tailwind.rb", "api.rb"]`) decides whether a module runs its own migrations. Add any new main template to every module's list.

### Source Path Resolution

Templates detect local vs GitHub execution via `__FILE__ =~ %r{https?://}` and resolve paths accordingly with `source_path()`.

### Semantic Git Commits

Each module creates its own git commit after installation, using conventional commit format. Generated apps enforce the format with `.githooks/commit-msg` (enabled via `core.hooksPath`, and by `bin/setup` in fresh clones).

## Rails 7 vs Rails 8 Differences

| Concern | Rails 7 | Rails 8 |
|---------|---------|---------|
| Asset pipeline | Sprockets (replaces Importmap) | Propshaft (default), Sprockets for Bootstrap |
| Bootstrap | Via `bootstrap` + `sassc-rails` gems | Same, but must swap out Propshaft for Sprockets |
| Authentication | Devise only | Native `rails generate authentication` OR Devise |
| Background jobs | Sidekiq + Redis | Solid Queue (built-in) |
| CSS in custom.rb | Bootstrap or Tailwind choice | Bootstrap, Tailwind, or Vanilla choice |
| RuboCop config | Le Wagon's `.rubocop.yml` | Rails' omakase `.rubocop.yml` |
| `gem "json", "< 3"` | Permanent (Rails 7.1 is EOL; json 3 breaks session cookies) | Until the Rails pin includes rails/rails#58601 |
| API template | — | `rails-8/api.rb` |

Bootstrap templates on Rails 8 explicitly remove Propshaft and add Sprockets because Bootstrap requires SCSS preprocessing. `custom.rb` writes `app/assets/config/manifest.js` when Bootstrap is chosen, before bundling, because Sprockets won't boot without one.

## Module Dependencies

- `admin.rb` (ActiveAdmin 3.5+) requires Devise (any version below 6); the templates only offer it when Devise is in the Gemfile
- `authentication.rb` is Rails 8 only (native auth); it adds `allow_unauthenticated_access only: :home` to PagesController, as `devise.rb` adds the Devise skip (main templates write PagesController with neither)
- `devise.rb` applies `devise_jwt.rb` in API apps (JWT endpoints under `/api/v1/users`, `JwtDenylist`, `Api::FailureApp`)
- `layout.rb` is applied by the Bootstrap/Tailwind main templates and by `shared/bootstrap.rb` / `shared/tailwind.rb` (container shell, footer, Google Fonts `<link>` tags)
- `navbar.rb` writes its own partial (Le Wagon structure) with links for Devise, Rails 8 auth, or none, so it runs after the auth modules; main templates write a placeholder partial as the "navbar chosen" flag
- `dev_tools.rb` downloads Le Wagon's `.rubocop.yml` only when the app has none (Rails 8 keeps omakase)
- `claude_code.rb` runs after every other module and detects what's installed from the app's own files
- `conventional_commits.rb` runs last, after the template's own commits

## Testing (When Testing Module Is Installed)

```bash
bundle exec rspec                          # All specs
bundle exec rspec spec/models/             # Model specs only
bundle exec rspec spec/models/post_spec.rb # Single file
bin/test                                   # Wrapper script (if created)
```

The testing module installs RSpec, FactoryBot, Faker, and Shoulda Matchers with example specs that pass on a fresh app: a health request spec, a home-page system spec (non-API), a User factory, a Post example only when a Post model exists, and, in API apps with devise-jwt, a request spec for the whole sign-up/sign-in/sign-out flow.

## Development Workflow

This repo has no application code to run — it's template code. To test changes:

```bash
# Test a template locally (Rails 8 example)
rails new test_app -d postgresql -m rails-8/bootstrap.rb

# Test a standalone shared module on an existing app
cd existing_app && rails app:template LOCATION=../rails-startup-templates/shared/testing.rb

# Test with all modules (non-interactive)
DEVISE=true AUTH=false NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true \
FRIENDLY_URLS=true ADMIN=true IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true CLAUDE_CODE=true \
rails new test_app -d postgresql -m rails-8/bootstrap.rb

# API template (all modules)
DEVISE=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true \
IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true CLAUDE_CODE=true \
rails new test_api --api -d postgresql -m rails-8/api.rb
```

A template change isn't verified until a generated app proves it: the generation exits 0 with the ✅ line, `bin/rubocop` reports no offenses, `bundle exec rspec` is green, `git status` is clean, every `git log` subject is conventional, and `GET /` (or `/up` for API apps) returns 200. Exit code 0 alone has hidden 500s on every page before. Probe sign-in flows over a real `bin/rails server`: `ActionDispatch::Integration::Session` inside `bin/rails runner` breaks Rails 8.1's ExecutionContext and fakes 500s. Drop the test apps' databases afterwards.

## Conventions

- All templates use `simple_form` (never raw `form_with`/`form_for`)
- Double quotes everywhere (Ruby strings, ERB, HTML attributes)
- `ENV.fetch("VAR", nil)` over `ENV["VAR"]` in generated application code
- Conventional commits for template-generated git history
- Flash messages use `_flashes.html.erb` partial, styled per CSS framework
- Generator config disables asset/helper/fixture generation by default
