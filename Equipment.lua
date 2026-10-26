-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Equipment.lua
--  Picked Equipment & Items HUD:
--  - Positioned between Chat Panel and Hero Unit Frame
--  - Displays picked equipment items (Trinkets, Rings, Weapons, Armor, Cards)
--  - Dynamic Rarity Borders matching item quality (Poor, Common, Uncommon, Rare, Epic, Legendary)
--  - Interactive Mouseover tooltips displaying complete item stats & bonuses
--  - Demo mode preview with full sample inventory
--  - Movable HUD frame via /bui unlock
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Equipment"

local MAX_SLOTS = 14
local TILE_SIZE = 28
local TILE_GAP = 4
local COLS = 7
local ROWS = 2

-- Standard WoW Equipment Slot IDs
local INVENTORY_SLOTS = {
    1,  -- Head
    2,  -- Neck
    3,  -- Shoulder
    15, -- Back
    5,  -- Chest
    9,  -- Wrist
    10, -- Hands
    6,  -- Waist
    7,  -- Legs
    8,  -- Feet
    11, -- Finger 1
    12, -- Finger 2
    13, -- Trinket 1
    14, -- Trinket 2
    16, -- Main Hand
    17, -- Off Hand
    18, -- Ranged
}

-- Fallback quality color map
local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor / Gray
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common / White
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon / Green
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare / Blue
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic / Purple
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary / Orange
    [6] = { r = 0.90, g = 0.80, b = 0.50 }, -- Artifact / Gold
}

