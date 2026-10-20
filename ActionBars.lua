-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  ActionBars.lua
--  Clean suppression of Blizzard action bars, bags, and micro menu.
--  In Azeroth Survivors spells auto-cast; action bars & bags are not used.
--  Uses hidden-parent reparenting (standard 1.12 foolproof suppression).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Action Bars"
mod.alwaysActive = false

-- Hidden sink frame: anything parented here is permanently invisible
local hiddenSink = CreateFrame("Frame", "BUI_HiddenSink", UIParent)
EUI_HiddenSink = hiddenSink -- Compatibility alias
hiddenSink:Hide()

function mod:HideBlizzardArt()
    -- Reparent and hide MainMenuBar (contains action buttons, bags, micro-buttons, exp bar, end-caps)
    if MainMenuBar then
        MainMenuBar:SetParent(hiddenSink)
        MainMenuBar:ClearAllPoints()
        MainMenuBar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000)
        MainMenuBar:Hide()
        MainMenuBar:SetScript("OnShow", function() this:Hide() end)
    end

    -- Reparent and hide BonusActionBarFrame (stances/stealth bar)
    if BonusActionBarFrame then
        if type(BonusActionBarFrame.SetParent) == "function" then BonusActionBarFrame:SetParent(hiddenSink) end
        if type(BonusActionBarFrame.ClearAllPoints) == "function" then BonusActionBarFrame:ClearAllPoints() end
        if type(BonusActionBarFrame.SetPoint) == "function" then BonusActionBarFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000) end
        if type(BonusActionBarFrame.Hide) == "function" then BonusActionBarFrame:Hide() end
        if type(BonusActionBarFrame.SetScript) == "function" then BonusActionBarFrame:SetScript("OnShow", function() this:Hide() end) end
    end

    -- Reparent and hide bags & micro menu individually if detached
    local framesToSink = {
        MainMenuBarArtFrame,
        MainMenuBarOverlayFrame,
        MainMenuBarPerformanceBarFrame,
        MainMenuBarPerformanceBar,
        MainMenuExpBar,
        ExhaustionTick,
        CharacterBag0Slot,
        CharacterBag1Slot,
        CharacterBag2Slot,
        CharacterBag3Slot,
        MainMenuBarBackpackButton,
        KeyRingButton,
        CharacterMicroButton,
        SpellbookMicroButton,
        TalentMicroButton,
        QuestLogMicroButton,
        SocialsMicroButton,
        WorldMapMicroButton,
        MainMenuMicroButton,
        HelpMicroButton,
        ShapeshiftBarFrame,
        PetActionBarFrame,
        ReputationWatchBar,
    }

    for i = 1, table.getn(framesToSink) do
        local f = framesToSink[i]
        if f then
            if type(f.SetParent) == "function" then f:SetParent(hiddenSink) end
            if type(f.ClearAllPoints) == "function" then f:ClearAllPoints() end
            if type(f.SetPoint) == "function" then f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000) end
            if type(f.Hide) == "function" then f:Hide() end
            if type(f.SetScript) == "function" then f:SetScript("OnShow", function() this:Hide() end) end
        end
    end

    for i = 1, 12 do
        local ab = getglobal("ActionButton" .. i)
        if ab then
            if type(ab.SetParent) == "function" then ab:SetParent(hiddenSink) end
            if type(ab.ClearAllPoints) == "function" then ab:ClearAllPoints() end
            if type(ab.SetPoint) == "function" then ab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000) end
            if type(ab.Hide) == "function" then ab:Hide() end
            if type(ab.SetScript) == "function" then ab:SetScript("OnShow", function() this:Hide() end) end
        end
        local bab = getglobal("BonusActionButton" .. i)
        if bab then
            if type(bab.SetParent) == "function" then bab:SetParent(hiddenSink) end
            if type(bab.ClearAllPoints) == "function" then bab:ClearAllPoints() end
            if type(bab.SetPoint) == "function" then bab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000) end
            if type(bab.Hide) == "function" then bab:Hide() end
            if type(bab.SetScript) == "function" then bab:SetScript("OnShow", function() this:Hide() end) end
        end
    end
end

-- Suppress Blizzard art immediately on event
local suppressor = CreateFrame("Frame")
suppressor:RegisterEvent("PLAYER_ENTERING_WORLD")
suppressor:SetScript("OnEvent", function()
    mod:HideBlizzardArt()
end)

function mod:Create()
    self:HideBlizzardArt()
end

function mod:Update(state)
end

B:RegisterModule("actionbars", mod)
