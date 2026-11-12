-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  UnitFrames.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
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
local L = B.L
local mod = {}
mod.label = "Unit Frames"
mod.alwaysActive = true
-- Blizzard unit frames are suppressed via OnShow; turning it off takes a /reload.
mod.reloadOnToggle = true
mod.hint = "Hero, target, target of target and the elites & bosses list."
mod.fontList = {}

local HEALTH_TEXT_VALUES = {
    { value = "both", label = "Value and percent" },
    { value = "percent", label = "Percent" },
    { value = "value", label = "Current value" },
    { value = "curmax", label = "Current / max" },
    { value = "none", label = "Hidden" },
}

mod.options = {
    { type = "section", label = "Hero & target" },
    { type = "range", key = "heroWidth", label = "Hero width", min = 160, max = 320, step = 10, default = 210, format = "%d px" },
    { type = "range", key = "heroHeight", label = "Hero height", min = 40, max = 80, step = 2, default = 46, format = "%d px" },
    { type = "range", key = "targetWidth", label = "Target width", min = 160, max = 320, step = 10, default = 210, format = "%d px" },
    { type = "range", key = "targetHeight", label = "Target height", min = 40, max = 80, step = 2, default = 46, format = "%d px" },
    { type = "range", key = "fontSize", label = "Text size", hint = "Added to the global text size.", min = -3, max = 4, step = 1, default = 0, format = "%d" },
    { type = "choice", key = "healthText", label = "Health text", default = "both", values = HEALTH_TEXT_VALUES },
    { type = "toggle", key = "shortNumbers", label = "Short numbers", hint = "Shows 12.5K instead of 12500.", default = true },
    { type = "toggle", key = "showNames", label = "Show names", default = true },
    { type = "toggle", key = "showLevel", label = "Show level and badges", default = true },
    { type = "toggle", key = "showPowerBar", label = "Show power bars", default = true },
    { type = "toggle", key = "showShieldBar", label = "Show shield bar", default = true },
    { type = "toggle", key = "showXpBar", label = "Show XP bar", default = true },
    { type = "toggle", db = "colorHealthByClass", label = "Class-coloured health", default = true },
    { type = "toggle", key = "customHealthColor", label = "Custom health colour", hint = "Used when class-coloured health is off, instead of the accent.", default = false },
    { type = "color", key = "healthColor", label = "Health colour", default = { r = 0.20, g = 0.80, b = 0.20 }, depends = "customHealthColor" },
    { type = "toggle", key = "showDebuffs", label = "Target debuff bars", default = true },
    { type = "range", key = "maxDebuffs", label = "Max debuff bars", min = 1, max = 6, step = 1, default = 6, format = "%d", depends = "showDebuffs" },
    { type = "toggle", key = "showToT", label = "Target of target", default = true },
    { type = "toggle", key = "showPet", label = "Pet frame", default = true },

    { type = "section", label = "Elites & bosses" },
    { type = "range", key = "encWidth", label = "Width", min = 180, max = 400, step = 10, default = 260, format = "%d px" },
    { type = "range", key = "encMaxRows", label = "Max rows", min = 1, max = 20, step = 1, default = 20, format = "%d" },
    { type = "range", key = "encRowHeight", label = "Row height", min = 12, max = 28, step = 1, default = 18, format = "%d px" },
    { type = "toggle", key = "encShowTags", label = "Show kind tags", hint = "[BOSS], [GUARD], [ELITE] in front of the name.", default = true },
    { type = "choice", key = "encHealthText", label = "Health text", default = "curmaxpct", values = {
        { value = "curmaxpct", label = "Current / max (percent)" },
        { value = "both", label = "Value and percent" },
        { value = "percent", label = "Percent" },
        { value = "value", label = "Current value" },
        { value = "none", label = "Hidden" },
    } },

    { type = "section", label = "Enemy colours" },
    { type = "note", label = "Target frame, elites & bosses list and nameplates use these colours." },
    { type = "color", key = "colorBoss", label = "Boss", default = { r = 0.86, g = 0.20, b = 0.20 } },
    { type = "color", key = "colorFinal", label = "Final boss", default = { r = 0.86, g = 0.16, b = 0.42 } },
    { type = "color", key = "colorGuardian", label = "Rare guardian", default = { r = 1.00, g = 0.78, b = 0.15 } },
    { type = "color", key = "colorElite", label = "Elite", default = { r = 0.25, g = 0.60, b = 1.00 } },
    { type = "color", key = "colorNormal", label = "Normal enemy", default = { r = 0.58, g = 0.42, b = 0.92 } },

    { type = "section", label = "Party" },
    { type = "toggle", key = "showParty", label = "Party frames", default = true },
    { type = "range", key = "partyWidth", label = "Party frame width", min = 90, max = 200, step = 5, default = 130, format = "%d px", depends = "showParty" },
    { type = "range", key = "partySpacing", label = "Party spacing", min = 0, max = 20, step = 1, default = 6, format = "%d px", depends = "showParty" },
}

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

-------------------------------------------------------------------------------
--  Style & option helpers
-------------------------------------------------------------------------------
-- Defaults that differ per style: the round frames are one health bar
-- without power / xp / shield lines. Sizes and positions stay those of the
-- classic layout in both styles.
local STYLE_DEFAULTS = {
    showPowerBar = { sharp = true, round = false },
    showXpBar = { sharp = true, round = false },
    showShieldBar = { sharp = true, round = false },
}

local function Opt(key, default)
    local sd = STYLE_DEFAULTS[key]
    if sd then
        if B:IsRound() then default = sd.round else default = sd.sharp end
    end
    return B:ModOpt("unitframes", key, default)
end

local function OptColor(key, def)
    local c = Opt(key, def)
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return def.r, def.g, def.b
end

-- Font strings of this module remember their base size for the text size option.
local function Font(parent, size, justify)
    local fs = B:Font(parent, size, justify)
    table.insert(mod.fontList, { fs = fs, size = size })
    return fs
end

-- Corner radius for a panel that can shrink to minHeight: capped at half
-- of it, else the round panel's centre strip gets a negative height.
local function PanelRadius(minHeight)
    local rad = (B.db and B.db.cornerRadius) or 10
    local cap = math.floor(minHeight / 2)
    if rad > cap then rad = cap end
    if rad < 0 then rad = 0 end
    return rad
end

-- Inset that keeps square bar corners inside a round corner: r * (1 - 1/sqrt 2).
local function RoundInset(radius)
    local p = math.ceil(radius * 0.3)
    if p < 2 then p = 2 end
    return p
end

-- Background in the active style; returns the inner padding for the bars.
local function FramePanel(f, minHeight, alpha)
    if B:IsRound() then
        local rad = PanelRadius(minHeight)
        B:Panel(f, rad)
        return RoundInset(rad)
    end
    B:Backdrop(f, alpha)
    return 1
end

-- Thin bar: RoundBar with round caps in the round style, StatusBar in sharp.
local function ThinBar(parent, height, r, g, b)
    if B:IsRound() then
        local bar = B:RoundBar(parent, height)
        if r then
            bar.buiR, bar.buiG, bar.buiB = r, g, b
            bar:SetFillColor(r, g, b)
        end
        return bar
    end
    local sb = B:Bar(parent, nil, r, g, b)
    sb:SetHeight(height)
    return sb
end

-- Value / colour setters that work on both StatusBars and RoundBars.
local function SetBarFill(bar, v)
    if type(bar.SetFill) == "function" then
        bar:SetFill(v)
    else
        bar:SetValue(v)
    end
end

