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
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/rails-8/bootstrap.rb \
  my_app
```

### Rails 8 with Tailwind
```bash
# Assuming Rails 8 is already installed as the latest version.
rails new my_app \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/rails-8/tailwind.rb \
  my_app
```

### Rails 7 with Bootstrap
```bash
# Check your installed Rails versions first:
# Run `gem list rails` to see which Rails versions are installed `rails (8.1.2, 7.2.2, 7.1.6, 7.1.5.2)`
# Then update the function with your specific 7.x version
rails _7.2.2_ new my_app \
  -d postgresql \
  -m https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/rails-7/bootstrap.rb \
  my_app
```

## What's Included

### Core Features (All Templates)
- PostgreSQL database configuration
- Pages controller with home page
- Flash messages with styled components
- Environment variable management (.env)
- Git initialization with .gitignore
- Heroku/Kamal deployment preparation
- Rubocop configuration

### Rails 8 Templates Specifics
- **Asset Pipeline**: Propshaft (Rails 8 default)
- **Modern approach**: Simpler, faster asset serving
- **Import Maps**: JavaScript management without bundler
- **CSS**: Tailwind CSS or Bootstrap via CDN/importmap

### Rails 7 Templates Specifics
- **Asset Pipeline**: Sprockets
- **Traditional approach**: Full asset compilation pipeline
- **Gem-based assets**: Bootstrap, Font Awesome via gems
- **SCSS/SASS**: Full preprocessing support

### Bootstrap Template Specifics

**Rails 8**:
- Bootstrap 5.3 via importmap
- Propshaft for asset serving
- Font Awesome icons
- Simple Form with Bootstrap styling
- Modern CSS architecture

**Rails 7**:
- Bootstrap 5.3 via gem
- Sprockets asset pipeline
- Font Awesome SASS
- Simple Form with Bootstrap styling
- Full SCSS preprocessing

### Tailwind Template Specifics
- Tailwind CSS 3+
- Simple Form with Tailwind styling
- Custom Tailwind configuration
- DaisyUI (optional)

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

| Feature | ENV Variable | Includes |
|---------|-------------|----------|
| **Devise** | `DEVISE=true/false` | User authentication, login/signup pages, customized views |
| **Navbar** | `NAVBAR=true/false` | Pre-built navigation bar (Le Wagon style or custom) |
| **Testing** | `TESTING=true/false` | RSpec, FactoryBot, Faker, Shoulda Matchers |
| **Dev Tools** | `DEV_TOOLS=true/false` | Better Errors, Binding of Caller, Annotate, Awesome Print |
| **Security** | `SECURITY=true/false` | Rack Attack, Secure Headers, brakeman |
| **Pagination** | `PAGINATION=true/false` | Pagy gem with helper configuration |
| **Active Storage** | `ACTIVE_STORAGE=true/false` | File uploads with ActiveStorage setup |
| **Image Processing** | `IMAGE_PROCESSING=true/false` | ImageMagick/libvips configuration |
| **Friendly URLs** | `FRIENDLY_URLS=true/false` | FriendlyId gem for slug-based URLs |
| **Admin Panel** | `ADMIN=true/false` | ActiveAdmin with authentication |

**If ENV variable is not set**, the template will prompt you interactively (yes/no).

## Shell Helper Functions

### Naming Structure for Helper Functions
```bash
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
```

Add these to your `~/.zshrc` or `~/.bashrc` for quick app creation:

```bash
# Replace YOUR_USERNAME with your GitHub username
export RAILS_TEMPLATES_BASE="https://raw.githubusercontent.com/YOUR_USERNAME/rails-startup-templates/main"

##############################################
# RAILS 8 - Interactive modes (prompts for extras)
##############################################

