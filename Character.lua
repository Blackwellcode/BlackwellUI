-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Character.lua
--  Complete Cyberpunk Redesign for Character Info ('C' Key).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Character"
mod.alwaysActive = true

local EQUIPMENT_SLOTS = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot",
    "CharacterBackSlot", "CharacterChestSlot", "CharacterShirtSlot",
    "CharacterTabardSlot", "CharacterWristSlot",
    "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot",
    "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot",
    "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot"
}

local function CleanFrameTextures(f)
    if not f or not f.GetRegions then return end
    local regions = { f:GetRegions() }
    local n = table.getn(regions)
    for i = 1, n do
        local r = regions[i]
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and not r.buiKeep then
            r:SetAlpha(0)
            r:Hide()
        end
    end
end

local function UpdateSlotQuality(slot)
    if not slot or not slot.GetID then return end
    local id = slot:GetID()
    local q = nil
    if GetInventoryItemQuality then
        q = GetInventoryItemQuality("player", id)
    end
    if q and q > 1 and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(q)
        if r and g and b then
            B:SetBorderColor(slot, r, g, b, 1)
            return
        end
    end
    B:SetBorderColor(slot, 0.18, 0.18, 0.18, 1)
end

local function SkinRunStatsPanel()
    local p = AZSMoreStats or (getglobal and getglobal("AZSMoreStats"))
    if not p then return end

    if not p.buiSkinned then
        p.buiSkinned = true
        CleanFrameTextures(p)
        B:Backdrop(p, 0.94)
        B:Border(p, 0, 0, 0, 1)

        -- Dock cleanly to the right of CharacterFrame
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 2, 0)
        p:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", 2, 0)
        p:SetWidth(165)

        if not p.buiAccentLine then
            local sideTop = p:CreateTexture(nil, "ARTWORK")
            sideTop.buiKeep = true
            sideTop:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
            sideTop:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -1)
            sideTop:SetHeight(2)
            sideTop:SetTexture(B.WHITE)
            B:Accent(sideTop, "tex", 0.9)
            p.buiAccentLine = sideTop
        end
    end

    if AZSMoreStatsTitle then
        AZSMoreStatsTitle:SetFont(B:GetFontPath(), 11, "OUTLINE")
        B:Accent(AZSMoreStatsTitle, "text")
        AZSMoreStatsTitle:ClearAllPoints()
        AZSMoreStatsTitle:SetPoint("TOP", p, "TOP", 0, -8)
    end

    -- Style rows AZSMoreStat1..25
    for i = 1, 25 do
        local row = getglobal and getglobal("AZSMoreStat" .. i)
        if row then
            row:SetWidth(150)
            local lbl = getglobal and getglobal("AZSMoreStat" .. i .. "Label")
            local val = getglobal and getglobal("AZSMoreStat" .. i .. "StatText")
            if lbl then
                lbl:SetFont(B:GetFontPath(), 9, "")
                lbl:SetTextColor(0.75, 0.75, 0.75)
            end
            if val then
                val:SetFont(B:GetFontPath(), 9, "OUTLINE")
                val:SetTextColor(1.0, 0.84, 0.20)
            end
        end
    end
end

local function HideCharacterTabs()
    for i = 1, 5 do
        local tab = getglobal and getglobal("CharacterFrameTab" .. i)
        if tab then
            tab:Hide()
            tab:SetAlpha(0)
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
            tab:SetScript("OnShow", function() this:Hide() end)
            tab.Show = function() end
        end
    end
end

