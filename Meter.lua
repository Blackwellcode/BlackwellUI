-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Meter.lua
--  Consolidated Cyberpunk Combat Meter & Multiplayer Party Drilldown:
--  - Single unified window with 5 modes: Damage, Healing, Boss, Taken, Party
--  - Full Multiplayer / Party mode: tracks all party members with class colors,
--    damage share, DPS, and Top Ability badge
--  - Party Drilldown: click any party member to inspect their abilities & spells
--  - Combat Log listener for party spell tracking & biggest critical strikes
--  - 8 Statusbar rows with ability/class icons, smooth mouse-wheel scrolling,
--    and comprehensive telemetry hover tooltips
--  - Session reset [R] (Left-click: session delta, Right-click: restore run totals)
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Damage Meter"

local METER_WIDTH = 330
local MAX_METER_ROWS = 8
local ROW_HEIGHT = 18
local ROW_GAP = 2

local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_COORDS = {
    ["WARRIOR"] = { 0, 0.25, 0, 0.25 },
    ["MAGE"]    = { 0.25, 0.49609375, 0, 0.25 },
    ["ROGUE"]   = { 0.49609375, 0.7421875, 0, 0.25 },
    ["DRUID"]   = { 0.7421875, 0.98828125, 0, 0.25 },
    ["HUNTER"]  = { 0, 0.25, 0.25, 0.5 },
    ["SHAMAN"]  = { 0.25, 0.49609375, 0.25, 0.5 },
    ["PRIEST"]  = { 0.49609375, 0.7421875, 0.25, 0.5 },
    ["WARLOCK"] = { 0.7421875, 0.98828125, 0.25, 0.5 },
    ["PALADIN"] = { 0, 0.25, 0.5, 0.75 },
}

local TABS = {
    { key = "damage",  label = "Damage",  r = 1.00, g = 0.75, b = 0.20 },
    { key = "healing", label = "Healing", r = 0.25, g = 0.90, b = 0.45 },
    { key = "boss",    label = "Boss",    r = 1.00, g = 0.35, b = 0.15 },
    { key = "taken",   label = "Taken",   r = 0.90, g = 0.25, b = 0.25 },
    { key = "party",   label = "Party",   r = 0.30, g = 0.75, b = 1.00 },
}

B.meterOffsets = { done = {}, boss = {}, healing = {}, taken = {}, party = {}, baseTime = 0, active = false }
B.biggestCrits = {}
B.meterPartySpells = {} -- [playerName][spellName] = { dmg = total, hits = count, crits = count }
B.meterDrilldown = nil
B.meterScrollOffset = 0
B.meterCollapsed = false

-------------------------------------------------------------------------------
--  Combat Log Listener for Crits & Party Spells
-------------------------------------------------------------------------------
local logWatcher = CreateFrame("Frame")
logWatcher:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
logWatcher:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
logWatcher:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
logWatcher:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
logWatcher:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")
logWatcher:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")

local function RecordPartySpell(player, spell, dmg, isCrit)
    if not player or player == "" or not spell or spell == "" then return end
    local pKey = string.lower(player)
    local sKey = spell
    if not B.meterPartySpells[pKey] then
        B.meterPartySpells[pKey] = {}
    end
    if not B.meterPartySpells[pKey][sKey] then
        B.meterPartySpells[pKey][sKey] = { name = spell, dmg = 0, hits = 0, crits = 0 }
    end
    local rec = B.meterPartySpells[pKey][sKey]
    rec.dmg = rec.dmg + (tonumber(dmg) or 0)
    rec.hits = rec.hits + 1
    if isCrit then
        rec.crits = rec.crits + 1
    end
end

logWatcher:SetScript("OnEvent", function()
    local msg = arg1 or ""
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        local _, _, spell, amount = string.find(msg, "^Your (.-) crits .- for (%d+)")
        if spell and amount then
            local val = tonumber(amount) or 0
            local cur = B.biggestCrits[spell] or 0
            if val > cur then B.biggestCrits[spell] = val end
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
        local _, _, amount = string.find(msg, "crits .- for (%d+)")
        if not amount then _, _, amount = string.find(msg, "crit .- for (%d+)") end
        if amount then
            local val = tonumber(amount) or 0
            local cur = B.biggestCrits["Melee"] or 0
            if val > cur then B.biggestCrits["Melee"] = val end
        end
    elseif event == "CHAT_MSG_SPELL_PARTY_DAMAGE" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" then
        -- "Valandil's Blizzard crits Kobold Vermin for 640 Frost damage."
        local _, _, p, sp, amt = string.find(msg, "^(.-)'s (.-) crits .- for (%d+)")
        if p and sp and amt then
            RecordPartySpell(p, sp, amt, true)
            return
        end
        -- "Valandil's Blizzard hits Kobold Vermin for 320 Frost damage."
        local _, _, p2, sp2, amt2 = string.find(msg, "^(.-)'s (.-) hits .- for (%d+)")
        if p2 and sp2 and amt2 then
            RecordPartySpell(p2, sp2, amt2, false)
            return
        end
    elseif event == "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE" then
        -- "Kobold Vermin suffers 140 Shadow damage from Eluna's Shadow Word: Pain."
        local _, _, amt, p, sp = string.find(msg, "suffers (%d+).-damage from (.-)'s ([^%.]+)")
        if p and sp and amt then
            RecordPartySpell(p, sp, amt, false)
            return
        end
    elseif event == "CHAT_MSG_COMBAT_PARTY_HITS" then
        -- "Thorin crits Kobold Vermin for 420."
        local _, _, p, amt = string.find(msg, "^(.-) crits .- for (%d+)")
        if p and amt then
            RecordPartySpell(p, "Melee", amt, true)
            return
        end
        -- "Thorin hits Kobold Vermin for 210."
        local _, _, p2, amt2 = string.find(msg, "^(.-) hits .- for (%d+)")
        if p2 and amt2 then
            RecordPartySpell(p2, "Melee", amt2, false)
            return
        end
    end
end)

