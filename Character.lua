-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Character.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Complete Retail/Dragonflight-style Redesign for Character Info ('C' Key):
--  - 775x460 Single Unified Blackwell Cyberpunk Glass Window
--  - Left: 3D PaperDoll Character Model with interactive mouse rotation
--  - Surrounding Equipment Slots with quality borders and side item-level badges
--  - Middle: Big Item Level display, Primary Attributes, Secondary Enhancements,
--    and Azeroth Survivors Run Multipliers
--  - Right: Full interactive Equipment List with slot badges, iLvls, and quality-colored
--    item names with complete hover tooltips
--  - Complete suppression of Classic parchment textures, tabs, and overlapping frames
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Character"
mod.alwaysActive = true
-- Replaces PaperDoll stat functions; turning it off takes a /reload.
mod.reloadOnToggle = true
mod.toggleLabel = "Character window restyle"
-- Restyles the game's own window: no scale / opacity / visibility settings.
mod.noLook = true

local SLOT_SIZE = 34
local LIST_WIDTH = 235

mod.options = {
    { type = "section", label = "Equipment slots" },
    { type = "toggle", key = "qualityBorders", label = "Quality colour slot borders", default = true },
    { type = "toggle", key = "showItemLevel", label = "Item level on slots", default = false },
    { type = "range", key = "slotSize", label = "Slot size", min = 28, max = 40, step = 2, default = 34, format = "%d px" },
    { type = "section", label = "Stats" },
    { type = "toggle", key = "showStats", label = "Show stat column", default = true },
    { type = "toggle", key = "showCombatStats", label = "Combat enhancements", default = true, depends = "showStats" },
    { type = "toggle", key = "showRunStats", label = "Run multipliers", default = true, depends = "showStats" },
    { type = "toggle", key = "colorStats", label = "Coloured stat values", hint = "Off shows all values in white.", default = true, depends = "showStats" },
    { type = "section", label = "Equipment list" },
    { type = "toggle", key = "showEquipList", label = "Show equipment list", default = true },
    { type = "range", key = "listWidth", label = "Panel width", min = 200, max = 320, step = 5, default = 235, format = "%d px", depends = "showEquipList" },
    { type = "toggle", key = "qualityNames", label = "Colour item names by quality", default = true, depends = "showEquipList" },
    { type = "section", label = "Text" },
    { type = "range", key = "fontSize", label = "Font size", hint = "Added to the global font size.", min = -2, max = 4, step = 1, default = 0, format = "%d" },
}

local function Opt(key, default)
    return B:ModOpt("character", key, default)
end

local modFunc = math.mod or math.fmod

local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor / Gray
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common / White
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon / Green
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare / Blue
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic / Purple
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary / Orange
    [6] = { r = 0.90, g = 0.80, b = 0.50 }, -- Artifact / Gold
}

local PAPERDOLL_SLOTS = {
    -- Left column (SlotId, FrameName, Label, Col, Order)
    { id = 1,  name = "CharacterHeadSlot",     label = "Head",     col = "left",   order = 1 },
    { id = 2,  name = "CharacterNeckSlot",     label = "Neck",     col = "left",   order = 2 },
    { id = 3,  name = "CharacterShoulderSlot", label = "Shoulder", col = "left",   order = 3 },
    { id = 15, name = "CharacterBackSlot",     label = "Back",     col = "left",   order = 4 },
    { id = 5,  name = "CharacterChestSlot",    label = "Chest",    col = "left",   order = 5 },
    { id = 9,  name = "CharacterWristSlot",    label = "Wrist",    col = "left",   order = 6 },
    { id = 4,  name = "CharacterShirtSlot",    label = "Shirt",    col = "left",   order = 7, optional = true },
    { id = 19, name = "CharacterTabardSlot",   label = "Tabard",   col = "left",   order = 8, optional = true },

    -- Right column
    { id = 10, name = "CharacterHandsSlot",    label = "Hands",    col = "right",  order = 1 },
    { id = 6,  name = "CharacterWaistSlot",    label = "Waist",    col = "right",  order = 2 },
    { id = 7,  name = "CharacterLegsSlot",     label = "Legs",     col = "right",  order = 3 },
    { id = 8,  name = "CharacterFeetSlot",     label = "Feet",     col = "right",  order = 4 },
    { id = 11, name = "CharacterFinger0Slot",  label = "Finger",   col = "right",  order = 5 },
    { id = 12, name = "CharacterFinger1Slot",  label = "Finger",   col = "right",  order = 6 },
    { id = 13, name = "CharacterTrinket0Slot", label = "Trinket",  col = "right",  order = 7 },
    { id = 14, name = "CharacterTrinket1Slot", label = "Trinket",  col = "right",  order = 8 },

    -- Bottom weapons row
    { id = 16, name = "CharacterMainHandSlot",      label = "Main Hand", col = "bottom", order = 1 },
    { id = 17, name = "CharacterSecondaryHandSlot", label = "Off Hand",   col = "bottom", order = 2 },
    { id = 18, name = "CharacterRangedSlot",         label = "Ranged",     col = "bottom", order = 3 },
}

local LIST_SLOTS = {
    { id = 1,  label = "Head" },
    { id = 2,  label = "Neck" },
    { id = 3,  label = "Shoulder" },
    { id = 15, label = "Back" },
    { id = 5,  label = "Chest" },
    { id = 9,  label = "Wrist" },
    { id = 10, label = "Hands" },
    { id = 6,  label = "Waist" },
    { id = 7,  label = "Legs" },
    { id = 8,  label = "Feet" },
    { id = 11, label = "Finger" },
    { id = 12, label = "Finger" },
    { id = 13, label = "Trinket" },
    { id = 14, label = "Trinket" },
    { id = 16, label = "Main Hand" },
    { id = 17, label = "Off Hand" },
    { id = 18, label = "Ranged" },
}

local function FormatNumber(n)
    local num = tonumber(n) or 0
    local s = string.format("%d", math.floor(num))
    local len = string.len(s)
    if len <= 3 then return s end
    local formatted = ""
    local rem = modFunc(len, 3)
    if rem > 0 then
        formatted = string.sub(s, 1, rem)
    end
    local pos = rem + 1
    while pos <= len do
        if formatted ~= "" then
            formatted = formatted .. "," .. string.sub(s, pos, pos + 2)
        else
            formatted = string.sub(s, pos, pos + 2)
        end
        pos = pos + 3
    end
    return formatted
