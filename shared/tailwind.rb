# shared/tailwind.rb
# Tailwind shared template - can be applied to new OR existing Rails apps.

# GUARD 1: Skip if already installed
# Tailwind 4 (tailwindcss-rails 4.x) creates app/assets/tailwind/application.css and no config/tailwind.config.js.
if File.exist?("config/tailwind.config.js") || File.exist?("app/assets/tailwind/application.css")
  say "Tailwind already installed, skipping...", :yellow
  exit
end

# STANDALONE SUPPORT: Add gem if missing
gemfile = File.read("Gemfile")

unless gemfile.include?('gem "tailwindcss-rails"')
  say "Adding Tailwind gem...", :cyan

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
    # Tailwind CSS 4 classes (v4 renamed shadow-sm/ring and dropped ring-opacity-*; its reset removes input borders)
    config.wrappers :tailwind, class: "mb-4" do |b|
      b.use :html5
      b.use :placeholder
      b.optional :maxlength
      b.optional :minlength
      b.optional :pattern
      b.optional :min_max
      b.optional :readonly
      b.use :label, class: "block text-sm font-medium text-gray-700 mb-1"
      b.use :input, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-xs focus:border-indigo-300 focus:ring-3 focus:ring-indigo-200/50 focus:outline-hidden", error_class: "border-red-500"
      b.use :error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
      b.use :hint, wrap_with: { tag: "p", class: "mt-2 text-sm text-gray-500" }
    end

    # Checkboxes: a small box beside its label, not the full-width text-input styling above.
    config.wrappers :tailwind_boolean, class: "mb-4" do |b|
      b.use :html5
      b.optional :readonly
      b.wrapper tag: "div", class: "flex items-center gap-2" do |ba|
        ba.use :input, class: "size-4 rounded border-gray-300 accent-indigo-600"
        ba.use :label, class: "text-sm text-gray-700"
      end
      b.use :error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
      b.use :hint, wrap_with: { tag: "p", class: "mt-2 text-sm text-gray-500" }
    end

    config.default_wrapper = :tailwind
    config.wrapper_mappings = { boolean: :tailwind_boolean }
    # Loaded after simple_form.rb (alphabetical), so these override its :nested and "btn" defaults.
    config.boolean_style = :inline
    config.button_class = "rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
  end
RUBY

# Layout shell: <main> container, footer, Google Fonts <link> tags (sibling shared/layout.rb;
# File.dirname(__FILE__) works for both a local path and a raw GitHub URL).
apply File.join(File.dirname(__FILE__), "layout.rb")

# STANDALONE MIGRATION SUPPORT
main_templates = ["custom.rb"]
in_main_template = caller_locations.any? { |loc| loc.label == 'after_bundle' || loc.path =~ Regexp.union(main_templates) }

if in_main_template
  say "Main template detected → skipping migrations", :yellow
else
  say "Standalone mode → executing db:migrate...", :cyan
  rails_command "db:migrate"
end

say "✅ Tailwind installation complete!", :green
