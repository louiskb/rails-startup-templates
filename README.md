# Rails Startup Templates

Custom Rails application templates for rapid app setup. Based on Le Wagon bootcamp templates with extensive additions for production-ready applications.

## Quick Start

### Requirements

- **Ruby**: 3.1+ (3.2+ recommended for Rails 8)
- **Rails**: 7.0+ or 8.0+
- **PostgreSQL**: 12+
- **Node.js**: 18+ (for asset compilation)
- **Git**: Latest version
- **Bundler**: 2.0+

### Rails 8 with Bootstrap
```bash
# Assuming Rails 8 is already installed as the latest version.
rails new my_app \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/rails-8/bootstrap.rb
```

### Rails 8 with Tailwind
```bash
# Assuming Rails 8 is already installed as the latest version.
rails new my_app \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/rails-8/tailwind.rb
```

### Rails 8 API (JSON only)
```bash
# --api is required: the template refuses to run without it.
rails new my_api --api \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/rails-8/api.rb
```

### Rails 7 with Bootstrap
```bash
# Check your installed Rails versions first:
# Run `gem list '^rails$'` to see which Rails versions are installed, e.g. `rails (8.1.3.1, 7.1.6)`
# Then use your specific 7.x version
rails _7.1.6_ new my_app \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/rails-7/bootstrap.rb
```

## What's Included

### Core Features (All Templates)
- PostgreSQL database configuration
- Pages controller with home page (API template: versioned `/api/v1` base controller instead)
- Flash messages with styled components
- Layout shell: the layout supplies a `<main>` container and a footer, so views never add their own (Bootstrap and Tailwind)
- Environment variable management (.env)
- Git initialization with a .gitignore that also covers `.claude/settings.local.json` and keeps `.env.example`
- Conventional Commits enforced by a versioned `.githooks/commit-msg` hook (`bin/setup` enables it in fresh clones)
- Heroku/Kamal deployment preparation
- RuboCop configuration, with generator output autocorrected so a new app passes `bin/rubocop`

### Rails 8 Templates Specifics
- **Asset Pipeline**: Propshaft (Rails 8 default) for Tailwind and vanilla CSS; the Bootstrap templates swap in Sprockets for SCSS
- **Import Maps**: JavaScript management without a bundler
- **RuboCop**: Rails' omakase config
- **Authentication**: Devise or Rails 8's native authentication generator
- **json pin**: `gem "json", "< 3"` until the Rails version in the shell functions includes rails/rails#58601 (json 3.0 breaks session cookies in Rails 8.1.3.1)

### Rails 7 Templates Specifics
- **Asset Pipeline**: Sprockets
- **Traditional approach**: Full asset compilation pipeline
- **Gem-based assets**: Bootstrap, Font Awesome via gems
- **SCSS/SASS**: Full preprocessing support
- **RuboCop**: Le Wagon's config (Rails 7.1 generates none)
- **json pin**: `gem "json", "< 3"` permanently (Rails 7.1 is end-of-life and incompatible with json 3)

### Bootstrap Template Specifics

**Rails 8 and Rails 7**:
- Bootstrap 5.3 via the `bootstrap` gem (Sprockets), JavaScript pinned with importmap
- Font Awesome SASS
- Le Wagon's stylesheet structure; Google Fonts load from `<link>` tags with preconnect hints
- Simple Form with Bootstrap styling
- Optional navbar whose links match the app's authentication (Devise, Rails 8 auth, or none) and follows `data-bs-theme` dark mode

### Tailwind Template Specifics
- Tailwind CSS 4 via `tailwindcss-rails` (styles in `app/assets/tailwind/application.css`, no `tailwind.config.js`)
- Simple Form with a Tailwind wrapper
- Layout shell with Tailwind classes

