# Changelog

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
