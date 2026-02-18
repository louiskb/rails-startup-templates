# shared/tailwind.rb
# Tailwind shared template - can be applied to new OR existing Rails apps.

# GUARD 1: Skip if already installed
if File.exist?("config/tailwind.config.js")
  say "Tailwind already installed (config/tailwind.config.js found), skipping...", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing
gemfile = File.read("Gemfile")

unless gemfile.include?('gem "tailwindcss-rails"')
  say "Adding Tailwind gem...", :blue

  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "tailwindcss-rails"
      gem "simple_form", github: "heartcombo/simple_form"

    RUBY
  end

  run "bundle install" unless system("bundle check")
end

# Install Tailwind (test generator availability post-bundle)
if system("bundle exec rails tailwindcss:install --help > /dev/null 2>&1")
  rails_command "tailwindcss:install"
else
  say "Tailwind generator unavailable. Run `bundle install` first.", :yellow
end

# Simple Form install (test availability)
if system("bundle exec rails generate simple_form:install --help > /dev/null 2>&1")
  generate("simple_form:install")
else
  say "Simple Form generator unavailable. Run `bundle install` first.", :yellow
end

# Tailwind Simple Form initializer
file "config/initializers/simple_form_tailwind.rb", <<~RUBY
  # Use this setup block to configure all options available in SimpleForm.
  SimpleForm.setup do |config|
    # Tailwind CSS configuration
    config.wrappers :tailwind, class: 'mb-4' do |b|
      b.use :html5
      b.use :placeholder
      b.optional :maxlength
      b.optional :minlength
      b.optional :pattern
      b.optional :min_max
      b.optional :readonly
      b.use :label, class: 'block text-sm font-medium text-gray-700 mb-1'
      b.use :input, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50', error_class: 'border-red-500'
      b.use :error, wrap_with: { tag: 'p', class: 'mt-2 text-sm text-red-600' }
      b.use :hint, wrap_with: { tag: 'p', class: 'mt-2 text-sm text-gray-500' }
    end

    config.default_wrapper = :tailwind
  end
RUBY

# STANDALONE MIGRATION SUPPORT
main_templates = ["custom.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :blue
  rails_command "db:migrate"
end

say "✅ Tailwind installation complete!", :green
