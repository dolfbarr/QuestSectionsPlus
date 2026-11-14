# ADR-0001: QuestSectionsPlus — In-Place Native ObjectiveTracker Architecture

* **Status**: Accepted
* **Date**: 2026-11-14
* **Deciders**: dolfbarr, Pairing Agent
* **Repository**: `https://github.com/dolfbarr/QuestSectionsPlus`

## 1. Context & Problem Statement

In *World of Warcraft: Forever*, Blizzard's `ObjectiveTrackerFrame` displays all tracked quests inside a single monolithic `Quests` module (`QuestObjectiveTracker`) under the `All Objectives` banner. With 15–25 active quests spanning multiple continents and dungeons, the flat list overflows vertically, mixes completed turn-ins with distant zones, orders quests arbitrarily, and wraps long quest names containing redundant `(Dungeon)` suffixes onto multiple lines.

QuestSectionsPlus replaces the monolithic `Quests` list with native peer `ObjectiveTrackerModuleMixin` sections (grouped by `Ready for Turn-In`, `Dungeon: <Instance>`, `Class` / `Professions`, and `<Zone Name>`), adds a compact Blizzard-styled filter and search bar, implements Smart Auto-Fold on zone transitions, and integrates with `ForeverQuestPins` and `Questie` without breaking Blizzard Edit Mode or triggering `ADDON_ACTION_BLOCKED` combat taint.

## 2. Decision Drivers

* **Native UI & Edit Mode Fidelity**: Reuse genuine Blizzard `ObjectiveTrackerFrame` headers, `?`/`...` icons, `►` super-track buttons, inline Quest Item buttons, right-click menus, and Edit Mode anchoring.
* **Zero Combat Lockdown Taint**: Never mutate protected `QuestObjectiveItemButtonTemplate` frames or re-layout `ObjectiveTrackerFrame.modules` during `InCombatLockdown()`.
* **Overflow Prevention Without Tainted `ScrollFrame`**: Collapse non-current zones automatically on zone change with `(count)` header badges rather than clipping protected frames inside a custom `ScrollFrame`.
* **Interface-Per-Boundary Testability**: Isolate pure classification, sorting, filtering, UTF-8 search, and Smart Auto-Fold reducers from WoW client globals so core logic executes in headless Lua 5.1 tests.

## 3. Considered Options

1. **Option A — In-Place Native `ObjectiveTrackerFrame` Module Hook (Accepted)**: Instantiate pooled peer `QuestObjectiveTracker`-derived modules inside `ObjectiveTrackerFrame`, insert a compact Blizzard-styled filter bar under `All Objectives`, and queue structural reflows when `InCombatLockdown()` is true.
2. **Option B — Custom Standalone Frame with Blizzard Atlases**: Hide `ObjectiveTrackerFrame` and rebuild every header, block, context menu, and secure item button pool inside a custom `ScrollFrame`.
3. **Option C — Single `QuestObjectiveTracker` Sub-Line Injection**: Inject non-collapsible divider lines inside the single `QuestObjectiveTracker` module.

## 4. Decision Outcome

* **Chosen Option**: **Option A**, preserving 100% of Blizzard's native block behavior and Edit Mode support while keeping the codebase compact and maintainable.

### Resolved Architectural Matrix

* **Top-Level Peer Headers**: Each active bucket renders as a peer `ObjectiveTrackerModuleMixin` header with native `-`/`+` button and count badge (e.g., `Stranglethorn Vale (4)`).
* **Strict Single-Bucket Precedence**:
  1. `Ready for Turn-In`
  2. `Dungeon: <Instance>` / `Raid: <Instance>` (split per dungeon header)
  3. `Class` / `Professions`
  4. `<Zone Name>` (player's current zone pinned first, remaining zones alphabetical)
* **Filter Bar & Transit Zone Fallback**: Compact bar below `All Objectives` (`All | Zone | Dungeon | Ready` + expandable Search + `Hide Gray`). Non-destructive visual filtering never calls `C_QuestLog.RemoveQuestWatch`. `Zone` matches both `C_QuestLog` header zone and `ForeverQuestPins`/`Questie` objective/turn-in zones; 0-quest transit zones (e.g., `The Veiled Sea`) show `No quests in <Zone> — Show All (N)`.
* **Smart Auto-Fold + Manual Override**: Zone transitions auto-expand `Ready for Turn-In` + matching Zone/Dungeon modules and fold distant zones; manual `+/-` clicks persist until the next zone change.
* **Intra-Section Sorting & Title Formatting**: Quests sort by Level ascending (tie-broken alphabetically), retain `[Level]` difficulty color and `(Elite)`/`(PvP)` suffixes, strip redundant `(Dungeon)` inside `Dungeon: <Instance>` sections, and bind `Ctrl+Click` to `ForeverQuestPins` / `Questie` / `TomTom` waypoints.
* **Non-Quest Modules & Persistence**: `AchievementObjectiveTracker` and `ProfessionsRecipeTracker` remain below quest sections (hidden under `Dungeon` and `Ready` filters). UI settings persist account-wide (`QuestSectionsPlusDB`); filter mode and manual fold overrides persist per-character (`QuestSectionsPlusCharDB`).

## 5. Architectural Invariants & Edge Cases

* **Combat Lockdown Invariant**: Structural module/visibility mutations check `InCombatLockdown()` first; mid-combat actions write to `Store`, flag `pendingReflow = true`, and flush on `PLAYER_REGEN_ENABLED`.
* **Non-Destructive Watch Invariant**: Visual filters never mutate Blizzard's server-saved quest watch list.
* **Literal UTF-8 Search Invariant**: Search queries escape Lua pattern metacharacters so inputs like `[40+]` or `Kurzen's` never raise pattern errors or corrupt multi-byte UTF-8 text.

## 6. Verification Contract

* `luacheck src tests` passes with 0 warnings and 0 errors.
* Headless Lua 5.1 test suite (`tests/`) verifies bucket priority, per-dungeon splitting, `(Dungeon)` stripping, literal UTF-8 search, transit-zone fallback, Smart Auto-Fold overrides, and `InCombatLockdown()` deferral.
* In-game `/qsp diag` verifies active client build, module pool health, combat queue status, and optional waypoint bridge bindings.
