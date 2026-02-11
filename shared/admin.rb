# shared/admin.rb
# Shared Admin Template

# TWO USE CASES:
# 1. Fresh app: called from main template INSIDE `after_bundle` (gems already added/bundles by main template).
# 2. Existing app: Standalone - applying the shared template with an existing app (e.g. `rails app:template LOCATION=shared/admin.rb`).

# GUARD 1: Skip if Admin is already installed.

# STANDALONE SUPPORT: Add gem if missing (existing apps only).
# Fresh apps: main template already added gem → this skips.

# STANDALONE MIGRATION SUPPORT
