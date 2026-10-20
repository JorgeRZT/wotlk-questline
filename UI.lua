-- Ventana con la lista por niveles y flecha de dirección.
local _, QL = ...

local ROW_H = 16
local STATUS_TEXT = { turnin = "|cff00ff00[entregar]|r ", doing = "|cffffff00[en curso]|r " }

local frame = CreateFrame("Frame", "QuestLineFrame", UIParent)
frame:SetSize(600, 380)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 } })
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("QuestLine")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local rateLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rateLabel:SetPoint("TOPRIGHT", -150, -17)
rateLabel:SetText("Multiplicador XP x")

local rateBox = CreateFrame("EditBox", "QuestLineRateBox", frame, "InputBoxTemplate")
rateBox:SetSize(50, 20)
rateBox:SetPoint("LEFT", rateLabel, "RIGHT", 8, 0)
rateBox:SetAutoFocus(false)
rateBox:SetScript("OnEnterPressed", function(self)
    if QL.SetRate(self:GetText()) then
        self:ClearFocus()
    else
        self:SetText(tostring(QL.GetRate()))
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QuestLine:|r el multiplicador de XP debe ser un número entre 0.1 y 1000.")
    end
end)
rateBox:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(QL.GetRate()))
    self:ClearFocus()
end)

local scroll = CreateFrame("ScrollFrame", "QuestLineScroll", frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 14, -36)
scroll:SetPoint("BOTTOMRIGHT", -32, 14)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(550, 10)
scroll:SetScrollChild(content)

-- Frame:SetShown no existe en 3.3.5
local function setShown(frame, shown)
    if shown then frame:Show() else frame:Hide() end
end