local DEMO_ITEMS = {
    { name = "Sulfuras, Hand of Ragnaros", quality = 5, icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras", type = "Two-Hand Mace", stats = { "223 - 372 Damage (Speed 3.70)", "+12 Strength", "+12 Stamina", "+30 Fire Resistance" }, equip = "Chance on hit: Hurls a fiery ball that causes 273 to 333 Fire damage." },
    { name = "Blackhand's Breadth", quality = 4, icon = "Interface\\Icons\\INV_Misc_ArmorKit_09", type = "Trinket", stats = {}, equip = "Equip: Increases your chance to land a critical strike by 2%." },
    { name = "Band of Accuria", quality = 4, icon = "Interface\\Icons\\INV_Jewelry_Ring_15", type = "Finger", stats = { "+16 Stamina" }, equip = "Equip: Improves your chance to hit with all attacks by 2%." },
    { name = "Onyxia Tooth Pendant", quality = 3, icon = "Interface\\Icons\\INV_Jewelry_Necklace_09", type = "Neck", stats = { "+12 Agility", "+9 Stamina", "+10 Fire Resistance" }, equip = "Equip: Improves your chance to hit by 1% and land a critical strike by 1%." },
    { name = "Choker of the Fire Lord", quality = 3, icon = "Interface\\Icons\\INV_Jewelry_Amulet_05", type = "Neck", stats = { "+7 Stamina", "+7 Intellect" }, equip = "Equip: Increases damage and healing done by magical spells by up to 34." },
    { name = "Heavy Dark Iron Ring", quality = 2, icon = "Interface\\Icons\\INV_Jewelry_Ring_14", type = "Finger", stats = { "+110 Armor", "+20 Stamina" }, equip = "" },
    { name = "Defias Bandana", quality = 2, icon = "Interface\\Icons\\INV_Misc_Bandana_03", type = "Head", stats = { "+6 Agility", "+5 Stamina" }, equip = "" },
    { name = "Cracked Stone Amulet", quality = 0, icon = "Interface\\Icons\\INV_Jewelry_Necklace_07", type = "Neck", stats = { "+1 Stamina" }, equip = "" },
}

local function CreateEquipmentFrame()
    local fW = 6 + COLS * TILE_SIZE + (COLS - 1) * TILE_GAP + 6
    local fH = 24 + ROWS * TILE_SIZE + (ROWS - 1) * TILE_GAP + 6

    local f = CreateFrame("Frame", "BUI_Equipment", UIParent)
    f:SetWidth(fW)
    f:SetHeight(fH)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 28)
    f:SetFrameStrata("MEDIUM")
    B:Backdrop(f, 0.85)

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(20)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.header = hdr

    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    B:Solid(hdrBg, 0.04, 0.04, 0.04, 0.95)
    hdrBg:SetAllPoints(hdr)

    local brandIcon = hdr:CreateTexture(nil, "ARTWORK")
    brandIcon:SetWidth(14)
    brandIcon:SetHeight(14)
    brandIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    brandIcon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    brandIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local titleFs = B:Font(hdr, 9, "LEFT")
    titleFs:SetPoint("LEFT", brandIcon, "RIGHT", 5, 0)
    titleFs:SetText("EQUIPMENT")
    titleFs:SetTextColor(1.0, 0.90, 0.62)

    local countFs = B:Font(hdr, 9, "RIGHT")
    countFs:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
    countFs:SetTextColor(0.85, 0.75, 0.45)
    countFs:SetText("(0/14)")
    hdr.count = countFs

    local rule = hdr:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetTexture(B.WHITE)
    B:Accent(rule, "tex", 0.90)

    -- 14 Grid Slots (2 rows of 7 slots)
    local slots = {}
    for i = 1, MAX_SLOTS do
        local col = math.mod(i - 1, COLS)
        local row = math.floor((i - 1) / COLS)

        local slot = CreateFrame("Button", "BUI_EquipSlot" .. i, f)
        slot:SetWidth(TILE_SIZE)
        slot:SetHeight(TILE_SIZE)
        slot:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + col * (TILE_SIZE + TILE_GAP), -24 - row * (TILE_SIZE + TILE_GAP))
        B:Backdrop(slot, 0.90)
        B:Border(slot, 0.20, 0.20, 0.20, 0.60)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.icon = icon

        local count = B:Font(slot, 9, "RIGHT")
        count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
        count:SetTextColor(1, 1, 1)
        count:Hide()
        slot.countFs = count

        local hl = slot:CreateTexture(nil, "HIGHLIGHT")
        B:Solid(hl, 1, 1, 1, 0.15)
        hl:SetAllPoints(slot)

        slot:EnableMouse(true)
        slot:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()

            if this.itemKind == "inv" and this.invSlot then
                local hasItem = GameTooltip:SetInventoryItem("player", this.invSlot)
                if not hasItem and this.itemLink then
                    GameTooltip:SetHyperlink(this.itemLink)
                end
            elseif this.itemKind == "bag" and this.bag and this.bagSlot then
                GameTooltip:SetBagItem(this.bag, this.bagSlot)
            elseif this.itemKind == "demo" and this.demoData then
                local d = this.demoData
                local qCol = QUALITY_COLORS[d.quality or 1] or QUALITY_COLORS[1]
                GameTooltip:AddLine(d.name, qCol.r, qCol.g, qCol.b)
                if d.type and d.type ~= "" then
                    GameTooltip:AddLine(d.type, 0.90, 0.90, 0.90)
                end
                if d.stats then
                    local nStats = table.getn(d.stats)
                    for sIdx = 1, nStats do
                        GameTooltip:AddLine(d.stats[sIdx], 1, 1, 1)
                    end
                end
                if d.equip and d.equip ~= "" then
                    GameTooltip:AddLine(d.equip, 0, 1, 0, 1)
                end
            end

            GameTooltip:Show()
        end)

        slot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        slots[i] = slot
    end
    f.slots = slots

    B:RegisterMover(f, "equipment", "Equipment / Items", "BOTTOMLEFT", "BOTTOMLEFT", 400, 28)
    return f
end

function mod:Create()
    self.frame = CreateEquipmentFrame()
end

