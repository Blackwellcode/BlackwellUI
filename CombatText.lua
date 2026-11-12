-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  CombatText.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Scrolling Battle Text Engine (MSBT Style) for WoW 1.12.1.
--  Features:
--    - 4 Draggable Zones: Incoming (Left), Outgoing (Right), Static (Top), Alerts (Bottom)
--    - Multi-Hit & DoT Batching ([2 Hits])
--    - School color-coded damage numbers with ability icons
--    - Auras gained/faded (Golden buffs, Teal debuffs)
--    - Cooldown Ready & Reactive Ability Alerts (Execute!, Overpower!, Revenge!)
--  Lua 5.0 / WoW 1.12.1 strict: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Combat text"
mod.alwaysActive = false
mod.hint = "Replaces Blizzard's floating numbers. Turning it off restores them at once."

mod.options = {
    { type = "section", label = "Show" },
    { type = "toggle", key = "showOutgoing", label = "Outgoing damage", default = true },
    { type = "toggle", key = "showIncoming", label = "Incoming damage", default = true },
    { type = "toggle", key = "showMisses", label = "Dodges, parries and misses", default = true, depends = "showIncoming" },
    { type = "toggle", key = "showSource", label = "Attacker name", default = true, depends = "showIncoming" },
    { type = "toggle", key = "showAuras", label = "Buffs and debuffs", default = true },
    { type = "toggle", db = "sctAlerts", label = "Ability alerts",
      hint = "Ready, Overpower and Execute prompts. They do not check your class.", default = false },
    { type = "section", label = "Text" },
    { type = "range", key = "outFontSize", label = "Outgoing font size", min = 10, max = 28, step = 1, default = 14, format = "%d px" },
    { type = "range", key = "incFontSize", label = "Incoming font size", min = 10, max = 28, step = 1, default = 13, format = "%d px" },
    { type = "range", key = "auraFontSize", label = "Aura font size", min = 10, max = 24, step = 1, default = 13, format = "%d px" },
    { type = "range", key = "alertFontSize", label = "Alert font size", min = 12, max = 30, step = 1, default = 16, format = "%d px" },
    { type = "range", key = "critScale", label = "Critical hit size", min = 1, max = 2, step = 0.05, default = 1.2, format = "%.2fx" },
    { type = "toggle", key = "colorBySchool", label = "Colour by spell school", default = true },
    { type = "toggle", key = "showIcons", label = "Show icons", default = true },
    { type = "section", label = "Motion" },
    { type = "range", key = "duration", label = "Duration", min = 0.8, max = 4, step = 0.1, default = 1.8, format = "%.1f s" },
    { type = "range", key = "scrollHeight", label = "Scroll distance", min = 40, max = 300, step = 10, default = 130, format = "%d px" },
    { type = "range", key = "arcWidth", label = "Arc width", min = 0, max = 150, step = 5, default = 60, format = "%d px" },
    { type = "toggle", key = "mergeHits", label = "Merge rapid hits", default = true },
    { type = "range", key = "mergeWindow", label = "Merge window", min = 0.1, max = 1, step = 0.05, default = 0.35, format = "%.2f s", depends = "mergeHits" },
}

local function Opt(key, default)
    return B:ModOpt("combattext", key, default)
end

local function CritSize(base, isCrit)
    if not isCrit then return base end
    return math.floor(base * Opt("critScale", 1.2) + 0.5)
end

-- Icons and their frame follow "Show icons"; the black frame is sharp-style only.
local function ShowIcon(f, tex)
    if not Opt("showIcons", true) then
        f.icon:Hide()
        f.iconBorder:Hide()
        f.text:ClearAllPoints()
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        return
    end
    f.icon:SetTexture(tex)
    f.icon:Show()
    if B:IsRound() then
        f.iconBorder:Hide()
    else
        f.iconBorder:Show()
    end
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.iconBorder, "RIGHT", 4, 0)
end

local SCHOOL_HEX = {
    ["physical"] = "|cffffffff",
    ["holy"]     = "|cffffe533",
    ["fire"]     = "|cffff730d",
    ["nature"]   = "|cff4df24d",
    ["frost"]    = "|cff59bfff",
    ["shadow"]   = "|cffd940d9",
    ["arcane"]   = "|cffbf73ff",
    ["heal"]     = "|cff26f259",
}