### API Template Specifics (Rails 8)
- `rails new --api`, JSON by default under `/api/v1`, every controller inheriting `Api::V1::BaseController`
- One error shape: `{ "error": "…", "code": "not_found", "details": {} }`
- `rack-cors` with an `ALLOWED_ORIGINS` allowlist that exposes `Authorization` and the pagination headers
- Blueprinter serializers
- Devise + devise-jwt (optional): `POST /api/v1/users`, `POST /api/v1/users/sign_in`, `DELETE /api/v1/users/sign_out` (revokes the token), `GET /api/v1/me`
- Pagination (optional) via Pagy 43 response headers; Rack::Attack (optional) with API paths and JSON 429s
- Not offered: native auth, navbar, FriendlyId, ActiveAdmin

## Optional Features

Templates support environment variables to control features without interactive prompts:

```bash
# Install everything (skip prompts)
DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true \
rails new my_app -d postgresql -m TEMPLATE_URL my_app

# Minimal install (skip optional features)
DEVISE=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
rails new my_app -d postgresql -m TEMPLATE_URL my_app
```

### Available Optional Features

| Feature | ENV Variable | Includes | Notes |
|---------|-------------|----------|----------|
| **Devise** | `DEVISE=true/false` | User authentication, login/signup pages, customized views |
| **Navbar** | `NAVBAR=true/false` | Bootstrap navigation bar (Le Wagon style) with Log in / Sign up / Log out links for Devise or Rails 8 auth | Bootstrap templates only |
| **Testing** | `TESTING=true/false` | RSpec, FactoryBot, Faker, Shoulda Matchers |
| **Dev Tools** | `DEV_TOOLS=true/false` | Better Errors, Binding of Caller, AnnotateRb, Awesome Print |
| **Security** | `SECURITY=true/false` | Rack Attack, Secure Headers |
| **Pagination** | `PAGINATION=true/false` | Pagy gem with helper configuration |
| **Image Upload Cloudinary** | `IMAGE_UPLOAD_CLOUDINARY=true/false` | ActiveStorage and Cloudinary configuration |
| **Friendly URLs** | `FRIENDLY_URLS=true/false` | FriendlyId gem for slug-based ID/URLs |
| **Ruby LLM** | `RUBY_LLM=true/false` | RubyLLM for AI models Integration |
| **Admin** | `ADMIN=true/false` | ActiveAdmin auto CRUD dashboard with authentication | Requires Devise (ActiveAdmin 3.5+ supports Devise 5); offered only when Devise is installed. Not in the API template |
| **Claude Code** | `CLAUDE_CODE=true/false` | `CLAUDE.md`, `.claude/settings.json`, one `.claude/rules/*.md` per installed module, and a gitignored `SETUP_NOTES.md` with MCP server suggestions | Runs after every other module |
| **Bootstrap** | `BOOTSTRAP=true/false` | Bootstrap integration | Only use with `custom.rb` main template |
| **Tailwind** | `TAILWIND=true/false` | Tailwind CSS integration | Only use with `custom.rb` main template |
| **Authentication** | `AUTH=true/false` | Asks Devise or Rails 8 native authentication | Rails 8 bootstrap/tailwind/custom templates only |

**If ENV variable is not set**, the template will prompt you interactively (yes/no).

## Shell Helper Functions

### Naming Structure for Helper Functions
```bash
#### Rails 8 ####
# Interactive modes
rails8-bootstrap()   # Bootstrap + asks for extras
rails8-tailwind()    # Tailwind + asks for extras
rails8-custom()      # Asks CSS + asks for extras

# All-inclusive shortcuts
rails8-bootstrap-all()  # Bootstrap + all extras
rails8-tailwind-all()   # Tailwind + all extras

# Minimal shortcuts
rails8-bootstrap-min()  # Bootstrap only
rails8-tailwind-min()   # Tailwind only
rails8-min()            # No CSS, no extras

# API only (rails new --api)
rails8-api()            # JSON API + asks for extras
rails8-api-all()        # JSON API + all extras
rails8-api-min()        # JSON API only

#### Rails 7 ####
# Interactive modes
rails7-bootstrap()   # Bootstrap + asks for extras
rails7-tailwind()    # Tailwind + asks for extras
rails7-custom()      # Asks CSS + asks for extras

# All-inclusive shortcuts
rails7-bootstrap-all()  # Bootstrap + all extras
rails7-tailwind-all()   # Tailwind + all extras

# Minimal shortcuts
rails7-bootstrap-min()  # Bootstrap only
rails7-tailwind-min()   # Tailwind only
rails7-min()            # No CSS, no extras
```