local function SetBarRGB(bar, r, g, b)
    if type(bar.SetFillColor) == "function" then
        bar.buiR, bar.buiG, bar.buiB = r, g, b
        bar:SetFillColor(r, g, b)
    else
        B:SetBarColor(bar, r, g, b)
    end
end

local function FormatNumber(v, short)
    if short then return B:Short(v) end
    return string.format("%d", math.floor((tonumber(v) or 0) + 0.5))
end

-- mode: "both" (12K | 52%), "percent", "value", "curmax" (12K / 20K),
-- "curmaxpct" (12K / 20K (52%)), "none".
local function FormatHealth(cur, max, pct, mode, short)
    local pctInt = math.floor((pct or 0) * 100 + 0.5)
    if mode == "none" then
        return ""
    elseif mode == "percent" then
        return string.format("%d%%", pctInt)
    elseif mode == "value" then
        return FormatNumber(cur, short)
    elseif mode == "curmax" then
        return FormatNumber(cur, short) .. " / " .. FormatNumber(max, short)
    elseif mode == "curmaxpct" then
        return string.format("%s / %s (%d%%)", FormatNumber(cur, short), FormatNumber(max, short), pctInt)
    end
    return string.format("%s | %d%%", FormatNumber(cur, short), pctInt)
end

-- Frame layout presets. sharpHpOff: health height = frame height - off with
-- the power bar shown (the old fixed layout); powerH: round power bar height.
local LAYOUT_BIG   = { sharpHpOff = 11, sharpPowerGap = 2, powerH = 4 }
local LAYOUT_SMALL = { sharpHpOff = 7, sharpPowerGap = 1, powerH = 3 }
local LAYOUT_PARTY = { sharpHpOff = 10, sharpPowerGap = 1, powerH = 4 }

-- Stacks health, power and the thin xp / shield slot inside a frame whose
-- health bar is anchored at the top (TOPLEFT/TOPRIGHT, inset f.buiPad).
local function LayoutStack(f, h, cfg, showPower, slot)
    local round = B:IsRound()
    local hpH
    if round then
        hpH = h - 2 * (f.buiPad or 3)
        if showPower then hpH = hpH - cfg.powerH - 2 end
        if slot then hpH = hpH - 4 end
    elseif showPower then
        hpH = h - cfg.sharpHpOff
    else
        hpH = h - 2
        if slot then hpH = hpH - 3 end
    end
    if hpH < 6 then hpH = 6 end
    f:SetHeight(h)
    f.hpBar:SetHeight(hpH)

    local below = f.hpBar
    if f.pBar then
        local gap = round and 2 or cfg.sharpPowerGap
        f.pBar:ClearAllPoints()
        f.pBar:SetPoint("TOPLEFT", f.hpBar, "BOTTOMLEFT", 0, -gap)
        f.pBar:SetPoint("TOPRIGHT", f.hpBar, "BOTTOMRIGHT", 0, -gap)
        if showPower then
            f.pBar:Show()
            below = f.pBar
        else
            f.pBar:Hide()
        end
    end
    local slotGap = round and 2 or 1
    local slotBars = { f.shBar, f.xpBar }
    for i = 1, 2 do
        local sb = slotBars[i]
        if sb then
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -slotGap)
            sb:SetPoint("TOPRIGHT", below, "BOTTOMRIGHT", 0, -slotGap)
        end
    end
end

-------------------------------------------------------------------------------
--  Round style: the health bar is the frame. It fills the whole frame with
--  the frame's corner radius; name, level / status and the health value sit
--  inside it, as in the classic layout. Power, xp and shield lines are off by
--  default and, when switched on, run as thin lines along the bottom edge.
-------------------------------------------------------------------------------
local function FullBar(f, w, h, showPower, showSlot, big)
    f:SetWidth(w)
    f:SetHeight(h)
    local rad = (B.db and B.db.cornerRadius) or 10
    if rad > h / 2 then rad = math.floor(h / 2) end
    local pad = 10
    if rad > pad then pad = rad end

    f.hpBar:ClearAllPoints()
    f.hpBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.hpBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    B:SetBarRadius(f.hpBar, rad)
    B:SetBarTrackColor(f.hpBar, 0, 0, 0, 0.35)

    f.nameText:ClearAllPoints()
    f.hpText:ClearAllPoints()
    f.hpText:SetPoint("RIGHT", f, "RIGHT", -pad, 0)
    f.hpText:SetJustifyH("RIGHT")
    local sub = f.lvlText or f.badgeText
    if big and h >= 34 then
        -- Two text rows: name on top, level / status below.
        f.nameText:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -6)
        if sub then
            sub:ClearAllPoints()
            sub:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, 6)
            sub:SetJustifyH("LEFT")
        end
    else
        f.nameText:SetPoint("LEFT", f, "LEFT", pad, 0)
        if sub then
            sub:ClearAllPoints()
            sub:SetPoint("LEFT", f.nameText, "RIGHT", 4, 0)
        end
    end
    -- Room for the health text: "12.5K | 85%" on big frames, "85%" on small.
    if big then
        f.nameText:SetWidth(w - 2 * pad - 90)
    else
        f.nameText:SetWidth(w - 2 * pad - 36)
    end
    f.nameText:SetJustifyH("LEFT")

    -- Optional thin lines inside the bottom edge.
    local y = 3
    if f.pBar then
        f.pBar:ClearAllPoints()
        f.pBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", rad, y)
        f.pBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -rad, y)
        if showPower then
            f.pBar:Show()
            y = y + 4
        else
            f.pBar:Hide()
        end
    end
    local slotBars = { f.shBar, f.xpBar }
    for i = 1, 2 do
        local sb = slotBars[i]
        if sb then
            sb:ClearAllPoints()
            sb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", rad, y)
            sb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -rad, y)
            if not showSlot then sb:Hide() end
        end
    end
end

-- Health text: one string in the sharp style, split into "current / max"
-- (left) and percent (right) on the round cards.
local function SetHealthTexts(f, cur, max, pct, mode, short)
    if not f.hpLeft then
        f.hpText:SetText(FormatHealth(cur, max, pct, mode, short))
        return
    end
    local pctText = string.format("%d%%", math.floor((pct or 0) * 100 + 0.5))
    if mode == "none" then
        f.hpLeft:SetText("")
        f.hpText:SetText("")
    elseif mode == "percent" then
        f.hpLeft:SetText("")
        f.hpText:SetText(pctText)
    elseif mode == "value" then
        f.hpLeft:SetText(FormatNumber(cur, short))
        f.hpText:SetText("")
    elseif mode == "curmax" then
        f.hpLeft:SetText(FormatNumber(cur, short) .. " / " .. FormatNumber(max, short))
        f.hpText:SetText("")
    else
        f.hpLeft:SetText(FormatNumber(cur, short) .. " / " .. FormatNumber(max, short))
        f.hpText:SetText(pctText)
    end
end

-- Hover tint in a normal layer: this engine draws the HIGHLIGHT layer all
-- the time, not only under the mouse. Shown from OnEnter, hidden on OnLeave.
local function HoverTint(owner, region, alpha)
    local hl = owner:CreateTexture(nil, "OVERLAY")
    B:Solid(hl, 1, 1, 1, alpha or 0.12)
    hl:SetAllPoints(region or owner)
    hl:Hide()
    return hl
end

-- Left click targets the unit, right click opens the game's own unit menu
-- (raid target icons, invite, trade ...). The stock frames stay hidden, but
-- their dropdowns are initialised by the game and still work.
local function OpenUnitMenu(menuName)
    local dd = menuName and getglobal(menuName)
    if dd and type(ToggleDropDownMenu) == "function" then
        ToggleDropDownMenu(1, nil, dd, "cursor")
    end
end

