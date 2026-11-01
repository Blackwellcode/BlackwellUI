-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  CastBar.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Clean 1px player cast bar, spell icon, countdown timer, spark animation.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Cast Bar"
mod.alwaysActive = true
mod.hint = "Your own cast and channel bar with spell icon and timer."
mod.fontList = {}

local BAR_WIDTH = 210
local BAR_HEIGHT = 16
local MIN_HEIGHT = 10

mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "width", label = "Width", min = 120, max = 400, step = 10, default = BAR_WIDTH, format = "%d px" },
    { type = "range", key = "height", label = "Height", min = MIN_HEIGHT, max = 32, step = 1, default = BAR_HEIGHT, format = "%d px" },
    { type = "range", key = "fontSize", label = "Text size", hint = "Added to the global text size.", min = -3, max = 4, step = 1, default = 0, format = "%d" },
    { type = "toggle", key = "showIcon", label = "Show icon", default = true },
    { type = "toggle", key = "showName", label = "Show spell name", default = true },
    { type = "toggle", key = "showSpark", label = "Show spark", default = true },
    { type = "toggle", key = "showTimer", label = "Show timer", default = true },
    { type = "choice", key = "timerFormat", label = "Timer format", default = "left", depends = "showTimer", values = {
        { value = "left", label = "Time left" },
        { value = "leftmax", label = "Time left / total" },
        { value = "elapsed", label = "Time elapsed" },
    } },
    { type = "section", label = "Colours" },
    { type = "choice", key = "colorMode", label = "Cast colour", default = "accent", values = {
        { value = "accent", label = "Accent" },
        { value = "class", label = "Class colour" },
        { value = "custom", label = "Custom" },
    } },
    { type = "color", key = "castColor", label = "Custom cast colour", default = { r = 0.00, g = 0.90, b = 1.00 } },
    { type = "color", key = "channelColor", label = "Channel colour", default = { r = 0.20, g = 0.70, b = 1.00 } },
    { type = "color", key = "interruptColor", label = "Interrupted colour", default = { r = 0.85, g = 0.20, b = 0.20 } },
}

local function Opt(key, default)
    return B:ModOpt("castbar", key, default)
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

local function CastColor()
    local m = Opt("colorMode", "accent")
    if m == "class" then
        return B:GetClassColor()
    elseif m == "custom" then
        return OptColor("castColor", { r = 0.00, g = 0.90, b = 1.00 })
    end
    return B:GetAccent()
end

-- left: seconds left, total: cast length, elapsed: seconds done.
local function FormatTimer(left, total, elapsed)
    local f = Opt("timerFormat", "left")
    if f == "leftmax" then
        return string.format("%.1f / %.1fs", left, total)
    elseif f == "elapsed" then
        return string.format("%.1fs", elapsed)
    end
    return string.format("%.1fs", left)
end