Add these to your `~/.zshrc` or `~/.bashrc` for quick app creation:

```bash
# RAILS 8 & 7 TEMPLATE SHELL FUNCTIONS (ZSH):
# Rails 8 vs 7 template differences = (1) choice between native `authentication` setup vs `devise` in Rails 8 templates, (2) a Rails 8 API-only template (`rails8-api*`).
# Check Rails version(s) on local machine `gem list '^rails$'` and specify in shell functions `rails <version> new...` e.g. `rails _8.1.3.1_ new...`

# `.zshrc` BACKUP:
# `~/.zshrc` = your terminal's "settings file". A syntax error in these functions can break every new terminal tab.
# - If `~/.zshrc` is tracked in git (e.g. a dotfiles repo, or a symlink into one), git IS the backup:
#   commit before adding the functions, and `git checkout` the file to recover. Never `cp` a backup over
#   a symlinked `~/.zshrc`: that replaces the link with a plain file and silently detaches it from the repo.
# - Otherwise, back it up first: `cp ~/.zshrc ~/.zshrc.rails.templates.backup`, and restore from a new tab
#   with `cp ~/.zshrc.rails.templates.backup ~/.zshrc`.
# `source ~/.zshrc` (or `. ~/.zshrc`) reloads Zsh shell configuration without starting a new shell.

# SHELL FUNCTION LIST: (quick reference)
# (Example usage: run `rails8-bootstrap app-name`)
#
###### RAILS 8: ######
#### Rails 8 - interactive mode ####
# `rails8-bootstrap` → # Bootstrap + asks for extras
# `rails8-tailwind` → # Tailwind + asks for extras
# `rails8-custom` → # Asks CSS + asks for extras
# `rails8-api` → # JSON API (rails new --api) + asks for extras
#
#### Rails 8 - everything ####
# `rails8-bootstrap-all` → # Bootstrap + all extras
# `rails8-tailwind-all` → # Tailwind + all extras
# `rails8-api-all` → # JSON API + all extras
#
#### Rails 8 - minimal ####
# `rails8-bootstrap-min` → # Bootstrap only (no extras)
# `rails8-tailwind-min` → # Tailwind only (no extras)
# `rails8-min` → # No CSS, no extras (bare Rails 8)
# `rails8-api-min` → # JSON API only (no extras)
#
###### RAILS 7: ######
#### Rails 7 - interactive mode ####
# `rails7-bootstrap` → # Bootstrap + asks for extras
# `rails7-tailwind` → # Tailwind + asks for extras
# `rails7-custom` → # Asks CSS + asks for extras
#
#### Rails 7 - everything ####
# `rails7-bootstrap-all` → # Bootstrap + all extras
# `rails7-tailwind-all` → # Tailwind + all extras
#
#### Rails 7 - minimal ####
# `rails7-bootstrap-min` → # Bootstrap only (no extras)
# `rails7-tailwind-min` → # Tailwind only (no extras)
# `rails7-min` → # No CSS, no extras (bare Rails 7)

# Replace YOUR_USERNAME with your GitHub username (the branch is part of the URL).
# Can replace RAILS_TEMPLATES_BASE with a local clone's path, e.g. "$HOME/code/rails-startup-templates".
export RAILS_TEMPLATES_BASE="https://raw.githubusercontent.com/YOUR_USERNAME/rails-startup-templates/refs/heads/master"

# `DEVISE=true` installs the latest Devise (ActiveAdmin 3.5+ supports Devise 5).
# `CLAUDE_CODE=true` scaffolds CLAUDE.md, .claude/settings.json, .claude/rules/ and a gitignored SETUP_NOTES.md.

##############################################
# RAILS 8 - Interactive modes (prompts for extras)
##############################################

rails8-bootstrap() {
  # Bootstrap + asks for extras
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind() {
  # Tailwind + asks for extras
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

rails8-custom() {
  # Asks CSS + asks for extras
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/custom.rb
}

rails8-api() {
  # JSON API + asks for extras
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}

##############################################
# RAILS 8 - All-inclusive shortcuts (no prompts)
##############################################
# Rails 8 main templates always defaults to Devise vs native authentication unless changed (e.g. DEVISE=false AUTH=true).

rails8-bootstrap-all() {
  # Bootstrap + all extras
  DEVISE=true AUTH=false RUBY_LLM=true IMAGE_UPLOAD_CLOUDINARY=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true FRIENDLY_URLS=true ADMIN=true CLAUDE_CODE=true \
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind-all() {
  # Tailwind + all extras
  DEVISE=true AUTH=false RUBY_LLM=true IMAGE_UPLOAD_CLOUDINARY=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true FRIENDLY_URLS=true ADMIN=true CLAUDE_CODE=true \
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

rails8-api-all() {
  # JSON API + all extras (Devise + JWT, testing, dev tools, security, pagination, Cloudinary, RubyLLM, Claude Code)
  DEVISE=true TESTING=true DEV_TOOLS=true SECURITY=true PAGINATION=true IMAGE_UPLOAD_CLOUDINARY=true RUBY_LLM=true CLAUDE_CODE=true \
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}

##############################################
# RAILS 8 - Minimal shortcuts (no extras, no prompts)
##############################################

rails8-bootstrap-min() {
  # Bootstrap only (no extras)
  DEVISE=false AUTH=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind-min() {
  # Tailwind only (no extras)
  DEVISE=false AUTH=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

rails8-min() {
  # No CSS, no extras (bare Rails 8)
  BOOTSTRAP=false TAILWIND=false DEVISE=false AUTH=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false \
  DEV_TOOLS=false SECURITY=false PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _8.1.3.1_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/custom.rb
}

rails8-api-min() {
  # JSON API only (no extras)
  DEVISE=false TESTING=false DEV_TOOLS=false SECURITY=false PAGINATION=false IMAGE_UPLOAD_CLOUDINARY=false RUBY_LLM=false CLAUDE_CODE=false \
  rails _8.1.3.1_ new "$1" --api -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/api.rb
}

##############################################
# RAILS 7 - Interactive modes (prompts for extras)
##############################################

rails7-bootstrap() {
  # Bootstrap + asks for extras
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind() {
  # Tailwind + asks for extras
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

rails7-custom() {
  # Asks CSS + asks for extras
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/custom.rb
}

##############################################
# RAILS 7 - All-inclusive shortcuts (no prompts)
##############################################

rails7-bootstrap-all() {
  # Bootstrap + all extras
  DEVISE=true RUBY_LLM=true IMAGE_UPLOAD_CLOUDINARY=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true FRIENDLY_URLS=true ADMIN=true CLAUDE_CODE=true \
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind-all() {
  # Tailwind + all extras
  DEVISE=true RUBY_LLM=true IMAGE_UPLOAD_CLOUDINARY=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true FRIENDLY_URLS=true ADMIN=true CLAUDE_CODE=true \
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

##############################################
# RAILS 7 - Minimal shortcuts (no extras, no prompts)
##############################################

rails7-bootstrap-min() {
  # Bootstrap only (no extras)
  DEVISE=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind-min() {
  # Tailwind only (no extras)
  DEVISE=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

rails7-min() {
  # No CSS, no extras (bare Rails 7)
  BOOTSTRAP=false TAILWIND=false DEVISE=false RUBY_LLM=false IMAGE_UPLOAD_CLOUDINARY=false NAVBAR=false TESTING=false \
  DEV_TOOLS=false SECURITY=false PAGINATION=false FRIENDLY_URLS=false ADMIN=false CLAUDE_CODE=false \
  rails _7.1.6_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/custom.rb
}
```

