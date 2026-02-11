# Changelog

## [0.1.5] - 2026-02-11

### Added

- `--skip-seeds` flag to skip database seeding during worktree creation and initialization
- `node_modules` cleanup when closing a worktree
- Support for `bin/setup` during worktree initialization (used when available)

### Changed

- Database names are now passed via environment variables instead of relying on `.env` files
- Improved database prefix detection with fallback to app directory name
- Gemspec now references `RailsWorktree::VERSION` instead of hardcoded version string
- Updated help text with new options and examples

### Fixed

- Database creation and teardown now work reliably without `.env` file dependency
