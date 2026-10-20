-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Meter.lua
--  Authentic Cyberpunk Combat Analytics & Dual Bottom-Right Meters:
--  - AoE Damage Meter & Boss Damage Meter side-by-side in Bottom-Right corner
--  - 4 Dynamic Modes on primary meter: AoE Damage, Boss Damage, Healing, Taken
--  - Real-time Combat Log Crits Engine (Tracks Biggest Crits per ability)
--  - Sleek dark translucent window (0.04, 0.04, 0.04, 0.85) with 1px black border
--  - Header toggle buttons with cyber neon accent rule and Session Reset [R]
--  - 18px rows with statusbars, square ability icons, and detailed hover tooltips
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Damage Meter"

local MAX_METER_ROWS = 8
local ROW_HEIGHT = 18
local METER_WIDTH = 250
local METER_GAP = 6

B.meterOffsets = { done = {}, boss = {}, healing = {}, taken = {}, baseTime = 0, active = false }
B.biggestCrits = {}

-------------------------------------------------------------------------------
--  Combat Log Listener for Biggest Critical Strikes
-------------------------------------------------------------------------------
local critWatcher = CreateFrame("Frame")
critWatcher:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
critWatcher:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
critWatcher:SetScript("OnEvent", function()
    local msg = arg1 or ""
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- "Your Mortal Strike crits Kobold Vermin for 1420 Physical damage."
        local _, _, spell, amount = string.find(msg, "^Your (.-) crits .- for (%d+)")
        if spell and amount then
            local val = tonumber(amount) or 0
            local cur = B.biggestCrits[spell] or 0
            if val > cur then
                B.biggestCrits[spell] = val
            end
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
        -- "You crit Kobold Vermin for 850."
        local _, _, amount = string.find(msg, "crits .- for (%d+)")
        if not amount then
            _, _, amount = string.find(msg, "crit .- for (%d+)")
        end
        if amount then
            local val = tonumber(amount) or 0
            local cur = B.biggestCrits["Melee"] or 0
            if val > cur then
                B.biggestCrits["Melee"] = val
            end
        end
    end
end)

function B:ResetMeter(restoreAll)
    if restoreAll then
        self.meterOffsets.done = {}
        self.meterOffsets.boss = {}
        self.meterOffsets.healing = {}
        self.meterOffsets.taken = {}
        self.meterOffsets.baseTime = 0
        self.meterOffsets.active = false
        self.biggestCrits = {}
        return
    end

    local s = self:GetState()
    self.meterOffsets.done = {}
    self.meterOffsets.boss = {}
    self.meterOffsets.healing = {}
    self.meterOffsets.taken = {}
    self.meterOffsets.active = true
    self.biggestCrits = {}

    local curT = 0
    if s and s.run and s.run.t then
        curT = tonumber(s.run.t) or 0
    elseif s and s.time then
        curT = tonumber(s.time) or 0
    else
        curT = GetTime()
    end
    self.meterOffsets.baseTime = curT

    local rawDone = (s and s.meter) or (type(AZS_GetMeter) == "function" and AZS_GetMeter()) or (type(AZS_METER) == "table" and AZS_METER) or {}
    if type(rawDone) ~= "table" then rawDone = {} end
    for i = 1, table.getn(rawDone) do
        local item = rawDone[i]
        if type(item) == "table" and item.name then
            self.meterOffsets.done[item.name] = tonumber(item.dmg) or 0
        end
    end

    local rawBoss = (s and s.bossMeter) or (type(AZS_GetBossMeter) == "function" and AZS_GetBossMeter()) or {}
    if type(rawBoss) ~= "table" then rawBoss = {} end
    for i = 1, table.getn(rawBoss) do
        local item = rawBoss[i]
        if type(item) == "table" and item.name then
            self.meterOffsets.boss[item.name] = tonumber(item.dmg) or 0
        end
    end

    local rawHeal = (s and s.healing) or (type(AZS_GetHealing) == "function" and AZS_GetHealing()) or {}
    if type(rawHeal) ~= "table" then rawHeal = {} end
    for i = 1, table.getn(rawHeal) do
        local item = rawHeal[i]
        if type(item) == "table" and item.name then
            self.meterOffsets.healing[item.name] = tonumber(item.healing or item.dmg) or 0
        end
    end

    local rawTaken = (s and s.taken) or (type(AZS_TAKEN) == "table" and AZS_TAKEN) or {}
    if type(rawTaken) ~= "table" then rawTaken = {} end
    for i = 1, table.getn(rawTaken) do
        local item = rawTaken[i]
        if type(item) == "table" and item.source then
            self.meterOffsets.taken[item.source] = tonumber(item.dmg) or 0
        end
    end
