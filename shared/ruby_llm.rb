# shared/ruby_llm.rb
# Shared Ruby LLM Template

# GUARD 1: Skip if ruby_llm is already installed.
if File.exist?("config/initializers/ruby_llm.rb")
  say "ruby_llm already installed, skipping.", :yellow
  exit
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
  # OPENAI_API_KEY=replace_with_your_openai_key
RUBY
