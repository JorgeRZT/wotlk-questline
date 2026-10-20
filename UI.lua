-- Ventana con la lista por niveles y flecha de dirección.
local _, QL = ...

local ROW_H = 16
local STATUS_TEXT = { turnin = "|cff00ff00[entregar]|r ", doing = "|cffffff00[en curso]|r " }

local frame = CreateFrame("Frame", "QuestLineFrame", UIParent)
frame:SetSize(430, 360)
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

local scroll = CreateFrame("ScrollFrame", "QuestLineScroll", frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 14, -36)
scroll:SetPoint("BOTTOMRIGHT", -32, 14)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(380, 10)
scroll:SetScrollChild(content)

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
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r:SetScript("OnClick", function(self) if self.entry then QL.SetTarget(self.entry) end end)
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
        h.text:SetText(string.format("|cffffd100Nivel %d|r  (faltan %d XP)", lv.level, lv.xpNeeded))
        for _, e in ipairs(lv.quests) do
            n = n + 1
            local r = getRow(n)
            r.entry = e
            local q = e.q
            local pt, verb = QL.StepFor(e)
            r.text:SetText(string.format("  %s%s [%d] +%d  |cff9d9d9d%s: %s|r", STATUS_TEXT[e.status] or "", q.t,
                q.l, e.xp, verb, QL.DescribePoint(pt)))
        end
    end
    for i = 1, #rows do rows[i]:SetShown(i <= n) end
    content:SetHeight(math.max(n * ROW_H, 10))
    if n == 0 then
        local r = getRow(1); r.entry = nil; r.text:SetText("Calculando..."); r:Show()
    end
end

function QL.OnPlanReady()
    if frame:IsShown() then render() end
    if QL.target then QL.RefreshTarget() end
end

frame:SetScript("OnShow", function() render() end)

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
    elseif msg == "arrow" then
        if arrow:IsShown() then arrow:Hide() else arrow:Show() end
    elseif msg == "debug" then
        local pos = QL.GetPlayerWorldPos()
        DEFAULT_CHAT_FRAME:AddMessage(string.format("QuestLine pos: %s | misiones: %d | plan: %s",
            pos and string.format("mapa %d x=%.0f y=%.0f", pos[1], pos[2], pos[3]) or "sin posicion",
            QL.CountQuests(), QL.plan and #QL.plan .. " niveles" or "nil"))
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
