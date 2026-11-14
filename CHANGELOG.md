# Changelog

All notable changes to **QuestSectionsPlus** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Collapsible peer Blizzard `ObjectiveTrackerFrame` sections grouped by `Ready for Turn-In`, `Dungeon: <Instance>`, `Class`, `Professions`, and `<Zone Name>` with header quest-count badges.
- Smart Auto-Fold on zone and instance transitions that automatically expands local and completed sections while folding distant zones, preserving manual `+/-` overrides until the next zone change.
- Compact Blizzard-styled filter toolbar beneath `All Objectives` with `All`, `Zone`, `Dungeon`, and `Ready` toggles, expandable literal search input, and `Hide Trivial (Gray)` toggle.
- Cross-zone objective/turn-in matching and blame-free fallback notice (`No quests in <Zone> — Show All`) for 0-quest transit zones such as *The Veiled Sea*.
- Level-ascending quest sorting, difficulty coloring, redundant `(Dungeon)` suffix stripping inside dungeon sections, and `Ctrl+Click` waypoint integration for `ForeverQuestPins`, `Questie`, and `TomTom`.
- Zero-taint `InCombatLockdown()` structural mutation queue that flushes safely upon leaving combat (`PLAYER_REGEN_ENABLED`).
- Account-wide (`QuestSectionsPlusDB`) and per-character (`QuestSectionsPlusCharDB`) SavedVariables persistence, Settings panel, and `/qsp` (`/qsp diag`, `/qsp reset`) slash commands.
