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
        MainMenuBar.Show = function() end
    end

    -- Reparent and hide BonusActionBarFrame (stances/stealth bar)
    if BonusActionBarFrame then
        BonusActionBarFrame:SetParent(hiddenSink)
        BonusActionBarFrame:ClearAllPoints()
        BonusActionBarFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000)
        BonusActionBarFrame:Hide()
        BonusActionBarFrame.Show = function() end
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
            f:SetParent(hiddenSink)
            f:ClearAllPoints()
            f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000)
            f:Hide()
            f.Show = function() end
        end
    end

    for i = 1, 12 do
        local ab = getglobal("ActionButton" .. i)
        if ab then
            ab:SetParent(hiddenSink)
            ab:ClearAllPoints()
            ab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000)
            ab:Hide()
            ab.Show = function() end
        end
        local bab = getglobal("BonusActionButton" .. i)
        if bab then
            bab:SetParent(hiddenSink)
            bab:ClearAllPoints()
            bab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 1000, 1000)
            bab:Hide()
            bab.Show = function() end
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