end

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

-- Fonts that follow the module's font size option: { fs, base size }.
local charFonts = {}

local function CharFont(parent, size, justify)
    local fs = B:Font(parent, size, justify)
    table.insert(charFonts, { fs = fs, base = size })
    return fs
end

-- Rounded shape in its own colour (not a panel, so the theme refresh leaves
-- its colour alone): four disc quarters, two edge strips and a centre.
-- Parts are marked buiKeep so CleanFrameTextures leaves them alone.
local function RoundShape(f, rad, layer)
    local shape = { parts = {} }
    local function Part(round, l, rr, t, bb)
        local tex = f:CreateTexture(nil, layer or "BACKGROUND")
        tex.buiKeep = true
        tex:SetTexture(round and B.ROUND or B.WHITE)
        if round then tex:SetTexCoord(l, rr, t, bb) end
        table.insert(shape.parts, tex)
        return tex
    end
    local tl = Part(true, 0, 0.5, 0, 0.5)
    tl:SetWidth(rad); tl:SetHeight(rad)
    tl:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local tr = Part(true, 0.5, 1, 0, 0.5)
    tr:SetWidth(rad); tr:SetHeight(rad)
    tr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local bl = Part(true, 0, 0.5, 0.5, 1)
    bl:SetWidth(rad); bl:SetHeight(rad)
    bl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    local br = Part(true, 0.5, 1, 0.5, 1)
    br:SetWidth(rad); br:SetHeight(rad)
    br:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local top = Part(false)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
    local bottom = Part(false)
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    local centre = Part(false)
    centre:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -rad)
    centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, rad)
    function shape:SetColor(r, g, b, a)
        for i = 1, table.getn(self.parts) do
            self.parts[i]:SetVertexColor(r, g, b)
            self.parts[i]:SetAlpha(a or 1)
        end
    end
    return shape
end

-- Round disc behind a small button (close / rotate), no square border.
local function RoundButtonBg(btn, r, g, b, a)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg.buiKeep = true
    bg:SetTexture(B.ROUND)
    bg:SetAllPoints(btn)
    bg:SetVertexColor(r, g, b)
    bg:SetAlpha(a or 1)
    return bg
end

-- Slot frame colour: rounded ring in the round style, 1px border in sharp.
local function SetSlotColor(slot, r, g, b, a)
    if slot.buiRing then
        slot.buiRing:SetColor(r, g, b, a)
    else
        B:SetBorderColor(slot, r, g, b, a)
    end
end

-- Hidden tooltip to scan exact Item Level strings
local scanTooltip = CreateFrame("GameTooltip", "BUI_CharScanTooltip", UIParent, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetSlotItemInfo(slotId)
    if not slotId or not GetInventoryItemTexture then
        return nil
    end

    local tex = GetInventoryItemTexture("player", slotId)
    if not tex or tex == "" then
        return nil
    end

    local link = (type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slotId)) or nil
    local quality = (type(GetInventoryItemQuality) == "function" and GetInventoryItemQuality("player", slotId)) or 1

    local name = L["Equipped Item"]
    local iLvl = 0

    if link then
        local _, _, parsedName = string.find(link, "%[(.+)%]")
        if parsedName then name = parsedName end

        local _, _, colorCode = string.find(link, "|cff(%x%x%x%x%x%x)")
        if colorCode then
            local hex = string.lower(colorCode)
            if hex == "9d9d9d" then quality = 0
            elseif hex == "ffffff" then quality = 1
            elseif hex == "1eff00" then quality = 2
            elseif hex == "0070dd" then quality = 3
            elseif hex == "a335ee" then quality = 4
            elseif hex == "ff8000" then quality = 5
            elseif hex == "e6cc80" then quality = 6
            end
        end

        if type(GetItemInfo) == "function" then
            local gName, _, gQ, gReqLvl = GetItemInfo(link)
            if gName then name = gName end
            if gQ and gQ >= 0 then quality = gQ end
            if gReqLvl and gReqLvl > 0 then iLvl = gReqLvl + quality * 5 end
        end
    end

    if type(scanTooltip.ClearLines) == "function" and type(scanTooltip.SetInventoryItem) == "function" then
        scanTooltip:ClearLines()
        local hasTip = scanTooltip:SetInventoryItem("player", slotId)
        if hasTip then
            for l = 2, 6 do
                local lineObj = getglobal("BUI_CharScanTooltipTextLeft" .. l)
                if lineObj and lineObj.GetText then
                    local txt = lineObj:GetText()
                    if txt then
                        local _, _, lvl = string.find(txt, "Item Level%s+(%d+)")
                        if not lvl then _, _, lvl = string.find(txt, "Gegenstandsstufe%s+(%d+)") end
                        if not lvl then _, _, lvl = string.find(txt, "Nivel de objeto%s+(%d+)") end
                        if lvl then
                            iLvl = tonumber(lvl) or iLvl
                            break
                        end
                    end
                end
            end
        end
    end

    if iLvl <= 0 then
        local pLvl = (type(UnitLevel) == "function" and UnitLevel("player")) or 60
        iLvl = pLvl + quality * 4
    end

    return {
        slotId = slotId,
        texture = tex,
        link = link,
        name = name,
        quality = quality or 1,
        iLvl = iLvl,
    }
end

local function SuppressAZSMoreStats()
    local p = AZSMoreStats or (getglobal and getglobal("AZSMoreStats"))
    if p then
        p:Hide()
        p:SetAlpha(0)
        p:ClearAllPoints()
        p:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
        p.Show = function() end
        if type(p.SetScript) == "function" then
            p:SetScript("OnShow", function() this:Hide() end)
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

-------------------------------------------------------------------------------
--  Modern Character Frame Builder
-------------------------------------------------------------------------------
local modernFrameBuilt = false

