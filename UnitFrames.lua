-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  UnitFrames.lua
--  Cyberpunk HUD Unit Frames:
--  - Hero & Target frames (210 x 46): tall 35px health bar + 6px sleek power bar
--  - Player class-colored or cyber-accent health bar with dark slate backdrop
--  - In-bar Typography: Name on LEFT, HP & Percent (HP | %) on RIGHT
--  - Target reaction-colored (Hostile red, Neutral yellow, Friendly green)
--  - Pet & Target of Target mini frames (110 x 24)
--  - Dynamic Encounter stack for 20 active elites, guardians, and bosses
--  - Clean Blizzard frame suppression
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Unit Frames"
mod.alwaysActive = true

local MAX_ENCOUNTER_ROWS = 20
local ENC_WIDTH = 260
local MAX_TARGET_DEBUFFS = 6
local DEBUFF_BAR_WIDTH = 208
local DEBUFF_BAR_HEIGHT = 16

local lastTickDamage = {
    ["rend"] = 450,
    ["deep wounds"] = 890,
    ["corruption"] = 1240,
    ["shadow word: pain"] = 720,
    ["immolate"] = 980,
    ["moonfire"] = 560,
    ["serpent sting"] = 340,
    ["thunder clap"] = 620,
}

local debuffTimers = {}
local DEBUFF_DURATIONS = {
    ["rend"] = 15,
    ["deep wounds"] = 12,
    ["corruption"] = 18,
    ["shadow word: pain"] = 18,
    ["immolate"] = 15,
    ["moonfire"] = 12,
    ["serpent sting"] = 15,
    ["insect swarm"] = 12,
    ["rip"] = 16,
    ["garrote"] = 18,
    ["deadly poison"] = 12,
    ["thunder clap"] = 30,
    ["demoralizing shout"] = 30,
    ["curse of agony"] = 24,
    ["siphon life"] = 30,
    ["gouge"] = 5.5,
    ["kidney shot"] = 6,
    ["blind"] = 10,
    ["hamstring"] = 15,
    ["frostbolt"] = 9,
    ["cone of cold"] = 8,
    ["blizzard"] = 8,
    ["chilled"] = 5,
}

local function ParsePeriodicDamage(msg)
    if not msg or msg == "" then return end

    -- Pattern 1 (EN): "X suffers 450 Fire damage from your Immolation."
    local _, _, dmg, spell = string.find(msg, "suffers (%d+).-damage from your ([^%.]+)")
    if dmg and spell then
        local d = tonumber(dmg)
        if d then
            lastTickDamage[string.lower(spell)] = d
            return
        end
    end

    -- Pattern 2 (EN): "suffers 450 ... from your Rend"
    local _, _, dmg2, spell2 = string.find(msg, "suffers (%d+).-from your ([^%.]+)")
    if dmg2 and spell2 then
        local d = tonumber(dmg2)
        if d then
            lastTickDamage[string.lower(spell2)] = d
            return
        end
    end

    -- Pattern 3 (DE): "X erleidet 450 Feuerschaden durch Euer/Eure/Euren Feuerbrand."
    local _, _, dmgDe, spellDe = string.find(msg, "erleidet (%d+).-durch Euer.- ([^%.]+)")
    if dmgDe and spellDe then
        local d = tonumber(dmgDe)
        if d then
            lastTickDamage[string.lower(spellDe)] = d
            return
        end
    end

    -- Pattern 4 (DE): "X erleidet 450 Schaden von Eurem Feuerbrand."
    local _, _, dmgDe2, spellDe2 = string.find(msg, "erleidet (%d+).-von Euer.- ([^%.]+)")
    if dmgDe2 and spellDe2 then
        local d = tonumber(dmgDe2)
        if d then
            lastTickDamage[string.lower(spellDe2)] = d
            return
        end
    end
end

local function GetSpellTickDamage(name)
    if not name then return nil end
    local lowerName = string.lower(name)
    local val = lastTickDamage[lowerName]

    if not val then
        for k, v in pairs(lastTickDamage) do
            if string.find(lowerName, k, 1, true) or string.find(k, lowerName, 1, true) then
                val = v
                break
            end
        end
    end

    if not val and type(AZS_METER) == "table" then
        for i = 1, table.getn(AZS_METER) do
            local item = AZS_METER[i]
            if type(item) == "table" and item.name and string.lower(item.name) == lowerName then
                if item.dps and item.dps > 0 then
                    val = math.floor(tonumber(item.dps) + 0.5)
                end
                break
            end
        end
    end
    return val
end

local function GetOrInitDebuffTimer(name, now)
    local key = name and string.lower(name) or "default"
    if not debuffTimers[key] then
        local dur = DEBUFF_DURATIONS[key] or 15
        debuffTimers[key] = { start = now, dur = dur }
    end
    return debuffTimers[key]
end

local debuffScanTooltip = nil
local function GetTargetDebuffName(index, tex)
    local name = nil
    if not debuffScanTooltip then
        debuffScanTooltip = CreateFrame("GameTooltip", "BUI_TargetDebuffScanTooltip", UIParent, "GameTooltipTemplate")
        debuffScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    if debuffScanTooltip.SetUnitDebuff then
        debuffScanTooltip:ClearLines()
        debuffScanTooltip:SetUnitDebuff("target", index)
        local fs = getglobal("BUI_TargetDebuffScanTooltipTextLeft1")
        if fs and fs.GetText then
            name = fs:GetText()
        end
    end
    if (not name or name == "") and tex then
        local _, _, file = string.find(tex, "[^\\]+$")
        if file then
            name = string.gsub(file, "^Ability_", "")
            name = string.gsub(name, "^Spell_", "")
            name = string.gsub(name, "_", " ")
        end
    end
    return name or ("Debuff " .. tostring(index))
