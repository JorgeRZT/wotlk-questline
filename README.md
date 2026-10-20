# WotLK QuestLine

A World of Warcraft **3.3.5a (WotLK)** addon that tells you which quests to do next to level as fast as possible.

It reads your class, race/faction, level, XP, completed quests, quest log and **current position**, then simulates your leveling and shows a per-level list:

```
Level 12  (3400 XP to go)
  [Turn in] Quest A [12] +950   Turn in: Redridge (31, 62)
  Quest B [13] +1150            Pick up: Redridge (33, 60)
  Quest C [12] +880             Pick up: Redridge (30, 59)
Level 13  (3800 XP to go)
  ...
```

Quests are ranked by **XP per second**, taking into account travel time from where you are, the number of objectives, and a bonus for quests that unlock follow-ups in a chain. Nearby quests naturally cluster together.

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
| `/ql arrow` | Show / hide the direction arrow |
| `/ql rate <n>` | Set your server XP multiplier (e.g. `/ql rate 5`); `/ql rate` shows the current value |
| `/ql replan` | Recalculate the plan now |
| `/ql debug` | Print the detected position and loaded data |

Click a quest in the list to point the arrow at it (pick up, objectives or turn-in, depending on its state). The plan refreshes automatically on level-up, quest log changes and zone changes.

## XP rate

Set your realm's quest XP multiplier with `/ql rate <n>` or the **XP rate** box in the window (default `1`, range 0.1-1000; saved account-wide). Quest XP, the XP shown per quest and the number of quests per level all scale with it, so at higher rates you need fewer quests per level and the plan reaches higher levels sooner. Ranking within a single level is largely unchanged, because every quest scales equally; the rate mainly changes how the plan is split across levels and when quests turn grey.

## How the next quest is chosen

1. Quests are filtered by race, faction, class, minimum level, prerequisites and exclusive groups. Dailies, group/dungeon/raid, PvP, profession and event quests are ignored.
2. Starting from your position and level, the planner repeatedly picks the quest with the best `XP / time` score, where:
   - XP is multiplied by your configured XP rate, scaled by your level vs. the quest level (grey quests are worth less) and slightly penalised for quests above your level;
   - time = travel (pick-up → objectives → turn-in) + a per-objective estimate, with extra cost for long trips and continent changes.
3. XP is accumulated until the level is reached, then the next level list starts. Five levels are planned ahead.

## Known limitations

- Based on AzerothCore data, not Warmane's database.
- Quests started by items or using custom scripts may be missing.
- Zone names for some quests are approximate (world coordinates and the arrow are exact).
- The rotation direction of the arrow texture has not been verified in-game yet; please open an issue if it points the wrong way.

## Development

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
