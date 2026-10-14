# Changelog

All notable changes to StoneovenBayTools are documented here.

## [Unreleased]

### Added

- Clickable minimap button with settings for response enablement and cooldown.
- Separate modules for initialization, settings, chat tools, and UI.
- Guild, party, and whisper tools using the `!` prefix (`!help`, `!status`, `!professions`, `!location`, `!session`, and `!today`).
- Configurable guild response control through `/sbt on`, `/sbt off`, and `/sbt status`.
- Per-command channel registration for guild chat, party chat, and whispers.
- Character-specific daily session tracking across logouts and reloads.
- Campsite party-profession sharing and `/sbt campsite` diagnostics.
- Response cooldowns and saved member status data.
- Addon-loaded notification when the player logs in.

### Changed

- Guild queries return only the information requested by each command.
- Help output lists each available command on its own line.
- Chat tools use `!` instead of the former `sbt ` prefix; local slash commands remain `/sbt`.
