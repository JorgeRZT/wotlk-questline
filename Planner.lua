-- Planificador: simula el leveo y devuelve las misiones agrupadas por nivel.
-- No usa la API del juego; recibe todo el estado en una tabla para poder probarlo fuera del cliente.
local _, QL = ...

local sqrt, floor, max = math.sqrt, math.floor, math.max

local PLAN_LEVELS = 5
local MAX_LEVEL = 80
local CONTINENT_SWAP_COST = 3000    -- segundos (barco/zepelin) al cambiar de continente
local LONG_LEG, LONG_LEG_FACTOR = 1500, 1.6   -- trayectos largos: rodeos, tranvias, cambio de zona
local QUEST_OVERHEAD = 25           -- segundos por misión (hablar, entregar)
local SECONDS_PER_OBJECTIVE = 9

local function speedFor(level)
    if level >= 40 then return 14 end
    if level >= 20 then return 10 end
    return 7
end

local function xpMultiplier(level, questLevel)
    local d = level - questLevel
    if d <= 5 then return 1 end
    if d == 6 then return 0.8 end
    if d == 7 then return 0.6 end
    if d == 8 then return 0.4 end
    if d == 9 then return 0.2 end
    return 0.1
end

local function hasBit(mask, index)
    return mask == 0 or floor(mask / 2 ^ (index - 1)) % 2 == 1
end

local function dist(a, b)
    if a[1] ~= b[1] then return nil end
    local dx, dy = a[2] - b[2], a[3] - b[3]
    return sqrt(dx * dx + dy * dy)
end

local function nearest(points, from)
    local best, bestD
    for i = 1, #points do
        local d = dist(points[i], from) or 1e9
        if not bestD or d < bestD then best, bestD = points[i], d end
    end
    return best, bestD
end

QL.Planner = {}

--- Coste en segundos de hacer la misión q desde pos. Devuelve segundos y el punto final.
function QL.Planner.Cost(q, pos, speed)
    local s = q.s[1] and nearest(q.s, pos) or pos
    local meters, cur = 0, pos
    local crossing = 0
    local function leg(to)
        local d = dist(cur, to)
        if not d then crossing = crossing + CONTINENT_SWAP_COST; d = 0
        elseif d > LONG_LEG then d = d * LONG_LEG_FACTOR end
        meters = meters + d
        cur = to
    end
    leg(s)
    for i = 1, #q.o do leg(q.o[i]) end
    local f = nearest(q.f, cur)
    leg(f)
    return meters / speed + crossing + QUEST_OVERHEAD + q.w * SECONDS_PER_OBJECTIVE, f
end

--- state: level, xp, xpMax, classIndex, raceIndex, xpRate (multiplicador del servidor, 1 = normal), side (1 Alianza, 2 Horda), completed{id=true}, active{id=complete?true/false}, pos{map,x,y}
--- Devuelve una lista de niveles { {level=, xpNeeded=, quests={...}}, ... }
function QL.Planner.Build(state, yield)
    local Q, XPL = QL.Quests, QL.XPToLevel
    local completed, active = state.completed, state.active
    local done = setmetatable({}, { __index = completed })
    local followers, groups = {}, {}
    for id, q in pairs(Q) do
        local p = q.p ~= 0 and math.abs(q.p) or nil
        if p then followers[p] = followers[p] or {}; followers[p][#followers[p] + 1] = id end
        if q.n ~= 0 and Q[q.n] then followers[id] = followers[id] or {}; followers[id][#followers[id] + 1] = q.n end
        if q.e > 0 then groups[q.e] = groups[q.e] or {}; groups[q.e][#groups[q.e] + 1] = id end
    end

    -- candidatas estáticas: raza, clase, no hechas, no en curso
    local pending = {}
    for id, q in pairs(Q) do
        if not done[id] and active[id] == nil and not (state.skipped and state.skipped[id]) and hasBit(q.r, state.raceIndex) and hasBit(q.c, state.classIndex)
            and (q.d == 0 or q.d == state.side)
            and (q.x > 0 or followers[id]) then
            pending[#pending + 1] = id
        end
    end

    local function available(id, q, level)
        if q.m > level or (q.M and level > q.M) then return false end
        if q.p > 0 then
            if not done[q.p] then return false end
        elseif q.p < 0 then
            if not (done[-q.p] or active[-q.p] ~= nil) then return false end
        end
        if q.e > 0 then
            for _, other in ipairs(groups[q.e]) do
                if other ~= id and (done[other] or active[other] ~= nil) then return false end
            end
        end
        if #q.s == 0 and q.p == 0 then return false end   -- sin origen conocido
        return true
    end

    local rate = state.xpRate or 1
    local level, xp, xpMax = state.level, state.xp, state.xpMax
    local pos = state.pos
    local result = {}
    local current = { level = level, xpNeeded = xpMax - xp, quests = {} }
    result[1] = current

    local function award(gain)
        xp = xp + gain
        while xp >= xpMax and level < MAX_LEVEL do
            xp = xp - xpMax
            level = level + 1
            xpMax = XPL[level] or xpMax
            if #result >= PLAN_LEVELS then return true end
            current = { level = level, xpNeeded = xpMax - xp, quests = {} }
            result[#result + 1] = current
        end
        return false
    end

    -- misiones ya aceptadas: van primero
    for id, isComplete in pairs(active) do
        local q = Q[id]
        if q then
            local ql = q.l > 0 and q.l or level
            local gain = q.x * xpMultiplier(level, ql) * rate
            current.quests[#current.quests + 1] = { id = id, q = q, xp = gain, status = isComplete and "turnin" or "doing" }
            award(gain)
            done[id] = true
        end
    end

    local picks = 0
    while #result <= PLAN_LEVELS do
        local speed = speedFor(level)
        local bestId, bestScore, bestEnd, bestGain
        local keep = {}
        for i = 1, #pending do
            local id = pending[i]
            local q = Q[id]
            if not done[id] then
                keep[#keep + 1] = id
                local ql = q.l > 0 and q.l or level
                if ql <= level + 2 and available(id, q, level) then
                    local gain = q.x * xpMultiplier(level, ql) * rate
                    local bonus = 0
                    local fl = followers[id]
                    if fl then
                        for j = 1, #fl do
                            local fq = Q[fl[j]]
                            if fq and fq.x * rate * 0.6 > bonus then bonus = fq.x * rate * 0.6 end
                        end
                    end
                    if ql > level then gain = gain * 0.92 end
                    local value = gain + (q.x == 0 and bonus or bonus * 0.3)
                    if value > 0 then
                        local t, fin = QL.Planner.Cost(q, pos, speed)
                        local score = value / t
                        if not bestScore or score > bestScore then
                            bestId, bestScore, bestEnd, bestGain = id, score, fin, gain
                        end
                    end
                end
            end
        end
        pending = keep
        if not bestId then break end
        local q = Q[bestId]
        done[bestId] = true
        pos = bestEnd
        current.quests[#current.quests + 1] = { id = bestId, q = q, xp = bestGain, status = "new" }
        if award(bestGain) then break end
        picks = picks + 1
        if yield and picks % 4 == 0 then yield() end
    end
    return result
end