**After adding to `~/.zshrc`:**
```bash
source ~/.zshrc
```

### Usage Examples
```bash
# Rails 8 - Interactive
rails8-bootstrap my_blog

# Rails 8 - Everything installed
rails8-bootstrap-all my_saas_app

# Rails 8 - Minimal setup
rails8-bootstrap-min my_simple_site

# Rails 8 - No CSS, no extras
rails8-min my_app

# Rails 8 - JSON API with everything
rails8-api-all my_api

# Rails 7 - Interactive
rails7-bootstrap my_legacy_app

# Rails 7 - All features
rails7-bootstrap-all my_full_app
```

## Rails 7 vs Rails 8 Differences

### Asset Pipeline

**Rails 7 Templates**:
- Uses Sprockets asset pipeline
- Bootstrap & Font Awesome via gems
- Full SCSS/SASS preprocessing
- Asset compilation required
- Traditional Rails asset management
- `app/assets/stylesheets/` with SCSS files

**Rails 8 Templates** (Modern approach):
- Uses Propshaft (Rails 8 default) for Tailwind and vanilla CSS
- Bootstrap templates swap Propshaft for Sprockets (SCSS)
- Import maps for JavaScript
- Native authentication generator as an alternative to Devise
- An API-only template

### When to Use Each

**Use Rails 7 Templates if you**:
- Need complex SCSS preprocessing
- Prefer gem-based asset management
- Are maintaining existing Rails 7 apps
- Want proven, stable asset pipeline