local rows = {}
local function getRow(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Button", nil, content)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT", content, "RIGHT")
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT")
        r.text:SetJustifyH("LEFT")
        r.text:SetWidth(280)
        r.text:SetHeight(ROW_H)
        r.zone = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.zone:SetPoint("LEFT", 285, 0)
        r.zone:SetJustifyH("LEFT")
        r.zone:SetWidth(175)
        r.zone:SetHeight(ROW_H)
        r.skip = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.skip:SetSize(40, 14)
        r.skip:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        r.skip:SetText("Saltar")
        r.done = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.done:SetSize(40, 14)
        r.done:SetPoint("RIGHT", r.skip, "LEFT", -2, 0)
        r.done:SetText("Hecha")
        r.done:SetScript("OnClick", function(self)
            local e = self:GetParent().entry
            if e then QL.MarkDone(e.id) end
        end)
        r.done:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Ya la tengo hecha")
            GameTooltip:AddLine("Se marca como completada y se desbloquean sus continuaciones", 1, 1, 1)
            GameTooltip:AddLine("Deshacer: /ql undone <id>", 1, 1, 1)
            GameTooltip:Show()
        end)
        r.done:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.skip:SetScript("OnClick", function(self)
            local e = self:GetParent().entry
            if e then QL.Skip(e.id) end
        end)
        r.skip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Saltar esta misión y buscar otra")
            GameTooltip:AddLine("Oculta hasta que uses /ql unskip", 1, 1, 1)
            GameTooltip:Show()
        end)
        r.skip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r:SetScript("OnClick", function(self) if self.entry then QL.SetTarget(self.entry) end end)
        r:SetScript("OnEnter", function(self)
            local e = self.entry
            if not e then return end
            local q = e.q
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format("%s [%d]", q.t, q.l))
            GameTooltip:AddLine(string.format("+%d XP", e.xp), 1, 1, 1)
            if e.requires then
                local pre = QL.Quests[e.requires]
                GameTooltip:AddLine("Bloqueada: antes completa \"" .. (pre and pre.t or e.requires) .. "\"", 1, 0.5, 0.25)
            end
            if q.s[1] then GameTooltip:AddLine("Coger: " .. QL.DescribePoint(q.s[1]), 0.8, 0.8, 0.8) end
            if q.o[1] then GameTooltip:AddLine("Objetivos: " .. QL.DescribePoint(q.o[1]), 0.8, 0.8, 0.8) end
            if q.f[1] then GameTooltip:AddLine("Entregar: " .. QL.DescribePoint(q.f[1]), 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    return r
end

local function render()
    local plan = QL.plan
    local n = 0
    for _, lv in ipairs(plan or {}) do
        n = n + 1
        local h = getRow(n)
        h.entry = nil
        h.skip:Hide()
        h.done:Hide()
        h.zone:SetText("")
        h.text:SetText(string.format("|cffffd100Nivel %d|r  (faltan %d XP)", lv.level, lv.xpNeeded))
        for _, e in ipairs(lv.quests) do
            n = n + 1
            local r = getRow(n)
            r.entry = e
            setShown(r.skip, e.status == "new")
            setShown(r.done, e.status == "new")
            local q = e.q
            local pt, verb = QL.StepFor(e)
            r.text:SetText(string.format("  %s%s [%d] +%d", STATUS_TEXT[e.status] or "", q.t, q.l, e.xp))
            if e.requires then
                local pre = QL.Quests[e.requires]
                r.zone:SetText("|cffff8040Primero: " .. (pre and pre.t or e.requires) .. "|r")
            else
                r.zone:SetText(string.format("%s: %s", verb, QL.DescribePoint(pt)))
            end
        end
    end
    for i = 1, #rows do setShown(rows[i], i <= n) end
    content:SetHeight(math.max(n * ROW_H, 10))
    if n == 0 then
        local r = getRow(1); r.entry = nil; r.skip:Hide(); r.done:Hide(); r.zone:SetText(""); r.text:SetText("Calculando..."); r:Show()
    end
end

function QL.OnPlanReady()
    if frame:IsShown() then render() end
    if QL.target then QL.RefreshTarget() end
    if QL.UpdatePins then QL.UpdatePins() end
end

frame:SetScript("OnShow", function()
    rateBox:SetText(tostring(QL.GetRate()))
    render()
end)

-- Flecha ----------------------------------------------------------------
local arrow = CreateFrame("Frame", "QuestLineArrow", UIParent)
arrow:SetSize(120, 70)
arrow:SetPoint("TOP", UIParent, "TOP", 0, -120)
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:RegisterForDrag("LeftButton")
arrow:SetScript("OnDragStart", arrow.StartMoving)
arrow:SetScript("OnDragStop", arrow.StopMovingOrSizing)
arrow:Hide()
arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
arrow.icon:SetSize(40, 40)
arrow.icon:SetPoint("TOP")
arrow.icon:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arrow.text:SetPoint("TOP", arrow.icon, "BOTTOM", 0, -2)

local function rotate(tex, angle)
    local s, c = math.sin(angle), math.cos(angle)
    local function pt(ox, oy) return 0.5 + ox * c - oy * s, 0.5 + ox * s + oy * c end
    local ULx, ULy = pt(-0.5, -0.5)
    local LLx, LLy = pt(-0.5, 0.5)
    local URx, URy = pt(0.5, -0.5)
    local LRx, LRy = pt(0.5, 0.5)
    tex:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local acc = 0
arrow:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.05 then return end
    acc = 0
    local tgt = QL.targetPoint
    local pos = QL.GetPlayerWorldPos()
    if not (tgt and pos) then return end
    if tgt[1] ~= pos[1] then
        arrow.text:SetText(QL.target.q.t .. "\n(otro continente)")
        return
    end
    local dx, dy = tgt[2] - pos[2], tgt[3] - pos[3]
    local d = math.sqrt(dx * dx + dy * dy)
    local bearing = math.atan2(dy, dx)   -- X = norte, Y = oeste: antihorario desde el norte
    rotate(arrow.icon, bearing - GetPlayerFacing())
    arrow.text:SetText(string.format("%s\n%d yd", QL.targetVerb .. ": " .. QL.target.q.t, d))
end)

