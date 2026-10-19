-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Meter.lua
--  Authentic Damage Meter (Done & Taken):
--  - Sleek dark translucent window (0.05, 0.05, 0.05, 0.85) with 1px black border
--  - Clean 18px header with clickable toggle and Cyber accent rule
--  - 18px rows with statusbars and ability icons
--  - Left: "1. Name", Right: "Value (Share% / DPS)"
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Damage Meter"

local MAX_METER_ROWS = 8
local ROW_HEIGHT = 18
local METER_WIDTH = 260

function mod:Create()
    local f = CreateFrame("Frame", "BUI_MeterFrame", UIParent)
    EUI_MeterFrame = f -- Compatibility alias
    f:SetWidth(METER_WIDTH)
    f:SetHeight(20 + MAX_METER_ROWS * (ROW_HEIGHT + 2) + 6)
    B:Backdrop(f, 0.85)
    self.frame = f

    -- Header (Clickable button to toggle between Done and Taken)
    local hdrBtn = CreateFrame("Button", nil, f)
    hdrBtn:SetHeight(20)
    hdrBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hdrBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hdrBtn:EnableMouse(true)
    if hdrBtn.RegisterForClicks then
        hdrBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    local bg = hdrBtn:CreateTexture(nil, "BACKGROUND")
    B:Solid(bg, 0.04, 0.04, 0.04, 0.95)
    bg:SetAllPoints(hdrBtn)

    local rule = hdrBtn:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", hdrBtn, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", hdrBtn, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetTexture(B.WHITE)
    B:Accent(rule, "tex", 0.90)

    local titleFs = B:Font(hdrBtn, 10, "LEFT")
    titleFs:SetPoint("LEFT", hdrBtn, "LEFT", 8, 0)
    titleFs:SetTextColor(0.95, 0.95, 0.95)
    hdrBtn.title = titleFs

    local valFs = B:Font(hdrBtn, 10, "RIGHT")
    valFs:SetPoint("RIGHT", hdrBtn, "RIGHT", -8, 0)
    B:Accent(valFs, "text")
    hdrBtn.value = valFs

    hdrBtn:SetScript("OnClick", function()
        if B.db.meterMode == "done" then
            B.db.meterMode = "taken"
        else
            B.db.meterMode = "done"
        end
        B:Tick()
    end)

    f.header = hdrBtn

    -- Rows
    local rows = {}
    for i = 1, MAX_METER_ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetWidth(METER_WIDTH - 12)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -22 - (i - 1) * (ROW_HEIGHT + 2))

        -- Square ability / source icon frame on the left (18x18)
        local iconFrame = CreateFrame("Frame", nil, r)
        iconFrame:SetWidth(ROW_HEIGHT)
        iconFrame:SetHeight(ROW_HEIGHT)
        iconFrame:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        B:Backdrop(iconFrame, 1.0)
        r.iconFrame = iconFrame

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon = icon

        -- Status bar next to icon
        local bar = B:Bar(r, nil)
        bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
        bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        r.bar = bar

        local nameFs = B:Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetWidth(125)
        nameFs:SetHeight(14)
        r.nameFs = nameFs

        local textRight = B:Font(bar, 9, "RIGHT")
        textRight:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        textRight:SetWidth(90)
        textRight:SetHeight(14)
        r.textRight = textRight

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    B:RegisterMover(f, "meter", "Damage Meter", "TOPRIGHT", "TOPRIGHT", -12, -400)
end