**Use Rails 8 Templates if you**:
- Want modern Rails 8 defaults
- Prefer simpler asset management
- Like import maps for JavaScript
- Want faster asset serving
- Starting fresh projects in 2026+

## Template Structure

### Main Templates
- **`rails-8/bootstrap.rb`** - Rails 8 with Bootstrap 5
- **`rails-8/tailwind.rb`** - Rails 8 with Tailwind CSS
- **`rails-8/custom.rb`** - Rails 8 with interactive CSS framework selection
- **`rails-8/api.rb`** - Rails 8 JSON API (run with `rails new --api`)
- **`rails-7/bootstrap.rb`** - Rails 7 with Bootstrap 5
- **`rails-7/tailwind.rb`** - Rails 7 with Tailwind CSS
- **`rails-7/custom.rb`** - Rails 7 with interactive CSS framework selection

### Shared Modules
Modular templates in `shared/` directory can be applied to existing Rails apps:

```bash
# Apply devise to existing app
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/shared/devise.rb

# Apply navbar to existing app
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/shared/navbar.rb

# Apply testing setup
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/shared/testing.rb

# Apply security features
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/refs/heads/master/shared/security.rb
```

Available shared modules (compatible with both Rails 7 & 8):
1. `navbar.rb` - Bootstrap navigation bar (Le Wagon style) with links for the app's authentication
2. `testing.rb` - RSpec, FactoryBot, Faker, Shoulda Matchers, with example specs that pass on a fresh app
3. `image_upload_cloudinary.rb` - Active Storage with Cloudinary for image uploads
4. `dev_tools.rb` - Better Errors, AnnotateRb, Pry, Awesome Print, RuboCop
5. `security.rb` - Security headers, Content Security Policy & rate limiting
6. `pagination.rb` - Pagy pagination (Pagy 43)
7. `friendly_urls.rb` - SEO-friendly URLs with FriendlyId
8. `admin.rb` - Admin dashboard with ActiveAdmin (requires Devise)
9. `devise.rb` - User authentication with Devise (JWT via `devise_jwt.rb` in API apps)
10. `devise_jwt.rb` - JWT authentication endpoints for API apps (applied by `devise.rb`)
11. `authentication.rb` - Native Rails user authentication (Only works with Rails 8 templates)
12. `ruby_llm.rb` - RubyLLM for AI model integration
13. `claude_code.rb` - Claude Code setup: `CLAUDE.md`, settings, per-module rules, MCP setup notes
14. `conventional_commits.rb` - Conventional Commits `commit-msg` hook + README section
15. `layout.rb` - Layout shell: `<main>` container, footer, Google Fonts `<link>` tags (Bootstrap or Tailwind)
16. `bootstrap.rb` - Bootstrap (Only works with Rails 7 and 8 `custom.rb` template)
17. `tailwind.rb` - Tailwind CSS (Only works with Rails 7 and 8 `custom.rb` template)

