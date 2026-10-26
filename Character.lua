-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Character.lua
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
local mod = {}
mod.label = "Character"
mod.alwaysActive = true

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

    local name = "Equipped Item"
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

    -- 3. Sleek Dark Glass Backdrop & 1px Border
    B:Backdrop(CharacterFrame, 0.96)
    B:Border(CharacterFrame, 0, 0, 0, 1)

    -- Top Accent Rule
    local topRule = CharacterFrame:CreateTexture(nil, "ARTWORK")
    topRule.buiKeep = true
    topRule:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 1, -1)
    topRule:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -1, -1)
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
        B:Backdrop(CharacterFrameCloseButton, 0.90)
        B:Border(CharacterFrameCloseButton, 0.35, 0.35, 0.35, 1)
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
        B:Border(CharacterModelFrame, 0.20, 0.20, 0.20, 1)

        local mBg = CharacterModelFrame:CreateTexture(nil, "BACKGROUND")
        mBg.buiKeep = true
        B:Solid(mBg, 0.02, 0.02, 0.02, 0.85)
        mBg:SetAllPoints(CharacterModelFrame)

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
            B:Backdrop(rotL, 0.90)
            B:Border(rotL, 0.25, 0.25, 0.25, 1)
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
            B:Backdrop(rotR, 0.90)
            B:Border(rotR, 0.25, 0.25, 0.25, 1)
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
            slot:SetWidth(34)
            slot:SetHeight(34)
            slot:ClearAllPoints()

            B:Backdrop(slot, 0.88)
            B:Border(slot, 0.18, 0.18, 0.18, 1)

            local norm = getglobal and getglobal(sDef.name .. "NormalTexture")
            if norm then norm:SetAlpha(0) end

            local icon = getglobal and getglobal(sDef.name .. "IconTexture")
            if icon then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

    -- Helper to create category headers and stat rows
    mid.statRows = {}
    local currY = 0

    local function AddCategoryHeader(title)
        local hFrame = CreateFrame("Frame", nil, statsContainer)
        hFrame:SetWidth(195)
        hFrame:SetHeight(18)
        hFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", 0, -currY)

        local hFs = B:Font(hFrame, 9, "LEFT")
        hFs:SetPoint("LEFT", hFrame, "LEFT", 2, 0)
        hFs:SetText(title)
        hFs:SetTextColor(1.0, 0.85, 0.40)

        local line = hFrame:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT", hFrame, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", hFrame, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        line:SetTexture(B.WHITE)
        line:SetVertexColor(0.35, 0.35, 0.35, 0.80)

        currY = currY + 20
    end

    local function AddStatRow(key, defaultLabel)
        local row = CreateFrame("Frame", nil, statsContainer)
        row:SetWidth(195)
        row:SetHeight(15)
        row:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", 0, -currY)

        local lbl = B:Font(row, 8, "LEFT")
        lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        lbl:SetWidth(125)
        lbl:SetTextColor(0.70, 0.70, 0.70)
        lbl:SetText(defaultLabel)
        row.lbl = lbl

        local val = B:Font(row, 8, "RIGHT")
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
    AddStatRow("health", "Max Health:")
    AddStatRow("dmg", "Damage Multiplier:")
    AddStatRow("crit", "Critical Strike:")
    AddStatRow("cm", "Critical Damage:")
    AddStatRow("cd", "Cooldown Reduction:")
    AddStatRow("spd", "Haste / Atk Speed:")
    AddStatRow("area", "Area of Effect:")
    AddStatRow("arm", "Armor / DR:")
    AddStatRow("speed", "Movement Speed:")
    AddStatRow("avoid", "Avoidance / Dodge:")

    currY = currY + 4

    -- 2. Run Multipliers & Perks (Azeroth Survivors)
    AddCategoryHeader("Run Multipliers & Perks")
    AddStatRow("echo", "Echo Strike:")
    AddStatRow("leech", "Lifesteal:")
    AddStatRow("heal", "Kill Heal:")
    AddStatRow("pick", "Pickup Radius:")
    AddStatRow("luck", "Luck Multiplier:")
    AddStatRow("bp", "Buff Power:")
    AddStatRow("gold", "Gold Bonus:")
    AddStatRow("xp", "Experience Bonus:")
    AddStatRow("doth", "DoT Haste:")
    AddStatRow("big", "Damage vs Elites:")
    AddStatRow("exe", "Execute (<30% HP):")
    AddStatRow("lives", "Revives / Lives:")

    ---------------------------------------------------------------------------
    --  7. Right Section: Complete Equipment List (Side-by-side Overview)
    ---------------------------------------------------------------------------
    local right = CreateFrame("Frame", "BUI_CharRightPanel", PaperDollFrame or CharacterFrame)
    right:SetWidth(235)
    right:SetHeight(396)
    right:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 524, -48)
    B:Backdrop(right, 0.92)
    B:Border(right, 0, 0, 0, 1)
    CharacterFrame.rightPanel = right

    -- Right Panel Header
    local rHdr = CreateFrame("Frame", nil, right)
    rHdr:SetHeight(24)
    rHdr:SetPoint("TOPLEFT", right, "TOPLEFT", 1, -1)
    rHdr:SetPoint("TOPRIGHT", right, "TOPRIGHT", -1, -1)
    right.header = rHdr

    local rHdrBg = rHdr:CreateTexture(nil, "BACKGROUND")
    B:Solid(rHdrBg, 0.04, 0.04, 0.04, 0.95)
    rHdrBg:SetAllPoints(rHdr)

    local pIcon = rHdr:CreateTexture(nil, "ARTWORK")
    pIcon:SetWidth(16)
    pIcon:SetHeight(16)
    pIcon:SetPoint("LEFT", rHdr, "LEFT", 4, 0)
    pIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    pIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    right.pIcon = pIcon

    local rNameFs = B:Font(rHdr, 9, "LEFT")
    rNameFs:SetPoint("LEFT", pIcon, "RIGHT", 5, 0)
    rNameFs:SetText("Equipment Overview")
    rNameFs:SetTextColor(1.0, 0.90, 0.62)
    right.nameFs = rNameFs

    local rLvlFs = B:Font(rHdr, 9, "RIGHT")
    rLvlFs:SetPoint("RIGHT", rHdr, "RIGHT", -6, 0)
    rLvlFs:SetText("")
    rLvlFs:SetTextColor(0.0, 0.90, 1.00)
    right.lvlFs = rLvlFs

    local rRule = rHdr:CreateTexture(nil, "ARTWORK")
    rRule:SetPoint("BOTTOMLEFT", rHdr, "BOTTOMLEFT", 0, 0)
    rRule:SetPoint("BOTTOMRIGHT", rHdr, "BOTTOMRIGHT", 0, 0)
    rRule:SetHeight(1)
    rRule:SetTexture(B.WHITE)
    B:Accent(rRule, "tex", 0.90)

    -- 17 Equipment List Rows
    local listRows = {}
    local nList = table.getn(LIST_SLOTS)
    for i = 1, nList do
        local lDef = LIST_SLOTS[i]
        local row = CreateFrame("Button", nil, right)
        row:SetWidth(227)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -28 - (i - 1) * 21)
        row.slotId = lDef.id

        local badge = B:Font(row, 8, "LEFT")
        badge:SetPoint("LEFT", row, "LEFT", 2, 0)
        badge:SetWidth(46)
        badge:SetHeight(16)
        badge:SetTextColor(0.25, 0.85, 0.95)
        badge:SetText(lDef.label)
        row.badge = badge

        local name = B:Font(row, 8, "LEFT")
        name:SetPoint("LEFT", badge, "RIGHT", 4, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        name:SetHeight(16)
        name:SetTextColor(0.50, 0.50, 0.50)
        name:SetText("(Empty)")
        row.name = name

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        B:Solid(hl, 1, 1, 1, 0.12)
        hl:SetAllPoints(row)

        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
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
            GameTooltip:Hide()
        end)

        listRows[i] = row
    end
    right.rows = listRows

    -- Hide Tabs & Clutter
    HideCharacterTabs()
    SuppressAZSMoreStats()
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
    local pClass, pClassToken = (type(UnitClass) == "function" and UnitClass("player")) or "Warrior", "WARRIOR"

    if CharacterNameText then
        CharacterNameText:SetText(pName)
    end
    if CharacterLevelText then
        local cCol = B:ResolveClassColor(pClassToken) or B:ResolveClassColor(pClass) or { r = 1, g = 1, b = 1 }
        local cr = math.floor((cCol.r or 1) * 255 + 0.5)
        local cg = math.floor((cCol.g or 1) * 255 + 0.5)
        local cb = math.floor((cCol.b or 1) * 255 + 0.5)
        CharacterLevelText:SetText(string.format("Level %d %s |cff%02x%02x%02x%s|r", pLvl, pRace, cr, cg, cb, pClass))
    end

    -- 2. Scan Equipment, Update Slots and Quality Borders
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
                B:SetBorderColor(slot, qCol.r, qCol.g, qCol.b, 1)

                if slot.buiLvlFs then slot.buiLvlFs:Hide() end
                slot:Show()
            else
                B:SetBorderColor(slot, 0.18, 0.18, 0.18, 0.80)
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
                row.name:SetTextColor(qCol.r, qCol.g, qCol.b)
            else
                row.itemLink = nil
                row.name:SetText("(Empty)")
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
        local _, effArm = (type(UnitArmor) == "function" and UnitArmor("player")) or 0, 0
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
                r.heal.val:SetText(string.format("+%.0f HP", hVal))
                r.heal.val:SetTextColor(0.30, 0.95, 0.50)
            else
                r.heal.val:SetText("0")
                r.heal.val:SetTextColor(0.60, 0.60, 0.60)
            end
        end

        if r.pick then
            local pVal = s.pick
            if pVal and pVal > 0 then
                r.pick.val:SetText(string.format("%.0f yd", pVal))
                r.pick.val:SetTextColor(0.90, 0.90, 0.90)
            else
                r.pick.val:SetText("0 yd")
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
    end

    HideCharacterTabs()
    SuppressAZSMoreStats()
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
            local sf = BUI_StatsFrame or EUI_StatsFrame
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
            local sf = BUI_StatsFrame or EUI_StatsFrame
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
