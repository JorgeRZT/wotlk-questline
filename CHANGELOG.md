# Changelog

## 0.7.0
- Objectives keep up to 5 spawn clusters instead of one; the arrow picks the nearest and the world map shows red dots for the selected quest.
- More item sources: reference loot tables, skinning, pickpocketing; drop chances use the full tables.
- Quests whose objective locations are unknown are flagged, aimed at the quest giver and penalised in the plan.
- Data now generated from the TrinityCore TDB 3.3.5 database (`tools/split_tdb.py`).

## 0.6.1
- Gateway quests are now scored as a chain with their follow-up (XP and time of both), instead of a flat bonus, and are marked with a blue `*`; the tooltip shows which quest they open.
- Item objectives now account for drop chance when estimating time.

## 0.6.0
- Quests locked behind an uncompleted prerequisite are now marked *Primero: <quest>*; the arrow and map markers lead to the prerequisite instead of an empty quest giver.
- New **Hecha** button and `/ql done <id>` / `/ql undone <id>` to mark quests as completed; turn-ins are also detected from the quest log and saved.
- `/ql debug` shows how many completed quests are known.

## 0.5.1
- Quest rows now show the region name in its own column (the text was being cut off); the window is wider.
- Hovering a quest shows a tooltip with the pick-up, objectives and turn-in regions and coordinates.

## 0.5.0
- In-game interface translated to Spanish (window, buttons, tooltips, chat messages). Quest names remain in English.

## 0.4.1
- Fix: the quest list was empty because `Frame:SetShown` does not exist in the 3.3.5 client (UI.lua error).

## 0.4.0
- Numbered quest markers on the world map, in route order (`/ql map` to toggle).

## 0.3.0
- Completed quests are read from the server (`QueryQuestsCompleted` / `QUEST_QUERY_COMPLETE`) and excluded from the plan.
- Per-quest **Skip** button to replace a quest with the next best alternative; `/ql skipped` and `/ql unskip`.
- UI text is now fully in English.

## 0.2.0
- Configurable XP multiplier (`/ql rate <n>` or the box in the window), taken into account by the planner.

## 0.1.0
- Initial release: per-level quest plan ranked by XP per second, based on class, faction, level and position.
- Direction arrow towards the selected quest step.
- Generated data for 4552 quests from AzerothCore.