function mod:Update(state)
    local f = self.frame
    if not f then return end

    if not B:IsEnabled("equipment") then
        f:Hide()
        return
    end

    local items = {}
    local nItems = 0

    -- 1. Scan equipped inventory slots
    if type(GetInventoryItemTexture) == "function" then
        local nSlots = table.getn(INVENTORY_SLOTS)
        for i = 1, nSlots do
            local slotId = INVENTORY_SLOTS[i]
            local tex = GetInventoryItemTexture("player", slotId)
            if tex and tex ~= "" then
                local link = (type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slotId)) or nil
                local quality = (type(GetInventoryItemQuality) == "function" and GetInventoryItemQuality("player", slotId)) or 1
                if (not quality or quality < 0) and link then
                    local _, _, colorCode = string.find(link, "|cff(%x%x%x%x%x%x)")
                    if colorCode then
                        local hex = string.lower(colorCode)
                        if hex == "9d9d9d" then quality = 0
                        elseif hex == "ffffff" then quality = 1
                        elseif hex == "1eff00" then quality = 2
                        elseif hex == "0070dd" then quality = 3
                        elseif hex == "a335ee" then quality = 4
                        elseif hex == "ff8000" then quality = 5
                        end
                    end
                end
                nItems = nItems + 1
                items[nItems] = {
                    kind = "inv",
                    slotId = slotId,
                    texture = tex,
                    link = link,
                    quality = quality or 1,
                }
            end
        end
    end

    -- 2. Scan bags if slots remain
    if nItems < MAX_SLOTS and type(GetContainerNumSlots) == "function" and type(GetContainerItemInfo) == "function" then
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag) or 0
            for bSlot = 1, numSlots do
                if nItems >= MAX_SLOTS then break end
                local tex, count = GetContainerItemInfo(bag, bSlot)
                if tex and tex ~= "" then
                    local link = (type(GetContainerItemLink) == "function" and GetContainerItemLink(bag, bSlot)) or nil
                    local quality = 1
                    if link then
                        local _, _, colorCode = string.find(link, "|cff(%x%x%x%x%x%x)")
                        if colorCode then
                            local hex = string.lower(colorCode)
                            if hex == "9d9d9d" then quality = 0
                            elseif hex == "ffffff" then quality = 1
                            elseif hex == "1eff00" then quality = 2
                            elseif hex == "0070dd" then quality = 3
                            elseif hex == "a335ee" then quality = 4
                            elseif hex == "ff8000" then quality = 5
                            end
                        end
                    end
                    nItems = nItems + 1
                    items[nItems] = {
                        kind = "bag",
                        bag = bag,
                        bagSlot = bSlot,
                        texture = tex,
                        link = link,
                        quality = quality,
                        count = count,
                    }
                end
            end
            if nItems >= MAX_SLOTS then break end
        end
    end

    -- 3. Demo / Unlocked Preview
    if nItems == 0 and (B.demo or B.unlocked) then
        local nDemo = table.getn(DEMO_ITEMS)
        for dIdx = 1, nDemo do
            nItems = nItems + 1
            local d = DEMO_ITEMS[dIdx]
            items[nItems] = {
                kind = "demo",
                demoData = d,
                texture = d.icon,
                quality = d.quality,
            }
        end
    end

    -- Update Header Count Badge
    f.header.count:SetText(string.format("(%d/%d)", nItems, MAX_SLOTS))

    -- Render Slots
    for i = 1, MAX_SLOTS do
        local slot = f.slots[i]
        if i <= nItems then
            local itm = items[i]
            slot.itemKind = itm.kind
            slot.invSlot = itm.slotId
            slot.bag = itm.bag
            slot.bagSlot = itm.bagSlot
            slot.itemLink = itm.link
            slot.demoData = itm.demoData

            slot.icon:SetTexture(itm.texture)
            slot.icon:Show()

            local q = itm.quality or 1
            local qCol = QUALITY_COLORS[q] or QUALITY_COLORS[1]
            if type(GetItemQualityColor) == "function" then
                local qr, qg, qb = GetItemQualityColor(q)
                if qr and qg and qb then
                    qCol = { r = qr, g = qg, b = qb }
                end
            end
            B:SetBorderColor(slot, qCol.r, qCol.g, qCol.b, 1)

            if itm.count and itm.count > 1 then
                slot.countFs:SetText(tostring(itm.count))
                slot.countFs:Show()
            else
                slot.countFs:Hide()
            end
            slot:Show()
        else
            slot.itemKind = nil
            slot.invSlot = nil
            slot.bag = nil
            slot.bagSlot = nil
            slot.itemLink = nil
            slot.demoData = nil

            slot.icon:Hide()
            slot.countFs:Hide()
            B:SetBorderColor(slot, 0.20, 0.20, 0.20, 0.60)
            slot:Show()
        end
    end

    f:Show()
end

B:RegisterModule("equipment", mod)
