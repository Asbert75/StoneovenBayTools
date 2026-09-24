# Changelog

All notable changes to StoneovenBayTools are documented here.

## [Unreleased]

### Added

- Guild and whisper tools for `sbt help`, `sbt status`, `sbt professions`, and `sbt location`.
- Configurable guild response control through `/sbt on`, `/sbt off`, and `/sbt status`.
- Per-command channel registration for guild chat and whispers.
- Response cooldowns and saved member status data.
- Addon-loaded notification when the player logs in.

### Changed

- Guild queries return only the information requested by each command.
- Help output lists each available command on its own line.