local function BuildModernCharacterFrame()
    if not CharacterFrame or modernFrameBuilt then return end
    modernFrameBuilt = true
    CharacterFrame.buiSkinned = true

    -- 1. Resize CharacterFrame to 775 x 460 px
    CharacterFrame:SetWidth(775)
    CharacterFrame:SetHeight(460)
    CharacterFrame:SetClampedToScreen(true)

    if UIPanelWindows and UIPanelWindows["CharacterFrame"] then
        UIPanelWindows["CharacterFrame"].area = "left"
        UIPanelWindows["CharacterFrame"].pushable = 0
        UIPanelWindows["CharacterFrame"].whileDead = 1
    end

    -- 2. Strip Blizzard Classic Textures & Parchment Chunks
    CleanFrameTextures(CharacterFrame)
    if PaperDollFrame then
        PaperDollFrame:SetWidth(775)
        PaperDollFrame:SetHeight(460)
        PaperDollFrame:ClearAllPoints()
        PaperDollFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        CleanFrameTextures(PaperDollFrame)
    end

    if CharacterFrameTopLeft then CharacterFrameTopLeft:Hide() end
    if CharacterFrameTopRight then CharacterFrameTopRight:Hide() end
    if CharacterFrameBottomLeft then CharacterFrameBottomLeft:Hide() end
    if CharacterFrameBottomRight then CharacterFrameBottomRight:Hide() end
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    -- Ammo plays no part in Azeroth Survivors; the stock ammo slot would sit
    -- unstyled next to the weapon slots, so it stays hidden.
    local ammo = getglobal and getglobal("CharacterAmmoSlot")
    if ammo then
        ammo:Hide()
        if type(ammo.SetScript) == "function" then
            ammo:SetScript("OnShow", function() this:Hide() end)
        end
    end

    -- Hide Blizzard Classic Stats / Attributes & Resistances Boxes
    if type(PaperDollFrame_UpdateStats) == "function" then
        PaperDollFrame_UpdateStats = function() end
    end
    if type(PaperDollFrame_SetResistances) == "function" then
        PaperDollFrame_SetResistances = function() end
    end

    local hideClassic = {
        CharacterAttributesFrame,
        CharacterResistanceFrame,
        PetPaperDollFrame,
        PetPaperDollFrameCompanionFrame,
        PetPaperDollFramePetInfo,
    }
    for i = 1, 5 do
        local mrf = getglobal and getglobal("MagicResFrame" .. i)
        if mrf then table.insert(hideClassic, mrf) end
    end
    for i = 1, 6 do
        local pfl = getglobal and getglobal("PlayerStatFrameLeft" .. i)
        if pfl then table.insert(hideClassic, pfl) end
        local pfr = getglobal and getglobal("PlayerStatFrameRight" .. i)
        if pfr then table.insert(hideClassic, pfr) end
    end

    for i = 1, table.getn(hideClassic) do
        local f = hideClassic[i]
        if f then
            CleanFrameTextures(f)
            f:Hide()
            f:SetAlpha(0)
            f:ClearAllPoints()
            f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
            f.Show = function() end
            if f.UnregisterAllEvents then f:UnregisterAllEvents() end
        end
    end

    -- 3. Backdrop: rounded panel (round style) or dark glass with 1px border
    local round = B:IsRound()
    local rad = (B.db and B.db.cornerRadius) or 10
    B:Backdrop(CharacterFrame, 0.96)
    if not round then
        B:Border(CharacterFrame, 0, 0, 0, 1)
    end

    -- Top Accent Rule (between the rounded corners in the round style)
    local ruleInset = (round and rad) or 1
    local topRule = CharacterFrame:CreateTexture(nil, "ARTWORK")
    topRule.buiKeep = true
    topRule:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", ruleInset, -1)
    topRule:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -ruleInset, -1)
    topRule:SetHeight(2)
    topRule:SetTexture(B.WHITE)
    B:Accent(topRule, "tex", 0.90)

    -- 4. Header: Character Name, Level, Spec / Class
    if CharacterNameText then
        CharacterNameText:SetFont(B:GetFontPath(), 13, "OUTLINE")
        CharacterNameText:ClearAllPoints()
        CharacterNameText:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 20, -10)
        B:Accent(CharacterNameText, "text")
    end

    if CharacterLevelText then
        CharacterLevelText:SetFont(B:GetFontPath(), 10, "")
        CharacterLevelText:ClearAllPoints()
        CharacterLevelText:SetPoint("TOPLEFT", CharacterNameText, "BOTTOMLEFT", 0, -2)
        CharacterLevelText:SetTextColor(0.85, 0.85, 0.85)
    end

    -- Close Button
    if CharacterFrameCloseButton then
        CleanFrameTextures(CharacterFrameCloseButton)
        CharacterFrameCloseButton:SetWidth(18)
        CharacterFrameCloseButton:SetHeight(18)
        CharacterFrameCloseButton:ClearAllPoints()
        CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -8, -8)
        if round then
            local cBg = RoundButtonBg(CharacterFrameCloseButton, 0.16, 0.17, 0.20, 0.95)
            CharacterFrameCloseButton.buiBgDisc = cBg
            local origEnter = (type(CharacterFrameCloseButton.GetScript) == "function" and CharacterFrameCloseButton:GetScript("OnEnter")) or nil
            local origLeave = (type(CharacterFrameCloseButton.GetScript) == "function" and CharacterFrameCloseButton:GetScript("OnLeave")) or nil
            CharacterFrameCloseButton:SetScript("OnEnter", function()
                if this.buiBgDisc then this.buiBgDisc:SetVertexColor(0.70, 0.22, 0.20) end
                if origEnter then origEnter() end
            end)
            CharacterFrameCloseButton:SetScript("OnLeave", function()
                if this.buiBgDisc then this.buiBgDisc:SetVertexColor(0.16, 0.17, 0.20) end
                if origLeave then origLeave() end
            end)
        else
            B:Backdrop(CharacterFrameCloseButton, 0.90)
            B:Border(CharacterFrameCloseButton, 0.35, 0.35, 0.35, 1)
        end
        if not CharacterFrameCloseButton.fs then
            local cFs = B:Font(CharacterFrameCloseButton, 10, "CENTER")
            cFs:SetPoint("CENTER", CharacterFrameCloseButton, "CENTER", 0, 0)
            cFs:SetText("X")
            cFs:SetTextColor(0.85, 0.85, 0.85)
            CharacterFrameCloseButton.fs = cFs
        end
    end

    ---------------------------------------------------------------------------
    --  5. Left Section: 3D Model & Surrounding Equipment Slots
    ---------------------------------------------------------------------------
    if CharacterModelFrame then
        CleanFrameTextures(CharacterModelFrame)
        CharacterModelFrame:ClearAllPoints()
        CharacterModelFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 68, -48)
        CharacterModelFrame:SetWidth(188)
        CharacterModelFrame:SetHeight(334)
        if round then
            local mShape = RoundShape(CharacterModelFrame, rad, "BACKGROUND")
            mShape:SetColor(0.02, 0.02, 0.02, 0.85)
        else
            B:Border(CharacterModelFrame, 0.20, 0.20, 0.20, 1)

            local mBg = CharacterModelFrame:CreateTexture(nil, "BACKGROUND")
            mBg.buiKeep = true
            B:Solid(mBg, 0.02, 0.02, 0.02, 0.85)
            mBg:SetAllPoints(CharacterModelFrame)
        end

        -- Interactive Drag Rotation
        CharacterModelFrame:EnableMouse(true)
        CharacterModelFrame:SetScript("OnMouseDown", function()
            this.isDragging = true
            local curX, _ = GetCursorPosition()
            this.lastX = curX
        end)
        CharacterModelFrame:SetScript("OnMouseUp", function()
            this.isDragging = false
        end)
        CharacterModelFrame:SetScript("OnUpdate", function()
            if this.isDragging then
                local curX, _ = GetCursorPosition()
                local diff = (curX - (this.lastX or curX)) * 0.015
                this.lastX = curX
                local curFacing = this:GetFacing() or 0
                this:SetFacing(curFacing + diff)
            end
        end)

        -- Rotation Buttons (< and >)
        local rotL = CharacterModelFrameRotateLeftButton
        if rotL then
            CleanFrameTextures(rotL)
            rotL:SetWidth(16)
            rotL:SetHeight(16)
            rotL:ClearAllPoints()
            rotL:SetPoint("TOPLEFT", CharacterModelFrame, "TOPLEFT", 4, -4)
            if round then
                RoundButtonBg(rotL, 0.16, 0.17, 0.20, 0.95)
            else
                B:Backdrop(rotL, 0.90)
                B:Border(rotL, 0.25, 0.25, 0.25, 1)
            end
            local lTxt = rotL:CreateFontString(nil, "OVERLAY")
            lTxt.buiKeep = true
            lTxt:SetFont(B:GetFontPath(), 9, "OUTLINE")
            lTxt:SetPoint("CENTER", rotL, "CENTER", 0, 0)
            lTxt:SetText("<")
            B:Accent(lTxt, "text")
        end

        local rotR = CharacterModelFrameRotateRightButton
        if rotR then
            CleanFrameTextures(rotR)
            rotR:SetWidth(16)
            rotR:SetHeight(16)
            rotR:ClearAllPoints()
            rotR:SetPoint("LEFT", rotL, "RIGHT", 3, 0)
            if round then
                RoundButtonBg(rotR, 0.16, 0.17, 0.20, 0.95)
            else
                B:Backdrop(rotR, 0.90)
                B:Border(rotR, 0.25, 0.25, 0.25, 1)
            end
            local rTxt = rotR:CreateFontString(nil, "OVERLAY")
            rTxt.buiKeep = true
            rTxt:SetFont(B:GetFontPath(), 9, "OUTLINE")
            rTxt:SetPoint("CENTER", rotR, "CENTER", 0, 0)
            rTxt:SetText(">")
            B:Accent(rTxt, "text")
        end
    end

    -- Position and style PaperDoll Equipment Slots
    local nSlots = table.getn(PAPERDOLL_SLOTS)
    for i = 1, nSlots do
        local sDef = PAPERDOLL_SLOTS[i]
        local slot = getglobal and getglobal(sDef.name)
        if slot then
            slot:SetWidth(SLOT_SIZE)
            slot:SetHeight(SLOT_SIZE)
            slot:ClearAllPoints()

            local icon = getglobal and getglobal(sDef.name .. "IconTexture")
            if round then
                -- Rounded quality ring, the icon sits 2px inside it.
                slot.buiRing = RoundShape(slot, 6, "BACKGROUND")
                slot.buiRing:SetColor(0.18, 0.18, 0.18, 0.80)
                if icon then
                    icon:ClearAllPoints()
                    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
                    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
                end
            else
                B:Backdrop(slot, 0.88)
                B:Border(slot, 0.18, 0.18, 0.18, 1)
            end

            local norm = getglobal and getglobal(sDef.name .. "NormalTexture")
            if norm then norm:SetAlpha(0) end

            if icon then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            -- Item level badge (module option "Item level on slots").
            if not slot.buiLvlFs then
                local lvlFs = CharFont(slot, 8, "RIGHT")
                lvlFs:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 3)
                lvlFs:Hide()
                slot.buiLvlFs = lvlFs
            end

            if sDef.col == "left" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 16, -48 - (sDef.order - 1) * 42)
                if slot.buiLvlFs then slot.buiLvlFs:Hide() end
            elseif sDef.col == "right" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 262, -48 - (sDef.order - 1) * 42)
                if slot.buiLvlFs then slot.buiLvlFs:Hide() end
            elseif sDef.col == "bottom" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 100 + (sDef.order - 1) * 44, -390)
                if slot.buiLvlFs then slot.buiLvlFs:Hide() end
            end
        end
    end

    ---------------------------------------------------------------------------
    --  6. Middle Section: Combat Enhancements & Run Multipliers
    ---------------------------------------------------------------------------
    local mid = CreateFrame("Frame", "BUI_CharMiddleStats", PaperDollFrame or CharacterFrame)
    mid:SetWidth(195)
    mid:SetHeight(396)
    mid:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 312, -48)
    CharacterFrame.middleStats = mid

    -- Dynamic Stats List Area
    local statsContainer = CreateFrame("Frame", nil, mid)
    statsContainer:SetWidth(195)
    statsContainer:SetHeight(396)
    statsContainer:SetPoint("TOPLEFT", mid, "TOPLEFT", 0, 0)
    mid.container = statsContainer

    -- Helper to create category headers and stat rows. mid.layout keeps the
    -- order so a section can be hidden and the rest moves up.
    mid.statRows = {}
    mid.layout = {}
    local currY = 0
    local currGroup = "combat"

    local function AddLayout(frame, h)
        table.insert(mid.layout, { frame = frame, h = h, group = currGroup })
    end

    local function AddCategoryHeader(title)
        local hFrame = CreateFrame("Frame", nil, statsContainer)
        hFrame:SetWidth(195)
        hFrame:SetHeight(18)
        hFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", 0, -currY)
        AddLayout(hFrame, 20)

        local hFs = CharFont(hFrame, 9, "LEFT")
        hFs:SetPoint("LEFT", hFrame, "LEFT", 2, 0)
        hFs:SetText(L[title])
        hFs:SetTextColor(1.0, 0.85, 0.40)

        local line = hFrame:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT", hFrame, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", hFrame, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        line:SetTexture(B.WHITE)
        line:SetVertexColor(0.35, 0.35, 0.35, 0.80)
        if round then line:SetAlpha(0.45) end

        currY = currY + 20
    end

    local function AddStatRow(key, defaultLabel)
        local row = CreateFrame("Frame", nil, statsContainer)
        row:SetWidth(195)
        row:SetHeight(15)
        row:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", 0, -currY)
        AddLayout(row, 15)

        local lbl = CharFont(row, 8, "LEFT")
        lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        lbl:SetWidth(125)
        lbl:SetTextColor(0.70, 0.70, 0.70)
        lbl:SetText(L[defaultLabel] .. ":")
        row.lbl = lbl

        local val = CharFont(row, 8, "RIGHT")
        val:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        val:SetWidth(65)
        val:SetTextColor(1, 1, 1)
        val:SetText("-")
        row.val = val

        currY = currY + 15
        mid.statRows[key] = row
    end

    -- 1. Combat Enhancements
    AddCategoryHeader("Combat Enhancements")
    AddStatRow("health", "Max Health")
    AddStatRow("dmg", "Damage Multiplier")
    AddStatRow("crit", "Critical Strike")
    AddStatRow("cm", "Critical Damage")
    AddStatRow("cd", "Cooldown Reduction")
    AddStatRow("spd", "Haste / Atk Speed")
    AddStatRow("area", "Area of Effect")
    AddStatRow("arm", "Armor / DR")
    AddStatRow("speed", "Movement Speed")
    AddStatRow("avoid", "Avoidance / Dodge")

    currGroup = "run"
    currY = currY + 4
    table.insert(mid.layout, { h = 4, group = "run" })

    -- 2. Run Multipliers & Perks (Azeroth Survivors)
    AddCategoryHeader("Run Multipliers & Perks")
    AddStatRow("echo", "Echo Strike")
    AddStatRow("leech", "Lifesteal")
    AddStatRow("heal", "Kill Heal")
    AddStatRow("pick", "Pickup Radius")
    AddStatRow("luck", "Luck Multiplier")
    AddStatRow("bp", "Buff Power")
    AddStatRow("gold", "Gold Bonus")
    AddStatRow("xp", "Experience Bonus")
    AddStatRow("doth", "DoT Haste")
    AddStatRow("big", "Damage vs Elites")
    AddStatRow("exe", "Execute (<30% HP)")
    AddStatRow("lives", "Revives / Lives")

    ---------------------------------------------------------------------------
    --  7. Right Section: Complete Equipment List (Side-by-side Overview)
    ---------------------------------------------------------------------------
    local right = CreateFrame("Frame", "BUI_CharRightPanel", PaperDollFrame or CharacterFrame)
    right:SetWidth(235)
    right:SetHeight(396)
    right:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 524, -48)
    if round then
        B:Panel(right)
        right.pad = 6
    else
        B:Backdrop(right, 0.92)
        B:Border(right, 0, 0, 0, 1)
        right.pad = 4
    end
    CharacterFrame.rightPanel = right

    -- Right Panel Header (round style: no strip, no rule, inset title)
    local rHdr = CreateFrame("Frame", nil, right)
    rHdr:SetHeight(24)
    rHdr:SetPoint("TOPLEFT", right, "TOPLEFT", 1, -1)
    rHdr:SetPoint("TOPRIGHT", right, "TOPRIGHT", -1, -1)
    right.header = rHdr

    if not round then
        local rHdrBg = rHdr:CreateTexture(nil, "BACKGROUND")
        B:Solid(rHdrBg, 0.04, 0.04, 0.04, 0.95)
        rHdrBg:SetAllPoints(rHdr)
    end

    local pIcon = rHdr:CreateTexture(nil, "ARTWORK")
    pIcon:SetWidth(16)
    pIcon:SetHeight(16)
    pIcon:SetPoint("LEFT", rHdr, "LEFT", (round and 8) or 4, 0)
    pIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    pIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    right.pIcon = pIcon

    local rNameFs = CharFont(rHdr, 9, "LEFT")
    rNameFs:SetPoint("LEFT", pIcon, "RIGHT", 5, 0)
    rNameFs:SetText(L["Equipment Overview"])
    rNameFs:SetTextColor(1.0, 0.90, 0.62)
    right.nameFs = rNameFs

    local rLvlFs = CharFont(rHdr, 9, "RIGHT")
    rLvlFs:SetPoint("RIGHT", rHdr, "RIGHT", (round and -10) or -6, 0)
    rLvlFs:SetText("")
    rLvlFs:SetTextColor(0.0, 0.90, 1.00)
    right.lvlFs = rLvlFs

    if not round then
        local rRule = rHdr:CreateTexture(nil, "ARTWORK")
        rRule:SetPoint("BOTTOMLEFT", rHdr, "BOTTOMLEFT", 0, 0)
        rRule:SetPoint("BOTTOMRIGHT", rHdr, "BOTTOMRIGHT", 0, 0)
        rRule:SetHeight(1)
        rRule:SetTexture(B.WHITE)
        B:Accent(rRule, "tex", 0.90)
    end

    -- 17 Equipment List Rows
    local listRows = {}
    local nList = table.getn(LIST_SLOTS)
    for i = 1, nList do
        local lDef = LIST_SLOTS[i]
        local row = CreateFrame("Button", nil, right)
        row:SetWidth(LIST_WIDTH - 2 * right.pad)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", right, "TOPLEFT", right.pad, -28 - (i - 1) * 21)
        row.slotId = lDef.id

        local badge = CharFont(row, 8, "LEFT")
        badge:SetPoint("LEFT", row, "LEFT", 2, 0)
        badge:SetWidth(46)
        badge:SetHeight(16)
        badge:SetTextColor(0.25, 0.85, 0.95)
        badge:SetText(L[lDef.label])
        row.badge = badge

        local name = CharFont(row, 8, "LEFT")
        name:SetPoint("LEFT", badge, "RIGHT", 4, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        name:SetHeight(16)
        name:SetTextColor(0.50, 0.50, 0.50)
        name:SetText(L["(Empty)"])
        row.name = name

        -- Hover tint, shown from OnEnter: this engine draws the HIGHLIGHT
        -- layer all the time, not only under the mouse.
        local hl = row:CreateTexture(nil, "BACKGROUND")
        B:Solid(hl, 1, 1, 1, (round and 0.06) or 0.12)
        hl:SetAllPoints(row)
        hl:Hide()
        row.hl = hl

        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
            if this.hl then this.hl:Show() end
            if this.slotId then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                local hasItem = GameTooltip:SetInventoryItem("player", this.slotId)
                if not hasItem and this.itemLink then
                    GameTooltip:SetHyperlink(this.itemLink)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            if this.hl then this.hl:Hide() end
            GameTooltip:Hide()
        end)

        listRows[i] = row
    end
    right.rows = listRows

    -- Hide Tabs & Clutter
    HideCharacterTabs()
    SuppressAZSMoreStats()

    if type(mod.ApplyOptions) == "function" then
        mod:ApplyOptions()
    end
