# Changelog

All notable changes to **QuestSectionsPlus** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Replaced custom flat RGBA filter pills and `InputBoxTemplate` search row with 100% native Blizzard `MenuUtil.CreateContextMenu` (on `All Objectives`'s `Header.FilterButton` and right-click on `Quests` header) and `SearchBoxNineSliceTemplate` (`common-searchbar-a`) aligned to `ObjectiveTrackerFrame`'s `250px` (`x = 7..-3`) rail.

### Fixed
- Restored the foldable master `Quests (N)` (`ObjectiveTrackerModuleHeaderTemplate`) header beneath `All Objectives` so collapsing `Quests` hides all quest sub-sections while keeping `Achievements` and `Professions` visible.
- Fixed search and header horizontal overflow beyond `ObjectiveTrackerFrame`'s `260px` container width.

### Added
- Collapsible peer Blizzard `ObjectiveTrackerFrame` sections grouped by `Ready for Turn-In`, `Dungeon: <Instance>`, `Class`, `Professions`, and `<Zone Name>` with header quest-count badges.
- Smart Auto-Fold on zone and instance transitions that automatically expands local and completed sections while folding distant zones, preserving manual `+/-` overrides until the next zone change.
- Native Blizzard filter menu (`All Tracked Quests`, `Current Zone`, `Dungeons & Raids`, `Ready for Turn-In`, `Hide Trivial (Gray)`, `Search Tracked Quests`, `Expand/Collapse All Sections`) and active filter summary badge on the `Quests` header.
- Cross-zone objective/turn-in matching and blame-free fallback notice (`No quests in <Zone> — Show All`) for 0-quest transit zones such as *The Veiled Sea*.
- Level-ascending quest sorting, difficulty coloring, redundant `(Dungeon)` suffix stripping inside dungeon sections, and `Ctrl+Click` waypoint integration for `ForeverQuestPins`, `Questie`, and `TomTom`.
- Zero-taint `InCombatLockdown()` structural mutation queue that flushes safely upon leaving combat (`PLAYER_REGEN_ENABLED`).
- Account-wide (`QuestSectionsPlusDB`) and per-character (`QuestSectionsPlusCharDB`) SavedVariables persistence, Settings panel, and `/qsp` (`/qsp diag`, `/qsp reset`) slash commands.