function mod:HideBlizzardCastBar()
    if CastingBarFrame then
        CastingBarFrame:Hide()
        CastingBarFrame:SetAlpha(0)
        CastingBarFrame:SetScript("OnShow", function() this:Hide() end)
    end
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_CastBarModule", UIParent)
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardCastBar()

    ---------------------------------------------------------------------------
    --  CastBar Container (210 x 16) - Seamlessly docked above Hero Frame
    ---------------------------------------------------------------------------
    local castBar = CreateFrame("Frame", "BUI_PlayerCastBar", root)
    castBar:SetWidth(BAR_WIDTH)
    castBar:SetHeight(BAR_HEIGHT)
    -- Frames are built once: a style switch needs /reload.
    local round = B:IsRound()
    self.round = round
    local pad = 0
    if round then
        -- Radius capped at half the smallest height option, so the round
        -- panel stays valid when the bar is made thinner later.
        local rad = (B.db and B.db.cornerRadius) or 10
        local cap = math.floor(MIN_HEIGHT / 2)
        if rad > cap then rad = cap end
        B:Panel(castBar, rad)
        pad = 2
    else
        B:Backdrop(castBar, 0.85)
    end
    castBar.buiPad = pad

    -- Spell Icon Frame (16 x 16, docked at TOPLEFT)
    local iconFrame = CreateFrame("Frame", nil, castBar)
    iconFrame:SetWidth(BAR_HEIGHT - 2 * pad)
    iconFrame:SetHeight(BAR_HEIGHT - 2 * pad)
    iconFrame:SetPoint("TOPLEFT", castBar, "TOPLEFT", pad, -pad)
    -- Own backdrop with black frame only in the sharp style.
    if not round then
        B:Backdrop(iconFrame, 0.90)
    end

    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    local iconInset = round and 0 or 1
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", iconInset, -iconInset)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -iconInset, iconInset)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castBar.iconFrame = iconFrame
    castBar.iconTex = iconTex

    -- Status Bar (fills remaining width next to iconFrame)
    local bar = B:Bar(castBar, nil)
    bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
    bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", -pad, pad)
    castBar.bar = bar

    -- Spell Name Text
    local nameFs = Font(bar, 9, "LEFT")
    nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameFs:SetWidth(BAR_WIDTH - BAR_HEIGHT - 55)
    nameFs:SetHeight(12)
    nameFs:SetTextColor(1, 1, 1)
    castBar.nameFs = nameFs

    -- Time Text
    local timeFs = Font(bar, 9, "RIGHT")
    timeFs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeFs:SetWidth(50)
    timeFs:SetHeight(12)
    timeFs:SetTextColor(0.9, 0.9, 0.9)
    castBar.timeFs = timeFs

    -- Spark Texture
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetWidth(12)
    spark:SetHeight(BAR_HEIGHT * 1.8)
    spark:SetBlendMode("ADD")
    castBar.spark = spark

    castBar:Hide()
    B:RegisterMover(castBar, "castbar", L["Player Cast Bar"], "BOTTOM", "BOTTOM", -220, 172)
    self.castBar = castBar
    -- The cast bar is placed on its own: Core's scale / opacity / visibility act on it.
    self.lookFrames = { castBar }

    -- Docks the bar next to the icon, or across the full width without one.
    local function AnchorBar(hasIcon)
        local p = castBar.buiPad or 0
        castBar.bar:ClearAllPoints()
        if hasIcon and Opt("showIcon", true) then
            castBar.iconFrame:Show()
            castBar.bar:SetPoint("TOPLEFT", castBar.iconFrame, "TOPRIGHT", 2, 0)
        else
            castBar.iconFrame:Hide()
            castBar.bar:SetPoint("TOPLEFT", castBar, "TOPLEFT", p, -p)
        end
        castBar.bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", -p, p)
    end
    self.AnchorBar = AnchorBar

    ---------------------------------------------------------------------------
    --  Spellcast Event Engine
    ---------------------------------------------------------------------------
    local casting = false
    local channeling = false
    local startTime = 0
    local maxValue = 0
    local endTime = 0
    local fadeTime = nil

    local function FindSpellIcon(spellName)
        if not spellName or not GetSpellName then return nil end
        local book = BOOKTYPE_SPELL or "spell"
        for s = 1, 150 do
            local name = GetSpellName(s, book)
            if not name then break end
            if name == spellName then
                return GetSpellTexture(s, book)
            end
        end
        return B:GetAbilityIcon(spellName)
    end

    local ev = CreateFrame("Frame", nil, castBar)
    ev:RegisterEvent("SPELLCAST_START")
    ev:RegisterEvent("SPELLCAST_STOP")
    ev:RegisterEvent("SPELLCAST_FAILED")
    ev:RegisterEvent("SPELLCAST_INTERRUPTED")
    ev:RegisterEvent("SPELLCAST_DELAYED")
    ev:RegisterEvent("SPELLCAST_CHANNEL_START")
    ev:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")
    ev:RegisterEvent("SPELLCAST_CHANNEL_STOP")

    ev:SetScript("OnEvent", function()
        local now = GetTime()

        if event == "SPELLCAST_START" then
            local spell = arg1 or L["Cast"]
            local dur = (arg2 or 1000) / 1000
            if dur <= 0 then dur = 1 end

            startTime = now
            maxValue = dur
            casting = true
            channeling = false
            fadeTime = nil

            castBar.nameFs:SetText(spell)
            castBar.bar:SetMinMaxValues(0, 1)
            castBar.bar:SetValue(0)
            local ar, ag, ab = CastColor()
            B:SetBarColor(castBar.bar, ar, ag, ab)

            local icon = FindSpellIcon(spell)
            if icon then
                castBar.iconTex:SetTexture(icon)
            end
            castBar.hasIcon = icon and true or false
            AnchorBar(castBar.hasIcon)

            castBar:Show()

        elseif event == "SPELLCAST_STOP" then
            if casting then
                casting = false
                castBar.bar:SetValue(1)
                fadeTime = now + 0.15
            end

        elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
            if casting or channeling then
                casting = false
                channeling = false
                local ir, ig, ib = OptColor("interruptColor", { r = 0.85, g = 0.20, b = 0.20 })
                B:SetBarColor(castBar.bar, ir, ig, ib)
                if event == "SPELLCAST_INTERRUPTED" then
                    castBar.nameFs:SetText(L["Interrupted"])
                else
                    castBar.nameFs:SetText(L["Failed"])
                end
                fadeTime = now + 0.4
            end

        elseif event == "SPELLCAST_DELAYED" then
            local delay = (arg1 or 0) / 1000
            startTime = startTime + delay

        elseif event == "SPELLCAST_CHANNEL_START" then
            local dur = (arg1 or 1000) / 1000
            local spell = arg2 or L["Channel"]
            if dur <= 0 then dur = 1 end

            startTime = now
            maxValue = dur
            endTime = now + dur
            channeling = true
            casting = false
            fadeTime = nil

            castBar.nameFs:SetText(spell)
            castBar.bar:SetMinMaxValues(0, 1)
            castBar.bar:SetValue(1)
            local cr, cg, cb = OptColor("channelColor", { r = 0.20, g = 0.70, b = 1.00 })
            B:SetBarColor(castBar.bar, cr, cg, cb)

            local icon = FindSpellIcon(spell)
            if icon then
                castBar.iconTex:SetTexture(icon)
            end
            castBar.hasIcon = icon and true or false
            AnchorBar(castBar.hasIcon)

            castBar:Show()

        elseif event == "SPELLCAST_CHANNEL_UPDATE" then
            local left = (arg1 or 0) / 1000
            endTime = now + left

        elseif event == "SPELLCAST_CHANNEL_STOP" then
            if channeling then
                channeling = false
                castBar:Hide()
            end
        end
    end)

    castBar:SetScript("OnUpdate", function()
        local now = GetTime()
        local barWidth = castBar.bar:GetWidth()
        if not barWidth or barWidth <= 0 then
            barWidth = Opt("width", BAR_WIDTH) - Opt("height", BAR_HEIGHT) - 2
        end

        if casting then
            local cur = now - startTime
            if cur > maxValue then cur = maxValue end
            local pct = maxValue > 0 and (cur / maxValue) or 0
            castBar.bar:SetValue(pct)

            local sparkPos = pct * barWidth
            castBar.spark:ClearAllPoints()
            castBar.spark:SetPoint("CENTER", castBar.bar, "LEFT", sparkPos, 0)

            local left = maxValue - cur
            if left < 0 then left = 0 end
            castBar.timeFs:SetText(FormatTimer(left, maxValue, cur))

            if cur >= maxValue then
                casting = false
                castBar:Hide()
            end

        elseif channeling then
            local left = endTime - now
            if left < 0 then left = 0 end
            local pct = maxValue > 0 and (left / maxValue) or 0
            castBar.bar:SetValue(pct)

            local sparkPos = pct * barWidth
            castBar.spark:ClearAllPoints()
            castBar.spark:SetPoint("CENTER", castBar.bar, "LEFT", sparkPos, 0)
            local done = maxValue - left
            if done < 0 then done = 0 end
            castBar.timeFs:SetText(FormatTimer(left, maxValue, done))

            if left <= 0 then
                channeling = false
                castBar:Hide()
            end

        elseif fadeTime and now >= fadeTime then
            fadeTime = nil
            castBar:Hide()
        end
    end)