rails8-bootstrap() {
  # Bootstrap + asks for extras
  rails new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind() {
  # Tailwind + asks for extras
  rails new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

rails8-custom() {
  # Asks CSS + asks for extras
  rails new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/custom.rb
}

##############################################
# RAILS 8 - All-inclusive shortcuts (no prompts)
##############################################

rails8-bootstrap-all() {
  # Bootstrap + all extras
  DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true ACTIVE_STORAGE=true IMAGE_PROCESSING=true \
  FRIENDLY_URLS=true ADMIN=true \
  rails new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind-all() {
  # Tailwind + all extras
  DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true ACTIVE_STORAGE=true IMAGE_PROCESSING=true \
  FRIENDLY_URLS=true ADMIN=true \
  rails new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

##############################################
# RAILS 8 - Minimal shortcuts (no extras, no prompts)
##############################################

rails8-bootstrap-min() {
  # Bootstrap only (no extras)
  DEVISE=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false ACTIVE_STORAGE=false IMAGE_PROCESSING=false \
  FRIENDLY_URLS=false ADMIN=false \
  rails new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-8/bootstrap.rb
}

rails8-tailwind-min() {
  # Tailwind only (no extras)
  DEVISE=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false ACTIVE_STORAGE=false IMAGE_PROCESSING=false \
  FRIENDLY_URLS=false ADMIN=false \
  rails new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-8/tailwind.rb
}

rails8-min() {
  # No CSS, no extras (bare Rails 8)
  rails new "$1" -d postgresql
}

##############################################
# RAILS 7 - Interactive modes (prompts for extras)
##############################################

rails7-bootstrap() {
  # Bootstrap + asks for extras
  rails _7.2.2_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind() {
  # Tailwind + asks for extras
  rails _7.2.2_ new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

rails7-custom() {
  # Asks CSS + asks for extras
  rails _7.2.2_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/custom.rb
}

##############################################
# RAILS 7 - All-inclusive shortcuts (no prompts)
##############################################

rails7-bootstrap-all() {
  # Bootstrap + all extras
  DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true ACTIVE_STORAGE=true IMAGE_PROCESSING=true \
  FRIENDLY_URLS=true ADMIN=true \
  rails _7.2.2_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind-all() {
  # Tailwind + all extras
  DEVISE=true NAVBAR=true TESTING=true DEV_TOOLS=true SECURITY=true \
  PAGINATION=true ACTIVE_STORAGE=true IMAGE_PROCESSING=true \
  FRIENDLY_URLS=true ADMIN=true \
  rails _7.2.2_ new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

##############################################
# RAILS 7 - Minimal shortcuts (no extras, no prompts)
##############################################

rails7-bootstrap-min() {
  # Bootstrap only (no extras)
  DEVISE=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false ACTIVE_STORAGE=false IMAGE_PROCESSING=false \
  FRIENDLY_URLS=false ADMIN=false \
  rails _7.2.2_ new "$1" -d postgresql \
    -m $RAILS_TEMPLATES_BASE/rails-7/bootstrap.rb
}

rails7-tailwind-min() {
  # Tailwind only (no extras)
  DEVISE=false NAVBAR=false TESTING=false DEV_TOOLS=false SECURITY=false \
  PAGINATION=false ACTIVE_STORAGE=false IMAGE_PROCESSING=false \
  FRIENDLY_URLS=false ADMIN=false \
  rails _7.2.2_ new "$1" -d postgresql --css=tailwind \
    -m $RAILS_TEMPLATES_BASE/rails-7/tailwind.rb
}

rails7-min() {
  # No CSS, no extras (bare Rails 7)
  rails _7.2.2_ new "$1" -d postgresql
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

# Rails8 - No CSS, no extras
rails8-min() my_app

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
- Uses Propshaft (Rails 8 default)
- Simpler, faster asset serving
- No compilation needed for most assets
- Import maps for JavaScript
- Bootstrap via importmap or CDN
- Cleaner asset structure

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
- **`rails-7/bootstrap.rb`** - Rails 7 with Bootstrap 5
- **`rails-7/tailwind.rb`** - Rails 7 with Tailwind CSS
- **`rails-7/custom.rb`** - Rails 7 with interactive CSS framework selection

### Shared Modules
Modular templates in `shared/` directory can be applied to existing Rails apps:

```bash
# Apply devise to existing app
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/shared/devise.rb

# Apply navbar to existing app
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/shared/navbar.rb

# Apply testing setup
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/shared/testing.rb

# Apply security features
rails app:template LOCATION=https://raw.githubusercontent.com/louiskb/rails-startup-templates/main/shared/security.rb
```

Available shared modules (compatible with both Rails 7 & 8):
- `devise.rb` - User authentication with Devise
- `navbar.rb` - Navigation bar (Le Wagon style or custom)
- `testing.rb` - RSpec, FactoryBot, Faker setup
- `dev_tools.rb` - Better Errors, Annotate, Awesome Print
- `security.rb` - Security headers & rate limiting
- `pagination.rb` - Pagy pagination
- `active_storage.rb` - File upload configuration
- `image_processing.rb` - Image manipulation setup
- `friendly_urls.rb` - SEO-friendly URLs with FriendlyId
- `admin.rb` - Admin dashboard with ActiveAdmin

## Local Development & Testing

To test templates locally before pushing to GitHub:

```bash
# Clone repository
git clone https://github.com/louiskb/rails-startup-templates.git
cd rails-startup-templates

# Test Rails 8 with local path
cd ~/projects
rails new test_app8 -d postgresql -m ~/rails-startup-templates/rails-8/bootstrap.rb

# Test Rails 7 with local path
rails _7.2.2_ new test_app7 -d postgresql -m ~/rails-startup-templates/rails-7/bootstrap.rb

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
