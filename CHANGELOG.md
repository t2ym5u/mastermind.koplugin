# Changelog

All notable changes to this project will be documented in this file.

Reconstructed from this repository's git history: each release lists the
feature and fix commits it carried. Version bumps, screenshot additions
and CI syncs are left out.

## [1.2.4] - 2026-11-04

### Changed
- Uses less memory: the game loads when you open it, not when KOReader
  starts, so it no longer takes memory or startup time while unplayed.

## [1.2.3] - 2026-11-03

### Changed
- Picks up game-common 1.11.0: the shared on-screen keyboard (where used)
  gives every key the same letter size, and the no-repeat history helper.

## [1.2.2] - 2026-11-02

### Changed
- Picks up game-common 1.10.0: the shared Tools → Games menu also lists
  the games' new "· multiplayer" entries under Party & quiz.

## [1.2.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.2.0] - 2026-10-30

### Added
- "New game" once the code is cracked or the rows run out: the action bar
  shows it in place of Submit and Clear, so the next game no longer needs
  the menu.
- The rules now explain how to play: select a slot, tap a number, Submit.

### Changed
- Redesigned play screen, in line with the other games: a full-width action
  bar, the unified number pad, and a larger board that fills the available
  room (it is now sized to the width too, not just the height). The status
  line reads "Code: 4 · Symbols: 6 · Attempt: n/m" and wraps in landscape
  instead of being cut off.
- The selected slot is shown on the board itself with a much heavier
  outline, instead of being named in the status line.
- The feedback next to each guess is written on two lines ("B:n" over
  "W:n"), which reads much larger in the narrow feedback column.
- New README screenshot.

### Fixed
- The digits in the slots and the feedback text were sized off the slot
  width and then scaled again by the screen DPI, so they overflowed their
  slots on high-DPI screens. Both are now fitted to the room they have and
  centred.

## [1.1.14] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.


## [1.1.13] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.1.12] - 2026-08-05

### Added
- Add ES and DE translations

### Changed
- Add issue/PR templates and CONTRIBUTING.md

## [1.1.11] - 2026-08-04

### Changed
- Symlink common/ to shared game-common

## [1.1.9] - 2026-07-29

### Fixed
- Drop deprecated name field from _meta.lua

## [1.1.8] - 2026-07-29

### Changed
- Use bordered buttons for the symbol selector

## [1.1.6] - 2026-07-28

### Changed
- Add GPL-3.0 LICENSE

## [1.1.3] - 2026-07-21

### Added
- Own translations locally instead of via game-common

## [1.1.1] - 2026-07-15

### Added
- Adopt TitleBar header, sync common/ with game-common

### Changed
- Remove ../game-common/ fallback from package.path

## [1.1.0] - 2026-07-08

### Added
- I18n FR/EN translation + bump to 1.1.0

## [1.0.1] - 2026-07-07

### Changed
- Remove redundant variable alignment in buildLayout
