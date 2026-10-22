-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  CastBar.lua
--  Clean 1px player cast bar, spell icon, countdown timer, spark animation.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Cast Bar"
mod.alwaysActive = true

local BAR_WIDTH = 210
local BAR_HEIGHT = 16

function mod:HideBlizzardCastBar()
    if CastingBarFrame then
        CastingBarFrame:Hide()
        CastingBarFrame:SetAlpha(0)
        CastingBarFrame:SetScript("OnShow", function() this:Hide() end)
    end
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_CastBarModule", UIParent)
    EUI_CastBarModule = root -- Compatibility alias
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardCastBar()

    ---------------------------------------------------------------------------
    --  CastBar Container (210 x 16) - Seamlessly docked above Hero Frame
    ---------------------------------------------------------------------------
    local castBar = CreateFrame("Frame", "BUI_PlayerCastBar", root)
    EUI_PlayerCastBar = castBar -- Compatibility alias
    castBar:SetWidth(BAR_WIDTH)
    castBar:SetHeight(BAR_HEIGHT)
    B:Backdrop(castBar, 0.85)

    -- Spell Icon Frame (16 x 16, docked at TOPLEFT)
    local iconFrame = CreateFrame("Frame", nil, castBar)
    iconFrame:SetWidth(BAR_HEIGHT)
    iconFrame:SetHeight(BAR_HEIGHT)
    iconFrame:SetPoint("TOPLEFT", castBar, "TOPLEFT", 0, 0)
    B:Backdrop(iconFrame, 0.90)

    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castBar.iconFrame = iconFrame
    castBar.iconTex = iconTex

    -- Status Bar (fills remaining width next to iconFrame)
    local bar = B:Bar(castBar, nil)
    bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
    bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
    castBar.bar = bar

    -- Spell Name Text
    local nameFs = B:Font(bar, 9, "LEFT")
    nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameFs:SetWidth(BAR_WIDTH - BAR_HEIGHT - 55)
    nameFs:SetHeight(12)
    nameFs:SetTextColor(1, 1, 1)
    castBar.nameFs = nameFs

    -- Time Text
    local timeFs = B:Font(bar, 9, "RIGHT")
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
    B:RegisterMover(castBar, "castbar", "Player Cast Bar", "BOTTOM", "BOTTOM", -220, 172)
    self.castBar = castBar

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
            local spell = arg1 or "Cast"
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
            local ar, ag, ab = B:GetAccent()
            B:SetBarColor(castBar.bar, ar, ag, ab)

            local icon = FindSpellIcon(spell)
            if icon then
                castBar.iconTex:SetTexture(icon)
                castBar.iconFrame:Show()
                castBar.bar:ClearAllPoints()
                castBar.bar:SetPoint("TOPLEFT", castBar.iconFrame, "TOPRIGHT", 2, 0)
                castBar.bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
            else
                castBar.iconFrame:Hide()
                castBar.bar:ClearAllPoints()
                castBar.bar:SetPoint("TOPLEFT", castBar, "TOPLEFT", 0, 0)
                castBar.bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
            end

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
                B:SetBarColor(castBar.bar, 0.85, 0.20, 0.20)
                if event == "SPELLCAST_INTERRUPTED" then
                    castBar.nameFs:SetText("Interrupted")
                else
                    castBar.nameFs:SetText("Failed")
                end
                fadeTime = now + 0.4
            end

        elseif event == "SPELLCAST_DELAYED" then
            local delay = (arg1 or 0) / 1000
            startTime = startTime + delay

        elseif event == "SPELLCAST_CHANNEL_START" then
            local dur = (arg1 or 1000) / 1000
            local spell = arg2 or "Channel"
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
            B:SetBarColor(castBar.bar, 0.20, 0.70, 1.00)

            local icon = FindSpellIcon(spell)
            if icon then
                castBar.iconTex:SetTexture(icon)
                castBar.iconFrame:Show()
                castBar.bar:ClearAllPoints()
                castBar.bar:SetPoint("TOPLEFT", castBar.iconFrame, "TOPRIGHT", 2, 0)
                castBar.bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
            else
                castBar.iconFrame:Hide()
                castBar.bar:ClearAllPoints()
                castBar.bar:SetPoint("TOPLEFT", castBar, "TOPLEFT", 0, 0)
                castBar.bar:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
            end

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
        if not barWidth or barWidth <= 0 then barWidth = BAR_WIDTH - BAR_HEIGHT - 2 end

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
            castBar.timeFs:SetText(string.format("%.1fs", left))

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
            castBar.timeFs:SetText(string.format("%.1fs", left))

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

function mod:Update(state)
end

B:RegisterModule("castbar", mod)
