# QuestSectionsPlus

Native Blizzard-styled foldable quest sections, Smart Auto-Fold, and non-destructive zone/dungeon filters for **World of Warcraft: Forever** (`## Interface: 16001`).

## Features

- **Master Foldable `Quests` Header + Native Peer Section Headers**: Preserves the foldable master `Quests (N)` (`ObjectiveTrackerModuleHeaderTemplate`) category under `All Objectives` and groups quests beneath it into `ObjectiveTrackerModuleTemplate` sub-sections with quest-count badges:
  1. `Ready for Turn-In (N)`
  2. `Dungeon: <Instance Name> (N)` / `Raid: <Instance Name> (N)`
  3. `Class: <Class> (N)` & `Professions (N)`
  4. `<Zone Name> (N)` (your current zone floats above distant zones)
- **Full Native Tracker Fidelity**: Preserves Blizzard Edit Mode positioning, `?` / `...` quest icons, `►` super-track POI buttons, right-click menus, AutoQuest popups, and inline usable Quest Item buttons (backed by taint-free `UIParent` secure item overlays).
- **Smart Auto-Fold + Manual Override**: Entering a new zone or dungeon automatically expands `Ready for Turn-In` and your local Zone/Dungeon while folding distant zones into single-line headers. Clicking any section header overrides folding until your next zone transition.
- **100% Native Blizzard Filter Menu & Search (`Zero Custom Buttons`)**:
  - **Header Filter Menu (`MenuUtil`)**: Left-clicking Blizzard's native Filter icon on `All Objectives` (or right-clicking `Quests`) opens a native `MenuUtil` menu with `All Tracked Quests`, `Current Zone`, `Dungeons & Raids`, `Ready for Turn-In`, `Hide Trivial (Gray)`, `Search Tracked Quests`, and `Expand / Collapse All Sections` (strictly visual—never calls `RemoveQuestWatch` or wipes map pins).
  - **Cross-Zone & Transit Handling**: `Current Zone` matches both Quest Log category headers and active objective/turn-in destination maps (`Word to Ironforge` matches inside *Ironforge*). Zero-quest zones display a 1-click `No quests in <Zone> — Show All (N)` tracker line.
  - **Native `SearchBoxNineSliceTemplate`**: Right-clicking the Filter icon (or toggling `Search Tracked Quests`) opens Blizzard's native `common-searchbar-a` input aligned under `Quests` to filter titles, zones, `[Level]`, and objective text safely with escaped Lua patterns.
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
- `/qsp search [query]` — Toggle the search bar or filter tracked quests by query
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
