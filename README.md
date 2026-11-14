# QuestSectionsPlus

Native Blizzard-styled foldable quest sections, Smart Auto-Fold, and non-destructive zone/dungeon filters for **World of Warcraft: Forever** (`## Interface: 16001`).

## Features

- **Native Peer Section Headers**: Replaces the flat `Quests` list inside Blizzard's `ObjectiveTrackerFrame` (`All Objectives`) with genuine `ObjectiveTrackerModuleTemplate` peer sections and quest-count badges:
  1. `Ready for Turn-In (N)`
  2. `Dungeon: <Instance Name> (N)` / `Raid: <Instance Name> (N)`
  3. `Class: <Class> (N)` & `Professions (N)`
  4. `<Zone Name> (N)` (your current zone floats above distant zones)
- **Full Native Tracker Fidelity**: Preserves Blizzard Edit Mode positioning, `?` / `...` quest icons, `►` super-track POI buttons, right-click menus, AutoQuest popups, and inline usable Quest Item buttons (backed by taint-free `UIParent` secure item overlays).
- **Smart Auto-Fold + Manual Override**: Entering a new zone or dungeon automatically expands `Ready for Turn-In` and your local Zone/Dungeon while folding distant zones into single-line headers. Clicking any section header overrides folding until your next zone transition.
- **Compact Filter & Search Bar**: Located directly below `All Objectives` (toggleable via Blizzard's header filter icon):
  - **Filter Pills**: `All`, `Zone`, `Dung`, `Ready` (strictly visual—never calls `RemoveQuestWatch` or wipes map pins).
  - **Cross-Zone & Transit Handling**: `Zone` matches both Quest Log category headers and active objective/turn-in destination maps (`Word to Ironforge` matches inside *Ironforge*). Zero-quest transit zones (*The Veiled Sea*) display a 1-click `No quests in <Zone> — Show All (N)` row.
  - **Hide Trivial (`!Gray`)**: Hides gray low-level quests per character.
  - **Literal Search (`Find`)**: Searches quest titles, zones, `[Level]`, and objective text safely with escaped Lua patterns and UTF-8 preservation.
- **Clean Dungeon Formatting & Sorting**: Sorts quests within each section from easiest to hardest by level and strips redundant `(Dungeon)` suffixes inside `Dungeon: <Instance>` sections to prevent two-line title wrapping.
- **Waypoint Bridge (`Ctrl + Left-Click`)**: `Ctrl+Click` on any quest header triggers a waypoint via **ForeverQuestPins**, **TomTom**, **Questie**, or Blizzard SuperTracking.

## Installation

Copy or symlink the `QuestSectionsPlus` folder into your *World of Warcraft: Forever* AddOns directory:

```text
World of Warcraft/_forever_/Interface/AddOns/QuestSectionsPlus/
```

Ensure `QuestSectionsPlus.toc` is directly inside `Interface/AddOns/QuestSectionsPlus/`.

## Slash Commands

- `/qsp` or `/questsections` — Open the Settings panel (`Options -> AddOns -> QuestSectionsPlus`)
- `/qsp filter <all|zone|dungeon|ready>` — Switch active tracker filter
- `/qsp gray` — Toggle hiding trivial (gray) quests
- `/qsp autofold` — Toggle Smart Auto-Fold on zone transitions
- `/qsp diag` — Print runtime diagnostics, section states, combat queue status, and detected bridges
- `/qsp reset` — Restore account and character settings to defaults

## Development & Verification

```bash
# Lint with luacheck (Lua 5.1 standard)
luacheck src tests

# Execute headless Lua 5.1 unit test suite
lua tests/run.lua
```

## License

MIT
