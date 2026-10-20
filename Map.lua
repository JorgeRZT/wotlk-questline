-- Marcadores numerados en el mapa del mundo con las misiones del nivel actual, en orden de ruta.
local _, QL = ...

local MAX_PINS = 25
local CONTINENT_MAP = { [1] = 1, [2] = 0, [3] = 530, [4] = 571 }
local COLORS = {
    new = { 1, 1, 1 },
    doing = { 1, 0.9, 0.2 },
    turnin = { 0.2, 1, 0.2 },
}

local zoneByWMA = {}
for _, z in pairs(QL.Zones) do zoneByWMA[z.id] = z end

local pins = {}
local dots = {}
local MAX_DOTS = 12

local function getDot(i)
    local d = dots[i]
    if not d then
        d = WorldMapButton:CreateTexture(nil, "OVERLAY")
        d:SetSize(10, 10)
        d:SetTexture("Interface\\COMMON\\Indicator-Gray")
        d:SetVertexColor(1, 0.3, 0.3)
        dots[i] = d
    end
    return d
end

--- Límites (map, l, r, t, b) del mapa que muestra ahora el mapa del mundo, o nil.
local function currentBounds()
    local cont, zone = GetCurrentMapContinent(), GetCurrentMapZone()
    if zone == 0 then
        local map = CONTINENT_MAP[cont]
        local c = map and QL.Continents[map]
        if c then return map, c end
    elseif GetCurrentMapAreaID then
        local z = zoneByWMA[GetCurrentMapAreaID()]
        if z then return z.map, z end
    end
end

local function getPin(i)
    local p = pins[i]
    if not p then
        p = CreateFrame("Frame", nil, WorldMapButton)
        p:SetSize(20, 20)
        p:SetFrameStrata("DIALOG")
        p.bg = p:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints()
        p.bg:SetTexture("Interface\\COMMON\\Indicator-Gray")
        p.num = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.num:SetPoint("CENTER")
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(self)
            local e = self.entry
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format("%d. %s [%d]", self.index, e.q.t, e.q.l))
            GameTooltip:AddLine(string.format("%s - +%d XP", self.verb, e.xp), 1, 1, 1)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnMouseUp", function(self) QL.SetTarget(self.entry) end)
        pins[i] = p
    end
    return p
end

function QL.UpdatePins()
    local shown = 0
    if QuestLineDB and QuestLineDB.showMap == false then
        for i = 1, #pins do pins[i]:Hide() end
        for i = 1, #dots do dots[i]:Hide() end
        return
    end
    local map, b = currentBounds()
    local level = QL.plan and QL.plan[1]
    if map and level and WorldMapButton and WorldMapButton:IsVisible() then
        local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
        for index, e in ipairs(level.quests) do
            if shown >= MAX_PINS then break end
            local pt, verb = QL.StepFor(e)
            if pt and pt[1] == map and not e.requires then
                local fx = (b.l - pt[3]) / (b.l - b.r)
                local fy = (b.t - pt[2]) / (b.t - b.b)
                if fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1 then
                    shown = shown + 1
                    local p = getPin(shown)
                    p.entry, p.index, p.verb = e, index, verb
                    local c = COLORS[e.status] or COLORS.new
                    p.bg:SetVertexColor(c[1], c[2], c[3])
                    p.num:SetText(index)
                    p:ClearAllPoints()
                    p:SetPoint("CENTER", WorldMapButton, "TOPLEFT", fx * w, -fy * h)
                    p:Show()
                end
            end
        end
    end
    for i = shown + 1, #pins do pins[i]:Hide() end

    -- puntos posibles de la misión seleccionada (todas las apariciones conocidas)
    local used = 0
    if map and QL.targetPoints and WorldMapButton and WorldMapButton:IsVisible() then
        local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
        for _, pt in ipairs(QL.targetPoints) do
            if used >= MAX_DOTS then break end
            if pt[1] == map then
                local fx = (b.l - pt[3]) / (b.l - b.r)
                local fy = (b.t - pt[2]) / (b.t - b.b)
                if fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1 then
                    used = used + 1
                    local d = getDot(used)
                    d:ClearAllPoints()
                    d:SetPoint("CENTER", WorldMapButton, "TOPLEFT", fx * w, -fy * h)
                    d:Show()
                end
            end
        end
    end
    for i = used + 1, #dots do dots[i]:Hide() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("WORLD_MAP_UPDATE")
f:SetScript("OnEvent", function() QL.UpdatePins() end)
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function() QL.UpdatePins() end)
end

function QL.ToggleMapPins()
    QuestLineDB = QuestLineDB or {}
    QuestLineDB.showMap = (QuestLineDB.showMap == false)
    QL.UpdatePins()
    return QuestLineDB.showMap ~= false
end