end

-------------------------------------------------------------------------------
--  Meter Window Factory
-------------------------------------------------------------------------------
local function CreateMeterWindow(name, titleText, titleColor, accentColor)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(METER_WIDTH)
    f:SetHeight(20 + MAX_METER_ROWS * (ROW_HEIGHT + 2) + 6)
    B:Backdrop(f, 0.85)

    -- Header (Clickable button to cycle modes)
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
    if accentColor then
        rule:SetVertexColor(accentColor[1], accentColor[2], accentColor[3], 0.90)
    else
        B:Accent(rule, "tex", 0.90)
    end
    hdrBtn.rule = rule

    local titleFs = B:Font(hdrBtn, 10, "LEFT")
    titleFs:SetPoint("LEFT", hdrBtn, "LEFT", 8, 0)
    titleFs:SetText(titleText)
    if titleColor then
        titleFs:SetTextColor(titleColor[1], titleColor[2], titleColor[3])
    else
        titleFs:SetTextColor(0.95, 0.95, 0.95)
    end
    hdrBtn.title = titleFs

    -- Reset / Refresh Button on the far right of header
    local resetBtn = CreateFrame("Button", name .. "ResetBtn", hdrBtn)
    resetBtn:SetWidth(14)
    resetBtn:SetHeight(14)
    resetBtn:SetPoint("RIGHT", hdrBtn, "RIGHT", -4, 0)
    resetBtn:EnableMouse(true)
    B:Backdrop(resetBtn, 0.90)
    B:Border(resetBtn, 0.35, 0.35, 0.35, 1)

    local resetFs = B:Font(resetBtn, 9, "CENTER")
    resetFs:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetFs:SetText("R")
    resetFs:SetTextColor(0.85, 0.85, 0.85)
    resetBtn.fs = resetFs

    resetBtn:SetScript("OnEnter", function()
        B:Border(this, 1.0, 0.82, 0.10, 1)
        this.fs:SetTextColor(1.0, 0.82, 0.10)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Reset Damage Meter", 1.0, 0.82, 0.10)
        GameTooltip:AddLine("Left-Click: Reset session stats & crits to 0", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-Click: Restore full run totals", 0.60, 0.60, 0.60)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function()
        B:Border(this, 0.35, 0.35, 0.35, 1)
        this.fs:SetTextColor(0.85, 0.85, 0.85)
        GameTooltip:Hide()
    end)

    if resetBtn.RegisterForClicks then
        resetBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    resetBtn:SetScript("OnClick", function()
        local btn = arg1
        if btn == "RightButton" then
            B:ResetMeter(true)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BlackwellUI]|r Combat Meter: Full run totals restored.")
            end
        else
            B:ResetMeter(false)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BlackwellUI]|r Combat Meter: Session reset to 0.")
            end
        end
        B:Tick()
    end)
    hdrBtn.resetBtn = resetBtn

    local valFs = B:Font(hdrBtn, 10, "RIGHT")
    valFs:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)
    if accentColor then
        valFs:SetTextColor(accentColor[1], accentColor[2], accentColor[3])
    else
        B:Accent(valFs, "text")
    end
    hdrBtn.value = valFs

    f.header = hdrBtn

    -- Rows
    local rows = {}
    for i = 1, MAX_METER_ROWS do
        local r = CreateFrame("Button", nil, f)
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
        bar:EnableMouse(false)
        r.bar = bar

        local nameFs = B:Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetWidth(120)
        nameFs:SetHeight(14)
        r.nameFs = nameFs

        local textRight = B:Font(bar, 9, "RIGHT")
        textRight:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        textRight:SetWidth(85)
        textRight:SetHeight(14)
        r.textRight = textRight

        r:EnableMouse(true)
        r:SetScript("OnEnter", function()
            local sn = this.spellName
            if sn and sn ~= "" then
                GameTooltip:SetOwner(this, "ANCHOR_LEFT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(sn, 1, 1, 1)
                if this.valStr then
                    GameTooltip:AddLine(this.valStr, 0.85, 0.85, 0.85)
                end
                local crit = B.biggestCrits and B.biggestCrits[sn]
                if not crit and B.biggestCrits then
                    for k, v in pairs(B.biggestCrits) do
                        if string.lower(k) == string.lower(sn) then
                            crit = v
                            break
                        end
                    end
                end
                if crit and crit > 0 then
                    GameTooltip:AddLine(string.format("Biggest Crit: %s", B:Short(crit)), 1.0, 0.82, 0.10)
                end
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    return f
end

-------------------------------------------------------------------------------
--  Module Lifecycle
-------------------------------------------------------------------------------
function mod:Create()
    -- 1. AoE Damage Meter (Left Window in Bottom-Right Corner)
    local fAoE = CreateMeterWindow("BUI_MeterFrame", "AOE DAMAGE", { 0.95, 0.95, 0.95 }, nil)
    EUI_MeterFrame = fAoE -- Compatibility alias
    self.frame = fAoE

    -- 2. Boss Damage Meter (Right Window in Bottom-Right Corner)
    local fBoss = CreateMeterWindow("BUI_BossMeterFrame", "BOSS DAMAGE", { 1.0, 0.25, 0.40 }, { 1.0, 0.25, 0.40 })
    EUI_BossMeterFrame = fBoss -- Compatibility alias
    self.bossFrame = fBoss

    -- Header Click handlers
    fAoE.header:SetScript("OnClick", function()
        local cur = B.db.meterMode or "aoe"
        if cur == "aoe" or cur == "done" then
            B.db.meterMode = "healing"
        elseif cur == "healing" then
            B.db.meterMode = "taken"
        else
            B.db.meterMode = "aoe"
        end
        B:Tick()
    end)

    fBoss.header:SetScript("OnClick", function()
        local cur = B.db.bossMeterMode or "boss"
        if cur == "boss" then
            B.db.bossMeterMode = "taken"
        else
            B.db.bossMeterMode = "boss"
        end
        B:Tick()
    end)

    -- Synchronize visibility between both frames
    fAoE:SetScript("OnShow", function()
        if fBoss and not fBoss:IsShown() and B:IsEnabled("meter") then
            fBoss:Show()
        end
    end)
    fAoE:SetScript("OnHide", function()
        if fBoss and fBoss:IsShown() then
            fBoss:Hide()
        end
    end)

    -- Register both as independent Movers
    -- Default placement: Boss in far bottom-right (-12, 24), AoE directly to its left (-268, 24)
    local aoeX = -12 - METER_WIDTH - METER_GAP
    B:RegisterMover(fAoE, "meter", "AoE Damage Meter", "BOTTOMRIGHT", "BOTTOMRIGHT", aoeX, 24)
    B:RegisterMover(fBoss, "meter_boss", "Boss Damage Meter", "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 24)
end

function mod:Update(state)
    local fAoE = self.frame
    local fBoss = self.bossFrame
    if not (fAoE and fBoss) then return end

    -- Position anchors if not moved by user
    if not (B.db and B.db.positions and B.db.positions["meter"]) then
        fAoE:ClearAllPoints()
        local aoeX = -12 - METER_WIDTH - METER_GAP
        fAoE:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", aoeX, 24)
    end
    if not (B.db and B.db.positions and B.db.positions["meter_boss"]) then
        fBoss:ClearAllPoints()
        fBoss:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 24)
    end

    if not fBoss:IsShown() then
        fBoss:Show()
    end

    local curT = 0
    if state and state.run and state.run.t then
        curT = tonumber(state.run.t) or 0
    elseif state and state.time then
        curT = tonumber(state.time) or 0
    else
        curT = GetTime()
    end
    local runSec = curT
    if B.meterOffsets and B.meterOffsets.active then
        runSec = curT - (B.meterOffsets.baseTime or 0)
    end
    if runSec < 1 then runSec = 1 end

    ---------------------------------------------------------------------------
    --  1. BOSS DAMAGE WINDOW
    ---------------------------------------------------------------------------
    local bossMode = B.db.bossMeterMode or "boss"
    local bossRows = fBoss.rows

    if bossMode == "taken" then
        if B.meterOffsets and B.meterOffsets.active then
            fBoss.header.title:SetText("DMG TAKEN (SESSION)")
        else
            fBoss.header.title:SetText("DAMAGE TAKEN")
        end
        fBoss.header.title:SetTextColor(1.0, 0.65, 0.20)

        local rawTaken = state.taken or {}
        if type(rawTaken) ~= "table" then rawTaken = {} end
        local count = table.getn(rawTaken)
        local takenList = {}
        local totalTaken = 0
        local maxVal = 0

        for i = 1, count do
            local item = rawTaken[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local src = item.source or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.taken and B.meterOffsets.taken[src]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(takenList, { source = src, dmg = d })
                    totalTaken = totalTaken + d
                    if d > maxVal then maxVal = d end
                end
            end
        end

        table.sort(takenList, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
        local displayCount = table.getn(takenList)
        fBoss.header.value:SetText(B:Short(totalTaken))

        local shown = 0
        for i = 1, MAX_METER_ROWS do
            local r = bossRows[i]
            if i <= displayCount then
                local item = takenList[i]
                local d = item.dmg
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)
                B:SetBarColor(r.bar, 0.75, 0.25, 0.25)

                local sourceName = item.source or "Unknown"
                local iconTex = B:GetAbilityIcon(sourceName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.spellName = sourceName
                r.valStr = string.format("Total Damage Taken: %s", B:Short(d))

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
        fBoss:SetHeight(h)
    else -- "boss" (Default for Boss Window)
        if B.meterOffsets and B.meterOffsets.active then
            fBoss.header.title:SetText("BOSS DMG (SESSION)")
        else
            fBoss.header.title:SetText("BOSS DAMAGE")
        end
        fBoss.header.title:SetTextColor(1.0, 0.25, 0.40) -- Crimson

        local rawBoss = (type(AZS_GetBossMeter) == "function" and AZS_GetBossMeter()) or state.bossMeter or {}
        if type(rawBoss) ~= "table" then rawBoss = {} end
        local count = table.getn(rawBoss)
        local bossList = {}
        local bossBySpell = {}
        local totalBossDmg = 0
        local maxVal = 0

        for i = 1, count do
            local item = rawBoss[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.boss and B.meterOffsets.boss[sName]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                bossBySpell[sName] = d
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(bossList, { name = sName, dmg = d })
                    totalBossDmg = totalBossDmg + d
                    if d > maxVal then maxVal = d end
                end
            end
        end

        table.sort(bossList, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
        local displayCount = table.getn(bossList)
        local totalDps = math.floor(totalBossDmg / runSec)
        fBoss.header.value:SetText(string.format("%s (%s/s)", B:Short(totalBossDmg), B:Short(totalDps)))

        local shown = 0
        for i = 1, MAX_METER_ROWS do
            local r = bossRows[i]
            if i <= displayCount then
                local item = bossList[i]
                local d = item.dmg
                local dps = math.floor(d / runSec)
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)
                if i == 1 then
                    B:SetBarColor(r.bar, 1.0, 0.25, 0.40)
                else
                    B:SetBarColor(r.bar, 0.80, 0.18, 0.32)
                end

                local spellName = item.name or "Unknown"
                local iconTex = B:GetAbilityIcon(spellName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.spellName = spellName
                r.valStr = string.format("Boss Damage: %s (%s/s)", B:Short(d), B:Short(dps))

                r.nameFs:SetText(string.format("%d. %s", i, spellName))
                r.nameFs:SetTextColor(0.95, 0.95, 0.95)

                if dps > 0 then
                    r.textRight:SetText(string.format("%s (%s)", B:Short(d), B:Short(dps)))
                else
                    local share = (totalBossDmg > 0) and (d / totalBossDmg * 100) or 0
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
        fBoss:SetHeight(h)

        -- Expose boss map for AoE calculations
        self.bossBySpell = bossBySpell
    end

    ---------------------------------------------------------------------------
    --  2. AOE DAMAGE WINDOW (Primary)
    ---------------------------------------------------------------------------
    local aoeMode = B.db.meterMode or "aoe"
    local aoeRows = fAoE.rows

    if aoeMode == "taken" then
        if B.meterOffsets and B.meterOffsets.active then
            fAoE.header.title:SetText("DMG TAKEN (SESSION)")
        else
            fAoE.header.title:SetText("DAMAGE TAKEN")
        end
        fAoE.header.title:SetTextColor(1.0, 0.65, 0.20) -- Cyber Amber

        local rawTaken = state.taken or {}
        if type(rawTaken) ~= "table" then rawTaken = {} end
        local count = table.getn(rawTaken)
        local takenList = {}
        local totalTaken = 0
        local maxVal = 0

        for i = 1, count do
            local item = rawTaken[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local src = item.source or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.taken and B.meterOffsets.taken[src]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(takenList, { source = src, dmg = d })
                    totalTaken = totalTaken + d
                    if d > maxVal then maxVal = d end
                end
            end
        end

        table.sort(takenList, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
        local displayCount = table.getn(takenList)
        fAoE.header.value:SetText(B:Short(totalTaken))

        local shown = 0
        for i = 1, MAX_METER_ROWS do
            local r = aoeRows[i]
            if i <= displayCount then
                local item = takenList[i]
                local d = item.dmg
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)
                B:SetBarColor(r.bar, 0.75, 0.25, 0.25)

                local sourceName = item.source or "Unknown"
                local iconTex = B:GetAbilityIcon(sourceName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.spellName = sourceName
                r.valStr = string.format("Total Damage Taken: %s", B:Short(d))

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
        fAoE:SetHeight(h)

    elseif aoeMode == "healing" then
        if B.meterOffsets and B.meterOffsets.active then
            fAoE.header.title:SetText("HEALING (SESSION)")
        else
            fAoE.header.title:SetText("HEALING DONE")
        end
        fAoE.header.title:SetTextColor(0.20, 0.90, 0.40) -- Emerald

        local rawHeal = (type(AZS_GetHealing) == "function" and AZS_GetHealing()) or state.healing or {}
        if type(rawHeal) ~= "table" then rawHeal = {} end
        local count = table.getn(rawHeal)
        local healList = {}
        local totalHeal = 0
        local maxVal = 0

        for i = 1, count do
            local item = rawHeal[i]
            if type(item) == "table" then
                local rawH = tonumber(item.healing or item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.healing and B.meterOffsets.healing[sName]) or 0
                local hVal = rawH - base
                if hVal < 0 then hVal = 0 end
                if hVal > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(healList, { name = sName, dmg = hVal })
                    totalHeal = totalHeal + hVal
                    if hVal > maxVal then maxVal = hVal end
                end
            end
        end

        table.sort(healList, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
        local displayCount = table.getn(healList)
        local totalHps = math.floor(totalHeal / runSec)
        fAoE.header.value:SetText(string.format("%s (%s/s)", B:Short(totalHeal), B:Short(totalHps)))

        local shown = 0
        for i = 1, MAX_METER_ROWS do
            local r = aoeRows[i]
            if i <= displayCount then
                local item = healList[i]
                local hVal = item.dmg
                local hps = math.floor(hVal / runSec)
                local pctMax = (maxVal > 0) and (hVal / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)
                B:SetBarColor(r.bar, 0.20, 0.75, 0.35)

                local spellName = item.name or "Unknown"
                local iconTex = B:GetAbilityIcon(spellName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.spellName = spellName
                r.valStr = string.format("Healing Done: %s (%s/s)", B:Short(hVal), B:Short(hps))

                r.nameFs:SetText(string.format("%d. %s", i, spellName))
                r.nameFs:SetTextColor(0.95, 0.95, 0.95)

                if hps > 0 then
                    r.textRight:SetText(string.format("%s (%s)", B:Short(hVal), B:Short(hps)))
                else
                    local share = (totalHeal > 0) and (hVal / totalHeal * 100) or 0
                    local shareInt = math.floor(share + 0.5)
                    r.textRight:SetText(string.format("%s (%d%%)", B:Short(hVal), shareInt))
                end

                r:Show()
                shown = shown + 1
            else
                r:Hide()
            end
        end

        local h = 24 + shown * (ROW_HEIGHT + 2) + 4
        if h < 32 then h = 32 end
        fAoE:SetHeight(h)

    else -- "aoe" or "done" (Default: AOE DAMAGE = Total Damage minus Boss Damage)
        if B.meterOffsets and B.meterOffsets.active then
            fAoE.header.title:SetText("AOE DMG (SESSION)")
        else
            fAoE.header.title:SetText("AOE DAMAGE")
        end
        fAoE.header.title:SetTextColor(0.95, 0.95, 0.95)

        local rawMeter = (type(AZS_GetMeter) == "function" and AZS_GetMeter()) or state.meter or {}
        if type(rawMeter) ~= "table" then rawMeter = {} end
        local count = table.getn(rawMeter)
        local aoeList = {}
        local totalAoEDmg = 0
        local maxVal = 0
        local bossMap = self.bossBySpell or {}

        for i = 1, count do
            local item = rawMeter[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.done and B.meterOffsets.done[sName]) or 0
                local totalD = rawD - base
                if totalD < 0 then totalD = 0 end

                local bossD = bossMap[sName] or 0
                local aoeD = totalD - bossD
                if aoeD < 0 then aoeD = 0 end

                if aoeD > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(aoeList, { name = sName, dmg = aoeD })
                    totalAoEDmg = totalAoEDmg + aoeD
                    if aoeD > maxVal then maxVal = aoeD end
                end
            end
        end

        table.sort(aoeList, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
        local displayCount = table.getn(aoeList)
        local totalDps = math.floor(totalAoEDmg / runSec)
        fAoE.header.value:SetText(string.format("%s (%s/s)", B:Short(totalAoEDmg), B:Short(totalDps)))

        local shown = 0
        local ar, ag, ab = B:GetAccent()
        local cr, cg, cb = B:GetClassColor()

        for i = 1, MAX_METER_ROWS do
            local r = aoeRows[i]
            if i <= displayCount then
                local item = aoeList[i]
                local d = item.dmg
                local dps = math.floor(d / runSec)
                local pctMax = (maxVal > 0) and (d / maxVal) or 0
                if pctMax > 1 then pctMax = 1 end

                r.bar:SetValue(pctMax)

                -- Top ability gets Class Color, remainder get Accent Color
                if i == 1 then
                    B:SetBarColor(r.bar, cr, cg, cb)
                else
                    B:SetBarColor(r.bar, ar, ag, ab)
                end

                local spellName = item.name or "Unknown"
                local iconTex = B:GetAbilityIcon(spellName)
                r.icon:SetTexture(iconTex)
                r.icon:Show()

                r.spellName = spellName
                r.valStr = string.format("AoE Damage: %s (%s/s)", B:Short(d), B:Short(dps))

                r.nameFs:SetText(string.format("%d. %s", i, spellName))
                r.nameFs:SetTextColor(0.95, 0.95, 0.95)

                if dps > 0 then
                    r.textRight:SetText(string.format("%s (%s)", B:Short(d), B:Short(dps)))
                else
                    local share = (totalAoEDmg > 0) and (d / totalAoEDmg * 100) or 0
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
        fAoE:SetHeight(h)
    end
end

B:RegisterModule("meter", mod)