function mod:Update(state)
    local f = self.frame
    local mode = B.db.meterMode or "done"
    local rows = f.rows

    -- Dynamic anchor below EncounterFrame or TimerFrame if not custom moved
    if not (B.db and B.db.positions and B.db.positions["meter"]) then
        f:ClearAllPoints()
        local encF = BUI_EncounterFrame or EUI_EncounterFrame
        local timerF = BUI_TimerFrame or EUI_TimerFrame
        if encF and encF:IsShown() then
            f:SetPoint("TOPRIGHT", encF, "BOTTOMRIGHT", 0, -6)
        elseif timerF and (timerF:IsShown() or B:IsEnabled("timer")) then
            f:SetPoint("TOPRIGHT", timerF, "BOTTOMRIGHT", 0, -6)
        else
            f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -320)
        end
    end

    if mode == "taken" then
        f.header.title:SetText("DAMAGE TAKEN")
        local takenList = state.taken or {}
        local count = table.getn(takenList)

        local totalTaken = 0
        local maxVal = 0
        for i = 1, count do
            local d = tonumber(takenList[i].dmg) or 0
            totalTaken = totalTaken + d
            if d > maxVal then maxVal = d end
        end
        f.header.value:SetText(B:Short(totalTaken))

        local shown = 0
        for i = 1, MAX_METER_ROWS do
            local r = rows[i]
            if i <= count then
                local item = takenList[i]
                local d = tonumber(item.dmg) or 0
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)
                B:SetBarColor(r.bar, 0.75, 0.25, 0.25)

                local sourceName = item.source or "Unknown"
                local iconTex = B:GetAbilityIcon(sourceName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.nameFs:SetText(string.format("%d. %s", i, sourceName))
                r.nameFs:SetTextColor(0.95, 0.95, 0.95)

                local share = (totalTaken > 0) and (d / totalTaken * 100) or 0
                local shareInt = math.floor(share + 0.5)
                r.textRight:SetText(string.format("%s (%d%%)", B:Short(d), shareInt))

                r:Show()
                shown = shown + 1
            else
                r:Hide()
            end
        end

        local h = 24 + shown * (ROW_HEIGHT + 2) + 4
        if h < 32 then h = 32 end
        f:SetHeight(h)

    else
        f.header.title:SetText("DAMAGE DONE")
        local meterList = state.meter or {}
        local count = table.getn(meterList)

        local totalDmg = 0
        local maxVal = 0
        for i = 1, count do
            local d = tonumber(meterList[i].dmg) or 0
            totalDmg = totalDmg + d
            if d > maxVal then maxVal = d end
        end

        local runSec = 0
        if state and state.run and state.run.t then
            runSec = tonumber(state.run.t) or 0
        end
        local totalDps = (runSec > 0) and math.floor(totalDmg / runSec) or 0
        f.header.value:SetText(string.format("%s (%s/s)", B:Short(totalDmg), B:Short(totalDps)))

        local shown = 0
        local ar, ag, ab = B:GetAccent()
        local cr, cg, cb = B:GetClassColor()

        for i = 1, MAX_METER_ROWS do
            local r = rows[i]
            if i <= count then
                local item = meterList[i]
                local d = tonumber(item.dmg) or 0
                local dps = tonumber(item.dps) or 0
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)

                -- If top ability, color with player class or accent
                if i == 1 then
                    B:SetBarColor(r.bar, cr, cg, cb)
                else
                    B:SetBarColor(r.bar, ar, ag, ab)
                end

                local spellName = item.name or "Unknown"
                local iconTex = B:GetAbilityIcon(spellName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.nameFs:SetText(string.format("%d. %s", i, spellName))
                r.nameFs:SetTextColor(0.95, 0.95, 0.95)

                if dps > 0 then
                    r.textRight:SetText(string.format("%s (%s)", B:Short(d), B:Short(dps)))
                else
                    local share = (totalDmg > 0) and (d / totalDmg * 100) or 0
                    local shareInt = math.floor(share + 0.5)
                    r.textRight:SetText(string.format("%s (%d%%)", B:Short(d), shareInt))
                end

                r:Show()
                shown = shown + 1
            else
                r:Hide()
            end
        end

        local h = 24 + shown * (ROW_HEIGHT + 2) + 4
        if h < 32 then h = 32 end
        f:SetHeight(h)
    end
end

B:RegisterModule("meter", mod)
