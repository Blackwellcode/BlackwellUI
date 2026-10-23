-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  CombatText.lua
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
local mod = {}
mod.label = "Combat Text"
mod.alwaysActive = false

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
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetWidth(200)
    f:SetHeight(20)
    f:Hide()

    -- 16x16 icon (or 18x18 for alert) with 1px black border
    local iconSize = isAlert and 18 or 16
    local iconBorder = f:CreateTexture(nil, "BACKGROUND")
    iconBorder:SetWidth(iconSize + 2)
    iconBorder:SetHeight(iconSize + 2)
    iconBorder:SetPoint("LEFT", f, "LEFT", 0, 0)
    B:Solid(iconBorder, 0, 0, 0, 1)
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
    if not B:IsEnabled("combattext") then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    spellName = spellName or "Physical"

    local now = (type(GetTime) == "function" and GetTime()) or 0

    -- Check for Multi-Hit / Batching within 0.35s
    local n = table.getn(poolOutgoing)
    for i = 1, n do
        local f = poolOutgoing[i]
        if f.inUse and f.abilityKey == spellName and (now - f.spawnTime) < 0.35 then
            f.amount = f.amount + amount
            f.hits = f.hits + 1
            f.isCrit = f.isCrit or isCrit
            local cHex = mod:GetSchoolHex(school or f.school)
            f.text:SetText(cHex .. tostring(f.amount) .. "|r |cffffff00[" .. tostring(f.hits) .. " Hits]|r")
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
    f.duration = 1.8
    f.anchor = anchorOutgoing

    local tex = B:GetAbilityIcon(spellName)
    f.icon:SetTexture(tex)
    f.icon:Show()
    f.iconBorder:Show()

    local colorHex = mod:GetSchoolHex(school)
    f.text:SetText(colorHex .. tostring(amount) .. "|r")

    local fontSize = isCrit and 17 or 14
    f.text:SetFont(B.FONTS["Expressway Bold"] or B:GetFontPath(), fontSize, "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorOutgoing, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddIncoming(sourceName, amount, isCrit, missType)
    if not B:IsEnabled("combattext") then return end
    local f = GetFreeFrame(poolIncoming)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = 1.8
    f.anchor = anchorIncoming
    f.icon:Hide()
    f.iconBorder:Hide()

    sourceName = sourceName or "Enemy"
    if missType then
        f.text:SetText("|cffff2020(" .. sourceName .. ")|r |cff00e5ff" .. string.upper(missType) .. "|r")
    else
        amount = tonumber(amount) or 0
        f.text:SetText("|cffff2020(" .. sourceName .. ")|r |cffffffff-" .. tostring(amount) .. "|r")
    end

    local fontSize = isCrit and 16 or 13
    f.text:SetFont(B.FONTS["Expressway Bold"] or B:GetFontPath(), fontSize, "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorIncoming, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddAura(name, isDebuff, isFade)
    if not B:IsEnabled("combattext") then return end
    name = name or "Aura"
    local f = GetFreeFrame(poolStatic)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = 2.0
    f.anchor = anchorStatic

    local tex = B:GetAbilityIcon(name)
    f.icon:SetTexture(tex)
    f.icon:Show()
    f.iconBorder:Show()

    if isFade then
        f.text:SetText("|cffaaaaaa[" .. name .. " Faded]|r")
    elseif isDebuff then
        -- Cyan / Teal
        f.text:SetText("|cff00e5ff[" .. name .. "]|r")
    else
        -- Golden Yellow
        f.text:SetText("|cffffd100[" .. name .. "]|r")
    end
    f.text:SetFont(B.FONTS["Expressway Bold"] or B:GetFontPath(), 13, "OUTLINE")

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorStatic, "CENTER", 0, 0)
    f:SetAlpha(1)
    f:Show()
end

function mod:AddAlert(spellName, alertType)
    if not B:IsEnabled("combattext") then return end
    spellName = spellName or "Ability"
    local f = GetFreeFrame(poolAlerts)
    f.inUse = true
    f.spawnTime = (type(GetTime) == "function" and GetTime()) or 0
    f.elapsed = 0
    f.duration = 2.2
    f.anchor = anchorAlerts

    local tex = B:GetAbilityIcon(spellName)
    f.icon:SetTexture(tex)
    f.icon:Show()
    f.iconBorder:Show()

    if alertType == "READY" then
        -- Red spell name + White READY NOW!
        f.text:SetText("|cffff2020" .. string.upper(spellName) .. "|r |cffffffffREADY NOW!|r")
    elseif alertType == "EXECUTE" then
        f.text:SetText("|cffff2020EXECUTE!|r")
    elseif alertType == "OVERPOWER" then
        f.text:SetText("|cffffb800OVERPOWER!|r")
    elseif alertType == "REVENGE" then
        f.text:SetText("|cff00ff88REVENGE!|r")
    else
        f.text:SetText("|cffff2020" .. string.upper(spellName) .. "!|r")
    end
    f.text:SetFont(B.FONTS["Expressway Bold"] or B:GetFontPath(), 16, "OUTLINE")

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
                local curX = 60 * curveDir * curveProgress
                local curY = 130 * progress
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
    -- 1. Suppress Blizzard stock CombatText & Floating Combat Damage
    if B.SuppressStockCombatText then
        B:SuppressStockCombatText()
    end

    -- 2. Create Zone Anchors (Movers)
    local aInc = CreateFrame("Frame", "BUI_SCT_Incoming", UIParent)
    aInc:SetWidth(120)
    aInc:SetHeight(40)
    B:RegisterMover(aInc, "sct_incoming", "Incoming Combat Text", "CENTER", "CENTER", -260, 0)
    anchorIncoming = aInc

    local aOut = CreateFrame("Frame", "BUI_SCT_Outgoing", UIParent)
    aOut:SetWidth(120)
    aOut:SetHeight(40)
    B:RegisterMover(aOut, "sct_outgoing", "Outgoing Combat Text", "CENTER", "CENTER", 260, 0)
    anchorOutgoing = aOut

    local aStat = CreateFrame("Frame", "BUI_SCT_Static", UIParent)
    aStat:SetWidth(160)
    aStat:SetHeight(30)
    B:RegisterMover(aStat, "sct_static", "Auras & Buffs", "CENTER", "CENTER", 0, 180)
    anchorStatic = aStat

    local aAlert = CreateFrame("Frame", "BUI_SCT_Alerts", UIParent)
    aAlert:SetWidth(200)
    aAlert:SetHeight(30)
    B:RegisterMover(aAlert, "sct_alerts", "Alerts & Cooldowns", "CENTER", "CENTER", 0, -140)
    anchorAlerts = aAlert

    -- 2. Pre-allocate Frame Pools
    for i = 1, 12 do
        local f = CreatePoolFrame(UIParent, "BUI_SCT_Inc_" .. i, false)
        table.insert(poolIncoming, f)
    end
    for i = 1, 16 do
        local f = CreatePoolFrame(UIParent, "BUI_SCT_Out_" .. i, false)
        table.insert(poolOutgoing, f)
    end
    for i = 1, 8 do
        local f = CreatePoolFrame(UIParent, "BUI_SCT_Stat_" .. i, false)
        table.insert(poolStatic, f)
    end
    for i = 1, 4 do
        local f = CreatePoolFrame(UIParent, "BUI_SCT_Alert_" .. i, true)
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
            if B.SuppressStockCombatText then
                B:SuppressStockCombatText()
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

function mod:Update(state)
    if B.SuppressStockCombatText then
        B:SuppressStockCombatText()
    end
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