function B:ResetMeter(restoreAll)
    if restoreAll then
        self.meterOffsets.done = {}
        self.meterOffsets.boss = {}
        self.meterOffsets.healing = {}
        self.meterOffsets.taken = {}
        self.meterOffsets.party = {}
        self.meterOffsets.baseTime = 0
        self.meterOffsets.active = false
        self.biggestCrits = {}
        self.meterPartySpells = {}
        self.meterDrilldown = nil
        self.meterScrollOffset = 0
        return
    end

    local s = self:GetState()
    self.meterOffsets.done = {}
    self.meterOffsets.boss = {}
    self.meterOffsets.healing = {}
    self.meterOffsets.taken = {}
    self.meterOffsets.party = {}
    self.meterOffsets.active = true
    self.biggestCrits = {}
    self.meterPartySpells = {}
    self.meterDrilldown = nil
    self.meterScrollOffset = 0

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
    if type(rawDone) == "table" then
        for i = 1, table.getn(rawDone) do
            local item = rawDone[i]
            if type(item) == "table" and item.name then
                self.meterOffsets.done[item.name] = tonumber(item.dmg) or 0
            end
        end
    end

    local rawBoss = (s and s.bossMeter) or (type(AZS_GetBossMeter) == "function" and AZS_GetBossMeter()) or {}
    if type(rawBoss) == "table" then
        for i = 1, table.getn(rawBoss) do
            local item = rawBoss[i]
            if type(item) == "table" and item.name then
                self.meterOffsets.boss[item.name] = tonumber(item.dmg) or 0
            end
        end
    end

    local rawHeal = (s and s.healing) or (type(AZS_GetHealing) == "function" and AZS_GetHealing()) or {}
    if type(rawHeal) == "table" then
        for i = 1, table.getn(rawHeal) do
            local item = rawHeal[i]
            if type(item) == "table" and item.name then
                self.meterOffsets.healing[item.name] = tonumber(item.healing or item.dmg) or 0
            end
        end
    end

    local rawTaken = (s and s.taken) or (type(AZS_TAKEN) == "table" and AZS_TAKEN) or {}
    if type(rawTaken) == "table" then
        for i = 1, table.getn(rawTaken) do
            local item = rawTaken[i]
            if type(item) == "table" and item.source then
                self.meterOffsets.taken[item.source] = tonumber(item.dmg) or 0
            end
        end
    end

    local rawParty = (s and s.party) or (type(AZS_GetPartyMeter) == "function" and AZS_GetPartyMeter()) or (type(AZS_PARTY) == "table" and AZS_PARTY) or {}
    if type(rawParty) == "table" then
        for i = 1, table.getn(rawParty) do
            local item = rawParty[i]
            if type(item) == "table" and item.name then
                self.meterOffsets.party[item.name] = tonumber(item.dmg) or 0
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Consolidated Meter Frame Creation
-------------------------------------------------------------------------------
function mod:Create()
    local f = CreateFrame("Frame", "BUI_MeterFrame", UIParent)
    EUI_MeterFrame = f
    BUI_Meter = f
    BUI_BossMeterFrame = f -- Compatibility alias
    self.frame = f

    f:SetWidth(METER_WIDTH)
    f:SetHeight(226)
    B:Backdrop(f, 0.88)

    ---------------------------------------------------------------------------
    --  1. Header Top Bar (Height 22px)
    ---------------------------------------------------------------------------
    local hdr = CreateFrame("Button", nil, f)
    hdr:SetHeight(22)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hdr:EnableMouse(true)
    if hdr.RegisterForClicks then
        hdr:RegisterForClicks("LeftButtonUp")
    end
    hdr:SetScript("OnClick", function()
        local cur = B.db.meterMode or "damage"
        if cur == "damage" or cur == "aoe" then
            B.db.meterMode = "healing"
        elseif cur == "healing" then
            B.db.meterMode = "taken"
        elseif cur == "taken" then
            B.db.meterMode = "boss"
        elseif cur == "boss" then
            B.db.meterMode = "party"
        else
            B.db.meterMode = "damage"
        end
        B.meterDrilldown = nil
        B.meterScrollOffset = 0
        B:Tick()
    end)
    f.header = hdr

    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    B:Solid(hdrBg, 0.04, 0.04, 0.04, 0.95)
    hdrBg:SetAllPoints(hdr)

    local rule = hdr:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetTexture(B.WHITE)
    B:Accent(rule, "tex", 0.90)
    hdr.rule = rule

    -- Player class icon / Mode icon on top left
    local brandIcon = hdr:CreateTexture(nil, "ARTWORK")
    brandIcon:SetWidth(16)
    brandIcon:SetHeight(16)
    brandIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    local _, pClass = UnitClass("player")
    if pClass and CLASS_COORDS[pClass] then
        local c = CLASS_COORDS[pClass]
        brandIcon:SetTexture(CLASS_SHEET)
        brandIcon:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        brandIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        brandIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    hdr.brandIcon = brandIcon

    -- Title / Mode Brand text
    local titleFs = B:Font(hdr, 10, "LEFT")
    titleFs:SetPoint("LEFT", brandIcon, "RIGHT", 6, 0)
    titleFs:SetWidth(95)
    titleFs:SetHeight(14)
    titleFs:SetTextColor(1.0, 0.90, 0.62)
    titleFs:SetText("COMBAT METER")
    hdr.title = titleFs

    -- Buttons on far right: Collapse [-] and Reset [R]
    local collapseBtn = CreateFrame("Button", nil, hdr)
    collapseBtn:SetWidth(14)
    collapseBtn:SetHeight(14)
    collapseBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    collapseBtn:EnableMouse(true)
    B:Backdrop(collapseBtn, 0.90)
    B:Border(collapseBtn, 0.35, 0.35, 0.35, 1)

    local collapseFs = B:Font(collapseBtn, 9, "CENTER")
    collapseFs:SetPoint("CENTER", collapseBtn, "CENTER", 0, 0)
    collapseFs:SetText("-")
    collapseFs:SetTextColor(0.85, 0.85, 0.85)
    collapseBtn.fs = collapseFs
    collapseBtn:SetScript("OnClick", function()
        B.meterCollapsed = not B.meterCollapsed
        if B.meterCollapsed then
            this.fs:SetText("+")
            f:SetHeight(44)
            if f.colsHeader then f.colsHeader:Hide() end
            if f.rows then
                for i = 1, MAX_METER_ROWS do f.rows[i]:Hide() end
            end
        else
            this.fs:SetText("-")
            if f.colsHeader then f.colsHeader:Show() end
            B:Tick()
        end
    end)
    hdr.collapseBtn = collapseBtn

    local resetBtn = CreateFrame("Button", nil, hdr)
    resetBtn:SetWidth(14)
    resetBtn:SetHeight(14)
    resetBtn:SetPoint("RIGHT", collapseBtn, "LEFT", -4, 0)
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
        GameTooltip:AddLine("Reset Combat Meter", 1.0, 0.82, 0.10)
        GameTooltip:AddLine("Left-Click: Reset session numbers & crits to 0", 0.85, 0.85, 0.85)
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
        if arg1 == "RightButton" then
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
    hdr.resetBtn = resetBtn

    -- Merge Procs Button [M]
    local mergeBtn = CreateFrame("Button", nil, hdr)
    mergeBtn:SetWidth(14)
    mergeBtn:SetHeight(14)
    mergeBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
    mergeBtn:EnableMouse(true)
    B:Backdrop(mergeBtn, 0.90)
    B:Border(mergeBtn, 0.35, 0.35, 0.35, 1)

    local mergeFs = B:Font(mergeBtn, 9, "CENTER")
    mergeFs:SetPoint("CENTER", mergeBtn, "CENTER", 0, 0)
    mergeFs:SetText("M")
    mergeFs:SetTextColor(0.85, 0.85, 0.85)
    mergeBtn.fs = mergeFs

    mergeBtn:SetScript("OnEnter", function()
        B:Border(this, 1.0, 0.82, 0.10, 1)
        this.fs:SetTextColor(1.0, 0.82, 0.10)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Merge Item Procs", 1.0, 0.82, 0.10)
        GameTooltip:AddLine("Left-Click: Toggle merging legendary neck & item procs into base abilities", 0.85, 0.85, 0.85)
        if B.db.mergeItemProcs then
            GameTooltip:AddLine("Status: |cff00ff00Merged (Compact)|r", 1, 1, 1)
        else
            GameTooltip:AddLine("Status: |cffffaa00Separated (Detailed)|r", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    mergeBtn:SetScript("OnLeave", function()
        if B.db.mergeItemProcs then
            B:Border(this, 0.30, 0.75, 1.00, 1)
            this.fs:SetTextColor(0.30, 0.75, 1.00)
        else
            B:Border(this, 0.35, 0.35, 0.35, 1)
            this.fs:SetTextColor(0.60, 0.60, 0.60)
        end
        GameTooltip:Hide()
    end)
    mergeBtn:SetScript("OnClick", function()
        B.db.mergeItemProcs = not B.db.mergeItemProcs
        if B.db.mergeItemProcs then
            B:Border(this, 0.30, 0.75, 1.00, 1)
            this.fs:SetTextColor(0.30, 0.75, 1.00)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BlackwellUI]|r Combat Meter: Item & neck procs merged.")
            end
        else
            B:Border(this, 0.35, 0.35, 0.35, 1)
            this.fs:SetTextColor(0.60, 0.60, 0.60)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BlackwellUI]|r Combat Meter: Item & neck procs separated.")
            end
        end
        B:Tick()
    end)
    hdr.mergeBtn = mergeBtn

    -- Total DPS text & Total Amount text
    local rateFs = B:Font(hdr, 9, "RIGHT")
    rateFs:SetPoint("RIGHT", mergeBtn, "LEFT", -6, 0)
    rateFs:SetTextColor(0.70, 0.92, 0.68)
    hdr.rate = rateFs

    local valFs = B:Font(hdr, 10, "RIGHT")
    valFs:SetPoint("RIGHT", rateFs, "LEFT", -6, 0)
    B:Accent(valFs, "text")
    hdr.value = valFs

    ---------------------------------------------------------------------------
    --  2. Five Mode Tabs (Height 18px)
    ---------------------------------------------------------------------------
    local tabsBar = CreateFrame("Frame", nil, f)
    tabsBar:SetHeight(18)
    tabsBar:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
    tabsBar:SetPoint("TOPRIGHT", hdr, "BOTTOMRIGHT", 0, -2)
    f.tabsBar = tabsBar

    -- Back Button for Party Drilldown
    local backBtn = CreateFrame("Button", nil, tabsBar)
    backBtn:SetWidth(126)
    backBtn:SetHeight(18)
    backBtn:SetPoint("LEFT", tabsBar, "LEFT", 3, 0)
    B:Backdrop(backBtn, 0.95)
    B:Border(backBtn, 0.30, 0.75, 1.00, 1)

    local backFs = B:Font(backBtn, 9, "CENTER")
    backFs:SetPoint("CENTER", backBtn, "CENTER", 0, 0)
    backFs:SetText("< Back to Party")
    backFs:SetTextColor(0.30, 0.75, 1.00)
    backBtn.fs = backFs

    backBtn:EnableMouse(true)
    backBtn:SetScript("OnClick", function()
        B.meterDrilldown = nil
        B.meterScrollOffset = 0
        B:Tick()
    end)
    backBtn:Hide()
    tabsBar.backBtn = backBtn

    local drillLabel = B:Font(tabsBar, 9, "LEFT")
    drillLabel:SetPoint("LEFT", backBtn, "RIGHT", 8, 0)
    drillLabel:SetPoint("RIGHT", tabsBar, "RIGHT", -4, 0)
    drillLabel:SetHeight(14)
    drillLabel:SetTextColor(1, 1, 1)
    drillLabel:Hide()
    tabsBar.drillLabel = drillLabel

    local tabButtons = {}
    local tabWidth = math.floor((METER_WIDTH - 8 - 4 * 3) / 5)
    for i = 1, 5 do
        local tInfo = TABS[i]
        local btn = CreateFrame("Button", nil, tabsBar)
        btn:SetWidth(tabWidth)
        btn:SetHeight(18)
        btn:SetPoint("LEFT", tabsBar, "LEFT", 3 + (i - 1) * (tabWidth + 3), 0)
        B:Backdrop(btn, 0.85)

        local fs = B:Font(btn, 9, "CENTER")
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetText(tInfo.label)
        btn.fs = fs
        btn.info = tInfo

        btn:EnableMouse(true)
        btn:SetScript("OnClick", function()
            B.db.meterMode = this.info.key
            B.meterDrilldown = nil
            B.meterScrollOffset = 0
            B:Tick()
        end)

        tabButtons[i] = btn
    end
    f.tabButtons = tabButtons

    ---------------------------------------------------------------------------
    --  3. Subheader: Column Labels (Height 14px)
    ---------------------------------------------------------------------------
    local cols = CreateFrame("Frame", nil, f)
    cols:SetHeight(14)
    cols:SetPoint("TOPLEFT", tabsBar, "BOTTOMLEFT", 0, -2)
    cols:SetPoint("TOPRIGHT", tabsBar, "BOTTOMRIGHT", 0, -2)
    f.colsHeader = cols

    local colName = B:Font(cols, 8, "LEFT")
    colName:SetPoint("LEFT", cols, "LEFT", 6, 0)
    colName:SetTextColor(0.55, 0.50, 0.40)
    colName:SetText("#  Ability / Source")
    cols.colName = colName

    local colDps = B:Font(cols, 8, "RIGHT")
    colDps:SetPoint("RIGHT", cols, "RIGHT", -7, 0)
    colDps:SetWidth(46)
    colDps:SetTextColor(0.55, 0.50, 0.40)
    colDps:SetText("DPS")
    cols.colDps = colDps

    local colShare = B:Font(cols, 8, "RIGHT")
    colShare:SetPoint("RIGHT", colDps, "LEFT", -4, 0)
    colShare:SetWidth(36)
    colShare:SetTextColor(0.55, 0.50, 0.40)
    colShare:SetText("%")
    cols.colShare = colShare

    local colAmount = B:Font(cols, 8, "RIGHT")
    colAmount:SetPoint("RIGHT", colShare, "LEFT", -6, 0)
    colAmount:SetWidth(56)
    colAmount:SetTextColor(0.55, 0.50, 0.40)
    colAmount:SetText("Damage")
    cols.colAmount = colAmount

    ---------------------------------------------------------------------------
    --  4. Meter Rows (8 Slots)
    ---------------------------------------------------------------------------
    local rows = {}
    for i = 1, MAX_METER_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetWidth(METER_WIDTH - 8)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 4, -(i - 1) * (ROW_HEIGHT + ROW_GAP) - 2)

        -- Rank number on left
        local rankFs = B:Font(r, 9, "LEFT")
        rankFs:SetPoint("LEFT", r, "LEFT", 2, 0)
        rankFs:SetWidth(14)
        rankFs:SetTextColor(0.60, 0.60, 0.60)
        r.rankFs = rankFs

        -- Square Icon frame
        local iconFrame = CreateFrame("Frame", nil, r)
        iconFrame:SetWidth(16)
        iconFrame:SetHeight(16)
        iconFrame:SetPoint("LEFT", rankFs, "RIGHT", 2, 0)
        B:Backdrop(iconFrame, 1.0)
        r.iconFrame = iconFrame

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon = icon

        -- Status bar behind texts
        local bar = B:Bar(r, nil)
        bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
        bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        bar:EnableMouse(false)
        r.bar = bar

        -- Right columns: Rate (DPS/HPS), Share (%), Amount
        local textRate = B:Font(bar, 9, "RIGHT")
        textRate:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        textRate:SetWidth(46)
        textRate:SetHeight(14)
        textRate:SetTextColor(0.70, 0.92, 0.68)
        r.textRate = textRate

        local textShare = B:Font(bar, 9, "RIGHT")
        textShare:SetPoint("RIGHT", textRate, "LEFT", -4, 0)
        textShare:SetWidth(36)
        textShare:SetHeight(14)
        textShare:SetTextColor(0.95, 0.86, 0.62)
        r.textShare = textShare

        local textAmount = B:Font(bar, 9, "RIGHT")
        textAmount:SetPoint("RIGHT", textShare, "LEFT", -6, 0)
        textAmount:SetWidth(56)
        textAmount:SetHeight(14)
        textAmount:SetTextColor(1, 1, 1)
        r.textAmount = textAmount

        -- Ability / Player Name text (clamped so it never overlaps numbers)
        local nameFs = B:Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetPoint("RIGHT", textAmount, "LEFT", -22, 0)
        nameFs:SetHeight(14)
        nameFs:SetTextColor(0.95, 0.95, 0.95)
        r.nameFs = nameFs

        -- Optional Top Spell Badge for Party mode
        local topBtn = CreateFrame("Frame", nil, bar)
        topBtn:SetWidth(14)
        topBtn:SetHeight(14)
        topBtn:SetPoint("RIGHT", textAmount, "LEFT", -4, 0)
        B:Backdrop(topBtn, 0.90)
        B:Border(topBtn, 0.40, 0.40, 0.40, 1)

        local topIcon = topBtn:CreateTexture(nil, "ARTWORK")
        topIcon:SetPoint("TOPLEFT", topBtn, "TOPLEFT", 1, -1)
        topIcon:SetPoint("BOTTOMRIGHT", topBtn, "BOTTOMRIGHT", -1, 1)
        topIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        topBtn.icon = topIcon
        topBtn:Hide()
        r.topBtn = topBtn

        -- Hover highlight
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        B:Solid(hl, 1, 1, 1, 0.12)
        hl:SetAllPoints(r)

        r:EnableMouse(true)
        if r.RegisterForClicks then
            r:RegisterForClicks("LeftButtonUp")
        end

        r:SetScript("OnClick", function()
            local d = this.data
            if not d then return end
            local curMode = B.db.meterMode or "damage"
            if curMode == "party" and not B.meterDrilldown then
                if d.name and d.name ~= "" then
                    B.meterDrilldown = d.name
                    B.meterScrollOffset = 0
                    B:Tick()
                end
            end
        end)

        r:SetScript("OnEnter", function()
            local d = this.data
            if not d then return end
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(d.name or "Ability", 1, 1, 1)

            if this.valStr then
                GameTooltip:AddLine(this.valStr, 0.85, 0.85, 0.85)
            end

            if d.share then
                GameTooltip:AddLine(string.format("Share: %.1f%%", d.share), 0.95, 0.86, 0.62)
            end

            if d.dps and d.dps > 0 then
                GameTooltip:AddLine(string.format("DPS: %s", B:Short(d.dps)), 0.70, 0.92, 0.68)
            end

            if d.procDmg and d.procDmg > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Proc & Item Breakdown:", 0.30, 0.75, 1.00)
                if d.baseDmg and d.baseDmg > 0 then
                    local basePct = (d.dmg > 0) and (d.baseDmg / d.dmg * 100) or 0
                    GameTooltip:AddDoubleLine("  Direct Casts:", string.format("%s (%.1f%%)", B:Short(d.baseDmg), basePct), 0.85, 0.85, 0.85, 1, 1, 1)
                end
                local totalProcPct = (d.dmg > 0) and (d.procDmg / d.dmg * 100) or 0
                GameTooltip:AddDoubleLine("  Total Procs:", string.format("%s (%.1f%%)", B:Short(d.procDmg), totalProcPct), 0.30, 0.75, 1.00, 0.30, 0.75, 1.00)
                if d.procs and table.getn(d.procs) > 0 then
                    for pIdx = 1, table.getn(d.procs) do
                        local pInfo = d.procs[pIdx]
                        if pInfo and pInfo.name and pInfo.dmg then
                            GameTooltip:AddDoubleLine(string.format("    - %s:", pInfo.name), B:Short(pInfo.dmg), 0.70, 0.70, 0.70, 0.90, 0.90, 0.90)
                        end
                    end
                end
            end

            if d.hits and d.hits > 0 then
                local crits = d.crits or 0
                local critPct = (d.hits > 0) and math.floor(crits / d.hits * 100 + 0.5) or 0
                GameTooltip:AddLine(string.format("%d hits, %d crits (%d%% crit)", d.hits, crits, critPct), 1.0, 0.82, 0.55)
            end

            local crit = B.biggestCrits and B.biggestCrits[d.name]
            if not crit and B.biggestCrits then
                for k, v in pairs(B.biggestCrits) do
                    if string.lower(k) == string.lower(d.name) then
                        crit = v
                        break
                    end
                end
            end
            if d.procs and table.getn(d.procs) > 0 and B.biggestCrits then
                for pIdx = 1, table.getn(d.procs) do
                    local pInfo = d.procs[pIdx]
                    if pInfo and pInfo.name then
                        local pFull = pInfo.name .. ": " .. d.name
                        local pCrit = B.biggestCrits[pFull]
                        if pCrit and (not crit or pCrit > crit) then
                            crit = pCrit
                        end
                    end
                end
            end
            if crit and crit > 0 then
                GameTooltip:AddLine(string.format("Biggest Crit: %s", B:Short(crit)), 1.0, 0.82, 0.10)
            end

            if d.top and d.top ~= "" then
                GameTooltip:AddLine(string.format("Top Ability: %s (%s DPS)", d.top, B:Short(d.topdps or 0)), 0.75, 0.85, 1.0)
            end

            if (B.db.meterMode or "damage") == "party" and not B.meterDrilldown then
                GameTooltip:AddLine("Click to view player's abilities & spells", 0.30, 0.75, 1.00)
            end

            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    -- Mouse Wheel scrolling for rows
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function()
        local delta = arg1
        if delta > 0 then
            if B.meterScrollOffset > 0 then
                B.meterScrollOffset = B.meterScrollOffset - 1
                B:Tick()
            end
        elseif delta < 0 then
            local maxScroll = (f.maxEntries or 0) - MAX_METER_ROWS
            if maxScroll > 0 and B.meterScrollOffset < maxScroll then
                B.meterScrollOffset = B.meterScrollOffset + 1
                B:Tick()
            end
        end
    end)

    -- Mover Registration
    B:RegisterMover(f, "meter", "Damage Meter", "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 34)
end

-------------------------------------------------------------------------------
--  Data Extraction & Update Logic
-------------------------------------------------------------------------------
function mod:Update(state)
    local f = self.frame
    if not f then return end

    if B.meterCollapsed then return end

    -- Time calculation
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

    local rawMode = B.db.meterMode or "damage"
    local mode = rawMode
    if mode == "aoe" then mode = "damage" end
    if mode ~= "damage" and mode ~= "healing" and mode ~= "boss" and mode ~= "taken" and mode ~= "party" then
        mode = "damage"
        B.db.meterMode = "damage"
    end

    ---------------------------------------------------------------------------
    --  Update Tab Bar
    ---------------------------------------------------------------------------
    local tb = f.tabsBar
    if B.meterDrilldown then
        tb.backBtn:Show()
        tb.drillLabel:SetText(string.format("%s's Spells", B.meterDrilldown))
        tb.drillLabel:Show()
        for i = 1, 5 do f.tabButtons[i]:Hide() end
    else
        tb.backBtn:Hide()
        tb.drillLabel:Hide()
        for i = 1, 5 do
            local btn = f.tabButtons[i]
            btn:Show()
            local isActive = (btn.info.key == mode)
            if isActive then
                btn.fs:SetTextColor(btn.info.r, btn.info.g, btn.info.b)
                B:Border(btn, btn.info.r, btn.info.g, btn.info.b, 1)
                btn:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
            else
                btn.fs:SetTextColor(0.60, 0.55, 0.50)
                B:Border(btn, 0.25, 0.22, 0.20, 1)
                btn:SetBackdropColor(0.06, 0.05, 0.04, 0.85)
            end
        end
    end

    -- Update Merge Procs button style
    if f.header and f.header.mergeBtn then
        local mBtn = f.header.mergeBtn
        if B.db.mergeItemProcs then
            B:Border(mBtn, 0.30, 0.75, 1.00, 1)
            mBtn.fs:SetTextColor(0.30, 0.75, 1.00)
        else
            B:Border(mBtn, 0.35, 0.35, 0.35, 1)
            mBtn.fs:SetTextColor(0.60, 0.60, 0.60)
        end
    end

    ---------------------------------------------------------------------------
    --  Pull Active Data
    ---------------------------------------------------------------------------
    local list = {}
    local totalAmt = 0
    local totalRate = 0
    local rateLabel = "DPS"
    local amtColLabel = "Damage"
    local maxVal = 0
    local hdrTitle = "DAMAGE"
    local themeR, themeG, themeB = 1.0, 0.75, 0.20

    if B.meterDrilldown then
        -- DRILLDOWN VIEW: Spells of selected party member
        local pName = B.meterDrilldown
        local pKey = string.lower(pName)
        hdrTitle = string.upper(pName)
        amtColLabel = "Damage"
        rateLabel = "DPS"
        themeR, themeG, themeB = 0.30, 0.75, 1.00

        local tracked = B.meterPartySpells[pKey] or {}
        local foundMap = {}

        for sName, sData in pairs(tracked) do
            local d = sData.dmg or 0
            if d > 0 then
                table.insert(list, {
                    name = sData.name or sName,
                    dmg = d,
                    dps = math.floor(d / runSec),
                    hits = sData.hits,
                    crits = sData.crits,
                })
                totalAmt = totalAmt + d
                foundMap[string.lower(sName)] = true
                if d > maxVal then maxVal = d end
            end
        end

        -- Check if server reported a top ability not yet in tracked combat log
        local partyData = state.party or {}
        for i = 1, table.getn(partyData) do
            local p = partyData[i]
            if p and p.name and string.lower(p.name) == pKey then
                if p.top and p.top ~= "" and not foundMap[string.lower(p.top)] then
                    local topDps = tonumber(p.topdps) or 0
                    local estDmg = topDps * runSec
                    table.insert(list, {
                        name = p.top,
                        dmg = estDmg,
                        dps = topDps,
                        hits = 0,
                        crits = 0,
                    })
                    totalAmt = totalAmt + estDmg
                    if estDmg > maxVal then maxVal = estDmg end
                end
                break
            end
        end

        totalRate = math.floor(totalAmt / runSec)

    elseif mode == "party" then
        -- MULTIPLAYER PARTY VIEW
        hdrTitle = "PARTY DAMAGE"
        amtColLabel = "Damage"
        rateLabel = "DPS"
        themeR, themeG, themeB = 0.30, 0.75, 1.00

        local rawParty = (type(AZS_GetPartyMeter) == "function" and AZS_GetPartyMeter()) or state.party or {}
        if type(rawParty) ~= "table" then rawParty = {} end

        for i = 1, table.getn(rawParty) do
            local item = rawParty[i]
            if type(item) == "table" and item.name then
                local rawD = tonumber(item.dmg) or 0
                local pName = item.name
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.party and B.meterOffsets.party[pName]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(list, {
                        name = pName,
                        class = item.class,
                        dmg = d,
                        dps = tonumber(item.dps) or math.floor(d / runSec),
                        top = item.top,
                        topdps = tonumber(item.topdps) or 0,
                    })
                    totalAmt = totalAmt + d
                    if d > maxVal then maxVal = d end
                end
            end
        end
        totalRate = math.floor(totalAmt / runSec)

    elseif mode == "healing" then
        -- HEALING VIEW
        hdrTitle = "HEALING DONE"
        amtColLabel = "Healing"
        rateLabel = "HPS"
        themeR, themeG, themeB = 0.25, 0.90, 0.45

        local rawHeal = (type(AZS_GetHealing) == "function" and AZS_GetHealing()) or state.healing or {}
        if type(rawHeal) ~= "table" then rawHeal = {} end

        for i = 1, table.getn(rawHeal) do
            local item = rawHeal[i]
            if type(item) == "table" then
                local rawH = tonumber(item.healing or item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.healing and B.meterOffsets.healing[sName]) or 0
                local hVal = rawH - base
                if hVal < 0 then hVal = 0 end
                if hVal > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(list, {
                        name = sName,
                        dmg = hVal,
                        dps = math.floor(hVal / runSec),
                    })
                    totalAmt = totalAmt + hVal
                    if hVal > maxVal then maxVal = hVal end
                end
            end
        end
        totalRate = math.floor(totalAmt / runSec)

    elseif mode == "boss" then
        -- BOSS DAMAGE VIEW
        hdrTitle = "BOSS DAMAGE"
        amtColLabel = "Damage"
        rateLabel = "DPS"
        themeR, themeG, themeB = 1.00, 0.35, 0.15

        local rawBoss = (type(AZS_GetBossMeter) == "function" and AZS_GetBossMeter()) or state.bossMeter or {}
        if type(rawBoss) ~= "table" then rawBoss = {} end

        local mergedMap = {}
        for i = 1, table.getn(rawBoss) do
            local item = rawBoss[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.boss and B.meterOffsets.boss[sName]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    totalAmt = totalAmt + d
                    if B.db.mergeItemProcs then
                        local _, _, itemPrefix, spellSuffix = string.find(sName, "^(.-): (.+)$")
                        if itemPrefix and spellSuffix and itemPrefix ~= "" and spellSuffix ~= "" then
                            local k = string.lower(spellSuffix)
                            local existing = mergedMap[k]
                            if existing then
                                existing.dmg = existing.dmg + d
                                existing.procDmg = (existing.procDmg or 0) + d
                                if not existing.procs then existing.procs = {} end
                                table.insert(existing.procs, { name = itemPrefix, dmg = d })
                            else
                                local entry = {
                                    name = spellSuffix,
                                    dmg = d,
                                    baseDmg = 0,
                                    procDmg = d,
                                    procs = { { name = itemPrefix, dmg = d } },
                                }
                                mergedMap[k] = entry
                                table.insert(list, entry)
                            end
                        else
                            local k = string.lower(sName)
                            local existing = mergedMap[k]
                            if existing then
                                existing.dmg = existing.dmg + d
                                existing.baseDmg = (existing.baseDmg or 0) + d
                            else
                                local entry = {
                                    name = sName,
                                    dmg = d,
                                    baseDmg = d,
                                    procDmg = 0,
                                    procs = {},
                                }
                                mergedMap[k] = entry
                                table.insert(list, entry)
                            end
                        end
                    else
                        table.insert(list, {
                            name = sName,
                            dmg = d,
                            dps = math.floor(d / runSec),
                        })
                    end
                end
            end
        end
        if B.db.mergeItemProcs then
            for i = 1, table.getn(list) do
                list[i].dps = math.floor((list[i].dmg or 0) / runSec)
            end
        end
        totalRate = math.floor(totalAmt / runSec)

    elseif mode == "taken" then
        -- DAMAGE TAKEN VIEW
        hdrTitle = "DAMAGE TAKEN"
        amtColLabel = "Taken"
        rateLabel = "DPS"
        themeR, themeG, themeB = 0.90, 0.25, 0.25

        local rawTaken = state.taken or {}
        if type(rawTaken) ~= "table" then rawTaken = {} end

        for i = 1, table.getn(rawTaken) do
            local item = rawTaken[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local src = item.source or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.taken and B.meterOffsets.taken[src]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    table.insert(list, {
                        name = src,
                        dmg = d,
                        dps = math.floor(d / runSec),
                    })
                    totalAmt = totalAmt + d
                    if d > maxVal then maxVal = d end
                end
            end
        end
        totalRate = math.floor(totalAmt / runSec)

    else
        -- DAMAGE DONE (Primary)
        if rawMode == "aoe" then
            hdrTitle = "AOE DAMAGE"
        else
            hdrTitle = "DAMAGE DONE"
        end
        amtColLabel = "Damage"
        rateLabel = "DPS"
        themeR, themeG, themeB = 1.00, 0.75, 0.20

        local rawMeter = (type(AZS_GetMeter) == "function" and AZS_GetMeter()) or state.meter or {}
        if type(rawMeter) ~= "table" then rawMeter = {} end

        local mergedMap = {}
        for i = 1, table.getn(rawMeter) do
            local item = rawMeter[i]
            if type(item) == "table" then
                local rawD = tonumber(item.dmg) or 0
                local sName = item.name or "Unknown"
                local base = (B.meterOffsets and B.meterOffsets.active and B.meterOffsets.done and B.meterOffsets.done[sName]) or 0
                local d = rawD - base
                if d < 0 then d = 0 end
                if d > 0 or not (B.meterOffsets and B.meterOffsets.active) then
                    totalAmt = totalAmt + d
                    if B.db.mergeItemProcs then
                        local _, _, itemPrefix, spellSuffix = string.find(sName, "^(.-): (.+)$")
                        if itemPrefix and spellSuffix and itemPrefix ~= "" and spellSuffix ~= "" then
                            local k = string.lower(spellSuffix)
                            local existing = mergedMap[k]
                            if existing then
                                existing.dmg = existing.dmg + d
                                existing.procDmg = (existing.procDmg or 0) + d
                                if not existing.procs then existing.procs = {} end
                                table.insert(existing.procs, { name = itemPrefix, dmg = d })
                            else
                                local entry = {
                                    name = spellSuffix,
                                    dmg = d,
                                    baseDmg = 0,
                                    procDmg = d,
                                    procs = { { name = itemPrefix, dmg = d } },
                                }
                                mergedMap[k] = entry
                                table.insert(list, entry)
                            end
                        else
                            local k = string.lower(sName)
                            local existing = mergedMap[k]
                            if existing then
                                existing.dmg = existing.dmg + d
                                existing.baseDmg = (existing.baseDmg or 0) + d
                            else
                                local entry = {
                                    name = sName,
                                    dmg = d,
                                    baseDmg = d,
                                    procDmg = 0,
                                    procs = {},
                                }
                                mergedMap[k] = entry
                                table.insert(list, entry)
                            end
                        end
                    else
                        table.insert(list, {
                            name = sName,
                            dmg = d,
                            dps = math.floor(d / runSec),
                        })
                    end
                end
            end
        end
        if B.db.mergeItemProcs then
            for i = 1, table.getn(list) do
                list[i].dps = math.floor((list[i].dmg or 0) / runSec)
            end
        end
        totalRate = math.floor(totalAmt / runSec)
    end

    -- Sort descending by amount
    table.sort(list, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)

    local maxVal = (list[1] and list[1].dmg) or 0

    local totalEntries = table.getn(list)
    f.maxEntries = totalEntries
    if B.meterScrollOffset > totalEntries - MAX_METER_ROWS then
        B.meterScrollOffset = math.max(0, totalEntries - MAX_METER_ROWS)
    end

    ---------------------------------------------------------------------------
    --  Update Header Texts & Column Labels
    ---------------------------------------------------------------------------
    if B.meterOffsets and B.meterOffsets.active then
        f.header.title:SetText(hdrTitle .. " (SESSION)")
    else
        f.header.title:SetText(hdrTitle)
    end
    f.header.title:SetTextColor(themeR, themeG, themeB)

    f.header.value:SetText(B:Short(totalAmt))
    f.header.rate:SetText(string.format("%s %s", B:Short(totalRate), rateLabel))

    f.colsHeader.colAmount:SetText(amtColLabel)
    f.colsHeader.colDps:SetText(rateLabel)
    if mode == "party" and not B.meterDrilldown then
        f.colsHeader.colName:SetText("#  Player")
    else
        f.colsHeader.colName:SetText("#  Ability / Source")
    end

    ---------------------------------------------------------------------------
    --  Populate Rows
    ---------------------------------------------------------------------------
    local startIdx = B.meterScrollOffset
    local shownRows = 0

    for i = 1, MAX_METER_ROWS do
        local r = f.rows[i]
        local dataIdx = startIdx + i

        if dataIdx <= totalEntries then
            local item = list[dataIdx]
            local d = item.dmg or 0
            local rate = item.dps or math.floor(d / runSec)
            local share = (totalAmt > 0) and (d / totalAmt) or 0
            local sharePct = share * 100
            item.share = sharePct

            local fill = (maxVal > 0) and (d / maxVal) or 0
            if d > 0 and fill < 0.02 then fill = 0.02 end
            if fill > 1 then fill = 1 end

            r.bar:SetValue(fill)
            r.data = item

            -- Status bar color
            if mode == "party" and not B.meterDrilldown then
                local cCol = B:ResolveClassColor(item.class) or { r = 0.30, g = 0.75, b = 1.00 }
                B:SetBarColor(r.bar, cCol.r, cCol.g, cCol.b)
            elseif dataIdx == 1 then
                B:SetBarColor(r.bar, themeR, themeG, themeB)
            else
                B:SetBarColor(r.bar, themeR * 0.75, themeG * 0.75, themeB * 0.75)
            end

            -- Rank
            r.rankFs:SetText(tostring(dataIdx))

            -- Icon
            if mode == "party" and not B.meterDrilldown then
                local uCls = item.class and string.upper(item.class)
                if uCls and CLASS_COORDS[uCls] then
                    local c = CLASS_COORDS[uCls]
                    r.icon:SetTexture(CLASS_SHEET)
                    r.icon:SetTexCoord(c[1], c[2], c[3], c[4])
                else
                    r.icon:SetTexture(B:GetAbilityIcon(item.name))
                    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
            else
                r.icon:SetTexture(B:GetAbilityIcon(item.name))
                r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            -- Name
            r.nameFs:SetText(item.name or "Unknown")

            -- Party Top Spell Badge
            if mode == "party" and not B.meterDrilldown and item.top and item.top ~= "" then
                if r.topBtn then
                    local topTex = B:GetAbilityIcon(item.top)
                    r.topBtn.icon:SetTexture(topTex)
                    r.topBtn:Show()
                end
            else
                if r.topBtn then
                    r.topBtn:Hide()
                end
            end

            -- Amount, Share, Rate
            r.textAmount:SetText(B:Short(d))
            if sharePct >= 9.95 then
                r.textShare:SetText(string.format("%d%%", math.floor(sharePct + 0.5)))
            elseif sharePct >= 0.05 then
                r.textShare:SetText(string.format("%.1f%%", sharePct))
            else
                r.textShare:SetText("0%")
            end
            r.textRate:SetText(B:Short(rate))

            r.valStr = string.format("%s: %s (%s %s)", amtColLabel, B:Short(d), B:Short(rate), rateLabel)

            r:Show()
            shownRows = shownRows + 1
        else
            r.data = nil
            r:Hide()
        end
    end

    local finalH = 60 + shownRows * (ROW_HEIGHT + ROW_GAP) + 6
    if finalH < 62 then finalH = 62 end
    f:SetHeight(finalH)
end

B:RegisterModule("meter", mod)