end

-------------------------------------------------------------------------------
--  Live Update Logic
-------------------------------------------------------------------------------
local function UpdateCharacterFrame()
    if not CharacterFrame or not CharacterFrame:IsShown() then return end
    BuildModernCharacterFrame()

    -- 1. Character Name & Class Details
    local pName = (type(UnitName) == "function" and UnitName("player")) or "Hero"
    local pLvl = (type(UnitLevel) == "function" and UnitLevel("player")) or 60
    local pRace = (type(UnitRace) == "function" and UnitRace("player")) or "Human"
    -- Lua 5.0 truncates `f() or x, y` to one value from f(): unpack the call first.
    local pClass, pClassToken
    if type(UnitClass) == "function" then pClass, pClassToken = UnitClass("player") end
    pClass = pClass or "Warrior"
    pClassToken = pClassToken or "WARRIOR"

    if CharacterNameText then
        CharacterNameText:SetText(pName)
    end
    if CharacterLevelText then
        local cCol = B:ResolveClassColor(pClassToken) or B:ResolveClassColor(pClass) or { r = 1, g = 1, b = 1 }
        local cr = math.floor((cCol.r or 1) * 255 + 0.5)
        local cg = math.floor((cCol.g or 1) * 255 + 0.5)
        local cb = math.floor((cCol.b or 1) * 255 + 0.5)
        local classText = string.format("|cff%02x%02x%02x%s|r", cr, cg, cb, pClass)
        CharacterLevelText:SetText(string.format(L["Level %d %s %s"], math.floor(pLvl), pRace, classText))
    end

    -- 2. Scan Equipment, Update Slots and Quality Borders
    local showQuality = Opt("qualityBorders", true)
    local showItemLevel = Opt("showItemLevel", false)
    local nSlots = table.getn(PAPERDOLL_SLOTS)
    for i = 1, nSlots do
        local sDef = PAPERDOLL_SLOTS[i]
        local slot = getglobal and getglobal(sDef.name)
        if slot then
            local info = GetSlotItemInfo(sDef.id)
            if info then
                local qCol = QUALITY_COLORS[info.quality] or QUALITY_COLORS[1]
                if type(GetItemQualityColor) == "function" then
                    local qr, qg, qb = GetItemQualityColor(info.quality)
                    if qr and qg and qb then qCol = { r = qr, g = qg, b = qb } end
                end
                if showQuality then
                    SetSlotColor(slot, qCol.r, qCol.g, qCol.b, 1)
                else
                    SetSlotColor(slot, 0.30, 0.31, 0.34, 1)
                end

                if slot.buiLvlFs then
                    if showItemLevel and info.iLvl and info.iLvl > 0 then
                        slot.buiLvlFs:SetText(tostring(math.floor(info.iLvl)))
                        slot.buiLvlFs:SetTextColor(qCol.r, qCol.g, qCol.b)
                        slot.buiLvlFs:Show()
                    else
                        slot.buiLvlFs:Hide()
                    end
                end
                slot:Show()
            else
                SetSlotColor(slot, 0.18, 0.18, 0.18, 0.80)
                if slot.buiLvlFs then slot.buiLvlFs:Hide() end
                if sDef.optional then
                    slot:Hide()
                else
                    slot:Show()
                end
            end
        end
    end

    -- Update Right Panel Overview List (Item Names with Quality Colors)
    local right = CharacterFrame.rightPanel
    if right then
        if right.nameFs then right.nameFs:SetText(pName) end
        if right.lvlFs then right.lvlFs:SetText("") end
        if right.pIcon and pClassToken and CLASS_COORDS and CLASS_COORDS[pClassToken] then
            local c = CLASS_COORDS[pClassToken]
            right.pIcon:SetTexture(CLASS_SHEET or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
            right.pIcon:SetTexCoord(c[1], c[2], c[3], c[4])
        end

        local nList = table.getn(LIST_SLOTS)
        for i = 1, nList do
            local row = right.rows[i]
            local info = GetSlotItemInfo(row.slotId)
            if info then
                row.itemLink = info.link
                local qCol = QUALITY_COLORS[info.quality] or QUALITY_COLORS[1]
                if type(GetItemQualityColor) == "function" then
                    local qr, qg, qb = GetItemQualityColor(info.quality)
                    if qr and qg and qb then qCol = { r = qr, g = qg, b = qb } end
                end
                row.name:SetText(info.name)
                if Opt("qualityNames", true) then
                    row.name:SetTextColor(qCol.r, qCol.g, qCol.b)
                else
                    row.name:SetTextColor(0.90, 0.90, 0.90)
                end
            else
                row.itemLink = nil
                row.name:SetText(L["(Empty)"])
                row.name:SetTextColor(0.40, 0.40, 0.40)
            end
        end
    end

    -- 3. Update Middle Stats Section (Combat Enhancements & Run Multipliers)
    local mid = CharacterFrame.middleStats
    if mid and mid.statRows then
        local r = mid.statRows
        local s = (type(AZS_STATS) == "table" and AZS_STATS) or {}

        -- 1. Combat Enhancements
        -- Max Health
        local maxHp = (type(UnitHealthMax) == "function" and UnitHealthMax("player")) or 0
        if r.health then
            r.health.val:SetText(FormatNumber(maxHp))
            r.health.val:SetTextColor(0.20, 0.90, 0.20)
        end

        -- Damage Multiplier
        if r.dmg then
            local dVal = s.dmg
            if dVal and dVal ~= 1 then
                r.dmg.val:SetText(string.format("+%.0f%%", (dVal - 1) * 100))
                r.dmg.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.dmg.val:SetText("+0%")
                r.dmg.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- Crit Chance
        local crit = (type(GetCritChance) == "function" and GetCritChance()) or 0
        if s.crit then crit = s.crit * 100 end
        if r.crit then
            r.crit.val:SetText(string.format("%.1f%%", crit))
            r.crit.val:SetTextColor(1.0, 0.40, 0.40)
        end

        -- Crit Damage
        if r.cm then
            local cmVal = s.cm
            if cmVal and cmVal > 0 then
                r.cm.val:SetText(string.format("%.0f%%", cmVal * 100))
                r.cm.val:SetTextColor(1.0, 0.40, 0.40)
            else
                r.cm.val:SetText("200%")
                r.cm.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- Cooldowns
        if r.cd then
            local cdVal = s.cd
            if cdVal and cdVal > 0 then
                r.cd.val:SetText(string.format("-%.0f%%", cdVal * 100))
                r.cd.val:SetTextColor(0.40, 0.80, 1.0)
            else
                r.cd.val:SetText("0%")
                r.cd.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- Attack Speed / Haste
        local spd = (type(UnitAttackSpeed) == "function" and UnitAttackSpeed("player")) or 0
        if r.spd then
            if s.spd and s.spd > 1 then
                r.spd.val:SetText(string.format("+%.0f%%", (s.spd - 1) * 100))
                r.spd.val:SetTextColor(1.0, 0.84, 0.20)
            elseif spd > 0 then
                r.spd.val:SetText(string.format("%.2fs", spd))
                r.spd.val:SetTextColor(1, 1, 1)
            else
                r.spd.val:SetText("0%")
                r.spd.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- Area
        if r.area then
            local aVal = s.area
            if aVal and aVal ~= 1 then
                r.area.val:SetText(string.format("+%.0f%%", (aVal - 1) * 100))
                r.area.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.area.val:SetText("+0%")
                r.area.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- Armor / DR
        local effArm
        if type(UnitArmor) == "function" then
            local _
            _, effArm = UnitArmor("player")
        end
        effArm = tonumber(effArm) or 0
        local dr = 0
        if effArm > 0 then
            dr = effArm / (effArm + 400 + 85 * pLvl) * 100
        end
        if s.arm then dr = dr + s.arm * 100 end
        if r.arm then
            r.arm.val:SetText(string.format("%.1f%%", dr))
            r.arm.val:SetTextColor(0.50, 0.75, 1.0)
        end

        -- Movement Speed
        local moveSpd = (s.spd and math.floor(s.spd * 100 + 0.5)) or 100
        if r.speed then
            r.speed.val:SetText(string.format("%d%%", moveSpd))
            r.speed.val:SetTextColor(1.0, 0.84, 0.20)
        end

        -- Avoidance / Dodge
        local dodge = (type(GetDodgeChance) == "function" and GetDodgeChance()) or 0
        if r.avoid then
            r.avoid.val:SetText(string.format("%.1f%%", dodge))
            r.avoid.val:SetTextColor(0.70, 0.90, 0.70)
        end

        -- 2. Run Multipliers & Perks
        if r.echo then
            local eVal = s.echo
            if eVal and eVal > 0 then
                r.echo.val:SetText(string.format("%.0f%%", eVal * 100))
                r.echo.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.echo.val:SetText("0%")
                r.echo.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.leech then
            local lch = s.lch
            if lch and lch > 0 then
                r.leech.val:SetText(string.format("%.1f%%", lch * 100))
                r.leech.val:SetTextColor(0.30, 0.95, 0.50)
            else
                r.leech.val:SetText("0%")
                r.leech.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.heal then
            local hVal = s.heal
            if hVal and hVal > 0 then
                r.heal.val:SetText(string.format(L["+%.0f HP"], hVal))
                r.heal.val:SetTextColor(0.30, 0.95, 0.50)
            else
                r.heal.val:SetText("0")
                r.heal.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.pick then
            local pVal = s.pick
            if pVal and pVal > 0 then
                r.pick.val:SetText(string.format(L["%.0f yd"], pVal))
                r.pick.val:SetTextColor(0.90, 0.90, 0.90)
            else
                r.pick.val:SetText(L["0 yd"])
                r.pick.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.luck then
            local lVal = s.luck
            if lVal and lVal > 0 then
                r.luck.val:SetText(string.format("+%.0f%%", lVal * 100))
                r.luck.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.luck.val:SetText("+0%")
                r.luck.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.bp then
            local bpVal = s.bp
            if bpVal and bpVal > 0 then
                r.bp.val:SetText(string.format("+%.0f%%", bpVal * 100))
                r.bp.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.bp.val:SetText("+0%")
                r.bp.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.gold then
            local gVal = s.gold
            if gVal and gVal > 0 then
                r.gold.val:SetText(string.format("+%.0f%%", gVal * 100))
                r.gold.val:SetTextColor(1.0, 0.85, 0.20)
            else
                r.gold.val:SetText("+0%")
                r.gold.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.xp then
            local xpVal = s.xp
            if xpVal and xpVal > 0 then
                r.xp.val:SetText(string.format("+%.0f%%", xpVal * 100))
                r.xp.val:SetTextColor(0.40, 0.80, 1.0)
            else
                r.xp.val:SetText("+0%")
                r.xp.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.doth then
            local dhVal = s.doth
            if dhVal and dhVal > 0 then
                r.doth.val:SetText(string.format("+%.0f%%", dhVal * 100))
                r.doth.val:SetTextColor(1.0, 0.84, 0.20)
            else
                r.doth.val:SetText("+0%")
                r.doth.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.big then
            local bVal = s.big
            if bVal and bVal > 0 then
                r.big.val:SetText(string.format("+%.0f%%", bVal * 100))
                r.big.val:SetTextColor(1.0, 0.40, 0.40)
            else
                r.big.val:SetText("+0%")
                r.big.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.exe then
            local exVal = s.exe
            if exVal and exVal > 0 then
                r.exe.val:SetText(string.format("+%.0f%%", exVal * 100))
                r.exe.val:SetTextColor(1.0, 0.30, 0.30)
            else
                r.exe.val:SetText("+0%")
                r.exe.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.lives then
            local lNum = (type(AZS_LIVES) == "number" and AZS_LIVES) or (s.lives) or 0
            r.lives.val:SetText(tostring(lNum))
            if lNum > 0 then
                r.lives.val:SetTextColor(0.30, 0.95, 0.50)
            else
                r.lives.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        -- "Coloured stat values" off: every value in plain white.
        if not Opt("colorStats", true) then
            for _, row in pairs(r) do
                if row.val then row.val:SetTextColor(0.92, 0.92, 0.92) end
            end
        end
    end

    HideCharacterTabs()
    SuppressAZSMoreStats()
end

-------------------------------------------------------------------------------
--  Module options (applied once the window is restyled)
-------------------------------------------------------------------------------
-- Slot size, stat sections, list panel width, window width and fonts. The
-- window is built on first use, so before that there is nothing to apply.
function mod:ApplyOptions()
    if not modernFrameBuilt or not CharacterFrame then return end

    -- Slots keep their grid cell; a smaller slot is centred in it.
    local size = Opt("slotSize", SLOT_SIZE)
    local shift = math.floor((SLOT_SIZE - size) / 2)
    local nSlots = table.getn(PAPERDOLL_SLOTS)
    for i = 1, nSlots do
        local sDef = PAPERDOLL_SLOTS[i]
        local slot = getglobal and getglobal(sDef.name)
        if slot then
            slot:SetWidth(size)
            slot:SetHeight(size)
            slot:ClearAllPoints()
            if sDef.col == "left" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 16 + shift, -48 - (sDef.order - 1) * 42 - shift)
            elseif sDef.col == "right" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 262 + shift, -48 - (sDef.order - 1) * 42 - shift)
            elseif sDef.col == "bottom" then
                slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 100 + (sDef.order - 1) * 44 + shift, -390 - shift)
            end
        end
    end

    -- Fonts
    local off = Opt("fontSize", 0)
    for i = 1, table.getn(charFonts) do
        local e = charFonts[i]
        e.fs.buiSize = e.base + off
        B:ApplyFont(e.fs)
    end

    -- Columns from left to right: stats (195 px), equipment list.
    local x = 312
    local mid = CharacterFrame.middleStats
    if mid then
        if Opt("showStats", true) then
            mid:ClearAllPoints()
            mid:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", x, -48)
            mid:Show()
            x = x + 212
            local showGroup = {
                combat = Opt("showCombatStats", true),
                run = Opt("showRunStats", true),
            }
            local y = 0
            for i = 1, table.getn(mid.layout) do
                local e = mid.layout[i]
                if showGroup[e.group] then
                    if e.frame then
                        e.frame:ClearAllPoints()
                        e.frame:SetPoint("TOPLEFT", mid.container, "TOPLEFT", 0, -y)
                        e.frame:Show()
                    end
                    y = y + e.h
                elseif e.frame then
                    e.frame:Hide()
                end
            end
        else
            mid:Hide()
        end
    end

    local right = CharacterFrame.rightPanel
    if right then
        if Opt("showEquipList", true) then
            local w = Opt("listWidth", LIST_WIDTH)
            right:SetWidth(w)
            right:ClearAllPoints()
            right:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", x, -48)
            right:Show()
            for i = 1, table.getn(right.rows) do
                right.rows[i]:SetWidth(w - 2 * (right.pad or 4))
            end
            x = x + w + 16
        else
            right:Hide()
        end
    end

    if x < 324 then x = 324 end
    CharacterFrame:SetWidth(x)
    if PaperDollFrame then PaperDollFrame:SetWidth(x) end