function QL.RefreshTarget()
    local e = QL.target
    if not e then return end
    -- localizar la entrada actualizada por id en el plan nuevo
    for _, lv in ipairs(QL.plan or {}) do
        for _, ne in ipairs(lv.quests) do
            if ne.id == e.id then e = ne end
        end
    end
    QL.target = e
    QL.targetPoint, QL.targetVerb = QL.StepFor(e)
end

function QL.SetTarget(entry)
    QL.target = entry
    QL.targetPoint, QL.targetVerb = QL.StepFor(entry)
    arrow:Show()
end

-- Comandos --------------------------------------------------------------
SLASH_QUESTLINE1 = "/ql"
SLASH_QUESTLINE2 = "/questline"
SlashCmdList["QUESTLINE"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "replan" then
        QL.RequestReplan(0)
    elseif strsub(msg, 1, 4) == "rate" then
        local value = strtrim(strsub(msg, 5))
        if value == "" then
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: el multiplicador de XP es x" .. QL.GetRate())
        elseif QL.SetRate(value) then
            rateBox:SetText(tostring(QL.GetRate()))
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: multiplicador de XP fijado en x" .. QL.GetRate())
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QuestLine:|r uso: /ql rate <0.1-1000>")
        end
    elseif strsub(msg, 1, 6) == "unskip" then
        local value = strtrim(strsub(msg, 7))
        if value == "all" then
            QL.Unskip("all")
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: todas las misiones saltadas se han restaurado")
        elseif tonumber(value) then
            QL.Unskip(tonumber(value))
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: misión " .. value .. " restaurada")
        else
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: uso: /ql unskip <idMisión|all>")
        end
    elseif strsub(msg, 1, 4) == "done" or strsub(msg, 1, 6) == "undone" then
        local undo = strsub(msg, 1, 6) == "undone"
        local id = tonumber(strtrim(strsub(msg, undo and 7 or 5)))
        if id then
            if undo then QL.Unmark(id) else QL.MarkDone(id) end
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: misión " .. id .. (undo and " desmarcada" or " marcada como hecha"))
        else
            DEFAULT_CHAT_FRAME:AddMessage("QuestLine: uso: /ql done <id> | /ql undone <id>")
        end
    elseif msg == "skipped" then
        local n = 0
        for id in pairs(QL.Skipped()) do
            n = n + 1
            local q = QL.Quests[id]
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d  %s", id, q and q.t or "?"))
        end
        DEFAULT_CHAT_FRAME:AddMessage("QuestLine: " .. n .. " misión(es) saltada(s)")
    elseif msg == "map" then
        DEFAULT_CHAT_FRAME:AddMessage("QuestLine: marcadores del mapa " .. (QL.ToggleMapPins() and "activados" or "desactivados"))
    elseif msg == "arrow" then
        if arrow:IsShown() then arrow:Hide() else arrow:Show() end
    elseif msg == "debug" then
        local pos = QL.GetPlayerWorldPos()
        DEFAULT_CHAT_FRAME:AddMessage("QuestLine: ID del área del mapa actual = " .. tostring(GetCurrentMapAreaID and GetCurrentMapAreaID()))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("QuestLine posición: %s | misiones: %d | plan: %s",
            pos and string.format("mapa %d x=%.0f y=%.0f", pos[1], pos[2], pos[3]) or "sin posición",
            QL.CountQuests(), QL.plan and #QL.plan .. " niveles" or "nil"))
        DEFAULT_CHAT_FRAME:AddMessage("QuestLine: misiones completadas conocidas = " .. select(1, QL.CountCompleted()) ..
            " (servidor) + " .. select(2, QL.CountCompleted()) .. " (manuales/detectadas)")
    else
        if frame:IsShown() then frame:Hide() else frame:Show() end
        if not QL.plan then QL.RequestReplan(0) end
    end
end

function QL.CountQuests()
    local n = 0
    for _ in pairs(QL.Quests) do n = n + 1 end
    return n
end