## Local Development & Testing

To test templates locally before pushing to GitHub:

```bash
# Clone repository
git clone https://github.com/louiskb/rails-startup-templates.git
cd rails-startup-templates

# Test Rails 8 with local path
cd ~/projects
rails new test_app8 -d postgresql -m ~/rails-startup-templates/rails-8/bootstrap.rb

# Test the API template with local path
rails new test_api --api -d postgresql -m ~/rails-startup-templates/rails-8/api.rb

# Test Rails 7 with local path
rails _7.1.6_ new test_app7 -d postgresql -m ~/rails-startup-templates/rails-7/bootstrap.rb

# Clean up test apps
rm -rf test_app8 test_app7
```

## Customization

### Using Your Own Template

1. Fork this repository
2. Modify templates to your preferences
3. Update URLs in your shell functions
4. Test locally first
5. Push to your GitHub

### Common Customizations

- **Change default gems**: Edit Gemfile injection sections
- **Modify stylesheets**: Update assets download URLs
- **Add company branding**: Customize navbar.rb with your design
- **Change authentication**: Replace Devise with Rails 8 built-in auth
- **Add deployment configs**: Kamal, Fly.io, Railway instead of Heroku
- **Switch asset pipeline**: Modify Rails 8 to use Sprockets if preferred

### Creating Custom Navbar

The `shared/navbar.rb` template can be customized for your own navbar design:

```ruby
# In your customized shared/navbar.rb
file "app/views/shared/_navbar.html.erb", <<~HTML
  <nav class="navbar">
    <!-- Your custom navbar HTML -->
  </nav>
HTML
```

Or skip the default navbar entirely and build your own from scratch.

## Troubleshooting

### Template fails with "Connection refused"
- Check your internet connection
- Verify GitHub raw URL is correct and accessible
- Try using local file path for testing

### Every sign-in or sign-up returns 500 (`ArgumentError` in `JSON.parse` / `unknown keyword: quirks_mode`)
json 3.0 (September 2026) is incompatible with Rails 8.1.3.1 and 7.1.6. The templates pin
`gem "json", "< 3"`. In an app generated before the pin, add that line to the Gemfile and run
`bundle install`.

### Bundler errors
```bash
gem update --system
gem install bundler
bundle update --bundler
```

### PostgreSQL connection errors
Ensure PostgreSQL is running:
```bash
# macOS
brew services start postgresql
```

### Asset pipeline issues (Rails 7)
If Sprockets assets aren't compiling:
```bash
rails assets:precompile
rails assets:clobber
rails assets:precompile
```

### Import map issues (Rails 8)
If JavaScript isn't loading:
```bash
bin/importmap pin bootstrap
rails importmap:install
```

## Credits & License

Created by **Louis Bourne** | Full Stack Software Engineer

Based on and inspired by [Le Wagon's Rails Templates](https://github.com/lewagon/rails-templates) (MIT License) with extensive modifications and additional production features.

Licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Email**: [dev@louisbourne.me](mailto:dev@louisbourne.me)
- **Portfolio**: [louisbourne.me](https://louisbourne.me)

---

**Good luck and happy coding!** 🚀
