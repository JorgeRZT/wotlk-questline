# WotLK QuestLine

A World of Warcraft **3.3.5a (WotLK)** addon that tells you which quests to do next to level as fast as possible.

It reads your class, race/faction, level, XP, completed quests, quest log and **current position**, then simulates your leveling and shows a per-level list:

```
Nivel 12  (faltan 3400 XP)
  [entregar] Quest A [12] +950   Entregar: Redridge (31, 62)
  Quest B [13] +1150             Coger: Redridge (33, 60)
  Quest C [12] +880              Coger: Redridge (30, 59)
Nivel 13  (faltan 3800 XP)
  ...
```

Quests are ranked by **XP per second**, taking into account travel time from where you are, the number of objectives, drop chances, and quests that unlock better follow-ups in a chain. Nearby quests naturally cluster together.

## Features

- Per-level quest plan (5 levels ahead) from your class, race/faction, level, XP, quest log and position.
- Configurable server XP multiplier (`/ql rate`).
- Completed quests are excluded; locked quests show their prerequisite; manual **Hecha** (done) and **Saltar** (skip) buttons.
- Gateway quests (low value but unlock a great follow-up) are scored as a chain and marked with `*`.
- Direction arrow to the next step, aiming at the nearest known spawn of each objective.
- Numbered quest markers and spawn dots on the world map.
- 4,553 quests for levels 1-80 from the TrinityCore 3.3.5 database.

## Reading the list

Each row looks like `[entregar] * Quest name [12] +950   Coger: Redridge (31, 62)`:

| Part | Meaning |
| --- | --- |
| `[entregar]` / `[en curso]` | Quest already in your log: ready to turn in / still has objectives. No tag = not picked up yet |
| `*` (blue) | Gateway quest: it mainly unlocks a better follow-up (see the tooltip) |
| `Quest name` | English name from the data |
| `[12]` | Quest level (not the minimum level) |
| `+950` | XP you will get, including your XP rate and the grey-quest reduction |
| `Coger` / `Completar` / `Entregar` + zone | Next step: pick up, do the objectives, or turn in, with the zone and 0-100 map coordinates of that zone |
| `Primero: <quest>` | Locked: complete that quest first (clicking points you to it) |
| **Hecha** / **Saltar** | Mark as already completed / hide it and find an alternative |

Hover a row for pick-up, objective and turn-in zones. Rows are in route order, not sorted by XP.

> The in-game interface is in **Spanish**; quest names come from the TrinityCore data and are in English. The documentation is in English.

> Built for private servers such as Warmane. Quest data comes from the TrinityCore TDB, so a few quests may differ from your realm.

## Installation

### Addon manager (recommended)
Add this repository URL in your GitHub-capable addon manager (WowUp, Ajour, GitHub-Addon-Manager, ...):

```
https://github.com/JorgeRZT/wotlk-questline
```