end

-------------------------------------------------------------------------------
--  Module Lifecycle
-------------------------------------------------------------------------------
function mod:Create()
    local watcher = CreateFrame("Frame", "BUI_CharacterWatcher", UIParent)
    watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if not B:IsEnabled("character") then return end
        BuildModernCharacterFrame()
        HideCharacterTabs()
        SuppressAZSMoreStats()
        if CharacterFrame and CharacterFrame:IsShown() then
            UpdateCharacterFrame()
        end
    end)
    self.frame = watcher
    self.watcher = watcher

    if CharacterFrame and type(CharacterFrame.SetScript) == "function" then
        local origOnShow = (type(CharacterFrame.GetScript) == "function" and CharacterFrame:GetScript("OnShow")) or nil
        CharacterFrame:SetScript("OnShow", function()
            local sf = BUI_StatsFrame
            if sf then sf:Hide() end

            if origOnShow then origOnShow() end
            if B:IsEnabled("character") then
                BuildModernCharacterFrame()
                UpdateCharacterFrame()
                HideCharacterTabs()
                SuppressAZSMoreStats()
            end
        end)

        local origOnHide = (type(CharacterFrame.GetScript) == "function" and CharacterFrame:GetScript("OnHide")) or nil
        CharacterFrame:SetScript("OnHide", function()
            if origOnHide then origOnHide() end
            local sf = BUI_StatsFrame
            if sf and B:IsEnabled("stats") then
                sf:Show()
            end
        end)
    end
end

function mod:Update(state)
    if CharacterFrame and CharacterFrame:IsShown() then
        UpdateCharacterFrame()
    end
end

B:RegisterModule("character", mod)
