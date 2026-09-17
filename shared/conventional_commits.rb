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
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/conventional_commits.rb`).

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

# Fresh clones: bin/setup turns the hook on. `system` (not `system!`) so a copy without .git
# (e.g. a downloaded zip) still sets up.
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
