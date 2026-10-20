#!/usr/bin/env python3
"""Genera Data/*.lua a partir de volcados SQL de AzerothCore (3.3.5a).

Uso (desde la raiz del proyecto): python3 tools/build_data.py <dir_con_sql_acore> Data
"""
import csv
import math
import re
import sys
from collections import defaultdict

SQL_DIR, OUT_DIR = sys.argv[1], sys.argv[2]
WMA_CSV = "tools/dbc/worldmaparea_wotlk.csv"
QUESTXP_CSV = "tools/dbc/questxp_wotlk.csv"
FACTION_CSV = "tools/dbc/factiontemplate_wotlk.csv"

CONTINENTS = {0, 1, 530, 571}
EXCLUDED_INFO = {1, 21, 41, 62, 81, 82, 83, 84, 85, 88, 89}  # grupo, pvp, mazmorra, raid, evento...
FLAG_DAILY, FLAG_WEEKLY = 0x1000, 0x8000
SPECIAL_REPEATABLE = 0x1
CLASS_SORTS = {61, 81, 82, 141, 161, 162, 261, 262, 263, 372}
MAX_SPAWN_POINTS = 3


def parse_table(name):
    """Devuelve (columnas, filas) de un volcado mysqldump con INSERT multi-fila."""
    text = open(f"{SQL_DIR}/{name}.sql", encoding="utf8").read()
    block = re.search(r"CREATE TABLE.*?\n\)", text, re.S).group(0)
    cols = [m.group(1) for m in re.finditer(r"^\s+`(\w+)`", block, re.M)]
    rows = []
    for m in re.finditer(r"^INSERT INTO `\w+` VALUES\n?(.*?);\n", text, re.S | re.M):
        rows.extend(parse_values(m.group(1)))
    return cols, rows


def parse_values(s):
    rows, row, i, n = [], None, 0, len(s)
    while i < n:
        c = s[i]
        if c == "(":
            row, i = [], i + 1
            continue
        if c == ")":
            rows.append(row)
            row, i = None, i + 1
            continue
        if row is None or c in ", \n":
            i += 1
            continue
        if c == "'":
            j, buf = i + 1, []
            while True:
                if s[j] == "\\":
                    buf.append(s[j + 1])
                    j += 2
                elif s[j] == "'":
                    if j + 1 < n and s[j + 1] == "'":
                        buf.append("'")
                        j += 2
                    else:
                        break
                else:
                    buf.append(s[j])
                    j += 1
            row.append("".join(buf))
            i = j + 1
        else:
            j = i
            while s[j] not in ",)":
                j += 1
            tok = s[i:j]
            if tok == "NULL":
                row.append(None)
            else:
                try:
                    row.append(int(tok))
                except ValueError:
                    row.append(float(tok))
            i = j
    return rows


