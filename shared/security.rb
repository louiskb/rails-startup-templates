# shared/security.rb
# Shared Security Template
# Security Headers + Rate Limiting
# Production security: CSP, XSS protection, rate limiting.

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/security.rb`).

gemfile = File.read("Gemfile")

# GUARD 1: Skip if Security Template is already installed.
if gemfile.match?(/^gem.*['"]secure_headers['"]/) && gemfile.match?(/^gem.*['"]rack-attack['"]/) && File.exist?("config/initializers/rack_attack.rb")
  say "Security gems + Rack::Attack config found, skipping.", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gems_added = false

unless gemfile.match?(/^gem.*['"]secure_headers['"]/)
  say "Adding `secure_headers` gem...", :blue

  inject_into_file "Gemfile", before: "group :development do\n" do
    <<~RUBY
      gem "secure_headers"

    RUBY
  end

  gems_added = true
end

unless gemfile.match?(/^gem.*['"]rack-attack['"]/)
  say "Adding rack-attack (rate limiting)...", :blue
  inject_into_file "Gemfile", before: "group :development do\n" do
    <<~RUBY
      gem "rack-attack"

    RUBY
  end

  gems_added = true
end

if gems_added
  run "bundle install" unless system("bundle check")
end

# `secure_headers` config
# Security Headers (automatic on every response): CSP → blocks XSS, HSTS → HTTPS only, X-Frame-Options → no clickjacking, no MIME sniffing.
unless File.exist?("config/initializers/secure_headers.rb")
  say "Creating `secure_headers` initializer...", :blue
  # `create_file` works similarly to `file` method.
  create_file "config/initializers/secure_headers.rb", <<~RUBY
    SecureHeaders::Configuration.default do |config|
      config.csp.build(:default_src => :self)
      config.hsts = {
        override: true,
        include_subdomains: true,
        max_age: 31_556_926 # 1 year (in seconds)
      }
      config.x_frame_options = :DENY
      config.x_content_type_options = :nosniff
      config.x_xss_protection = { value: '1; mode=block' }
      config.x_permitted_cross_domain_policies = :none
      config.referrer_policy = :strict_origin_when_cross_origin
    end
  RUBY

  say "Headers: CSP, HSTS, X-Frame, XSS protection enabled", :green

else
  say "Secure headers initializer exists.", :yellow
end

# `secure_headers`: CSP, HSTS, XSS protection (automatic).
# `secure_headers` docs = https://github.com/github/secure_headers

# `rack-attack` (rate limiting)
# Rate limiting: 5 login attempts/minute/IP, 100 API calls/minute/IP, blocks bad bots. 
unless File.exist?("config/initializers/rack_attack.rb")
  say "Creating rack-attack rate limiting...", :blue

  create_file "config/initializers/rack_attack.rb", <<-RUBY
  class Rack::Attack
    # Throttle login attempts (brute force protection)
    throttle("req/ip login", limit: 5, period: 1.minute) do |req|
      req.ip if req.path == '/users/sign_in' && req.post?
    end

    # Throttle API requests
    throttle("req/ip api", limit: 100, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/api')
    end

    # Block obvious bad bots
    Rack::Attack.blacklist("bad bots") do |req|
      Rack::Attack::Request.new(req).user_agent.to_s.downcase.match?(/\b(ahrefs|semrush|mj12bot)\b/i)
    end
  end
  RUBY

  say "Rate limiting: 5 logins/min/IP, 100 API/min/IP enabled.", :green

else
  say "Rack::Attack initializer exists.", :yellow
end

# `rack-attack`: Rate limiting (5 logins/minute/IP, 100 API calls/minute/IP).
# Rate limit exceeded? → `429 Too Many Requests`.
# `rack-attack` gem docs = https://github.com/rack/rack-attack

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

say "✅ Security installation complete!", :green