local function UnitClick(unit, button, menuName)
    if B.unlocked or not unit or not UnitExists(unit) then return end
    if button == "RightButton" then
        if menuName then OpenUnitMenu(menuName) end
    elseif not UnitIsUnit(unit, "target") then
        TargetUnit(unit)
    end
end

-- For plain frames (no OnClick): mouse-up carries the button in arg1.
local function MakeUnitClickable(f, unit, menuName)
    f.unitId = unit
    f.unitMenu = menuName
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function()
        UnitClick(this.unitId, arg1, this.unitMenu)
    end)
end

-- Raid target icon on the top edge, on its own frame above the bars.
local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function AddRaidIcon(f, size)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetWidth(size)
    holder:SetHeight(size)
    holder:SetPoint("CENTER", f, "TOP", 0, 0)
    holder:SetFrameLevel(f:GetFrameLevel() + 10)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(holder)
    tex:SetTexture(RAID_ICON_TEXTURE)
    holder:Hide()
    f.raidIcon = holder
    f.raidIconTex = tex
end

-- index 1..8 (star .. skull) or nil. The atlas is a 4 x 4 grid.
local function SetRaidIcon(f, index)
    local holder = f and f.raidIcon
    if not holder then return end
    index = tonumber(index)
    if not index or index < 1 or index > 8 then
        holder:Hide()
        return
    end
    if type(SetRaidTargetIconTexture) == "function" then
        SetRaidTargetIconTexture(f.raidIconTex, index)
    else
        local col = math.mod(index - 1, 4)
        local row = math.floor((index - 1) / 4)
        f.raidIconTex:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
    end
    holder:Show()