def table_dicts(name):
    cols, rows = parse_table(name)
    return [dict(zip(cols, r)) for r in rows]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    # --- zonas ---
    zones, continents = {}, {}
    with open(WMA_CSV, encoding="utf8") as f:
        for r in csv.DictReader(f):
            if int(r["MapID"]) not in CONTINENTS:
                continue
            z = dict(id=int(r["ID"]), map=int(r["MapID"]), area=int(r["AreaID"]), name=r["AreaName"],
                     l=float(r["LocLeft"]), r=float(r["LocRight"]), t=float(r["LocTop"]), b=float(r["LocBottom"]))
            if z["area"] == 0:
                continents[z["map"]] = z
            else:
                z["size"] = abs(z["l"] - z["r"]) * abs(z["t"] - z["b"])
                zones[z["area"]] = z
    print("zonas:", len(zones))

    def inside(z, map_id, x, y):
        return z["map"] == map_id and z["r"] <= y <= z["l"] and z["b"] <= x <= z["t"]

    def area_of(map_id, x, y, prefer=0):
        """Zona del punto: la de la propia misión si lo contiene; si no, la de centro más cercano (los rectángulos se solapan)."""
        if prefer in zones and inside(zones[prefer], map_id, x, y):
            return prefer
        best, best_d = 0, 9.0
        for z in zones.values():
            if not inside(z, map_id, x, y):
                continue
            u = abs((z["l"] - y) / (z["l"] - z["r"]) - 0.5)
            v = abs((z["t"] - x) / (z["t"] - z["b"]) - 0.5)
            if max(u, v) < best_d:
                best, best_d = z["area"], max(u, v)
        return best

    # --- XP ---
    with open(QUESTXP_CSV, encoding="utf8") as f:
        rd = csv.reader(f)
        next(rd)
        questxp = {int(r[0]): [int(v) for v in r[1:11]] for r in rd}
    xp_level = {r["Level"]: r["Experience"] for r in table_dicts("player_xp_for_level")}

    # --- bando de las facciones: 1 = Alianza, 2 = Horda, 0 = neutral ---
    side_of_template = {}
    with open(FACTION_CSV, encoding="utf8") as f:
        for r in csv.DictReader(f):
            enemy = int(r["EnemyGroup"])
            if enemy & 4 and not enemy & 2:
                side_of_template[int(r["ID"])] = 1
            elif enemy & 2 and not enemy & 4:
                side_of_template[int(r["ID"])] = 2
    creature_side = {c["entry"]: side_of_template.get(c["faction"], 0) for c in table_dicts("creature_template")}

    def side_of(refs):
        sides = {creature_side.get(i, 0) if k == "c" else 0 for k, i in refs}
        sides.discard(0)
        return sides.pop() if len(sides) == 1 else 0

    # --- spawns ---
    spawns = defaultdict(list)  # creature entry -> [(area, x, y)]
    for c in table_dicts("creature"):
        if c["map"] in CONTINENTS:
            spawns[c["id1"]].append((c["map"], c["position_x"], c["position_y"]))
    go_spawns = defaultdict(list)
    for g in table_dicts("gameobject"):
        if g["map"] in CONTINENTS:
            go_spawns[g["id"]].append((g["map"], g["position_x"], g["position_y"]))

    def cluster(points, k=MAX_SPAWN_POINTS, prefer=0):
        """Reduce spawns a <=k puntos: zona mayoritaria y centroides por rejilla de 300 yardas."""
        if not points:
            return []
        zcount = defaultdict(int)
        for p in points:
            zcount[p[0]] += 1
        out = []
        for area in sorted(zcount, key=lambda a: -zcount[a]):
            cells = defaultdict(list)
            for p in points:
                if p[0] == area:
                    cells[(int(p[1] // 300), int(p[2] // 300))].append(p)
            for cell in sorted(cells.values(), key=len, reverse=True):
                out.append((area, sum(p[1] for p in cell) / len(cell), sum(p[2] for p in cell) / len(cell), len(cell)))
        out.sort(key=lambda p: -p[3])
        return [(a, round(x), round(y), area_of(a, x, y, prefer)) for a, x, y, _ in out[:k]]

    # --- quest givers / enders ---
    starters, enders = defaultdict(list), defaultdict(list)
    for r in table_dicts("creature_queststarter"):
        starters[r["quest"]].append(("c", r["id"]))
    for r in table_dicts("gameobject_queststarter"):
        starters[r["quest"]].append(("g", r["id"]))
    for r in table_dicts("creature_questender"):
        enders[r["quest"]].append(("c", r["id"]))
    for r in table_dicts("gameobject_questender"):
        enders[r["quest"]].append(("g", r["id"]))

    def giver_points(refs, prefer=0):
        pts = []
        for kind, ident in refs:
            pts += (spawns if kind == "c" else go_spawns).get(ident, [])
        return cluster(pts, MAX_SPAWN_POINTS, prefer)

    # --- loot: item -> criaturas / objetos ---
    ct_loot = {c["entry"]: c["lootid"] for c in table_dicts("creature_template") if c["lootid"]}
    loot_to_creatures = defaultdict(list)
    for entry, lootid in ct_loot.items():
        loot_to_creatures[lootid].append(entry)
    item_sources = defaultdict(set)  # item -> {(kind, id)}
    for r in table_dicts("creature_loot_template"):
        if r["Reference"] == 0 and r["Item"] > 0:
            for ce in loot_to_creatures.get(r["Entry"], []):
                item_sources[r["Item"]].add(("c", ce))
    go_loot = defaultdict(list)
    for g in table_dicts("gameobject_template"):
        if g["type"] == 3 and g["Data1"]:
            go_loot[g["Data1"]].append(g["entry"])
    for r in table_dicts("gameobject_loot_template"):
        if r["Reference"] == 0 and r["Item"] > 0:
            for ge in go_loot.get(r["Entry"], []):
                item_sources[r["Item"]].add(("g", ge))

    # --- quests ---
    addon = {r["ID"]: r for r in table_dicts("quest_template_addon")}
    quests = {}
    for q in table_dicts("quest_template"):
        qid = q["ID"]
        a = addon.get(qid, {})
        sort = q["QuestSortID"]
        if sort < 0 and -sort not in CLASS_SORTS:
            continue
        if q["QuestInfoID"] in EXCLUDED_INFO or q["SuggestedGroupNum"] > 1:
            continue
        if q["Flags"] & (FLAG_DAILY | FLAG_WEEKLY) or a.get("SpecialFlags", 0) & SPECIAL_REPEATABLE or q["TimeAllowed"]:
            continue
        if a.get("RequiredSkillID") or a.get("RequiredMinRepFaction") or q["RequiredFactionId1"]:
            continue
        if not q["LogTitle"] or q["LogTitle"].startswith("[") or "DEPRECATED" in q["LogTitle"].upper():
            continue
        side = side_of(starters.get(qid, [])) or side_of(enders.get(qid, []))
        end_pts = giver_points(enders.get(qid, []), sort)
        start_pts = giver_points(starters.get(qid, []), sort)
        if not end_pts:
            continue
        xp = 0
        row = questxp.get(q["QuestLevel"] if q["QuestLevel"] > 0 else 1)
        if row and 0 <= q["RewardXPDifficulty"] <= 9:
            xp = row[q["RewardXPDifficulty"]]
        # objetivos
        objs, work = [], 0
        for i in range(1, 5):
            t, cnt = q[f"RequiredNpcOrGo{i}"], q[f"RequiredNpcOrGoCount{i}"]
            if t and cnt:
                pts = cluster((spawns if t > 0 else go_spawns).get(abs(t), []), 1, sort)
                if pts:
                    objs.append(pts[0])
                work += cnt
        for i in range(1, 7):
            it, cnt = q[f"RequiredItemId{i}"], q[f"RequiredItemCount{i}"]
            if it and cnt:
                pts = []
                for kind, ident in item_sources.get(it, ()):
                    pts += (spawns if kind == "c" else go_spawns).get(ident, [])
                pts = cluster(pts, 1, sort)
                if pts:
                    objs.append(pts[0])
                work += cnt * 2
        quests[qid] = dict(
            title=q["LogTitle"], lvl=q["QuestLevel"], min=q["MinLevel"], xp=xp, races=q["AllowableRaces"],
            classes=a.get("AllowableClasses", 0), prev=a.get("PrevQuestID", 0), nxt=q["RewardNextQuest"],
            excl=a.get("ExclusiveGroup", 0), maxlvl=a.get("MaxLevel", 0), start=start_pts, end=end_pts,
            objs=objs, work=work, sort=sort, side=side, chain=a.get("NextQuestID", 0), flags=q["Flags"],
        )
    # una misión sin punto de inicio solo es válida si es continuación de cadena
    followers = {q["nxt"] for q in quests.values() if q["nxt"]} | {q["chain"] for q in quests.values() if q["chain"]}
    followers |= {q["prev"] for q in quests.values() if q["prev"] < 0}
    quests = {i: q for i, q in quests.items() if q["start"] or i in followers}
    print("misiones:", len(quests))

    # --- salida ---
    with open(f"{OUT_DIR}/Zones.lua", "w", encoding="utf8") as f:
        f.write("-- Generado por tools/build_data.py\nlocal _, QL = ...\nQL.Zones = {\n")
        for z in sorted(zones.values(), key=lambda z: z["id"]):
            f.write(f'  [{z["area"]}] = {{id={z["id"]},map={z["map"]},name={lua_str(z["name"])},'
                    f'l={z["l"]:.2f},r={z["r"]:.2f},t={z["t"]:.2f},b={z["b"]:.2f}}},\n')
        f.write("}\nQL.Continents = {\n")
        for z in continents.values():
            f.write(f'  [{z["map"]}] = {{l={z["l"]:.2f},r={z["r"]:.2f},t={z["t"]:.2f},b={z["b"]:.2f}}},\n')
        f.write("}\nQL.XPToLevel = {")
        f.write(",".join(f"[{l}]={x}" for l, x in sorted(xp_level.items())))
        f.write("}\n")

    def pts(ps):
        return "{" + ",".join(f"{{{m},{x},{y},{a}}}" for m, x, y, a in ps) + "}"

    with open(f"{OUT_DIR}/Quests.lua", "w", encoding="utf8") as f:
        f.write("-- Generado por tools/build_data.py\nlocal _, QL = ...\nQL.Quests = {\n")
        for qid in sorted(quests):
            q = quests[qid]
            f.write(f'[{qid}]={{t={lua_str(q["title"])},l={q["lvl"]},m={q["min"]},x={q["xp"]},r={q["races"]},c={q["classes"]},'
                    f'd={q["side"]},p={q["prev"]},n={q["nxt"]},e={q["excl"]},w={q["work"]},s={pts(q["start"])},f={pts(q["end"])},o={pts(q["objs"])}')
            if q["maxlvl"]:
                f.write(f',M={q["maxlvl"]}')
            f.write("},\n")
        f.write("}\n")


main()