local SCHOOL_MAP = {
    ["physical"] = "physical", ["physisch"] = "physical", ["fisico"] = "physical",
    ["holy"]     = "holy",     ["heilig"]   = "holy",     ["sagrado"] = "holy",
    ["fire"]     = "fire",     ["feuer"]    = "fire",     ["fuego"]   = "fire",
    ["nature"]   = "nature",   ["natur"]    = "nature",   ["naturaleza"] = "nature",
    ["frost"]    = "frost",                               ["escarcha"] = "frost",
    ["shadow"]   = "shadow",   ["schatten"] = "shadow",   ["sombras"] = "shadow", ["sombra"] = "shadow",
    ["arcane"]   = "arcane",   ["arkan"]    = "arcane",   ["arcano"]  = "arcane",
}

function mod:GetSchoolHex(school)
    if not school or school == "" then
        return "|cffffffff"
    end
    local low = string.lower(school)
    local canon = SCHOOL_MAP[low] or low
    return SCHOOL_HEX[canon] or "|cffffffff"
end

-- Frame Pools
local poolIncoming = {}
local poolOutgoing = {}
local poolStatic = {}
local poolAlerts = {}

local anchorIncoming = nil
local anchorOutgoing = nil
local anchorStatic = nil
local anchorAlerts = nil

local function CreatePoolFrame(parent, frameName, isAlert)
    local f = CreateFrame("Frame", frameName, parent or UIParent)
    f:SetFrameStrata("HIGH")
    f:SetWidth(200)
    f:SetHeight(20)
    f:Hide()

    -- 16x16 icon (or 18x18 for alert); sharp style: 1px black border,
    -- round style: the borderless icon (the border texture stays as spacer).
    local iconSize = isAlert and 18 or 16
    local iconBorder = f:CreateTexture(nil, "BACKGROUND")
    iconBorder:SetWidth(iconSize + 2)
    iconBorder:SetHeight(iconSize + 2)
    iconBorder:SetPoint("LEFT", f, "LEFT", 0, 0)
    B:Solid(iconBorder, 0, 0, 0, 1)
    if B:IsRound() then iconBorder:Hide() end
    f.iconBorder = iconBorder

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)
    icon:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon

    local text = B:Font(f, isAlert and 16 or 14, "LEFT")
    text:SetPoint("LEFT", iconBorder, "RIGHT", 4, 0)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    f.text = text

    f.inUse = false
    f.elapsed = 0
    f.duration = 1.8
    f.startX = 0
    f.startY = 0
    f.spawnTime = 0
    f.abilityKey = nil
    f.amount = 0
    f.hits = 1
    f.isCrit = false
    f.school = nil

    return f
end

local function GetFreeFrame(pool)
    local n = table.getn(pool)
    for i = 1, n do
        local f = pool[i]
        if not f.inUse then
            return f
        end
    end
    -- Fallback: steal oldest frame
    local oldest = pool[1]
    local oldestTime = oldest.spawnTime or 0
    for i = 2, n do
        local f = pool[i]
        if (f.spawnTime or 0) < oldestTime then
            oldest = f
            oldestTime = f.spawnTime or 0
        end
    end
    return oldest
end