The manager should install the zip attached to the latest [release](https://github.com/JorgeRZT/wotlk-questline/releases), which already contains the correct `QuestLine/` folder.

### Manual
1. Download `QuestLine-<version>.zip` from the [latest release](https://github.com/JorgeRZT/wotlk-questline/releases/latest).
2. Extract it so you end up with `World of Warcraft/Interface/AddOns/QuestLine/QuestLine.toc`.
3. Restart the game and enable **QuestLine** on the character select screen.

### Updating
Replace the `QuestLine` folder with the one from the new release. `/reload` is enough when a release only changes existing files; **restart the game** when the `.toc` changes (new files, new version number) or when in doubt.

> Do **not** use "Download ZIP" on the repository page: the folder would be named `wotlk-questline-main` and WoW would not load it. Rename it to `QuestLine` if you do.

## Usage

| Command | Action |
| --- | --- |
| `/ql` | Open / close the quest list |
| `/ql map` | Show / hide the numbered quest markers on the world map |
| `/ql arrow` | Show / hide the direction arrow |
| `/ql rate <n>` | Set your server XP multiplier (e.g. `/ql rate 5`); `/ql rate` shows the current value |
| `/ql done <id>` / `/ql undone <id>` | Mark a quest as already completed (unlocks its follow-ups) or undo it |
| `/ql skipped` | List the quests you skipped |
| `/ql unskip <questID\|all>` | Bring a skipped quest (or all of them) back |
| `/ql replan` | Recalculate the plan now |
| `/ql debug` | Print the detected position and loaded data |

Click a quest in the list to point the arrow at it (pick up, objectives or turn-in, depending on its state). The plan refreshes automatically on level-up, quest log changes and zone changes.

## World map markers

Open the world map (`M`) and the quests of your current level appear as numbered markers in route order (white = pick up, yellow = in progress, green = turn in). The marker shows the next step of each quest: where to pick it up, its objectives, or where to turn it in. Hover for details and click to aim the arrow at it. Markers work on both zone and continent maps; use `/ql map` to toggle them.

## Objective locations

Kill and collect objectives keep up to **5 spawn clusters** each. The arrow aims at the nearest one (re-evaluated every second) and, when a quest is selected, the world map shows a red dot for every known spawn area. Item sources include creature drops, reference loot tables, skinning, pickpocketing and world objects, using drop chances to estimate the time needed. Objectives whose items are crafted, handed out or come from vendors have no known location: the arrow then points to the quest giver, the row says *ubicación aproximada*, and the planner adds a time penalty.

## Completed and skipped quests

- **Completed quests** are fetched from the server (`QueryQuestsCompleted`) on every replan and never shown again. Quests already in your log are shown as *en curso* / *entregar* instead of new.
- **Locked quests**: if a quest needs a previous quest that you have not completed yet, its row shows *Primero: <quest>* instead of a location, and clicking it (or the map/arrow) points you to the prerequisite first. Quests with reputation or skill requirements, and quests started from items, are not planned at all.
- **Gateway quests (`*`)**: a quest marked with a blue `*` is worth doing mainly because it unlocks a better one (for example a low-level quest that opens a high-XP follow-up). The planner scores the whole chain (quest plus follow-up) by XP over time, and the tooltip shows what it opens.
- **Done button**: **Hecha** marks a quest as already completed, which unlocks its follow-ups. Quests that disappear from your log while complete are recorded automatically as turned in. Use this if the server's completed-quest list does not load on your realm (`/ql debug` shows how many completed quests are known).
- **Skip button**: every quest still to be picked up has a **Saltar** (Skip) button. It hides that quest and the planner immediately finds the next best alternative (its chain follow-ups are hidden too, since they need it). Skips are saved across sessions; use `/ql skipped` and `/ql unskip` to review or undo them.

## XP rate

Set your realm's quest XP multiplier with `/ql rate <n>` or the **XP rate** box in the window (default `1`, range 0.1-1000; saved account-wide). Quest XP, the XP shown per quest and the number of quests per level all scale with it, so at higher rates you need fewer quests per level and the plan reaches higher levels sooner. Ranking within a single level is largely unchanged, because every quest scales equally; the rate mainly changes how the plan is split across levels and when quests turn grey.

## How the next quest is chosen

1. Quests are filtered by race, faction, class, minimum level, prerequisites and exclusive groups. Dailies, group/dungeon/raid, PvP, profession and event quests are ignored.
2. Starting from your position and level, the planner repeatedly picks the quest with the best `XP / time` score, where:
   - XP is multiplied by your configured XP rate, scaled by your level vs. the quest level (grey quests are worth less) and slightly penalised for quests above your level;
   - time = travel (pick-up → nearest objective spawns → turn-in) + a per-objective estimate based on drop chances, with extra cost for long trips, continent changes and objectives with unknown location;
   - quests that unlock a follow-up are scored as a chain: (XP of both) / (time of both).
3. XP is accumulated until the level is reached, then the next level list starts. Five levels are planned ahead. Everything is recalculated on level-up, quest log changes and zone changes.

## Troubleshooting

- **Empty quest list, only the "Level N" header and a stray *Skip* button** (v0.4.0): caused by `Frame:SetShown`, which does not exist in the 3.3.5 client. Fixed in v0.4.1; update the addon and `/reload`.
- **Red Lua errors**: enable them with `/console scriptErrors 1` and open an issue with a screenshot of the message.
- **Map markers missing or misplaced**: open the world map and run `/ql debug`, then include the printed map area ID in your issue.

## Known limitations

- Based on TrinityCore TDB data, not Warmane's own database.
- Quests started by items or using custom scripts may be missing.
- About 27% of the quests have at least one objective with no known location (crafted or handed-out items, vendor items, script-driven credits); they are aimed at the quest giver and penalised.
- Time estimates are heuristics (straight-line distance, flat per-objective cost); real completion times are not measured yet.
- Zone names for some quests are approximate (world coordinates and the arrow are exact).
- The rotation direction of the arrow texture has not been verified in-game yet; please open an issue if it points the wrong way.

## Development

The client is 3.3.5a, so retail-era APIs are not available (for example `Frame:SetShown`, `C_*` namespaces or `SetColorTexture`). Test any new UI code against the 3.3.5 API.

Data files in `Data/` are generated from the [TrinityCore TDB 3.3.5](https://github.com/TrinityCore/TrinityCore/releases) world database (the core family Warmane is based on):

```bash
# 1. download TDB_full_world_335.<build>.7z from the TrinityCore releases and extract the .sql
# 2. split the tables we need
python3 tools/split_tdb.py TDB_full_world_335.<build>.sql /tmp/tdb
# 3. generate the Lua data
python3 tools/build_data.py /tmp/tdb Data
```

`tools/build_data.py` also accepts AzerothCore `db_world` per-table dumps. Extra DBC tables live in `tools/dbc/`.

See [MEMORY.md](MEMORY.md) for the project history, design decisions and 3.3.5 API notes.

Releases are built automatically: pushing a tag like `v0.1.1` runs `.github/workflows/release.yml` and attaches `QuestLine-<version>.zip`.

## Credits and licenses

- Addon code: [MIT](LICENSE).
- Generated quest data is derived from the [TrinityCore](https://github.com/TrinityCore/TrinityCore) TDB world database (GPL-2.0) and, in earlier versions, [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (AGPL-3.0).
- DBC CSV extracts in `tools/dbc/` come from the [Questie](https://github.com/Questie/Questie) repository (GPL-3.0).
- World of Warcraft is a trademark of Blizzard Entertainment. This project is not affiliated with Blizzard.
