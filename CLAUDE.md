# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Rails application templates for rapid project scaffolding. Three variants per Rails version (7 and 8): `bootstrap.rb`, `tailwind.rb`, and `custom.rb`. Based on Le Wagon bootcamp templates with extensive production-ready additions.

Templates are used via `rails new my_app -d postgresql -m <template_url>`.

## Repository Structure

```
rails-8/                  # Main templates for Rails 8
rails-7/                  # Main templates for Rails 7
shared/                   # Modular, composable feature templates
shell-functions.txt       # Copy-paste shell shortcuts for ~/.zshrc
```

**Main templates** (`bootstrap.rb`, `tailwind.rb`, `custom.rb`) run in 3 phases:
1. Core setup (gems, config, flash partials) — non-interactive
2. Interactive module selection (or ENV var overrides) — prompts user
3. `after_bundle` — generators, shared module application, git commits, migrations

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

ENV var names: `AUTH`, `DEVISE`, `ADMIN`, `DEV_TOOLS`, `TESTING`, `SECURITY`, `PAGINATION`, `FRIENDLY_URLS`, `IMAGE_UPLOAD_CLOUDINARY`, `NAVBAR`, `RUBY_LLM`, `BOOTSTRAP`, `TAILWIND`.

### Idempotency Guards

Every shared module checks if it's already installed before proceeding (e.g., checks for `config/initializers/devise.rb`). Safe to run multiple times.

### Source Path Resolution

Templates detect local vs GitHub execution via `__FILE__ =~ %r{https?://}` and resolve paths accordingly with `source_path()`.

### Semantic Git Commits

Each module creates its own git commit after installation, using conventional commit format.

## Rails 7 vs Rails 8 Differences

| Concern | Rails 7 | Rails 8 |
|---------|---------|---------|
| Asset pipeline | Sprockets (replaces Importmap) | Propshaft (default), Sprockets for Bootstrap |
| Bootstrap | Via `bootstrap` + `sassc-rails` gems | Same, but must swap out Propshaft for Sprockets |
| Authentication | Devise only | Native `rails generate authentication` OR Devise |
| Background jobs | Sidekiq + Redis | Solid Queue (built-in) |
| CSS in custom.rb | Bootstrap or Tailwind choice | Bootstrap, Tailwind, or Vanilla choice |

Bootstrap templates on Rails 8 explicitly remove Propshaft and add Sprockets because Bootstrap requires SCSS preprocessing.

## Module Dependencies

- `admin.rb` (ActiveAdmin) requires Devise v4.9 — checks for Devise before proceeding
- `authentication.rb` is Rails 8 only (native auth)
- `navbar.rb` downloads from Le Wagon's awesome-navbars repo
- `dev_tools.rb` downloads Le Wagon's `.rubocop.yml`

## Testing (When Testing Module Is Installed)

```bash
bundle exec rspec                          # All specs
bundle exec rspec spec/models/             # Model specs only
bundle exec rspec spec/models/post_spec.rb # Single file
bin/test                                   # Wrapper script (if created)
```

The testing module installs RSpec, FactoryBot, Faker, and Shoulda Matchers with example specs.

## Development Workflow

This repo has no application code to run — it's template code. To test changes:

```bash
# Test a template locally (Rails 8 example)
rails new test_app -d postgresql -m rails-8/bootstrap.rb

# Test a standalone shared module on an existing app
cd existing_app && rails app:template LOCATION=../rails-startup-templates/shared/testing.rb

# Test with all modules (non-interactive)
DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true \
FRIENDLY_URLS=true ADMIN=true IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true \
rails new test_app -d postgresql -m rails-8/bootstrap.rb
```

## Conventions

- All templates use `simple_form` (never raw `form_with`/`form_for`)
- Double quotes everywhere (Ruby strings, ERB, HTML attributes)
- `ENV.fetch("VAR", nil)` over `ENV["VAR"]` in generated application code
- Conventional commits for template-generated git history
- Flash messages use `_flashes.html.erb` partial, styled per CSS framework
- Generator config disables asset/helper/fixture generation by default