-- Public API
function mod:AddOutgoing(spellName, amount, isCrit, school)
    if not B:IsEnabled("combattext") or not Opt("showOutgoing", true) then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    spellName = spellName or "Physical"

    local now = (type(GetTime) == "function" and GetTime()) or 0

    -- Check for Multi-Hit / Batching within the merge window (0.35s by default)
    local n = table.getn(poolOutgoing)
    local window = Opt("mergeWindow", 0.35)
    local merge = Opt("mergeHits", true)
    local bySchool = Opt("colorBySchool", true)
    for i = 1, n do
        local f = poolOutgoing[i]
        if merge and f.inUse and f.abilityKey == spellName and (now - f.spawnTime) < window then
            f.amount = f.amount + amount
            f.hits = f.hits + 1
            f.isCrit = f.isCrit or isCrit
            local cHex = bySchool and mod:GetSchoolHex(school or f.school) or "|cffffffff"
            f.text:SetText(cHex .. tostring(f.amount) .. "|r |cffffff00" .. string.format(L["[%d Hits]"], math.floor(f.hits)) .. "|r")
            f.elapsed = math.max(0, f.elapsed - 0.25)
            return
        end
    end

    local f = GetFreeFrame(poolOutgoing)
    f.inUse = true
    f.abilityKey = spellName
    f.amount = amount
    f.hits = 1
    f.isCrit = isCrit
    f.school = school
    f.spawnTime = now
    f.elapsed = 0
    f.duration = Opt("duration", 1.8)
    f.anchor = anchorOutgoing

    ShowIcon(f, B:GetAbilityIcon(spellName))

    local colorHex = bySchool and mod:GetSchoolHex(school) or "|cffffffff"
    f.text:SetText(colorHex .. tostring(amount) .. "|r")

    local fontSize = CritSize(Opt("outFontSize", 14), isCrit)
    f.text:SetFont(B:GetBoldFontPath(), fontSize, "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorOutgoing, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddIncoming(sourceName, amount, isCrit, missType)
    if not B:IsEnabled("combattext") or not Opt("showIncoming", true) then return end
    if missType and not Opt("showMisses", true) then return end
    local f = GetFreeFrame(poolIncoming)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = Opt("duration", 1.8)
    f.anchor = anchorIncoming
    f.icon:Hide()
    f.iconBorder:Hide()
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.iconBorder, "RIGHT", 4, 0)

    sourceName = sourceName or L["Enemy"]
    local prefix = ""
    if Opt("showSource", true) then
        prefix = "|cffff2020(" .. sourceName .. ")|r "
    end
    if missType then
        f.text:SetText(prefix .. "|cff00e5ff" .. L[string.upper(missType)] .. "|r")
    else
        amount = tonumber(amount) or 0
        f.text:SetText(prefix .. "|cffffffff-" .. tostring(amount) .. "|r")
    end

    local fontSize = CritSize(Opt("incFontSize", 13), isCrit)
    f.text:SetFont(B:GetBoldFontPath(), fontSize, "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorIncoming, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddAura(name, isDebuff, isFade)
    if not B:IsEnabled("combattext") or not Opt("showAuras", true) then return end
    local shownName = name or L["Aura"]
    name = name or "Aura"
    local f = GetFreeFrame(poolStatic)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = Opt("duration", 1.8) + 0.2
    f.anchor = anchorStatic

    ShowIcon(f, B:GetAbilityIcon(name))

    if isFade then
        f.text:SetText("|cffaaaaaa" .. string.format(L["[%s Faded]"], shownName) .. "|r")
    elseif isDebuff then
        -- Cyan / Teal
        f.text:SetText("|cff00e5ff[" .. shownName .. "]|r")
    else
        -- Golden Yellow
        f.text:SetText("|cffffd100[" .. shownName .. "]|r")
    end
    f.text:SetFont(B:GetBoldFontPath(), Opt("auraFontSize", 13), "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorStatic, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddAlert(spellName, alertType)
    if not B:IsEnabled("combattext") or (B.db and B.db.sctAlerts == false) then return end
    local shownName = (spellName and string.upper(spellName)) or L["ABILITY"]
    spellName = spellName or "Ability"
    local f = GetFreeFrame(poolAlerts)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = Opt("duration", 1.8) + 0.4
    f.anchor = anchorAlerts

    ShowIcon(f, B:GetAbilityIcon(spellName))

    if alertType == "READY" then
        -- Red spell name + White READY NOW!
        f.text:SetText("|cffff2020" .. shownName .. "|r |cffffffff" .. L["READY NOW!"] .. "|r")
    elseif alertType == "EXECUTE" then
        f.text:SetText("|cffff2020" .. L["EXECUTE!"] .. "|r")
    elseif alertType == "OVERPOWER" then
        f.text:SetText("|cffffb800" .. L["OVERPOWER!"] .. "|r")
    elseif alertType == "REVENGE" then
        f.text:SetText("|cff00ff88" .. L["REVENGE!"] .. "|r")
    else
        f.text:SetText("|cffff2020" .. shownName .. "!|r")
    end
    f.text:SetFont(B:GetBoldFontPath(), Opt("alertFontSize", 16), "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorAlerts, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

-------------------------------------------------------------------------------
--  Combat Log Event Parser
-------------------------------------------------------------------------------
local function ParseOutgoingSpellDamage(msg)
    -- English direct hits
    local _, _, spell, target, amount, school = string.find(msg, "^Your (.+) hits (.+) for (%d+)%s*(%a*)")
    if spell and amount then return spell, tonumber(amount), false, school end

    local _, _, spell, target, amount, school = string.find(msg, "^Your (.+) crits (.+) for (%d+)%s*(%a*)")
    if spell and amount then return spell, tonumber(amount), true, school end

    -- German
    local _, _, spell, target, amount, school = string.find(msg, "^Eure? (.+) trifft (.+) f.-r (%d+)%s*(%a*)")
    if spell and amount then return spell, tonumber(amount), false, school end

    local _, _, spell, target, amount, school = string.find(msg, "^Eure? (.+) trifft (.+) kritisch f.-r (%d+)%s*(%a*)")
    if spell and amount then return spell, tonumber(amount), true, school end

    -- Spanish
    local _, _, spell, target, amount, school = string.find(msg, "^Tu (.+) inflige a (.+) (%d+)%s*(%a*)")
    if spell and amount then return spell, tonumber(amount), false, school end

    return nil
end

local function ParseOutgoingPeriodicDamage(msg)
    -- English DoT
    local _, _, target, amount, school, spell = string.find(msg, "^(.+) suffers (%d+)%s*(%a*) .- from your ([^%.]+)")
    if spell and amount then return spell, tonumber(amount), false, school end

    -- German
    local _, _, target, amount, school, spell = string.find(msg, "^(.+) erleidet (%d+)%s*(%a*) .- durch Eure? ([^%.]+)")
    if spell and amount then return spell, tonumber(amount), false, school end

    -- Spanish
    local _, _, target, amount, school, spell = string.find(msg, "^(.+) recibe (%d+)%s*(%a*) .- de tu ([^%.]+)")
    if spell and amount then return spell, tonumber(amount), false, school end

    return nil
end

local function ParseOutgoingMeleeHits(msg)
    local _, _, target, amount = string.find(msg, "^You hit (.+) for (%d+)")
    if amount then return "Melee", tonumber(amount), false, "physical" end

    local _, _, target, amount = string.find(msg, "^You crit (.+) for (%d+)")
    if amount then return "Melee", tonumber(amount), true, "physical" end

    -- German
    local _, _, target, amount = string.find(msg, "^Ihr trefft (.+) f.-r (%d+)")
    if amount then return "Melee", tonumber(amount), false, "physical" end

    local _, _, target, amount = string.find(msg, "^Ihr trefft (.+) kritisch f.-r (%d+)")
    if amount then return "Melee", tonumber(amount), true, "physical" end

    -- Spanish
    local _, _, target, amount = string.find(msg, "^Golpeas a (.+) por (%d+)")
    if amount then return "Melee", tonumber(amount), false, "physical" end

    return nil
end

local function ParseIncomingMelee(msg)
    local _, _, source, amount = string.find(msg, "^(.+) hits you for (%d+)")
    if source and amount then return source, tonumber(amount), false end

    local _, _, source, amount = string.find(msg, "^(.+) crits you for (%d+)")
    if source and amount then return source, tonumber(amount), true end

    -- German
    local _, _, source, amount = string.find(msg, "^(.+) trifft Euch f.-r (%d+)")
    if source and amount then return source, tonumber(amount), false end

    local _, _, source, amount = string.find(msg, "^(.+) trifft Euch kritisch f.-r (%d+)")
    if source and amount then return source, tonumber(amount), true end

    -- Spanish
    local _, _, source, amount = string.find(msg, "^(.+) te inflige (%d+)")
    if source and amount then return source, tonumber(amount), false end

    return nil
end

local function ParseIncomingSpell(msg)
    local _, _, source, spell, amount = string.find(msg, "^(.+)'s (.+) hits you for (%d+)")
    if source and amount then return source, tonumber(amount), false end

    local _, _, source, spell, amount = string.find(msg, "^(.+)'s (.+) crits you for (%d+)")
    if source and amount then return source, tonumber(amount), true end

    local _, _, amount, school, source, spell = string.find(msg, "^You suffer (%d+)%s*(%a*) .- from (.+)'s (.+)")
    if source and amount then return source, tonumber(amount), false end

    return nil
end

local function ParseIncomingMiss(msg)
    local _, _, source = string.find(msg, "^(.+) misses you%.")
    if source then return source, "MISS" end

    local _, _, source = string.find(msg, "^You dodge (.+)'s attack%.")
    if source then return source, "DODGE" end

    local _, _, source = string.find(msg, "^You parry (.+)'s attack%.")
    if source then return source, "PARRY" end

    local _, _, source = string.find(msg, "^You block (.+)'s attack%.")
    if source then return source, "BLOCK" end

    -- German
    local _, _, source = string.find(msg, "^(.+) verfehlt Euch%.")
    if source then return source, "MISS" end

    local _, _, source = string.find(msg, "^Ihr weicht dem Angriff von (.+) aus%.")
    if source then return source, "DODGE" end

    local _, _, source = string.find(msg, "^Ihr pariert den Angriff von (.+)%.")
    if source then return source, "PARRY" end

    local _, _, source = string.find(msg, "^Ihr blockt den Angriff von (.+) ab%.")
    if source then return source, "BLOCK" end

    return nil
end

-------------------------------------------------------------------------------
--  Cooldown & Proc Watcher
-------------------------------------------------------------------------------
local activeCooldowns = {}
local lastCdScan = 0

local function CheckCooldowns()
    if type(GetSpellName) ~= "function" or type(GetSpellCooldown) ~= "function" then return end
    local book = BOOKTYPE_SPELL or "spell"
    local now = (type(GetTime) == "function" and GetTime()) or 0

    local i = 1
    while true do
        local name = GetSpellName(i, book)
        if not name then break end
        local start, duration, enable = GetSpellCooldown(i, book)
        if start and duration and duration > 2.0 then
            -- Spell is on genuine cooldown (>2.0s to avoid GCD triggers)
            activeCooldowns[name] = { start = start, duration = duration }
        elseif activeCooldowns[name] then
            -- Cooldown finished
            local info = activeCooldowns[name]
            if start == 0 or (now >= info.start + info.duration) then
                activeCooldowns[name] = nil
                mod:AddAlert(name, "READY")
            end
        end
        i = i + 1
    end
end

-------------------------------------------------------------------------------
--  Animation Update Loop
-------------------------------------------------------------------------------
local function UpdateArcPool(pool, curveDir, dt)
    local n = table.getn(pool)
    local arcWidth = Opt("arcWidth", 60)
    local rise = Opt("scrollHeight", 130)
    for i = 1, n do
        local f = pool[i]
        if f.inUse then
            f.elapsed = f.elapsed + dt
            local progress = f.elapsed / f.duration
            if progress >= 1.0 then
                f.inUse = false
                f:Hide()
            else
                local alpha = 1.0
                if progress > 0.70 then
                    alpha = (1.0 - progress) / 0.30
                end
                if alpha < 0 then alpha = 0 end
                f:SetAlpha(alpha)

                -- Parabolic arc: curveDir is -1 for Left, +1 for Right
                local curveProgress = math.pow(progress, 0.7)
                local curX = arcWidth * curveDir * curveProgress
                local curY = rise * progress
                f:ClearAllPoints()
                f:SetPoint("CENTER", f.anchor or UIParent, "CENTER", curX, curY)
            end
        end
    end
end

local function UpdateStaticPool(pool, dt)
    local n = table.getn(pool)
    for i = 1, n do
        local f = pool[i]
        if f.inUse then
            f.elapsed = f.elapsed + dt
            local progress = f.elapsed / f.duration
            if progress >= 1.0 then
                f.inUse = false
                f:Hide()
            else
                local alpha = 1.0
                if progress > 0.65 then
                    alpha = (1.0 - progress) / 0.35
                end
                if alpha < 0 then alpha = 0 end
                f:SetAlpha(alpha)

                local curY = 50 * progress
                f:ClearAllPoints()
                f:SetPoint("CENTER", f.anchor or UIParent, "CENTER", 0, curY)
            end
        end
    end
end

local function UpdateAlertsPool(pool, dt)
    local n = table.getn(pool)
    for i = 1, n do
        local f = pool[i]
        if f.inUse then
            f.elapsed = f.elapsed + dt
            local progress = f.elapsed / f.duration
            if progress >= 1.0 then
                f.inUse = false
                f:Hide()
            else
                local alpha = 1.0
                if progress > 0.75 then
                    alpha = (1.0 - progress) / 0.25
                end
                if alpha < 0 then alpha = 0 end
                f:SetAlpha(alpha)

                -- Pop scale in the first 0.15s
                local scale = 1.0
                if progress < 0.15 then
                    scale = 1.0 + (0.15 - progress) / 0.15 * 0.25
                end
                f:SetScale(scale * (B.db.scale or 1.0))
                f:ClearAllPoints()
                f:SetPoint("CENTER", f.anchor or UIParent, "CENTER", 0, 0)
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Module Setup & Event Registration
-------------------------------------------------------------------------------
function mod:Create()
    -- 1. Synchronize Blizzard stock CombatText & Floating Combat Damage
    if B.SyncCombatText then
        B:SyncCombatText()
    end

    -- 2. Create Zone Anchors (Movers)
    local aInc = CreateFrame("Frame", "BUI_SCT_Incoming", UIParent)
    aInc:SetWidth(120)
    aInc:SetHeight(40)
    B:RegisterMover(aInc, "sct_incoming", L["Incoming Combat Text"], "CENTER", "CENTER", -260, 0)
    anchorIncoming = aInc

    local aOut = CreateFrame("Frame", "BUI_SCT_Outgoing", UIParent)
    aOut:SetWidth(120)
    aOut:SetHeight(40)
    B:RegisterMover(aOut, "sct_outgoing", L["Outgoing Combat Text"], "CENTER", "CENTER", 260, 0)
    anchorOutgoing = aOut

    local aStat = CreateFrame("Frame", "BUI_SCT_Static", UIParent)
    aStat:SetWidth(160)
    aStat:SetHeight(30)
    B:RegisterMover(aStat, "sct_static", L["Auras & Buffs"], "CENTER", "CENTER", 0, 180)
    anchorStatic = aStat

    local aAlert = CreateFrame("Frame", "BUI_SCT_Alerts", UIParent)
    aAlert:SetWidth(200)
    aAlert:SetHeight(30)
    B:RegisterMover(aAlert, "sct_alerts", L["Alerts & Cooldowns"], "CENTER", "CENTER", 0, -140)
    anchorAlerts = aAlert

    -- 2. Pre-allocate Frame Pools under one holder, so the module's scale,
    -- opacity and visibility settings reach every number at once.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetAllPoints(UIParent)
    holder:SetFrameStrata("HIGH")
    self.holder = holder
    self.lookFrames = { holder }
    for i = 1, 12 do
        local f = CreatePoolFrame(holder, "BUI_SCT_Inc_" .. i, false)
        table.insert(poolIncoming, f)
    end
    for i = 1, 16 do
        local f = CreatePoolFrame(holder, "BUI_SCT_Out_" .. i, false)
        table.insert(poolOutgoing, f)
    end
    for i = 1, 8 do
        local f = CreatePoolFrame(holder, "BUI_SCT_Stat_" .. i, false)
        table.insert(poolStatic, f)
    end
    for i = 1, 4 do
        local f = CreatePoolFrame(holder, "BUI_SCT_Alert_" .. i, true)
        table.insert(poolAlerts, f)
    end

    -- 3. Event Listener & Animation Driver Frame
    local driver = CreateFrame("Frame", "BUI_SCT_Driver", UIParent)
    driver:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    driver:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    driver:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
    driver:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
    driver:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
    driver:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
    driver:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
    driver:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
    driver:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    driver:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
    driver:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
    driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    driver:RegisterEvent("UNIT_HEALTH")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")

    driver:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            if B.SyncCombatText then
                B:SyncCombatText()
            end
            return
        end
        if not B:IsEnabled("combattext") then return end
        local msg = arg1 or ""

        if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
            local spell, amount, isCrit, school = ParseOutgoingSpellDamage(msg)
            if spell and amount then
                mod:AddOutgoing(spell, amount, isCrit, school)
            end
        elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
            local spell, amount, isCrit, school = ParseOutgoingMeleeHits(msg)
            if spell and amount then
                mod:AddOutgoing(spell, amount, isCrit, school)
            end
        elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
            local spell, amount, isCrit, school = ParseOutgoingPeriodicDamage(msg)
            if spell and amount then
                mod:AddOutgoing(spell, amount, isCrit, school)
            end
        elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" then
            local source, amount, isCrit = ParseIncomingMelee(msg)
            if source and amount then
                mod:AddIncoming(source, amount, isCrit, nil)
            end
        elseif event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
            local source, amount, isCrit = ParseIncomingSpell(msg)
            if source and amount then
                mod:AddIncoming(source, amount, isCrit, nil)
            else
                local _, _, debuff = string.find(msg, "^You are afflicted by ([^%.]+)")
                if not debuff then
                    _, _, debuff = string.find(msg, "^Ihr seid von ([^%.]+) betroffen")
                end
                if debuff then
                    mod:AddAura(debuff, true, false)
                end
            end
        elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" then
            local source, missType = ParseIncomingMiss(msg)
            if source and missType then
                mod:AddIncoming(source, 0, false, missType)
            end
        elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
            if string.find(msg, "dodge", 1, true) or string.find(msg, "weicht", 1, true) then
                mod:AddAlert("Overpower", "OVERPOWER")
            end
        elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
            local _, _, buff = string.find(msg, "^You gain ([^%.]+)")
            if not buff then
                _, _, buff = string.find(msg, "^Ihr erhaltet ([^%.]+)")
            end
            if buff then
                mod:AddAura(buff, false, false)
            end
        elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
            local _, _, faded = string.find(msg, "^([^%.]+) fades from you")
            if not faded then
                _, _, faded = string.find(msg, "^([^%.]+) schwindet von Euch")
            end
            if faded then
                mod:AddAura(faded, false, true)
            end
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            CheckCooldowns()
        elseif event == "UNIT_HEALTH" and arg1 == "target" then
            if UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
                local hp = UnitHealth("target") or 0
                local maxhp = UnitHealthMax("target") or 1
                if maxhp > 0 and (hp / maxhp) <= 0.20 and not driver.alertedExecute then
                    driver.alertedExecute = true
                    mod:AddAlert("Execute", "EXECUTE")
                elseif maxhp > 0 and (hp / maxhp) > 0.20 then
                    driver.alertedExecute = false
                end
            end
        end
    end)

    local lastUpdate = 0
    driver:SetScript("OnUpdate", function()
        if not B:IsEnabled("combattext") then return end
        local dt = arg1 or 0.016
        if dt > 0.1 then dt = 0.1 end

        -- Update animation of active pool frames
        UpdateArcPool(poolIncoming, -1, dt)
        UpdateArcPool(poolOutgoing, 1, dt)
        UpdateStaticPool(poolStatic, dt)
        UpdateAlertsPool(poolAlerts, dt)

        -- Periodic cooldown check fallback
        lastUpdate = lastUpdate + dt
        if lastUpdate > 0.20 then
            lastUpdate = 0
            CheckCooldowns()
        end
    end)

    driver:SetScript("OnHide", function()
        local hidePool = function(pool)
            local n = table.getn(pool)
            for i = 1, n do
                local f = pool[i]
                if f then
                    f.inUse = false
                    f:Hide()
                end
            end
        end
        hidePool(poolIncoming)
        hidePool(poolOutgoing)
        hidePool(poolStatic)
        hidePool(poolAlerts)
    end)

    self.driver = driver
    self.frame = driver
end

-- Stock combat text is synced by Core (SyncHud every 5 s and on module changes),
-- not from this 10 Hz update.
function mod:Update(state)
    if not B:IsEnabled("combattext") then
        local hidePool = function(pool)
            local n = table.getn(pool)
            for i = 1, n do
                local f = pool[i]
                if f then
                    f.inUse = false
                    f:Hide()
                end
            end
        end
        hidePool(poolIncoming)
        hidePool(poolOutgoing)
        hidePool(poolStatic)
        hidePool(poolAlerts)
    end
end

B:RegisterModule("combattext", mod)