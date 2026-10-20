-- Estado del jugador, posición y planificación asíncrona.
local _, QL = ...

local CLASS_INDEX = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}
local RACE_INDEX = {
    Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6,
    Gnome = 7, Troll = 8, BloodElf = 10, Draenei = 11,
}
local CONTINENT_MAP = { [1] = 1, [2] = 0, [3] = 530, [4] = 571 }

QL.plan = nil
QL.pos = nil

--- Posición del jugador en coordenadas de mundo {map, x, y}, o nil si no está disponible.
function QL.GetPlayerWorldPos()
    local mapFrameOpen = WorldMapFrame and WorldMapFrame:IsVisible()
    if mapFrameOpen then return QL.pos end
    SetMapToCurrentZone()
    local cont = GetCurrentMapContinent()
    local map = CONTINENT_MAP[cont]
    if not map then return QL.pos end
    SetMapZoom(cont)
    local px, py = GetPlayerMapPosition("player")
    SetMapToCurrentZone()
    if px == 0 and py == 0 then return QL.pos end
    local c = QL.Continents[map]
    QL.pos = { map, c.t - py * (c.t - c.b), c.l - px * (c.l - c.r) }
    return QL.pos
end

--- Zona y porcentaje de mapa de un punto {map, x, y, area}.
function QL.DescribePoint(pt)
    local z = pt and QL.Zones[pt[4]]
    if not z then return "?" end
    local px = (z.l - pt[3]) / (z.l - z.r) * 100
    local py = (z.t - pt[2]) / (z.t - z.b) * 100
    return string.format("%s (%.0f, %.0f)", z.name, px, py)
end

local function readLog()
    local active = {}
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if not isHeader and questID then active[questID] = (isComplete == 1) end
    end
    return active
end

local function readState()
    local _, classFile = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local pos = QL.GetPlayerWorldPos()
    if not pos then return nil end
    local completed = GetQuestsCompleted() or {}
    return {
        level = UnitLevel("player"), xp = UnitXP("player"), xpMax = UnitXPMax("player"),
        side = (UnitFactionGroup("player") == "Horde") and 2 or 1,
        classIndex = CLASS_INDEX[classFile] or 1, raceIndex = RACE_INDEX[raceFile] or 1,
        completed = completed, active = readLog(), pos = pos,
    }
end

local worker
local function runWorker(state)
    worker = coroutine.create(function()
        QL.plan = QL.Planner.Build(state, coroutine.yield)
        QL.planStamp = GetTime()
        if QL.OnPlanReady then QL.OnPlanReady() end
    end)
end

local pump = CreateFrame("Frame")
pump:SetScript("OnUpdate", function()
    if worker and coroutine.status(worker) == "suspended" then
        local ok, err = coroutine.resume(worker)
        if not ok then
            worker = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QuestLine:|r " .. tostring(err))
        end
    end
end)

local pendingAt
function QL.RequestReplan(delay)
    pendingAt = GetTime() + (delay or 1)
end

local timer = CreateFrame("Frame")
timer:SetScript("OnUpdate", function()
    if pendingAt and GetTime() >= pendingAt then
        pendingAt = nil
        local state = readState()
        if state then runWorker(state) end
    end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
    QL.RequestReplan(event == "PLAYER_ENTERING_WORLD" and 3 or 1.5)
end)

--- Paso actual de una misión del plan: punto objetivo y texto.
function QL.StepFor(entry)
    local q = entry.q
    if entry.status == "turnin" then
        return q.f[1], "Entregar"
    elseif entry.status == "doing" then
        return q.o[1] or q.f[1], q.o[1] and "Completar" or "Entregar"
    end
    return q.s[1] or q.f[1], "Coger"
end