local function SkinCharacterFrame()
    if not CharacterFrame or CharacterFrame.buiSkinned then return end
    CharacterFrame.buiSkinned = true

    -- 1. Wipe all default Blizzard / Azeroth legacy textures
    CleanFrameTextures(CharacterFrame)
    if PaperDollFrame then
        CleanFrameTextures(PaperDollFrame)
    end

    if CharacterFrameTopLeft then CharacterFrameTopLeft:Hide() end
    if CharacterFrameTopRight then CharacterFrameTopRight:Hide() end
    if CharacterFrameBottomLeft then CharacterFrameBottomLeft:Hide() end
    if CharacterFrameBottomRight then CharacterFrameBottomRight:Hide() end
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end

    -- 2. Blackwell Dark Translucent Backdrop & Sharp 1px Border
    B:Backdrop(CharacterFrame, 0.96)
    B:Border(CharacterFrame, 0, 0, 0, 1)

    -- 3. Top Accent Line
    local topRule = CharacterFrame:CreateTexture(nil, "ARTWORK")
    topRule.buiKeep = true
    topRule:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 1, -1)
    topRule:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -1, -1)
    topRule:SetHeight(2)
    topRule:SetTexture(B.WHITE)
    B:Accent(topRule, "tex", 0.9)

    -- 4. Title & Level Text in Expressway
    if CharacterNameText then
        CharacterNameText:SetFont(B:GetFontPath(), 14, "OUTLINE")
        CharacterNameText:ClearAllPoints()
        CharacterNameText:SetPoint("TOP", CharacterFrame, "TOP", 0, -10)
        B:Accent(CharacterNameText, "text")
    end

    if CharacterLevelText then
        CharacterLevelText:SetFont(B:GetFontPath(), 10, "")
        CharacterLevelText:ClearAllPoints()
        CharacterLevelText:SetPoint("TOP", CharacterFrame, "TOP", 0, -26)
        CharacterLevelText:SetTextColor(0.78, 0.78, 0.78)
    end

    -- 5. Close Button
    if CharacterFrameCloseButton then
        CharacterFrameCloseButton:SetWidth(18)
        CharacterFrameCloseButton:SetHeight(18)
        CharacterFrameCloseButton:ClearAllPoints()
        CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -6, -6)
    end

    -- 6. 3D Model Frame
    if CharacterModelFrame then
        CleanFrameTextures(CharacterModelFrame)
        B:Border(CharacterModelFrame, 0.25, 0.25, 0.25, 1)
        local mBg = CharacterModelFrame:CreateTexture(nil, "BACKGROUND")
        mBg.buiKeep = true
        B:Solid(mBg, 0.02, 0.02, 0.02, 0.85)
        mBg:SetAllPoints(CharacterModelFrame)

        -- Rotate buttons
        local rotL = CharacterModelFrameRotateLeftButton
        if rotL then
            CleanFrameTextures(rotL)
            rotL:SetWidth(18)
            rotL:SetHeight(18)
            rotL:ClearAllPoints()
            rotL:SetPoint("TOPLEFT", CharacterModelFrame, "TOPLEFT", 4, -4)
            B:Backdrop(rotL, 0.90)
            B:Border(rotL, 0.25, 0.25, 0.25, 1)
            local lTxt = rotL:CreateFontString(nil, "OVERLAY")
            lTxt.buiKeep = true
            lTxt:SetFont(B:GetFontPath(), 11, "OUTLINE")
            lTxt:SetPoint("CENTER", rotL, "CENTER", 0, 0)
            lTxt:SetText("<")
            B:Accent(lTxt, "text")
        end
        local rotR = CharacterModelFrameRotateRightButton
        if rotR then
            CleanFrameTextures(rotR)
            rotR:SetWidth(18)
            rotR:SetHeight(18)
            rotR:ClearAllPoints()
            rotR:SetPoint("LEFT", rotL, "RIGHT", 3, 0)
            B:Backdrop(rotR, 0.90)
            B:Border(rotR, 0.25, 0.25, 0.25, 1)
            local rTxt = rotR:CreateFontString(nil, "OVERLAY")
            rTxt.buiKeep = true
            rTxt:SetFont(B:GetFontPath(), 11, "OUTLINE")
            rTxt:SetPoint("CENTER", rotR, "CENTER", 0, 0)
            rTxt:SetText(">")
            B:Accent(rTxt, "text")
        end
    end

    -- 7. All 19 Equipment Slots
    local nSlots = table.getn(EQUIPMENT_SLOTS)
    for i = 1, nSlots do
        local slotName = EQUIPMENT_SLOTS[i]
        local slot = getglobal and getglobal(slotName)
        if slot then
            B:Backdrop(slot, 0.85)
            B:Border(slot, 0.18, 0.18, 0.18, 1)

            local norm = getglobal and getglobal(slotName .. "NormalTexture")
            if norm then norm:SetAlpha(0) end

            local icon = getglobal and getglobal(slotName .. "IconTexture")
            if icon then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
    end

    -- 8. Suppress and block bottom tabs (Character, Skills, Honor)
    HideCharacterTabs()

    -- 9. Style attached Run Stats panel
    SkinRunStatsPanel()
end

local function UpdateEquipment()
    local nSlots = table.getn(EQUIPMENT_SLOTS)
    for i = 1, nSlots do
        local slot = getglobal and getglobal(EQUIPMENT_SLOTS[i])
        if slot then
            UpdateSlotQuality(slot)
        end
    end

    HideCharacterTabs()
    SkinRunStatsPanel()
end

function mod:Create()
    local watcher = CreateFrame("Frame", "BUI_CharacterWatcher", UIParent)
    watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if not B:IsEnabled("character") then return end
        SkinCharacterFrame()
        HideCharacterTabs()
        if CharacterFrame and CharacterFrame:IsShown() then
            UpdateEquipment()
        end
    end)
    self.frame = watcher
    self.watcher = watcher

    if CharacterFrame then
        local origOnShow = CharacterFrame:GetScript("OnShow")
        CharacterFrame:SetScript("OnShow", function()
            local sf = BUI_StatsFrame or EUI_StatsFrame
            if sf then sf:Hide() end

            if origOnShow then origOnShow() end
            if B:IsEnabled("character") then
                SkinCharacterFrame()
                UpdateEquipment()
                HideCharacterTabs()
                SkinRunStatsPanel()
            end
        end)

        local origOnHide = CharacterFrame:GetScript("OnHide")
        CharacterFrame:SetScript("OnHide", function()
            if origOnHide then origOnHide() end
            local sf = BUI_StatsFrame or EUI_StatsFrame
            if sf and B:IsEnabled("stats") then
                sf:Show()
            end
        end)
    end
end

function mod:Update(state)
    if CharacterFrame and CharacterFrame:IsShown() then
        SkinRunStatsPanel()
    end
end

B:RegisterModule("character", mod)