end

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
    SuppressBlizzardFrame(PartyMemberFrame1)
    SuppressBlizzardFrame(PartyMemberFrame2)
    SuppressBlizzardFrame(PartyMemberFrame3)
    SuppressBlizzardFrame(PartyMemberFrame4)
    SuppressBlizzardFrame(PartyMemberFrame1PetFrame)
    SuppressBlizzardFrame(PartyMemberFrame2PetFrame)
    SuppressBlizzardFrame(PartyMemberFrame3PetFrame)
    SuppressBlizzardFrame(PartyMemberFrame4PetFrame)
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_UnitFrames", UIParent)
    root:SetAllPoints(UIParent)
    self.frame = root
    -- Frames are built once: a style switch needs /reload.
    local round = B:IsRound()
    self.round = round

    self:HideBlizzardFrames()

    ---------------------------------------------------------------------------
    --  1. Hero Frame (210 x 46)
    ---------------------------------------------------------------------------
    local hero = CreateFrame("Frame", "BUI_HeroFrame", root)
    BUI_PlayerFrame = hero
    hero:SetWidth(210)
    hero:SetHeight(46)
    -- Round style: round panel, bars inset so they stay inside its corners.
    local bigPad = FramePanel(hero, 40, 0.90)
    hero.buiPad = bigPad

    -- Health Bar (208 x 35) - Dominates frame
    local hpBar = B:Bar(hero, nil, 0.2, 0.8, 0.2)
    hpBar:SetPoint("TOPLEFT", hero, "TOPLEFT", bigPad, -bigPad)
    hpBar:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -bigPad, -bigPad)
    hpBar:SetHeight(35)
    hero.hpBar = hpBar

    -- Player Name (inside Health Bar, TOPLEFT aligned)
    local nameText = Font(hpBar, 11, "LEFT")
    nameText:SetPoint("TOPLEFT", hpBar, "TOPLEFT", 6, round and -2 or -3)
    nameText:SetWidth(110)
    nameText:SetHeight(14)
    nameText:SetTextColor(1, 1, 1)
    hero.nameText = nameText

    -- Health Text (inside Health Bar, RIGHT aligned, e.g. "270 | 100%")
    local hpText = Font(hpBar, 11, "RIGHT")
    hpText:SetPoint("RIGHT", hpBar, "RIGHT", -6, 0)
    hpText:SetWidth(90)
    hpText:SetHeight(16)
    hpText:SetTextColor(1, 1, 1)
    hero.hpText = hpText

    -- Level badge (inside Health Bar, BOTTOMLEFT aligned)
    local lvlText = Font(hpBar, 8, "LEFT")
    lvlText:SetPoint("BOTTOMLEFT", hpBar, "BOTTOMLEFT", 6, round and 2 or 4)
    lvlText:SetWidth(60)
    lvlText:SetHeight(12)
    B:Accent(lvlText, "text")
    hero.lvlText = lvlText


    -- Power Bar (208 x 6) Mana / Rage / Energy; thin round-capped bar in the round style
    local pBar = ThinBar(hero, round and LAYOUT_BIG.powerH or 6, 0.0, 0.55, 1.0)
    pBar:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -2)
    pBar:SetPoint("TOPRIGHT", hpBar, "BOTTOMRIGHT", 0, -2)
    hero.pBar = pBar

    local pText = Font(pBar, 8, "CENTER")
    pText:SetPoint("CENTER", pBar, "CENTER", 0, 0)
    -- The round power bar is too thin to carry a number.
    if round then pText:Hide() end
    hero.pText = pText

    -- Shield Bar (absorb indicator overlay on power bar bottom)
    local shBar = ThinBar(hero, 2, 0.25, 0.70, 1.00)
    shBar:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -1)
    shBar:SetPoint("TOPRIGHT", pBar, "BOTTOMRIGHT", 0, -1)
    shBar:Hide()
    hero.shBar = shBar

    -- XP Bar (2px Cyber Accent at bottom)
    local xpBar = ThinBar(hero, 2)
    xpBar:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -1)
    xpBar:SetPoint("TOPRIGHT", pBar, "BOTTOMRIGHT", 0, -1)
    hero.xpBar = xpBar
    -- Shield and XP share the slot: the shield draws on top while it is up.
    if shBar.SetFrameLevel and xpBar.GetFrameLevel then
        shBar:SetFrameLevel(xpBar:GetFrameLevel() + 1)
    end

    MakeUnitClickable(hero, "player", "PlayerFrameDropDown")
    AddRaidIcon(hero, 18)
    B:RegisterMover(hero, "hero", L["Hero Frame"], "BOTTOM", "BOTTOM", -220, 140)
    self.hero = hero

    ---------------------------------------------------------------------------
    --  2. Target Frame (210 x 46)
    ---------------------------------------------------------------------------
    local tgt = CreateFrame("Frame", "BUI_TargetFrame", root)
    tgt:SetWidth(210)
    tgt:SetHeight(46)
    tgt.buiPad = FramePanel(tgt, 40, 0.90)

    -- Target Health Bar (208 x 35)
    local tgtHpBar = B:Bar(tgt, nil, 0.8, 0.2, 0.2)
    tgtHpBar:SetPoint("TOPLEFT", tgt, "TOPLEFT", tgt.buiPad, -tgt.buiPad)
    tgtHpBar:SetPoint("TOPRIGHT", tgt, "TOPRIGHT", -tgt.buiPad, -tgt.buiPad)
    tgtHpBar:SetHeight(35)
    tgt.hpBar = tgtHpBar

    -- Target Name (inside Health Bar, TOPLEFT aligned)
    local tgtNameText = Font(tgtHpBar, 11, "LEFT")
    tgtNameText:SetPoint("TOPLEFT", tgtHpBar, "TOPLEFT", 6, round and -2 or -3)
    tgtNameText:SetWidth(115)
    tgtNameText:SetHeight(14)
    tgtNameText:SetTextColor(1, 1, 1)
    tgt.nameText = tgtNameText

    -- Target Badge (boss/elite/enraged status inside Health Bar, BOTTOMLEFT aligned)
    local badgeText = Font(tgtHpBar, 8, "LEFT")
    badgeText:SetPoint("BOTTOMLEFT", tgtHpBar, "BOTTOMLEFT", 6, round and 2 or 4)
    badgeText:SetWidth(100)
    badgeText:SetHeight(12)
    tgt.badgeText = badgeText

    -- Target HP Text (inside Health Bar, RIGHT aligned, e.g. "118K | 52%")
    local tgtHpText = Font(tgtHpBar, 11, "RIGHT")
    tgtHpText:SetPoint("RIGHT", tgtHpBar, "RIGHT", -6, 0)
    tgtHpText:SetWidth(90)
    tgtHpText:SetHeight(16)
    tgtHpText:SetTextColor(1, 1, 1)
    tgt.hpText = tgtHpText

    -- Target Power Bar (208 x 6)
    local tgtPBar = ThinBar(tgt, round and LAYOUT_BIG.powerH or 6, 0.0, 0.55, 1.0)
    tgtPBar:SetPoint("TOPLEFT", tgtHpBar, "BOTTOMLEFT", 0, -2)
    tgtPBar:SetPoint("TOPRIGHT", tgtHpBar, "BOTTOMRIGHT", 0, -2)
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
        -- Square black frame only in the sharp style.
        if not round then
            B:Border(iconFrame, 0, 0, 0, 1)
        end

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
        local nameFs = Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetWidth(95)
        nameFs:SetHeight(12)
        r.nameFs = nameFs

        -- Tick Damage in the center
        local centerFs = Font(bar, 10, "CENTER")
        centerFs:SetPoint("CENTER", bar, "CENTER", 0, 0)
        centerFs:SetTextColor(1.0, 0.85, 0.20)
        r.centerFs = centerFs

        -- Time / Stacks on the right
        local timeFs = Font(bar, 9, "RIGHT")
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
                    GameTooltip:AddLine(string.format(L["Tick Damage: %d"], this.tickDmg), 1.0, 0.85, 0.20)
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

    MakeUnitClickable(tgt, "target", "TargetFrameDropDown")
    AddRaidIcon(tgt, 18)
    tgt:Hide()
    B:RegisterMover(tgt, "target", "Target Frame", "BOTTOM", "BOTTOM", 220, 140)
    self.target = tgt

    ---------------------------------------------------------------------------
    --  3. Target of Target Frame (110 x 24)
    ---------------------------------------------------------------------------
    local tot = CreateFrame("Frame", "BUI_TargetTargetFrame", tgt)
    tot:SetWidth(110)
    tot:SetHeight(24)
    tot:SetPoint("TOPLEFT", tgt, "TOPRIGHT", 6, 0)
    tot.buiPad = FramePanel(tot, 24, 0.90)

    local totHpBar = B:Bar(tot, nil, 0.8, 0.2, 0.2)
    totHpBar:SetPoint("TOPLEFT", tot, "TOPLEFT", tot.buiPad, -tot.buiPad)
    totHpBar:SetPoint("TOPRIGHT", tot, "TOPRIGHT", -tot.buiPad, -tot.buiPad)
    totHpBar:SetHeight(17)
    tot.hpBar = totHpBar

    local totName = Font(totHpBar, 9, "LEFT")
    totName:SetPoint("LEFT", totHpBar, "LEFT", 4, 0)
    totName:SetWidth(60)
    totName:SetHeight(12)
    tot.nameText = totName

    local totPct = Font(totHpBar, 9, "RIGHT")
    totPct:SetPoint("RIGHT", totHpBar, "RIGHT", -4, 0)
    totPct:SetWidth(38)
    totPct:SetHeight(12)
    tot.hpText = totPct

    local totPBar = ThinBar(tot, 3, 0.0, 0.55, 1.0)
    totPBar:SetPoint("TOPLEFT", totHpBar, "BOTTOMLEFT", 0, -1)
    totPBar:SetPoint("TOPRIGHT", totHpBar, "BOTTOMRIGHT", 0, -1)
    tot.pBar = totPBar

    MakeUnitClickable(tot, "targettarget", nil)
    tot:Hide()
    self.tot = tot

    ---------------------------------------------------------------------------
    --  4. Pet Frame (110 x 24)
    ---------------------------------------------------------------------------
    local pet = CreateFrame("Frame", "BUI_PetFrame", hero)
    pet:SetWidth(110)
    pet:SetHeight(24)
    pet:SetPoint("TOPRIGHT", hero, "BOTTOMRIGHT", 0, -8)
    pet.buiPad = FramePanel(pet, 24, 0.90)

    local petHpBar = B:Bar(pet, nil, 0.2, 0.8, 0.2)
    petHpBar:SetPoint("TOPLEFT", pet, "TOPLEFT", pet.buiPad, -pet.buiPad)
    petHpBar:SetPoint("TOPRIGHT", pet, "TOPRIGHT", -pet.buiPad, -pet.buiPad)
    petHpBar:SetHeight(17)
    pet.hpBar = petHpBar

    local petName = Font(petHpBar, 9, "LEFT")
    petName:SetPoint("LEFT", petHpBar, "LEFT", 4, 0)
    petName:SetWidth(60)
    petName:SetHeight(12)
    pet.nameText = petName

    local petPct = Font(petHpBar, 9, "RIGHT")
    petPct:SetPoint("RIGHT", petHpBar, "RIGHT", -4, 0)
    petPct:SetWidth(38)
    petPct:SetHeight(12)
    pet.hpText = petPct

    local petPBar = ThinBar(pet, 3, 1.0, 0.50, 0.25)
    petPBar:SetPoint("TOPLEFT", petHpBar, "BOTTOMLEFT", 0, -1)
    petPBar:SetPoint("TOPRIGHT", petHpBar, "BOTTOMRIGHT", 0, -1)
    pet.pBar = petPBar

    MakeUnitClickable(pet, "pet", "PetFrameDropDown")
    pet:Hide()
    self.pet = pet

    ---------------------------------------------------------------------------
    --  5. Encounter / Elite & Boss Frame (ENC_WIDTH x dynamic)
    ---------------------------------------------------------------------------
    local enc = CreateFrame("Frame", "BUI_EncounterFrame", root)
    enc:SetWidth(ENC_WIDTH)
    enc:SetHeight(130)
    FramePanel(enc, 40, 0.88)

    enc.header = B:Header(enc, L["ELITES & BOSSES"], 18)

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

        local badgeFs = Font(bar, 9, "LEFT")
        badgeFs:SetPoint("LEFT", bar, "LEFT", 3, 0)
        badgeFs:SetWidth(40)
        badgeFs:SetHeight(12)
        r.badgeFs = badgeFs

        local rHpFs = Font(bar, 9, "RIGHT")
        rHpFs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
        rHpFs:SetWidth(100)
        rHpFs:SetHeight(12)
        r.hpFs = rHpFs

        local rNameFs = Font(bar, 9, "LEFT")
        rNameFs:SetPoint("LEFT", badgeFs, "RIGHT", 3, 0)
        rNameFs:SetPoint("RIGHT", rHpFs, "LEFT", -3, 0)
        rNameFs:SetHeight(12)
        r.nameFs = rNameFs

        -- Hover highlight (normal layer on the bar, shown from OnEnter)
        r.hl = HoverTint(bar, bar, 0.12)

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
            if this.hl then this.hl:Show() end
            if this.unitName then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(this.unitName, 1, 1, 1)
                if this.unitHp and this.unitHpm then
                    GameTooltip:AddLine(string.format(L["Health: %d / %d (%d%%)"], this.unitHp, this.unitHpm, this.unitPct or 0), 1, 0.82, 0)
                end
                GameTooltip:AddLine(L["Click to target"], 0, 0.9, 1)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function()
            if this.hl then this.hl:Hide() end
            GameTooltip:Hide()
        end)

        r:Hide()
        rows[i] = r
    end
    enc.rows = rows

    enc:Hide()
    B:RegisterMover(enc, "encounters", L["Elites & Bosses"], "TOPRIGHT", "TOPRIGHT", -12, -340)
    self.enc = enc

    ---------------------------------------------------------------------------
    --  6. Party Frames (4 horizontal side-by-side frames: 538 x 30)
    --  Positioned between Hero Frame (Y=140) and DataBar (Y=24) at Y=68
    ---------------------------------------------------------------------------
    local partyRoot = CreateFrame("Frame", "BUI_PartyFrames", root)
    partyRoot:SetWidth(538)
    partyRoot:SetHeight(30)
    self.partyRoot = partyRoot

    local partyFrames = {}
    for i = 1, 4 do
        local pf = CreateFrame("Button", "BUI_PartyFrame" .. i, partyRoot)
        pf:SetWidth(130)
        pf:SetHeight(30)
        pf:SetPoint("TOPLEFT", partyRoot, "TOPLEFT", (i - 1) * 136, 0)
        pf.buiPad = FramePanel(pf, 30, 0.90)

        local hpBar = B:Bar(pf, nil, 0.2, 0.8, 0.2)
        hpBar:SetPoint("TOPLEFT", pf, "TOPLEFT", pf.buiPad, -pf.buiPad)
        hpBar:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -pf.buiPad, -pf.buiPad)
        hpBar:SetHeight(20)
        pf.hpBar = hpBar

        local nameFs = Font(hpBar, 9, "LEFT")
        nameFs:SetPoint("LEFT", hpBar, "LEFT", 4, 0)
        nameFs:SetWidth(72)
        nameFs:SetHeight(12)
        nameFs:SetTextColor(1, 1, 1)
        pf.nameText = nameFs

        local hpFs = Font(hpBar, 9, "RIGHT")
        hpFs:SetPoint("RIGHT", hpBar, "RIGHT", -4, 0)
        hpFs:SetWidth(48)
        hpFs:SetHeight(12)
        hpFs:SetTextColor(1, 1, 1)
        pf.hpText = hpFs

        local pBar = ThinBar(pf, round and LAYOUT_PARTY.powerH or 5, 0.0, 0.55, 1.0)
        pBar:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -1)
        pBar:SetPoint("TOPRIGHT", hpBar, "BOTTOMRIGHT", 0, -1)
        pf.pBar = pBar

        -- Hover highlight (normal layer on the health bar, shown from OnEnter)
        pf.hl = HoverTint(hpBar, hpBar, 0.12)

        pf:EnableMouse(true)
        if pf.RegisterForClicks then
            pf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        pf.unitId = "party" .. i
        pf.unitMenu = "PartyMemberFrame" .. i .. "DropDown"
        pf:SetScript("OnClick", function()
            UnitClick(this.unitId, arg1, this.unitMenu)
        end)
        AddRaidIcon(pf, 14)
        pf:SetScript("OnEnter", function()
            if this.hl then this.hl:Show() end
            local unit = this.unitId
            if unit and UnitExists(unit) then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetUnit(unit)
                GameTooltip:Show()
            end
        end)
        pf:SetScript("OnLeave", function()
            if this.hl then this.hl:Hide() end
            GameTooltip:Hide()
        end)

        pf:Hide()
        partyFrames[i] = pf
    end
    self.partyFrames = partyFrames

    partyRoot:Hide()
    B:RegisterMover(partyRoot, "party", L["Party Frames"], "BOTTOM", "BOTTOM", 0, 68)

    -- Separately placed frames: Core's scale / opacity / visibility act on these
    -- (pet and target of target are children of hero and target).
    self.lookFrames = { hero, tgt, enc, partyRoot }

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

