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

Quests are ranked by **XP per second**, taking into account travel time from where you are, the number of objectives, and a bonus for quests that unlock follow-ups in a chain. Nearby quests naturally cluster together.

> The in-game interface is in **Spanish**; quest names come from the AzerothCore data and are in English. The documentation is in English.

> Built for private servers such as Warmane. Quest data comes from AzerothCore, so a few quests may differ from your realm.

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
3. Restart the game (or reload the UI) and enable **QuestLine** on the character select screen.

> Do **not** use "Download ZIP" on the repository page: the folder would be named `wotlk-questline-main` and WoW would not load it. Rename it to `QuestLine` if you do.

## Usage

| Command | Action |
| --- | --- |
| `/ql` | Open / close the quest list |
| `/ql map` | Show / hide the numbered quest markers on the world map |
| `/ql arrow` | Show / hide the direction arrow |
| `/ql rate <n>` | Set your server XP multiplier (e.g. `/ql rate 5`); `/ql rate` shows the current value |
| `/ql skipped` | List the quests you skipped |
| `/ql unskip <questID\|all>` | Bring a skipped quest (or all of them) back |
| `/ql replan` | Recalculate the plan now |
| `/ql debug` | Print the detected position and loaded data |

Click a quest in the list to point the arrow at it (pick up, objectives or turn-in, depending on its state). The plan refreshes automatically on level-up, quest log changes and zone changes.

## World map markers

Open the world map (`M`) and the quests of your current level appear as numbered markers in route order (white = pick up, yellow = in progress, green = turn in). The marker shows the next step of each quest: where to pick it up, its objectives, or where to turn it in. Hover for details and click to aim the arrow at it. Markers work on both zone and continent maps; use `/ql map` to toggle them.

## Completed and skipped quests

- **Completed quests** are fetched from the server (`QueryQuestsCompleted`) on every replan and never shown again. Quests already in your log are shown as *en curso* / *entregar* instead of new.
- **Skip button**: every quest still to be picked up has a **Saltar** (Skip) button. It hides that quest and the planner immediately finds the next best alternative (its chain follow-ups are hidden too, since they need it). Skips are saved across sessions; use `/ql skipped` and `/ql unskip` to review or undo them.

## XP rate

Set your realm's quest XP multiplier with `/ql rate <n>` or the **XP rate** box in the window (default `1`, range 0.1-1000; saved account-wide). Quest XP, the XP shown per quest and the number of quests per level all scale with it, so at higher rates you need fewer quests per level and the plan reaches higher levels sooner. Ranking within a single level is largely unchanged, because every quest scales equally; the rate mainly changes how the plan is split across levels and when quests turn grey.

## How the next quest is chosen

1. Quests are filtered by race, faction, class, minimum level, prerequisites and exclusive groups. Dailies, group/dungeon/raid, PvP, profession and event quests are ignored.
2. Starting from your position and level, the planner repeatedly picks the quest with the best `XP / time` score, where:
   - XP is multiplied by your configured XP rate, scaled by your level vs. the quest level (grey quests are worth less) and slightly penalised for quests above your level;
   - time = travel (pick-up → objectives → turn-in) + a per-objective estimate, with extra cost for long trips and continent changes.
3. XP is accumulated until the level is reached, then the next level list starts. Five levels are planned ahead.

## Troubleshooting

- **Empty quest list, only the "Level N" header and a stray *Skip* button** (v0.4.0): caused by `Frame:SetShown`, which does not exist in the 3.3.5 client. Fixed in v0.4.1; update the addon and `/reload`.
- **Red Lua errors**: enable them with `/console scriptErrors 1` and open an issue with a screenshot of the message.
- **Map markers missing or misplaced**: open the world map and run `/ql debug`, then include the printed map area ID in your issue.

## Known limitations

- Based on AzerothCore data, not Warmane's database.
- Quests started by items or using custom scripts may be missing.
- Zone names for some quests are approximate (world coordinates and the arrow are exact).
- The rotation direction of the arrow texture has not been verified in-game yet; please open an issue if it points the wrong way.

## Development

The client is 3.3.5a, so retail-era APIs are not available (for example `Frame:SetShown`, `C_*` namespaces or `SetColorTexture`). Test any new UI code against the 3.3.5 API.

Data files in `Data/` are generated:

```bash
# download db_world SQL dumps from AzerothCore, then:
python3 tools/build_data.py <dir_with_acore_sql> Data
```

Required dumps: `quest_template`, `quest_template_addon`, `creature_queststarter`, `creature_questender`, `gameobject_queststarter`, `gameobject_questender`, `creature`, `gameobject`, `creature_template`, `gameobject_template`, `creature_loot_template`, `gameobject_loot_template`, `player_xp_for_level`.

Extra DBC tables used live in `tools/dbc/`.

Releases are built automatically: pushing a tag like `v0.1.1` runs `.github/workflows/release.yml` and attaches `QuestLine-<version>.zip`.

## Credits and licenses

- Addon code: [MIT](LICENSE).
- Generated quest data is derived from the [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) world database (AGPL-3.0).
- DBC CSV extracts in `tools/dbc/` come from the [Questie](https://github.com/Questie/Questie) repository (GPL-3.0).
- World of Warcraft is a trademark of Blizzard Entertainment. This project is not affiliated with Blizzard.