end

local DEBUFF_TYPE_COLORS = {
    ["Curse"]   = { r = 0.65, g = 0.20, b = 0.95 },
    ["Disease"] = { r = 0.65, g = 0.40, b = 0.10 },
    ["Magic"]   = { r = 0.20, g = 0.65, b = 1.00 },
    ["Poison"]  = { r = 0.15, g = 0.75, b = 0.20 },
    ["none"]    = { r = 0.85, g = 0.20, b = 0.25 },
}

local function GetDebuffBarColor(debuffType, name)
    if debuffType and DEBUFF_TYPE_COLORS[debuffType] then
        return DEBUFF_TYPE_COLORS[debuffType]
    end
    if name then
        local s = string.lower(name)
        if string.find(s, "fire") or string.find(s, "burn") or string.find(s, "immolat") or string.find(s, "flame") then
            return { r = 1.00, g = 0.45, b = 0.10 }
        elseif string.find(s, "frost") or string.find(s, "ice") or string.find(s, "chill") or string.find(s, "cold") then
            return { r = 0.25, g = 0.75, b = 1.00 }
        elseif string.find(s, "shadow") or string.find(s, "pain") or string.find(s, "curse") or string.find(s, "dark") then
            return { r = 0.65, g = 0.20, b = 0.95 }
        elseif string.find(s, "thunder") or string.find(s, "nature") or string.find(s, "lightning") then
            return { r = 0.30, g = 0.75, b = 0.95 }
        elseif string.find(s, "poison") or string.find(s, "venom") or string.find(s, "toxin") then
            return { r = 0.15, g = 0.75, b = 0.20 }
        elseif string.find(s, "shout") or string.find(s, "roar") then
            return { r = 0.85, g = 0.50, b = 0.18 }
        end
    end
    return DEBUFF_TYPE_COLORS["none"]
end

local POWER_COLORS = {
    [0] = { r = 0.00, g = 0.55, b = 1.00 }, -- Mana
    [1] = { r = 0.90, g = 0.20, b = 0.20 }, -- Rage
    [2] = { r = 1.00, g = 0.50, b = 0.25 }, -- Focus
    [3] = { r = 1.00, g = 0.85, b = 0.10 }, -- Energy
}

local REACTION_COLORS = {
    hostile  = { r = 0.80, g = 0.15, b = 0.15 }, -- Red
    neutral  = { r = 0.85, g = 0.75, b = 0.15 }, -- Yellow
    friendly = { r = 0.20, g = 0.80, b = 0.25 }, -- Green
    tapped   = { r = 0.55, g = 0.55, b = 0.55 }, -- Grey
}

local function SuppressBlizzardFrame(f)
    if not f then return end
    f:Hide()
    f:SetAlpha(0)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 500, 500)
    f:SetScript("OnShow", function()
        this:Hide()
    end)
end