-- Sizes, layout, text size and element visibility from the module settings.
-- Called after Create and after every option change; safe to repeat.
function mod:ApplyOptions()
    if not self.hero then return end
    local round = self.round
    -- Enemy colours from the settings into the shared kind colour table.
    local kindKeys = { boss = "colorBoss", final = "colorFinal", guardian = "colorGuardian", elite = "colorElite", normal = "colorNormal" }
    for kind, optKey in pairs(kindKeys) do
        local c = B:ModOpt("unitframes", optKey, nil)
        local target = B.KIND_COLORS[kind]
        if target then
            if not target.buiDefault then
                target.buiDefault = { r = target.r, g = target.g, b = target.b }
            end
            local src = (type(c) == "table" and c.r and c) or target.buiDefault
            target.r, target.g, target.b = src.r, src.g, src.b
        end
    end
    -- The options page shows (and resets to) the active style's defaults.
    for i = 1, table.getn(self.options or {}) do
        local entry = self.options[i]
        local sd = entry.key and STYLE_DEFAULTS[entry.key]
        if sd then
            if round then entry.default = sd.round else entry.default = sd.sharp end
        end
    end
    local showPower = Opt("showPowerBar", true)
    local showNames = Opt("showNames", true)
    local showLevel = Opt("showLevel", true)

    -- Text size offset on top of the global size.
    local fontOff = math.floor(tonumber(Opt("fontSize", 0)) or 0)
    for i = 1, table.getn(self.fontList) do
        local e = self.fontList[i]
        e.fs.buiSize = e.size + fontOff
        B:ApplyFont(e.fs)
    end

    -- Hero
    local hero = self.hero
    local heroW = Opt("heroWidth", 210)
    hero:SetWidth(heroW)
    local xpSlot = Opt("showXpBar", true) or Opt("showShieldBar", true)
    if round then
        FullBar(hero, heroW, Opt("heroHeight", 46), showPower, xpSlot, true)
    else
        LayoutStack(hero, Opt("heroHeight", 46), LAYOUT_BIG, showPower, xpSlot)
        hero.nameText:SetWidth(heroW - 100)
    end
    if showNames then hero.nameText:Show() else hero.nameText:Hide() end
    if showLevel then hero.lvlText:Show() else hero.lvlText:Hide() end
    if Opt("showXpBar", true) then hero.xpBar:Show() else hero.xpBar:Hide() end
    if not Opt("showShieldBar", true) then hero.shBar:Hide() end

    -- Target (the sharp layout keeps its old 35px health bar with the slot)
    local tgt = self.target
    local tgtW = Opt("targetWidth", 210)
    tgt:SetWidth(tgtW)
    if round then
        FullBar(tgt, tgtW, Opt("targetHeight", 46), showPower, false, true)
    else
        LayoutStack(tgt, Opt("targetHeight", 46), LAYOUT_BIG, showPower, true)
        tgt.nameText:SetWidth(tgtW - 95)
    end
    if showNames then tgt.nameText:Show() else tgt.nameText:Hide() end
    if showLevel then tgt.badgeText:Show() else tgt.badgeText:Hide() end
    if tgt.debuffBars then
        for i = 1, MAX_TARGET_DEBUFFS do
            local r = tgt.debuffBars[i]
            r:ClearAllPoints()
            if round then
                r:SetWidth(tgtW)
                r:SetPoint("BOTTOMLEFT", tgt, "TOPLEFT", 0, 4 + (i - 1) * 18)
            else
                r:SetWidth(tgtW - 2)
                r:SetPoint("BOTTOMLEFT", tgt, "TOPLEFT", 1, 4 + (i - 1) * 18)
            end
        end
    end

    -- Target of target and pet
    local small = { self.tot, self.pet }
    for i = 1, 2 do
        local f = small[i]
        if f then
            if round then
                FullBar(f, 130, 24, showPower, false, false)
            else
                LayoutStack(f, 24, LAYOUT_SMALL, showPower, false)
            end
            if showNames then f.nameText:Show() else f.nameText:Hide() end
        end
    end

    -- Elites & bosses
    local enc = self.enc
    local encW = Opt("encWidth", ENC_WIDTH)
    local rowH = Opt("encRowHeight", 18)
    local showTags = Opt("encShowTags", true)
    local inset = round and 8 or 4
    local top = round and 26 or 22
    enc:SetWidth(encW)
    for i = 1, MAX_ENCOUNTER_ROWS do
        local r = enc.rows[i]
        r:SetWidth(encW - 2 * inset)
        r:SetHeight(rowH)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", enc, "TOPLEFT", inset, -top - (i - 1) * (rowH + 3))
        r.nameFs:ClearAllPoints()
        if showTags then
            r.badgeFs:Show()
            r.nameFs:SetPoint("LEFT", r.badgeFs, "RIGHT", 3, 0)
        else
            r.badgeFs:Hide()
            r.nameFs:SetPoint("LEFT", r.bar, "LEFT", 3, 0)
        end
        r.nameFs:SetPoint("RIGHT", r.hpFs, "LEFT", -3, 0)
    end

    -- Party
    local pw = Opt("partyWidth", 130)
    local sp = Opt("partySpacing", 6)
    self.partyRoot:SetWidth(4 * pw + 3 * sp)
    for i = 1, 4 do
        local pf = self.partyFrames[i]
        pf:SetWidth(pw)
        pf:ClearAllPoints()
        pf:SetPoint("TOPLEFT", self.partyRoot, "TOPLEFT", (i - 1) * (pw + sp), 0)
        if round then
            FullBar(pf, pw, 28, showPower, false, false)
        else
            LayoutStack(pf, 30, LAYOUT_PARTY, showPower, false)
            pf.nameText:SetWidth(pw - 58)
        end
        if showNames then pf.nameText:Show() else pf.nameText:Hide() end
    end
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
    hero.lvlText:SetText(string.format(L["Lv %s"], tostring(lvl)))

    local hp = tonumber(run.hp)
    local hpm = tonumber(run.hpm)
    if not hp or not hpm or hpm <= 0 then
        hp = UnitHealth("player") or 0
        hpm = UnitHealthMax("player") or 1
    end
    -- Fallback for lobby/preview: if HP is 0 and player is not dead in an active run, display full bar
    if hp <= 0 and (not run.ph or run.ph == "ready" or run.ph == "choosing") then
        hp = 1
        hpm = 1
    end
    if hpm <= 0 then hpm = 1 end
    local hpPct = B:Percent(hp, hpm)
    hero.hpBar:SetValue(hpPct)

    -- Player class color, custom colour or theme accent on Health Bar
    local cr, cg, cb
    if B.db and B.db.colorHealthByClass == false then
        if Opt("customHealthColor", false) then
            cr, cg, cb = OptColor("healthColor", { r = 0.20, g = 0.80, b = 0.20 })
        else
            cr, cg, cb = B:GetAccent()
        end
    else
        cr, cg, cb = B:GetClassColor()
    end
    B:SetBarColor(hero.hpBar, cr, cg, cb)
    if hero.buiDot then hero.buiDot:SetVertexColor(cr, cg, cb) end

    local healthMode = Opt("healthText", "both")
    local shortNum = Opt("shortNumbers", true)
    SetHealthTexts(hero, hp, hpm, hpPct, healthMode, shortNum)

    -- Power bar (Mana / Rage / Energy)
    local pType = UnitPowerType("player") or 0
    local pCur = UnitMana("player") or 0
    local pMax = UnitManaMax("player") or 1
    if pMax <= 0 then pMax = 1 end
    local pPct = B:Percent(pCur, pMax)
    SetBarFill(hero.pBar, pPct)

    local pColor = POWER_COLORS[pType] or POWER_COLORS[0]
    SetBarRGB(hero.pBar, pColor.r, pColor.g, pColor.b)

    if pType == 1 or pType == 3 then
        hero.pText:SetText(tostring(pCur))
    else
        hero.pText:SetText(string.format("%d", pCur))
    end

    -- Shield absorb
    local sh = tonumber(run.sh) or 0
    if sh > 0 and Opt("showShieldBar", true) then
        local shPct = B:Percent(sh, hpm)
        hero.shBar:Show()
        SetBarFill(hero.shBar, shPct)
    else
        hero.shBar:Hide()
    end

    -- XP bar
    local xp = tonumber(run.xp) or UnitXP("player") or 0
    local xpn = tonumber(run.xpn) or UnitXPMax("player") or 0
    if xpn > 0 then
        SetBarFill(hero.xpBar, B:Percent(xp, xpn))
    else
        SetBarFill(hero.xpBar, 0)
    end
    -- The round XP bar is no StatusBar: it follows the theme accent here.
    if type(hero.xpBar.SetFillColor) == "function" then
        local xr, xg, xb = B:GetAccent()
        hero.xpBar:SetFillColor(xr, xg, xb)
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
                tgt.nameText:SetText(tData.name or L["Target"])
                tgt.nameText:SetTextColor(0.5, 0.5, 0.5)
                tgt.badgeText:SetText(L["DEAD"])
                tgt.badgeText:SetTextColor(0.5, 0.5, 0.5)
                tgt.hpBar:SetValue(0)
                B:SetBarColor(tgt.hpBar, 0.4, 0.4, 0.4)
                if healthMode == "none" then
                    tgt.hpText:SetText("")
                else
                    tgt.hpText:SetText("0%")
                end
                if tgt.hpLeft then tgt.hpLeft:SetText("") end
                if tgt.buiDot then tgt.buiDot:SetVertexColor(0.4, 0.4, 0.4) end
            else
                tgt.nameText:SetText(tData.name or L["Target"])
                tgt.nameText:SetTextColor(1, 1, 1)

                local badge = kInfo.label or ""
                local br, bg, bb = kInfo.r, kInfo.g, kInfo.b

                if (kind == "boss" or kind == "final") and tData.state == 1 then
                    badge = "ENRAGED"
                    br, bg, bb = 1.0, 0.15, 0.15
                elseif kind == "guardian" and tData.state == 1 then
                    badge = "AWAKE"
                end

                tgt.badgeText:SetText(L[badge])
                tgt.badgeText:SetTextColor(br, bg, bb)

                local tHp = tonumber(tData.hp) or 0
                local tHpm = tonumber(tData.hpm) or 1
                if tHpm <= 0 then tHpm = 1 end
                local tPct = B:Percent(tHp, tHpm)
                tgt.hpBar:SetValue(tPct)
                B:SetBarColor(tgt.hpBar, kInfo.r, kInfo.g, kInfo.b)

                SetHealthTexts(tgt, tHp, tHpm, tPct, healthMode, shortNum)
            if tgt.buiDot then tgt.buiDot:SetVertexColor(tgt.hpBar.buiR or 1, tgt.hpBar.buiG or 1, tgt.hpBar.buiB or 1) end
            end
            tgt.pBar:Hide()
        else
            -- Standard WoW Target
            local tName = UnitName("target") or L["Target"]
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
            tgt.badgeText:SetText(L[badge])
            tgt.badgeText:SetTextColor(1.0, 0.8, 0.2)

            local tPct = B:Percent(tHp, tHpm)
            tgt.hpBar:SetValue(tPct)

            -- Color target: reaction colored or class colored
            if UnitIsPlayer("target") then
                local loc, targetClass = UnitClass("target")
                local tc = B:ResolveClassColor(targetClass) or B:ResolveClassColor(loc)
                if tc then
                    B:SetBarColor(tgt.hpBar, tc.r, tc.g, tc.b)
                else
                    B:SetBarColor(tgt.hpBar, REACTION_COLORS.neutral.r, REACTION_COLORS.neutral.g, REACTION_COLORS.neutral.b)
                end
            else
                local reaction = UnitReaction("target", "player")
                if reaction then
                    if reaction <= 2 then
                        -- Hostile NPCs take the kind colours: boss red, rare
                        -- yellow, elite blue, normal mobs violet.
                        local tKind = "normal"
                        if tClass == "worldboss" then
                            tKind = "boss"
                        elseif tClass == "rare" then
                            tKind = "guardian"
                        elseif tClass == "elite" or tClass == "rareelite" then
                            tKind = "elite"
                        end
                        B:SetBarColor(tgt.hpBar, B:KindColor(tKind))
                    elseif reaction <= 4 then
                        B:SetBarColor(tgt.hpBar, REACTION_COLORS.neutral.r, REACTION_COLORS.neutral.g, REACTION_COLORS.neutral.b)
                    else
                        B:SetBarColor(tgt.hpBar, REACTION_COLORS.friendly.r, REACTION_COLORS.friendly.g, REACTION_COLORS.friendly.b)
                    end
                else
                    B:SetBarColor(tgt.hpBar, REACTION_COLORS.hostile.r, REACTION_COLORS.hostile.g, REACTION_COLORS.hostile.b)
                end
            end

            SetHealthTexts(tgt, tHp, tHpm, tPct, healthMode, shortNum)
            if tgt.buiDot then tgt.buiDot:SetVertexColor(tgt.hpBar.buiR or 1, tgt.hpBar.buiG or 1, tgt.hpBar.buiB or 1) end

            -- Target Power
            local tpType = UnitPowerType("target") or 0
            local tpCur = UnitMana("target") or 0
            local tpMax = UnitManaMax("target") or 1
            if tpMax <= 0 then tpMax = 1 end
            local tpColor = POWER_COLORS[tpType] or POWER_COLORS[0]
            if Opt("showPowerBar", true) then
                tgt.pBar:Show()
                SetBarFill(tgt.pBar, B:Percent(tpCur, tpMax))
                SetBarRGB(tgt.pBar, tpColor.r, tpColor.g, tpColor.b)
            else
                tgt.pBar:Hide()
            end
        end

        -- Target Debuff Bars update (Cyberpunk Aura Bars with Tick Damage)
        if tgt.debuffBars then
            local shownCount = 0
            local maxDebuffs = 0
            if Opt("showDebuffs", true) then
                maxDebuffs = math.floor(tonumber(Opt("maxDebuffs", MAX_TARGET_DEBUFFS)) or MAX_TARGET_DEBUFFS)
            end
            if maxDebuffs <= 0 then
                for i = 1, MAX_TARGET_DEBUFFS do tgt.debuffBars[i]:Hide() end
            elseif (state and state.demo) or (B.unlocked and not UnitExists("target")) then
                local demoDebuffs = {
                    { name = "Rend", icon = "Interface\\Icons\\Ability_Gouge", left = 11.4, max = 15, tick = 450, color = { r = 0.85, g = 0.25, b = 0.20 } },
                    { name = "Deep Wounds", icon = "Interface\\Icons\\Ability_BackStab", left = 7.8, max = 12, tick = 890, color = { r = 0.95, g = 0.35, b = 0.15 } },
                    { name = "Thunder Clap", icon = "Interface\\Icons\\Spell_Nature_ThunderClap", left = 18.2, max = 30, tick = 620, color = { r = 0.25, g = 0.75, b = 1.00 } },
                    { name = "Demoralizing Shout", icon = "Interface\\Icons\\Ability_Warrior_WarCry", left = 24.0, max = 30, tick = 0, color = { r = 0.85, g = 0.50, b = 0.18 } },
                }
                shownCount = table.getn(demoDebuffs)
                for i = 1, MAX_TARGET_DEBUFFS do
                    local r = tgt.debuffBars[i]
                    if i <= shownCount and i <= maxDebuffs then
                        local d = demoDebuffs[i]
                        r.icon:SetTexture(d.icon)
                        r.nameFs:SetText(d.name)
                        local pct = d.left / d.max
                        if pct > 1 then pct = 1 elseif pct < 0 then pct = 0 end
                        r.bar:SetValue(pct)
                        B:SetBarColor(r.bar, d.color.r, d.color.g, d.color.b)
                        local bg = r.bar.buiBg
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
                    if tex and i <= maxDebuffs then
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
                        local bg = r.bar.buiBg
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
            if UnitExists("targettarget") and Opt("showToT", true) then
                local totName = UnitName("targettarget") or L["Unknown"]
                local totHp = UnitHealth("targettarget") or 0
                local totHpm = UnitHealthMax("targettarget") or 1
                if totHpm <= 0 then totHpm = 1 end
                local totPctVal = B:Percent(totHp, totHpm)

                self.tot.nameText:SetText(totName)
                self.tot.hpBar:SetValue(totPctVal)
                -- Same colours as the target: players by class, hostile NPCs
                -- by kind, friendly ones green.
                if UnitIsPlayer("targettarget") then
                    local loc, cls = UnitClass("targettarget")
                    local cc = B:ResolveClassColor(cls) or B:ResolveClassColor(loc)
                    if cc then B:SetBarColor(self.tot.hpBar, cc.r, cc.g, cc.b) end
                else
                    local reaction = UnitReaction("targettarget", "player")
                    if reaction and reaction > 4 then
                        B:SetBarColor(self.tot.hpBar, REACTION_COLORS.friendly.r, REACTION_COLORS.friendly.g, REACTION_COLORS.friendly.b)
                    else
                        local c = UnitClassification("targettarget")
                        local k = "normal"
                        if c == "worldboss" then k = "boss"
                        elseif c == "rare" then k = "guardian"
                        elseif c == "elite" or c == "rareelite" then k = "elite" end
                        B:SetBarColor(self.tot.hpBar, B:KindColor(k))
                    end
                end
                local totPctInt = math.floor(totPctVal * 100 + 0.5)
                self.tot.hpText:SetText(tostring(totPctInt) .. "%")
                local totP = UnitMana("targettarget") or 0
                local totPm = UnitManaMax("targettarget") or 1
                if totPm <= 0 then totPm = 1 end
                local totPType = UnitPowerType("targettarget") or 0
                local totPColor = POWER_COLORS[totPType] or POWER_COLORS[0]
                SetBarFill(self.tot.pBar, B:Percent(totP, totPm))
                SetBarRGB(self.tot.pBar, totPColor.r, totPColor.g, totPColor.b)
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
        if UnitExists("pet") and Opt("showPet", true) then
            local petName = UnitName("pet") or L["Pet"]
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
            SetBarFill(self.pet.pBar, B:Percent(petP, petPm))
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

        local maxRows = math.floor(tonumber(Opt("encMaxRows", MAX_ENCOUNTER_ROWS)) or MAX_ENCOUNTER_ROWS)
        if maxRows > MAX_ENCOUNTER_ROWS then maxRows = MAX_ENCOUNTER_ROWS end
        if maxRows < 1 then maxRows = 1 end
        local shownCount = nBosses
        if shownCount > maxRows then
            shownCount = maxRows
        end
        local rowStep = Opt("encRowHeight", 18) + 3
        if self.round then
            enc:SetHeight(26 + shownCount * rowStep - 3 + 8)
        else
            enc:SetHeight(22 + shownCount * rowStep + 4)
        end

        -- Dynamic anchor below TimerFrame if not custom moved by user
        if not (B.db and B.db.positions and B.db.positions["encounters"]) then
            enc:ClearAllPoints()
            local timerF = BUI_TimerFrame
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

                -- Kind badge and bar colour from the shared kind colours; the
                -- badge is a lighter tint so it reads on the coloured bar.
                local badgeKey = "[ELITE]"
                if bKind == "final" then
                    badgeKey = "[FINAL]"
                elseif bKind == "boss" then
                    badgeKey = "[BOSS]"
                elseif bKind == "guardian" then
                    badgeKey = "[GUARD]"
                else
                    bKind = "elite"
                end
                local kr, kg, kb = B:KindColor(bKind)
                r.badgeFs:SetText(L[badgeKey])
                r.badgeFs:SetTextColor(kr + (1 - kr) * 0.55, kg + (1 - kg) * 0.55, kb + (1 - kb) * 0.55)
                B:SetBarColor(r.bar, kr, kg, kb)

                r.unitName = bData.name or "Elite"
                r.unitHp = bHp
                r.unitHpm = bHpm
                r.unitPct = bPctInt

                r.nameFs:SetText(bData.name or L["Elite"])
                r.nameFs:SetTextColor(1, 1, 1)

                r.hpFs:SetText(FormatHealth(bHp, bHpm, bPct, Opt("encHealthText", "curmaxpct"), Opt("shortNumbers", true)))
                r.hpFs:SetTextColor(1, 1, 1)

                r:Show()
            else
                r:Hide()
            end
        end
    end

    ---------------------------------------------------------------------------
    --  5. Update Party Frames
    ---------------------------------------------------------------------------
    self:UpdateParty(state)
    self:UpdateRaidIcons(state)
