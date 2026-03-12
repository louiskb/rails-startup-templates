# shared/ruby_llm.rb
# Shared Ruby LLM Template

# TODO after adding Ruby_LLM:
# 1) Add API key to OPENAI_API_KEY ENV var in `.env` file or for any other AI API Key and reflect changes in `config/initializers/ruby_llm.rb` and '.env' files.

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/ruby_llm.rb`).

# GUARD 1: Skip entire template if Ruby LLM is already installed.
if File.exist?("config/initializers/ruby_llm.rb")
  say "ruby_llm already installed, skipping.", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Inside conditional, once gem added to `Gemfile`, run `bundle install` if not already executed.
# Fresh apps: main template already added gem → this skips.
gemfile = File.read("Gemfile")
if !gemfile.include?('gem "ruby_llm"') && !gemfile.include?("gem 'ruby_llm'")
  say "Adding ruby_llm gem to Gemfile...", :cyan

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "ruby_llm"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

file "config/initializers/ruby_llm.rb", <<~RUBY
  RubyLLM.configure do |config|
    # Add keys ONLY for the providers you intend to use.
    # Using environment variables is highly recommended.
    config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
    # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  end
RUBY

append_file ".env", <<~RUBY
  # OPENAI_API_KEY=replace_with_your_openai_api_key
RUBY

say "✅ Ruby LLM installation complete!", :green