function mod:HideBlizzardFrames()
    SuppressBlizzardFrame(PlayerFrame)
    SuppressBlizzardFrame(TargetFrame)
    SuppressBlizzardFrame(ComboFrame)
    SuppressBlizzardFrame(PetFrame)
    SuppressBlizzardFrame(TargetofTargetFrame)
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_UnitFrames", UIParent)
    EUI_UnitFrames = root -- Compatibility alias
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardFrames()

    ---------------------------------------------------------------------------
    --  1. Hero Frame (210 x 46)
    ---------------------------------------------------------------------------
    local hero = CreateFrame("Frame", "BUI_HeroFrame", root)
    EUI_HeroFrame = hero -- Compatibility alias
    BUI_PlayerFrame = hero
    EUI_PlayerFrame = hero
    hero:SetWidth(210)
    hero:SetHeight(46)
    B:Backdrop(hero, 0.90)

    -- Health Bar (208 x 35) - Dominates frame
    local hpBar = B:Bar(hero, nil, 0.2, 0.8, 0.2)
    hpBar:SetPoint("TOPLEFT", hero, "TOPLEFT", 1, -1)
    hpBar:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -1, -1)
    hpBar:SetHeight(35)
    hero.hpBar = hpBar

    -- Player Name (inside Health Bar, TOPLEFT aligned)
    local nameText = B:Font(hpBar, 11, "LEFT")
    nameText:SetPoint("TOPLEFT", hpBar, "TOPLEFT", 6, -3)
    nameText:SetWidth(110)
    nameText:SetHeight(14)
    nameText:SetTextColor(1, 1, 1)
    hero.nameText = nameText

    -- Health Text (inside Health Bar, RIGHT aligned, e.g. "270 | 100%")
    local hpText = B:Font(hpBar, 11, "RIGHT")
    hpText:SetPoint("RIGHT", hpBar, "RIGHT", -6, 0)
    hpText:SetWidth(90)
    hpText:SetHeight(16)
    hpText:SetTextColor(1, 1, 1)
    hero.hpText = hpText

    -- Level badge (inside Health Bar, BOTTOMLEFT aligned)
    local lvlText = B:Font(hpBar, 8, "LEFT")
    lvlText:SetPoint("BOTTOMLEFT", hpBar, "BOTTOMLEFT", 6, 4)
    lvlText:SetWidth(60)
    lvlText:SetHeight(12)
    B:Accent(lvlText, "text")
    hero.lvlText = lvlText

    -- Power Bar (208 x 6) Mana / Rage / Energy
    local pBar = B:Bar(hero, nil, 0.0, 0.55, 1.0)
    pBar:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -2)
    pBar:SetPoint("TOPRIGHT", hpBar, "BOTTOMRIGHT", 0, -2)
    pBar:SetHeight(6)
    hero.pBar = pBar

    local pText = B:Font(pBar, 8, "CENTER")
    pText:SetPoint("CENTER", pBar, "CENTER", 0, 0)
    hero.pText = pText

    -- Shield Bar (absorb indicator overlay on power bar bottom)
    local shBar = B:Bar(hero, nil, 0.25, 0.70, 1.00)
    shBar:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -1)
    shBar:SetPoint("TOPRIGHT", pBar, "BOTTOMRIGHT", 0, -1)
    shBar:SetHeight(2)
    shBar:Hide()
    hero.shBar = shBar

    -- XP Bar (2px Cyber Accent at bottom)
    local xpBar = B:Bar(hero, nil)
    xpBar:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -1)
    xpBar:SetPoint("TOPRIGHT", pBar, "BOTTOMRIGHT", 0, -1)
    xpBar:SetHeight(2)
    hero.xpBar = xpBar

    B:RegisterMover(hero, "hero", "Hero Frame", "BOTTOM", "BOTTOM", -240, 140)
    self.hero = hero

    ---------------------------------------------------------------------------
    --  2. Target Frame (210 x 46)
    ---------------------------------------------------------------------------
    local tgt = CreateFrame("Frame", "BUI_TargetFrame", root)
    EUI_TargetFrame = tgt -- Compatibility alias
    tgt:SetWidth(210)
    tgt:SetHeight(46)
    B:Backdrop(tgt, 0.90)

    -- Target Health Bar (208 x 35)
    local tgtHpBar = B:Bar(tgt, nil, 0.8, 0.2, 0.2)
    tgtHpBar:SetPoint("TOPLEFT", tgt, "TOPLEFT", 1, -1)
    tgtHpBar:SetPoint("TOPRIGHT", tgt, "TOPRIGHT", -1, -1)
    tgtHpBar:SetHeight(35)
    tgt.hpBar = tgtHpBar

    -- Target Name (inside Health Bar, TOPLEFT aligned)
    local tgtNameText = B:Font(tgtHpBar, 11, "LEFT")
    tgtNameText:SetPoint("TOPLEFT", tgtHpBar, "TOPLEFT", 6, -3)
    tgtNameText:SetWidth(115)
    tgtNameText:SetHeight(14)
    tgtNameText:SetTextColor(1, 1, 1)
    tgt.nameText = tgtNameText

    -- Target Badge (boss/elite/enraged status inside Health Bar, BOTTOMLEFT aligned)
    local badgeText = B:Font(tgtHpBar, 8, "LEFT")
    badgeText:SetPoint("BOTTOMLEFT", tgtHpBar, "BOTTOMLEFT", 6, 4)
    badgeText:SetWidth(100)
    badgeText:SetHeight(12)
    tgt.badgeText = badgeText

    -- Target HP Text (inside Health Bar, RIGHT aligned, e.g. "118K | 52%")
    local tgtHpText = B:Font(tgtHpBar, 11, "RIGHT")
    tgtHpText:SetPoint("RIGHT", tgtHpBar, "RIGHT", -6, 0)
    tgtHpText:SetWidth(90)
    tgtHpText:SetHeight(16)
    tgtHpText:SetTextColor(1, 1, 1)
    tgt.hpText = tgtHpText

    -- Target Power Bar (208 x 6)
    local tgtPBar = B:Bar(tgt, nil, 0.0, 0.55, 1.0)
    tgtPBar:SetPoint("TOPLEFT", tgtHpBar, "BOTTOMLEFT", 0, -2)
    tgtPBar:SetPoint("TOPRIGHT", tgtHpBar, "BOTTOMRIGHT", 0, -2)
    tgtPBar:SetHeight(6)
    tgt.pBar = tgtPBar

    -- Target Debuff Bars (Stacked above Target Frame, matching center Buff Bars)
    -- 16px high aura bars with 16x16 icon on left, Name on left, Tick damage in center, Time/stacks on right
    local debuffBars = {}
    for i = 1, MAX_TARGET_DEBUFFS do
        local r = CreateFrame("Button", "BUI_TargetDebuffBar" .. i, tgt)
        r:SetWidth(DEBUFF_BAR_WIDTH)
        r:SetHeight(DEBUFF_BAR_HEIGHT)
        r:SetPoint("BOTTOMLEFT", tgt, "TOPLEFT", 1, 4 + (i - 1) * 18)
        r:EnableMouse(true)

        -- Square Icon tile on the left (16x16)
        local iconFrame = CreateFrame("Frame", nil, r)
        iconFrame:SetWidth(DEBUFF_BAR_HEIGHT)
        iconFrame:SetHeight(DEBUFF_BAR_HEIGHT)
        iconFrame:SetPoint("LEFT", r, "LEFT", 0, 0)
        B:Border(iconFrame, 0, 0, 0, 1)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon = icon

        -- Status bar on the right of the icon
        local bar = B:Bar(r, nil)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
        bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        bar:EnableMouse(false)
        r.bar = bar

        -- Debuff Name on the left
        local nameFs = B:Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetWidth(95)
        nameFs:SetHeight(12)
        r.nameFs = nameFs

        -- Tick Damage in the center
        local centerFs = B:Font(bar, 10, "CENTER")
        centerFs:SetPoint("CENTER", bar, "CENTER", 0, 0)
        centerFs:SetTextColor(1.0, 0.85, 0.20)
        r.centerFs = centerFs

        -- Time / Stacks on the right
        local timeFs = B:Font(bar, 9, "RIGHT")
        timeFs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        timeFs:SetWidth(44)
        timeFs:SetHeight(12)
        r.timeFs = timeFs

        r.debuffIndex = i
        r:SetScript("OnEnter", function()
            if UnitExists("target") and this.debuffIndex then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                if type(GameTooltip.SetUnitDebuff) == "function" then
                    GameTooltip:SetUnitDebuff("target", this.debuffIndex)
                end
                if this.tickDmg and this.tickDmg > 0 then
                    GameTooltip:AddLine(string.format("Tick Damage: %d", this.tickDmg), 1.0, 0.85, 0.20)
                end
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        debuffBars[i] = r
    end
    tgt.debuffBars = debuffBars
    tgt.debuffs = debuffBars

    tgt:Hide()
    B:RegisterMover(tgt, "target", "Target Frame", "BOTTOM", "BOTTOM", 240, 140)
    self.target = tgt

    ---------------------------------------------------------------------------
    --  3. Target of Target Frame (110 x 24)
    ---------------------------------------------------------------------------
    local tot = CreateFrame("Frame", "BUI_TargetTargetFrame", tgt)
    EUI_TargetTargetFrame = tot -- Compatibility alias
    tot:SetWidth(110)
    tot:SetHeight(24)
    tot:SetPoint("TOPLEFT", tgt, "TOPRIGHT", 6, 0)
    B:Backdrop(tot, 0.90)

    local totHpBar = B:Bar(tot, nil, 0.8, 0.2, 0.2)
    totHpBar:SetPoint("TOPLEFT", tot, "TOPLEFT", 1, -1)
    totHpBar:SetPoint("TOPRIGHT", tot, "TOPRIGHT", -1, -1)
    totHpBar:SetHeight(17)
    tot.hpBar = totHpBar

    local totName = B:Font(totHpBar, 9, "LEFT")
    totName:SetPoint("LEFT", totHpBar, "LEFT", 4, 0)
    totName:SetWidth(60)
    totName:SetHeight(12)
    tot.nameText = totName

    local totPct = B:Font(totHpBar, 9, "RIGHT")
    totPct:SetPoint("RIGHT", totHpBar, "RIGHT", -4, 0)
    totPct:SetWidth(38)
    totPct:SetHeight(12)
    tot.hpText = totPct

    local totPBar = B:Bar(tot, nil, 0.0, 0.55, 1.0)
    totPBar:SetPoint("TOPLEFT", totHpBar, "BOTTOMLEFT", 0, -1)
    totPBar:SetPoint("TOPRIGHT", totHpBar, "BOTTOMRIGHT", 0, -1)
    totPBar:SetHeight(3)
    tot.pBar = totPBar

    tot:Hide()
    self.tot = tot

    ---------------------------------------------------------------------------
    --  4. Pet Frame (110 x 24)
    ---------------------------------------------------------------------------
    local pet = CreateFrame("Frame", "BUI_PetFrame", hero)
    EUI_PetFrame = pet -- Compatibility alias
    pet:SetWidth(110)
    pet:SetHeight(24)
    pet:SetPoint("TOPRIGHT", hero, "BOTTOMRIGHT", 0, -8)
    B:Backdrop(pet, 0.90)

    local petHpBar = B:Bar(pet, nil, 0.2, 0.8, 0.2)
    petHpBar:SetPoint("TOPLEFT", pet, "TOPLEFT", 1, -1)
    petHpBar:SetPoint("TOPRIGHT", pet, "TOPRIGHT", -1, -1)
    petHpBar:SetHeight(17)
    pet.hpBar = petHpBar

    local petName = B:Font(petHpBar, 9, "LEFT")
    petName:SetPoint("LEFT", petHpBar, "LEFT", 4, 0)
    petName:SetWidth(60)
    petName:SetHeight(12)
    pet.nameText = petName

    local petPct = B:Font(petHpBar, 9, "RIGHT")
    petPct:SetPoint("RIGHT", petHpBar, "RIGHT", -4, 0)
    petPct:SetWidth(38)
    petPct:SetHeight(12)
    pet.hpText = petPct

    local petPBar = B:Bar(pet, nil, 1.0, 0.50, 0.25)
    petPBar:SetPoint("TOPLEFT", petHpBar, "BOTTOMLEFT", 0, -1)
    petPBar:SetPoint("TOPRIGHT", petHpBar, "BOTTOMRIGHT", 0, -1)
    petPBar:SetHeight(3)
    pet.pBar = petPBar

    pet:Hide()
    self.pet = pet

    ---------------------------------------------------------------------------
    --  5. Encounter / Elite & Boss Frame (ENC_WIDTH x dynamic)
    ---------------------------------------------------------------------------
    local enc = CreateFrame("Frame", "BUI_EncounterFrame", root)
    EUI_EncounterFrame = enc -- Compatibility alias
    enc:SetWidth(ENC_WIDTH)
    enc:SetHeight(130)
    B:Backdrop(enc, 0.88)

    enc.header = B:Header(enc, "ELITES & BOSSES", 18)

    local rows = {}
    for i = 1, MAX_ENCOUNTER_ROWS do
        local r = CreateFrame("Button", nil, enc)
        r:SetWidth(ENC_WIDTH - 8)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", enc, "TOPLEFT", 4, -22 - (i - 1) * 21)

        local bar = B:Bar(r, nil, 0.8, 0.2, 0.2)
        bar:SetAllPoints(r)
        bar:EnableMouse(false)
        r.bar = bar

        local badgeFs = B:Font(bar, 9, "LEFT")
        badgeFs:SetPoint("LEFT", bar, "LEFT", 3, 0)
        badgeFs:SetWidth(40)
        badgeFs:SetHeight(12)
        r.badgeFs = badgeFs

        local rHpFs = B:Font(bar, 9, "RIGHT")
        rHpFs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
        rHpFs:SetWidth(100)
        rHpFs:SetHeight(12)
        r.hpFs = rHpFs

        local rNameFs = B:Font(bar, 9, "LEFT")
        rNameFs:SetPoint("LEFT", badgeFs, "RIGHT", 3, 0)
        rNameFs:SetPoint("RIGHT", rHpFs, "LEFT", -3, 0)
        rNameFs:SetHeight(12)
        r.nameFs = rNameFs

        -- Hover highlight
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        B:Solid(hl, 1, 1, 1, 0.15)
        hl:SetAllPoints(r)
        r.hl = hl

        r:EnableMouse(true)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function()
            local uName = this.unitName
            if uName and uName ~= "" then
                ClearTarget()
                TargetByName(uName, true)
                if not UnitExists("target") then
                    TargetByName(uName, false)
                end
                B:Tick()
            end
        end)

        r:SetScript("OnEnter", function()
            if this.unitName then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(this.unitName, 1, 1, 1)
                if this.unitHp and this.unitHpm then
                    GameTooltip:AddLine(string.format("Health: %d / %d (%d%%)", this.unitHp, this.unitHpm, this.unitPct or 0), 1, 0.82, 0)
                end
                GameTooltip:AddLine("Click to target", 0, 0.9, 1)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        rows[i] = r
    end
    enc.rows = rows

    enc:Hide()
    B:RegisterMover(enc, "encounters", "Elites & Bosses", "TOPRIGHT", "TOPRIGHT", -12, -280)
    self.enc = enc

    local ufWatcher = CreateFrame("Frame")
    ufWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    ufWatcher:RegisterEvent("UNIT_AURA")
    ufWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    ufWatcher:SetScript("OnEvent", function()
        if B and B.Tick then B:Tick() end
    end)
    self.ufWatcher = ufWatcher

    local cmbWatcher = CreateFrame("Frame")
    cmbWatcher:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
    cmbWatcher:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
    cmbWatcher:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    cmbWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    cmbWatcher:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" then
            debuffTimers = {}
        elseif arg1 then
            ParsePeriodicDamage(arg1)
        end
    end)
    self.cmbWatcher = cmbWatcher
