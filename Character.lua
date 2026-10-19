-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Character.lua
--  Cyberpunk-styled Character Info & PaperDoll frame ('C' key).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Character"
mod.alwaysActive = false

local EQUIPMENT_SLOTS = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot",
    "CharacterBackSlot", "CharacterChestSlot", "CharacterShirtSlot",
    "CharacterTabardSlot", "CharacterWristSlot",
    "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot",
    "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot",
    "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot"
}

local function UpdateSlotQuality(slot)
    if not slot or not slot.GetID then return end
    local id = slot:GetID()
    local q = nil
    if GetInventoryItemQuality then
        q = GetInventoryItemQuality("player", id)
    end
    if q and q > 1 then
        local r, g, b = GetItemQualityColor(q)
        B:Border(slot, r, g, b, 1)
    else
        B:Border(slot, 0.25, 0.25, 0.25, 1)
    end
end

local function SkinCharacterFrame()
    if not CharacterFrame or CharacterFrame.buiSkinned then return end
    CharacterFrame.buiSkinned = true

    -- Hide default parchment textures
    if CharacterFrameTopLeft then CharacterFrameTopLeft:Hide() end
    if CharacterFrameTopRight then CharacterFrameTopRight:Hide() end
    if CharacterFrameBottomLeft then CharacterFrameBottomLeft:Hide() end
    if CharacterFrameBottomRight then CharacterFrameBottomRight:Hide() end
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end

    -- BlackwellUI Backdrop and 1px Border
    B:Backdrop(CharacterFrame, 0.95)
    B:Border(CharacterFrame, 0, 0, 0, 1)

    -- Top accent bar
    local topRule = CharacterFrame:CreateTexture(nil, "ARTWORK")
    topRule:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 1, -1)
    topRule:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -1, -1)
    topRule:SetHeight(2)
    topRule:SetTexture(B.WHITE)
    B:Accent(topRule, "tex", 0.9)

    -- Title text
    if CharacterNameText then
        CharacterNameText:SetFont(B:GetFontPath(), 13, "OUTLINE")
        CharacterNameText:ClearAllPoints()
        CharacterNameText:SetPoint("TOP", CharacterFrame, "TOP", 0, -12)
        B:Accent(CharacterNameText, "text")
    end

    -- Close Button
    if CharacterFrameCloseButton then
        CharacterFrameCloseButton:SetWidth(18)
        CharacterFrameCloseButton:SetHeight(18)
        CharacterFrameCloseButton:ClearAllPoints()
        CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -6, -6)
    end

    -- Model Frame
    if CharacterModelFrame then
        B:Border(CharacterModelFrame, 0.25, 0.25, 0.25, 1)
        local mBg = CharacterModelFrame:CreateTexture(nil, "BACKGROUND")
        B:Solid(mBg, 0.02, 0.02, 0.02, 0.6)
        mBg:SetAllPoints(CharacterModelFrame)
    end

    -- Equipment Slots
    local nSlots = table.getn(EQUIPMENT_SLOTS)
    for i = 1, nSlots do
        local slotName = EQUIPMENT_SLOTS[i]
        local slot = _G[slotName]
        if slot then
            B:Backdrop(slot, 0.85)
            B:Border(slot, 0.25, 0.25, 0.25, 1)

            local norm = _G[slotName .. "NormalTexture"]
            if norm then norm:SetAlpha(0) end

            local icon = _G[slotName .. "IconTexture"]
            if icon then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
    end

    -- Tabs at the bottom
    for i = 1, 5 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab then
            local tLeft = _G["CharacterFrameTab" .. i .. "Left"]
            local tMid = _G["CharacterFrameTab" .. i .. "Middle"]
            local tRight = _G["CharacterFrameTab" .. i .. "Right"]
            if tLeft then tLeft:Hide() end
            if tMid then tMid:Hide() end
            if tRight then tRight:Hide() end
            B:Backdrop(tab, 0.90)
            B:Border(tab, 0.25, 0.25, 0.25, 1)
            tab:SetHeight(24)
        end
    end
end

local function UpdateEquipment()
    local nSlots = table.getn(EQUIPMENT_SLOTS)
    for i = 1, nSlots do
        local slot = _G[EQUIPMENT_SLOTS[i]]
        if slot then
            UpdateSlotQuality(slot)
        end
    end
end

function mod:Create()
    local watcher = CreateFrame("Frame", "BUI_CharacterWatcher", UIParent)
    watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if not B:IsEnabled("character") then return end
        SkinCharacterFrame()
        if CharacterFrame and CharacterFrame:IsShown() then
            UpdateEquipment()
        end
    end)
    self.watcher = watcher

    if CharacterFrame then
        local origOnShow = CharacterFrame:GetScript("OnShow")
        CharacterFrame:SetScript("OnShow", function()
            if origOnShow then origOnShow() end
            if B:IsEnabled("character") then
                SkinCharacterFrame()
                UpdateEquipment()
            end
        end)
    end
end

function mod:Update(state)
    -- Character frame updates on inventory events / OnShow
end

B:RegisterModule("character", mod)
