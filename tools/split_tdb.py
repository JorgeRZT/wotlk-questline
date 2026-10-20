#!/usr/bin/env python3
"""Separa el volcado TDB_full_world_335.*.sql de TrinityCore en un .sql por tabla (solo las necesarias).

Uso: python3 tools/split_tdb.py <TDB_full_world.sql> <directorio_salida>
"""
import os
import re
import sys

WANTED = {
    "quest_template", "quest_template_addon", "creature_queststarter", "creature_questender",
    "gameobject_queststarter", "gameobject_questender", "creature", "gameobject", "creature_template",
    "gameobject_template", "creature_loot_template", "gameobject_loot_template", "reference_loot_template",
    "skinning_loot_template", "pickpocketing_loot_template", "player_xp_for_level",
}

src, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)
out = None
with open(src, encoding="utf8", errors="replace") as f:
    for line in f:
        m = re.match(r"-- Table structure for table `(\w+)`", line)
        if m:
            if out:
                out.close()
                out = None
            if m.group(1) in WANTED:
                out = open(os.path.join(out_dir, m.group(1) + ".sql"), "w", encoding="utf8")
        if out:
            out.write(line)
if out:
    out.close()