end

-- Size, text size and element visibility from the module settings.
-- Called after Create and after every option change; safe to repeat.
function mod:ApplyOptions()
    local castBar = self.castBar
    if not castBar then return end
    local w = Opt("width", BAR_WIDTH)
    local h = Opt("height", BAR_HEIGHT)
    local pad = castBar.buiPad or 0
    castBar:SetWidth(w)
    castBar:SetHeight(h)
    castBar.iconFrame:SetWidth(h - 2 * pad)
    castBar.iconFrame:SetHeight(h - 2 * pad)

    local fontOff = math.floor(tonumber(Opt("fontSize", 0)) or 0)
    for i = 1, table.getn(self.fontList) do
        local e = self.fontList[i]
        e.fs.buiSize = e.size + fontOff
        B:ApplyFont(e.fs)
    end

    local timerW = 50
    if Opt("timerFormat", "left") == "leftmax" then timerW = 70 end
    castBar.timeFs:SetWidth(timerW)
    castBar.nameFs:SetWidth(w - h - timerW - 5)
    if Opt("showName", true) then castBar.nameFs:Show() else castBar.nameFs:Hide() end
    if Opt("showTimer", true) then castBar.timeFs:Show() else castBar.timeFs:Hide() end
    castBar.spark:SetHeight(h * 1.8)
    if Opt("showSpark", true) then castBar.spark:Show() else castBar.spark:Hide() end

    if type(self.AnchorBar) == "function" then
        local hasIcon = castBar.hasIcon
        if hasIcon == nil then hasIcon = true end
        self.AnchorBar(hasIcon)
    end
end

-- The mover overlay is a child of the bar, which is hidden between casts:
-- while unlocked, keep a preview bar up so the mover can be grabbed.
function mod:Update(state)
    local castBar = self.castBar
    if not castBar then return end
    if B.unlocked then
        if not castBar:IsShown() then
            castBar.buiPreview = true
            castBar.nameFs:SetText(L["Player Cast Bar"])
            castBar.timeFs:SetText("")
            castBar.bar:SetValue(0.5)
            castBar:Show()
        end
    elseif castBar.buiPreview then
        castBar.buiPreview = nil
        castBar:Hide()
    end
end

B:RegisterModule("castbar", mod)