end

function mod:Update(state)
    local run = state and state.run or {}
    local zone = state and state.zone or {}

    ---------------------------------------------------------------------------
    --  1. Update Hero Frame
    ---------------------------------------------------------------------------
    local hero = self.hero
    local heroName = zone.hero
    if not heroName or heroName == "" then
        heroName = UnitName("player") or "Hero"
    end
    hero.nameText:SetText(heroName)

    local lvl = run.lvl or UnitLevel("player") or 1
    hero.lvlText:SetText("Lv " .. tostring(lvl))

    local hp = tonumber(run.hp)
    local hpm = tonumber(run.hpm)
    if not hp or not hpm or hpm <= 0 then
        hp = UnitHealth("player") or 0
        hpm = UnitHealthMax("player") or 1
    end
    if hpm <= 0 then hpm = 1 end
    local hpPct = B:Percent(hp, hpm)
    hero.hpBar:SetValue(hpPct)

    -- Player class color or theme accent on Health Bar
    local cr, cg, cb
    if B.db and B.db.colorHealthByClass == false then
        cr, cg, cb = B:GetAccent()
    else
        cr, cg, cb = B:GetClassColor()
    end
    B:SetBarColor(hero.hpBar, cr, cg, cb)

    local pctInt = math.floor(hpPct * 100 + 0.5)
    hero.hpText:SetText(string.format("%s | %d%%", B:Short(hp), pctInt))

    -- Power bar (Mana / Rage / Energy)
    local pType = UnitPowerType("player") or 0
    local pCur = UnitMana("player") or 0
    local pMax = UnitManaMax("player") or 1
    if pMax <= 0 then pMax = 1 end
    local pPct = B:Percent(pCur, pMax)
    hero.pBar:SetValue(pPct)

    local pColor = POWER_COLORS[pType] or POWER_COLORS[0]
    B:SetBarColor(hero.pBar, pColor.r, pColor.g, pColor.b)

    if pType == 1 or pType == 3 then
        hero.pText:SetText(tostring(pCur))
    else
        hero.pText:SetText(string.format("%d", pCur))
    end

    -- Shield absorb
    local sh = tonumber(run.sh) or 0
    if sh > 0 then
        local shPct = B:Percent(sh, hpm)
        hero.shBar:SetValue(shPct)
        hero.shBar:Show()
    else
        hero.shBar:Hide()
    end

    -- XP bar
    local xp = tonumber(run.xp) or UnitXP("player") or 0
    local xpn = tonumber(run.xpn) or UnitXPMax("player") or 0
    if xpn > 0 then
        hero.xpBar:SetValue(B:Percent(xp, xpn))
    else
        hero.xpBar:SetValue(0)
    end

    ---------------------------------------------------------------------------
    --  2. Update Target Frame
    ---------------------------------------------------------------------------
    local tgt = self.target
    local tData = state and state.target
    local kind = tData and tData.kind

    local hasAzsTarget = (kind and kind ~= "none" and kind ~= "")
    local hasBlizzTarget = UnitExists("target")

    if not hasAzsTarget and not hasBlizzTarget then
        tgt:Hide()
        if tgt.debuffBars then
            for i = 1, MAX_TARGET_DEBUFFS do tgt.debuffBars[i]:Hide() end
        end
        if self.tot then self.tot:Hide() end
    else
        tgt:Show()

        if hasAzsTarget then
            local kInfo = B.KIND_COLORS[kind] or B.KIND_COLORS["normal"]

            if kind == "dead" then
                tgt.nameText:SetText(tData.name or "Target")
                tgt.nameText:SetTextColor(0.5, 0.5, 0.5)
                tgt.badgeText:SetText("DEAD")
                tgt.badgeText:SetTextColor(0.5, 0.5, 0.5)
                tgt.hpBar:SetValue(0)
                B:SetBarColor(tgt.hpBar, 0.4, 0.4, 0.4)
                tgt.hpText:SetText("0%")
            else
                tgt.nameText:SetText(tData.name or "Target")
                tgt.nameText:SetTextColor(1, 1, 1)

                local badge = kInfo.label or ""
                local br, bg, bb = kInfo.r, kInfo.g, kInfo.b

                if (kind == "boss" or kind == "final") and tData.state == 1 then
                    badge = "ENRAGED"
                    br, bg, bb = 1.0, 0.15, 0.15
                elseif kind == "guardian" and tData.state == 1 then
                    badge = "AWAKE"
                end

                tgt.badgeText:SetText(badge)
                tgt.badgeText:SetTextColor(br, bg, bb)

                local tHp = tonumber(tData.hp) or 0
                local tHpm = tonumber(tData.hpm) or 1
                if tHpm <= 0 then tHpm = 1 end
                local tPct = B:Percent(tHp, tHpm)
                tgt.hpBar:SetValue(tPct)
                B:SetBarColor(tgt.hpBar, kInfo.r, kInfo.g, kInfo.b)

                local tPctInt = math.floor(tPct * 100 + 0.5)
                tgt.hpText:SetText(string.format("%s | %d%%", B:Short(tHp), tPctInt))
            end
            tgt.pBar:Hide()
        else
            -- Standard WoW Target
            local tName = UnitName("target") or "Target"
            local tClass = UnitClassification("target")
            local tHp = UnitHealth("target")
            local tHpm = UnitHealthMax("target")
            if tHpm <= 0 then tHpm = 1 end

            tgt.nameText:SetText(tName)
            tgt.nameText:SetTextColor(1, 1, 1)

            local badge = ""
            if tClass == "worldboss" then
                badge = "BOSS"
            elseif tClass == "rareelite" then
                badge = "RARE ELITE"
            elseif tClass == "elite" then
                badge = "ELITE"
            elseif tClass == "rare" then
                badge = "RARE"
            end
            tgt.badgeText:SetText(badge)
            tgt.badgeText:SetTextColor(1.0, 0.8, 0.2)

            local tPct = B:Percent(tHp, tHpm)
            tgt.hpBar:SetValue(tPct)

            -- Color target: reaction colored or class colored
            if UnitIsPlayer("target") then
                local _, targetClass = UnitClass("target")
                local tc = targetClass and B.CLASS_COLORS[targetClass]
                if tc then
                    B:SetBarColor(tgt.hpBar, tc.r, tc.g, tc.b)
                else
                    B:SetBarColor(tgt.hpBar, REACTION_COLORS.neutral.r, REACTION_COLORS.neutral.g, REACTION_COLORS.neutral.b)
                end
            else
                local reaction = UnitReaction("target", "player")
                if reaction then
                    if reaction <= 2 then
                        B:SetBarColor(tgt.hpBar, REACTION_COLORS.hostile.r, REACTION_COLORS.hostile.g, REACTION_COLORS.hostile.b)
                    elseif reaction <= 4 then
                        B:SetBarColor(tgt.hpBar, REACTION_COLORS.neutral.r, REACTION_COLORS.neutral.g, REACTION_COLORS.neutral.b)
                    else
                        B:SetBarColor(tgt.hpBar, REACTION_COLORS.friendly.r, REACTION_COLORS.friendly.g, REACTION_COLORS.friendly.b)
                    end
                else
                    B:SetBarColor(tgt.hpBar, REACTION_COLORS.hostile.r, REACTION_COLORS.hostile.g, REACTION_COLORS.hostile.b)
                end
            end

            local tPctInt = math.floor(tPct * 100 + 0.5)
            tgt.hpText:SetText(string.format("%s | %d%%", B:Short(tHp), tPctInt))

            -- Target Power
            local tpType = UnitPowerType("target") or 0
            local tpCur = UnitMana("target") or 0
            local tpMax = UnitManaMax("target") or 1
            if tpMax <= 0 then tpMax = 1 end
            tgt.pBar:SetValue(B:Percent(tpCur, tpMax))
            local tpColor = POWER_COLORS[tpType] or POWER_COLORS[0]
            B:SetBarColor(tgt.pBar, tpColor.r, tpColor.g, tpColor.b)
            tgt.pBar:Show()
        end

        -- Target Debuff Bars update (Cyberpunk Aura Bars with Tick Damage)
        if tgt.debuffBars then
            local shownCount = 0
            if (state and state.demo) or (B.unlocked and not UnitExists("target")) then
                local demoDebuffs = {
                    { name = "Rend", icon = "Interface\\Icons\\Ability_Gouge", left = 11.4, max = 15, tick = 450, color = { r = 0.85, g = 0.25, b = 0.20 } },
                    { name = "Deep Wounds", icon = "Interface\\Icons\\Ability_BackStab", left = 7.8, max = 12, tick = 890, color = { r = 0.95, g = 0.35, b = 0.15 } },
                    { name = "Thunder Clap", icon = "Interface\\Icons\\Spell_Nature_ThunderClap", left = 18.2, max = 30, tick = 620, color = { r = 0.25, g = 0.75, b = 1.00 } },
                    { name = "Demoralizing Shout", icon = "Interface\\Icons\\Ability_Warrior_WarCry", left = 24.0, max = 30, tick = 0, color = { r = 0.85, g = 0.50, b = 0.18 } },
                }
                shownCount = table.getn(demoDebuffs)
                for i = 1, MAX_TARGET_DEBUFFS do
                    local r = tgt.debuffBars[i]
                    if i <= shownCount then
                        local d = demoDebuffs[i]
                        r.icon:SetTexture(d.icon)
                        r.nameFs:SetText(d.name)
                        local pct = d.left / d.max
                        if pct > 1 then pct = 1 elseif pct < 0 then pct = 0 end
                        r.bar:SetValue(pct)
                        B:SetBarColor(r.bar, d.color.r, d.color.g, d.color.b)
                        local bg = r.bar.buiBg or r.bar.euiBg
                        if bg then
                            bg:SetVertexColor(d.color.r * 0.25, d.color.g * 0.25, d.color.b * 0.25)
                            bg:SetAlpha(0.85)
                        end
                        if d.tick and d.tick > 0 then
                            r.centerFs:SetText(tostring(d.tick))
                            r.tickDmg = d.tick
                        else
                            r.centerFs:SetText("")
                            r.tickDmg = nil
                        end
                        r.timeFs:SetText(string.format("%.1fs", d.left))
                        r:Show()
                    else
                        r:Hide()
                    end
                end
            elseif UnitExists("target") then
                local now = GetTime()
                for i = 1, MAX_TARGET_DEBUFFS do
                    local r = tgt.debuffBars[i]
                    local tex, count, debuffType = UnitDebuff("target", i)
                    if tex then
                        r.debuffIndex = i
                        r.icon:SetTexture(tex)

                        -- Resolve debuff name via tooltip scanner or texture
                        local dName = GetTargetDebuffName(i, tex)
                        r.nameFs:SetText(dName or "Debuff")

                        -- Duration tracking
                        local timer = GetOrInitDebuffTimer(dName, now)
                        local elapsed = now - timer.start
                        local left = timer.dur - elapsed
                        if left <= 0 then
                            timer.start = now
                            left = timer.dur
                            elapsed = 0
                        end
                        local pct = left / timer.dur
                        if pct > 1 then pct = 1 elseif pct < 0 then pct = 0 end
                        r.bar:SetValue(pct)

                        -- Color
                        local col = GetDebuffBarColor(debuffType, dName)
                        B:SetBarColor(r.bar, col.r, col.g, col.b)
                        local bg = r.bar.buiBg or r.bar.euiBg
                        if bg then
                            bg:SetVertexColor(col.r * 0.25, col.g * 0.25, col.b * 0.25)
                            bg:SetAlpha(0.85)
                        end

                        -- Tick Damage in Center
                        local tickVal = GetSpellTickDamage(dName)
                        if tickVal and tickVal > 0 then
                            r.centerFs:SetText(tostring(tickVal))
                            r.tickDmg = tickVal
                        else
                            r.centerFs:SetText("")
                            r.tickDmg = nil
                        end

                        -- Time / Stacks on Right
                        if count and count > 1 then
                            r.timeFs:SetText(string.format("%.1fs (%d)", left, count))
                        else
                            r.timeFs:SetText(string.format("%.1fs", left))
                        end

                        r:Show()
                        shownCount = shownCount + 1
                    else
                        r:Hide()
                    end
                end
            else
                for i = 1, MAX_TARGET_DEBUFFS do
                    tgt.debuffBars[i]:Hide()
                end
            end
        end

        -- Target of Target update
        if self.tot then
            if UnitExists("targettarget") then
                local totName = UnitName("targettarget") or "Unknown"
                local totHp = UnitHealth("targettarget") or 0
                local totHpm = UnitHealthMax("targettarget") or 1
                if totHpm <= 0 then totHpm = 1 end
                local totPctVal = B:Percent(totHp, totHpm)

                self.tot.nameText:SetText(totName)
                self.tot.hpBar:SetValue(totPctVal)
                local totPctInt = math.floor(totPctVal * 100 + 0.5)
                self.tot.hpText:SetText(tostring(totPctInt) .. "%")
                self.tot:Show()
            else
                self.tot:Hide()
            end
        end
    end

    ---------------------------------------------------------------------------
    --  3. Update Pet Frame
    ---------------------------------------------------------------------------
    if self.pet then
        if UnitExists("pet") then
            local petName = UnitName("pet") or "Pet"
            local petHp = UnitHealth("pet") or 0
            local petHpm = UnitHealthMax("pet") or 1
            if petHpm <= 0 then petHpm = 1 end
            local petPctVal = B:Percent(petHp, petHpm)

            self.pet.nameText:SetText(petName)
            self.pet.hpBar:SetValue(petPctVal)
            local petPctInt = math.floor(petPctVal * 100 + 0.5)
            self.pet.hpText:SetText(tostring(petPctInt) .. "%")

            local petP = UnitMana("pet") or 0
            local petPm = UnitManaMax("pet") or 1
            if petPm <= 0 then petPm = 1 end
            self.pet.pBar:SetValue(B:Percent(petP, petPm))
            self.pet:Show()
        else
            self.pet:Hide()
        end
    end

    ---------------------------------------------------------------------------
    --  4. Update Encounter Stack (Elites, Guardians, Bosses)
    ---------------------------------------------------------------------------
    local enc = self.enc
    local units = state and state.units
    if not units or table.getn(units) == 0 then
        if type(AZS_UNITS) == "table" and table.getn(AZS_UNITS) > 0 then
            units = AZS_UNITS
        end
    end

    if (state and state.demo) or B.unlocked then
        units = {
            { kind = "boss", name = "Stitches", hp = 142500, hpm = 220000 },
            { kind = "guardian", name = "Shrine Warden", hp = 48000, hpm = 65000 },
            { kind = "elite", name = "Skeletal Fiend", hp = 12000, hpm = 18000 },
            { kind = "elite", name = "Rotting Ghoul", hp = 8400, hpm = 14000 },
        }
    end

    local nUnits = units and table.getn(units) or 0
    local bossRows = {}
    for i = 1, nUnits do
        local u = units[i]
        local uKind = u.kind
        if uKind == "boss" or uKind == "final" or uKind == "guardian" or uKind == "elite" then
            table.insert(bossRows, u)
        end
    end

    local nBosses = table.getn(bossRows)
    if nBosses == 0 then
        enc:Hide()
    else
        enc:Show()
        enc.header.value:SetText(tostring(nBosses))

        local shownCount = nBosses
        if shownCount > MAX_ENCOUNTER_ROWS then
            shownCount = MAX_ENCOUNTER_ROWS
        end
        enc:SetHeight(22 + shownCount * 21 + 4)

        -- Dynamic anchor below TimerFrame if not custom moved by user
        if not (B.db and B.db.positions and B.db.positions["encounters"]) then
            enc:ClearAllPoints()
            local timerF = BUI_TimerFrame or EUI_TimerFrame
            if timerF and (timerF:IsShown() or B:IsEnabled("timer")) then
                enc:SetPoint("TOPRIGHT", timerF, "BOTTOMRIGHT", 0, -6)
            else
                enc:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -165)
            end
        end

        for i = 1, MAX_ENCOUNTER_ROWS do
            local r = enc.rows[i]
            if i <= shownCount then
                local bData = bossRows[i]
                local bKind = bData.kind or "elite"

                local bHp = tonumber(bData.hp) or 0
                local bHpm = tonumber(bData.hpm) or 1
                if bHpm <= 0 then bHpm = 1 end
                local bPct = B:Percent(bHp, bHpm)
                local bPctInt = math.floor(bPct * 100 + 0.5)

                r.bar:SetValue(bPct)

                -- Kind Badge and Bar Color
                if bKind == "final" then
                    r.badgeFs:SetText("[FINAL]")
                    r.badgeFs:SetTextColor(1.0, 0.35, 0.45)
                    B:SetBarColor(r.bar, 0.85, 0.15, 0.35)
                elseif bKind == "boss" then
                    r.badgeFs:SetText("[BOSS]")
                    r.badgeFs:SetTextColor(1.0, 0.30, 0.30)
                    B:SetBarColor(r.bar, 0.82, 0.18, 0.18)
                elseif bKind == "guardian" then
                    r.badgeFs:SetText("[GUARD]")
                    r.badgeFs:SetTextColor(1.0, 0.78, 0.15)
                    B:SetBarColor(r.bar, 0.88, 0.62, 0.12)
                else -- elite
                    r.badgeFs:SetText("[ELITE]")
                    r.badgeFs:SetTextColor(0.35, 0.80, 1.0)
                    B:SetBarColor(r.bar, 0.20, 0.55, 0.85)
                end

                r.unitName = bData.name or "Elite"
                r.unitHp = bHp
                r.unitHpm = bHpm
                r.unitPct = bPctInt

                r.nameFs:SetText(bData.name or "Elite")
                r.nameFs:SetTextColor(1, 1, 1)

                local remHp = B:Short(bHp)
                local maxHp = B:Short(bHpm)
                r.hpFs:SetText(string.format("%s / %s (%d%%)", remHp, maxHp, bPctInt))
                r.hpFs:SetTextColor(1, 1, 1)

                r:Show()
            else
                r:Hide()
            end
        end
    end
end

B:RegisterModule("unitframes", mod)