end

-- Raid target icons on hero, target and party frames; samples in preview.
local function RaidIndex(unit)
    if type(GetRaidTargetIndex) ~= "function" or not UnitExists(unit) then return nil end
    return GetRaidTargetIndex(unit)
end

function mod:UpdateRaidIcons(state)
    local isDemo = (state and state.demo) or B.unlocked
    local Index = RaidIndex
    if isDemo then
        SetRaidIcon(self.hero, 1)
        SetRaidIcon(self.target, 8)
    else
        SetRaidIcon(self.hero, Index("player"))
        SetRaidIcon(self.target, Index("target"))
    end
    for i = 1, 4 do
        local f = self.partyFrames and self.partyFrames[i]
        if f then
            if isDemo then
                SetRaidIcon(f, (i == 2) and 2 or nil)
            else
                SetRaidIcon(f, Index("party" .. i))
            end
        end
    end
end

function mod:UpdateParty(state)
    local root = self.partyRoot
    if not root then return end
    if not Opt("showParty", true) then
        root:Hide()
        return
    end

    local isDemo = (state and state.demo) or B.unlocked
    local nParty = (type(GetNumPartyMembers) == "function" and GetNumPartyMembers()) or 0

    if isDemo then
        root:Show()
        local demoParty = {
            { name = "Valandil", class = "MAGE", hp = 1420, hpm = 1420, mp = 2200, mpm = 2200, pType = 0 },
            { name = "Thorin", class = "WARRIOR", hp = 3100, hpm = 3100, mp = 65, mpm = 100, pType = 1 },
            { name = "Eluna", class = "PRIEST", hp = 1650, hpm = 1800, mp = 1950, mpm = 2400, pType = 0 },
            { name = "Sylvana", class = "ROGUE", hp = 1900, hpm = 2100, mp = 100, mpm = 100, pType = 3 },
        }
        for i = 1, 4 do
            local f = self.partyFrames[i]
            local d = demoParty[i]
            f.nameText:SetText(d.name)
            local hpPct = d.hp / d.hpm
            f.hpBar:SetValue(hpPct)
            local col = B:ResolveClassColor(d.class) or { r = 0.2, g = 0.8, b = 0.2 }
            B:SetBarColor(f.hpBar, col.r, col.g, col.b)
            local pctInt = math.floor(hpPct * 100 + 0.5)
            f.hpText:SetText(tostring(pctInt) .. "%")
            local pCol = POWER_COLORS[d.pType] or POWER_COLORS[0]
            SetBarFill(f.pBar, d.mp / d.mpm)
            SetBarRGB(f.pBar, pCol.r, pCol.g, pCol.b)
            f:Show()
        end
        return
    end

    if nParty == 0 then
        -- Check if AZS_PARTY has members without standard WoW party frames
        local azsParty = state and state.party
        local nAzs = (type(azsParty) == "table" and table.getn(azsParty)) or 0
        if nAzs <= 1 then
            root:Hide()
            return
        end
    end

    root:Show()
    for i = 1, 4 do
        local f = self.partyFrames[i]
        local unit = "party" .. i
        if i <= nParty and UnitExists(unit) then
            local uName = UnitName(unit) or string.format(L["Party %d"], i)
            f.nameText:SetText(uName)

            local loc, uClass = UnitClass(unit)
            local cColor = B:ResolveClassColor(uClass) or B:ResolveClassColor(loc) or { r = 0.2, g = 0.8, b = 0.2 }
            B:SetBarColor(f.hpBar, cColor.r, cColor.g, cColor.b)

            local isConn = (type(UnitIsConnected) == "function" and UnitIsConnected(unit))
            local isDead = (type(UnitIsDead) == "function" and UnitIsDead(unit))
            local isGhost = (type(UnitIsGhost) == "function" and UnitIsGhost(unit))

            if not isConn then
                f.hpBar:SetValue(0)
                f.hpText:SetText("|cff888888" .. L["OFFLINE"] .. "|r")
                B:SetBarColor(f.hpBar, 0.4, 0.4, 0.4)
            elseif isDead then
                f.hpBar:SetValue(0)
                f.hpText:SetText("|cffff2222" .. L["DEAD"] .. "|r")
                B:SetBarColor(f.hpBar, 0.5, 0.15, 0.15)
            elseif isGhost then
                f.hpBar:SetValue(0)
                f.hpText:SetText("|cffaaaaaa" .. L["GHOST"] .. "|r")
                B:SetBarColor(f.hpBar, 0.3, 0.3, 0.3)
            else
                local curHp = UnitHealth(unit) or 0
                local maxHp = UnitHealthMax(unit) or 1
                if maxHp <= 0 then maxHp = 1 end
                local pct = B:Percent(curHp, maxHp)
                f.hpBar:SetValue(pct)
                local pctInt = math.floor(pct * 100 + 0.5)
                f.hpText:SetText(tostring(pctInt) .. "%")
            end

            local pType = UnitPowerType(unit) or 0
            local curP = UnitMana(unit) or 0
            local maxP = UnitManaMax(unit) or 1
            if maxP <= 0 then maxP = 1 end
            SetBarFill(f.pBar, B:Percent(curP, maxP))
            local pColor = POWER_COLORS[pType] or POWER_COLORS[0]
            SetBarRGB(f.pBar, pColor.r, pColor.g, pColor.b)

            f:Show()
        elseif state and state.party and state.party[i + 1] then
            -- Fallback if server provides AZS_PARTY entries
            local pData = state.party[i + 1]
            f.nameText:SetText(pData.name or string.format(L["Party %d"], i))
            local cColor = B:ResolveClassColor(pData.class) or { r = 0.2, g = 0.8, b = 0.2 }
            B:SetBarColor(f.hpBar, cColor.r, cColor.g, cColor.b)
            f.hpBar:SetValue(1.0)
            f.hpText:SetText(B:Short(pData.dmg or 0))
            SetBarFill(f.pBar, 1.0)
            SetBarRGB(f.pBar, 0, 0.55, 1)
            f:Show()
        else
            f:Hide()
        end
    end
end

B:RegisterModule("unitframes", mod)
