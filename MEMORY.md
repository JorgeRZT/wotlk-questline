# Project memory

Running log of what has been built, why, and what is still open. Newest information is in the sections at the top; the version history is at the bottom.

## What this is

**WotLK QuestLine** (`wotlk-questline`) is a WoW **3.3.5a** addon for Warmane (a TrinityCore-based private server). It simulates leveling from the player's class/race/faction/level/XP/position and lists the most efficient quests per level, with an arrow and world-map markers. Repo: <https://github.com/JorgeRZT/wotlk-questline> (owner `JorgeRZT`). UI is in Spanish, documentation in English.

## Decisions

- **No leveling guide available**, so the plan is computed dynamically from a quest database instead of a hand-written route.
- **Score = XP / seconds**, greedy simulation: pick the best quest, move the simulated position to its turn-in, repeat until the level bar is full, then the next level.
- **Data is static** (generated Lua), because the 3.3.5 client has no quest database. Source: TrinityCore TDB 3.3.5 (same family as Warmane). AzerothCore was used first, but its base dump lacks many loot rows.
- **World coordinates internally**, zone percentages only for display. Distances, the arrow and map markers use world X/Y; zone bounds come from `WorldMapArea` CSVs (Questie repo).
- **Zone names are approximate**: zone rectangles overlap, so the zone is the quest's own sort zone if it contains the point, otherwise the rectangle whose centre is closest.
- **XP rate** is a user setting (`QuestLineDB.xpRate`), applied to quest XP only (no kill XP).
- **Releases via tag**: `.github/workflows/release.yml` zips `QuestLine/` (no `tools/`) so addon managers get the right folder name.
- **Docs in English, UI in Spanish** (user requirement).

## Architecture

| File | Role |
| --- | --- |
| `QuestLine.toc` | Interface 30300, SavedVariables `QuestLineDB`, file order |
| `Data/Zones.lua`, `Data/Quests.lua` | Generated data (`QL.Zones`, `QL.Continents`, `QL.XPToLevel`, `QL.Quests`) |
| `Planner.lua` | Pure planner (no WoW API): eligibility, scoring, chain scoring, level simulation; testable outside the client |
| `Core.lua` | Player state, world position, completed-quest query, done/skipped lists, async replanning (coroutine), `StepFor` |
| `UI.lua` | Window, rows, buttons, tooltip, arrow, slash commands |
| `Map.lua` | World map numbered pins and spawn dots |
| `tools/split_tdb.py`, `tools/build_data.py`, `tools/dbc/*.csv` | Data pipeline |

Quest data fields (`Quests.lua`): `t` title, `l` level, `m` min level, `M` max level, `x` base XP, `r` race mask, `c` class mask, `d` side (1 Alliance, 2 Horde, 0 both), `p` prerequisite quest (negative = must be active), `n` next quest, `e` exclusive group, `w` work estimate, `s`/`f` start/finish points, `o` objectives (list of point lists), `u` unknown-location objectives. Points are `{map, worldX, worldY, areaID}`.

## Data pipeline

1. Download `TDB_full_world_335.<build>.7z` from the TrinityCore releases, extract the `.sql`.
2. `python3 tools/split_tdb.py <sql> <dir>` writes one file per needed table.
3. `python3 tools/build_data.py <dir> Data` regenerates `Data/*.lua` (~17 s).

Filters: no dailies/weeklies/repeatables, timed quests, group/dungeon/raid/PvP/event quests, profession or reputation/skill-gated quests; negative sort IDs are kept only for class quests. Quests without a known turn-in spawn or start (unless a chain follower) are dropped. Faction side is derived from the quest giver's faction template (`EnemyGroup` bits), race/class from the allowable masks.

Objective locations: creature/GO spawns clustered on a 300-yd grid (top 5 clusters). Item objectives use creature loot, reference loot (with a 25% assumed chance when none), skinning, pickpocketing and GO chests; unknown-source objectives set `u` (120 s penalty each in the planner).

## 3.3.5 client gotchas learned

- `Frame:SetShown` does not exist (caused the empty list in v0.4.0). Use `Show`/`Hide`.
- Completed quests need `QueryQuestsCompleted()` then the `QUEST_QUERY_COMPLETE` event, then `GetQuestsCompleted(table)`.
- No player world position API: read continent-level `GetPlayerMapPosition` after `SetMapZoom(continent)` and convert with continent bounds; skip while the world map is open.
- `GetCurrentMapAreaID()` is assumed to return the `WorldMapArea.ID` (unverified; `/ql debug` prints it).
- Texture rotation uses 8-argument `SetTexCoord`; direction of the arrow still unverified in-game.
- `UnitXP`, `UnitFactionGroup`, `GetQuestLogTitle` (9th return = questID) behave as expected.

## Things that went wrong (and fixes)

- AzerothCore `zoneId`/`areaId` are mostly 0 → zones derived from coordinates and `WorldMapArea` rectangles.
- `QuestXP.dbc` is empty in the SQL dumps → CSV from Questie, indexed 0-9 by `RewardXPDifficulty`.
- Repeatable flag was mis-masked (0x8 is "sharable"); repeatable is `SpecialFlags & 1`.
- Neutral NPCs offer quests across factions; side filter uses the NPC faction template.
- A grey prerequisite quest was recommended because of a flat unlock bonus → replaced by chain scoring and a visible `*` marker.
- The row text was cut off, hiding the zone → separate zone column, wider window, tooltip.

## Open items / ideas

- Verify in-game: arrow rotation direction, `GetCurrentMapAreaID` semantics, map pin icon, `QueryQuestsCompleted` on Warmane.
- Measure real completion times in-game (accept → turn-in) and calibrate estimates per player.
- Show quest-giver NPC names in rows and tooltips.
- Include kill-XP in the model for high XP rates.
- Draw route lines between map markers; minimap markers.
- Translate quest and zone names (needs localized data).

## Version history

| Version | Change |
| --- | --- |
| 0.1.0 | First release: per-level plan, arrow, TDB-like data from AzerothCore |
| 0.2.0 | Configurable XP rate (`/ql rate`, input box) |
| 0.3.0 | Completed quests via server query; Skip button; `/ql skipped`/`unskip` |
| 0.4.0 | Numbered quest markers on the world map |
| 0.4.1 | Fix `SetShown` error (empty list) |
| 0.5.0 | Interface translated to Spanish |
| 0.5.1 | Zone column and quest tooltip |
| 0.6.0 | Locked quests ("Primero"), Hecha button, turn-in detection |
| 0.6.1 | Chain scoring for gateway quests (`*`), drop chances |
| 0.7.0 | Multi-point objectives, spawn dots, more loot sources, unknown-location fallback, TrinityCore TDB data |
