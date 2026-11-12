-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Equipment.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Picked Equipment & Items HUD:
--  - Positioned between Chat Panel and Hero Unit Frame
--  - Displays picked equipment items (Trinkets, Rings, Weapons, Armor, Cards)
--  - Rounded quality rings (round style) or 1px rarity borders (sharp style)
--    matching item quality (Poor, Common, Uncommon, Rare, Epic, Legendary)
--  - Interactive Mouseover tooltips displaying complete item stats & bonuses
--  - Demo mode preview with full sample inventory
--  - Movable HUD frame via /bui unlock
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Equipment"
mod.hint = "Equipped and carried items as a grid with quality colours."

local TILE_SIZE = 28
local TILE_GAP = 4
-- Defaults; the grid size comes from the module options.
local COLS = 7
local ROWS = 3 -- 21 tiles: all 17 equipment slots fit, weapons included
local MAX_SLOTS = COLS * ROWS

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

mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "tileSize", label = "Slot size", min = 20, max = 44, step = 2, default = 28, format = "%d px" },
    { type = "range", key = "columns", label = "Columns", min = 3, max = 12, step = 1, default = 7, format = "%d" },
    { type = "range", key = "rows", label = "Rows", min = 1, max = 6, step = 1, default = 3, format = "%d" },
    { type = "range", key = "spacing", label = "Spacing", min = 0, max = 10, step = 1, default = 4, format = "%d px" },
    { type = "range", key = "fontSize", label = "Font size", hint = "Added to the global font size.", min = -3, max = 6, step = 1, default = 0, format = "%d" },
    { type = "section", label = "Elements" },
    { type = "toggle", key = "showHeader", label = "Show header", default = true },
    { type = "toggle", key = "showCounter", label = "Show counter", default = true, depends = "showHeader" },
    { type = "toggle", key = "qualityRing", label = "Quality colour ring", hint = "Frames each slot in its item quality colour.", default = true },
    { type = "toggle", key = "showEmpty", label = "Show empty slots", hint = "Off shrinks the panel to the filled rows.", default = true },
    { type = "toggle", key = "showBags", label = "Include bag items", default = true },
    { type = "toggle", key = "showStacks", label = "Show stack counts", default = true },
}

local function Opt(key, default)
    return B:ModOpt("equipment", key, default)
end

local function SlotCount()
    return Opt("columns", COLS) * Opt("rows", ROWS)
end

local EMPTY_SHARP = { r = 0.20, g = 0.20, b = 0.20, a = 0.60 }
local EMPTY_ROUND = { r = 0.16, g = 0.17, b = 0.20, a = 0.90 }
local NEUTRAL_ROUND = { r = 0.12, g = 0.13, b = 0.16, a = 0.95 }

-- Rounded shape in its own colour (not a panel, so the theme refresh leaves
-- its colour alone): four disc quarters, two edge strips and a centre.
local function RoundShape(f, rad, layer)
    local shape = { parts = {} }
    local function Part(round, l, rr, t, bb)
        local tex = f:CreateTexture(nil, layer or "BACKGROUND")
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

-- Slot frame colour: rounded ring in the round style, 1px border in sharp.
local function SetSlotColor(slot, r, g, b, a)
    if slot.ring then
        slot.ring:SetColor(r, g, b, a)
    else
        B:SetBorderColor(slot, r, g, b, a)
    end
end

local function SetSlotEmpty(slot)
    local c = (slot.ring and EMPTY_ROUND) or EMPTY_SHARP
    SetSlotColor(slot, c.r, c.g, c.b, c.a)
end

local function CreateSlot(f, i)
    -- Named frames only for the 21 slots the panel always had.
    local slotName = nil
    if i <= MAX_SLOTS then slotName = "BUI_EquipSlot" .. i end
    local slot = CreateFrame("Button", slotName, f)
    slot:SetWidth(TILE_SIZE)
    slot:SetHeight(TILE_SIZE)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    if B:IsRound() then
        -- Rounded quality ring: the icon sits 2px inside a rounded shape.
        slot.ring = RoundShape(slot, 5, "BACKGROUND")
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    else
        B:Backdrop(slot, 0.90)
        B:Border(slot, 0.20, 0.20, 0.20, 0.60)
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.icon = icon
    SetSlotEmpty(slot)

    local count = B:Font(slot, 9, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    count:SetTextColor(1, 1, 1)
    count:Hide()
    slot.countFs = count

    -- Hover tint, shown from OnEnter: this engine draws the HIGHLIGHT layer
    -- all the time, not only under the mouse.
    local hl = slot:CreateTexture(nil, "OVERLAY")
    B:Solid(hl, 1, 1, 1, 0.15)
    hl:SetAllPoints(icon)
    hl:Hide()
    slot.hl = hl

    slot:EnableMouse(true)
    slot:SetScript("OnEnter", function()
        if this.hl then this.hl:Show() end
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
        if this.hl then this.hl:Hide() end
        GameTooltip:Hide()
    end)

    return slot
end

-- Panel size for a number of grid rows (header and padding included).
local function PanelSize(f, nRows)
    local size = Opt("tileSize", TILE_SIZE)
    local gap = Opt("spacing", TILE_GAP)
    local cols = Opt("columns", COLS)
    local top = f.pad
    if Opt("showHeader", true) then top = f.headerPad end
    local w = 2 * f.pad + cols * size + (cols - 1) * gap
    local h = top + nRows * size + (nRows - 1) * gap + f.pad
    return w, h, top
end

local function LayoutSlots(f)
    local size = Opt("tileSize", TILE_SIZE)
    local gap = Opt("spacing", TILE_GAP)
    local cols = Opt("columns", COLS)
    local nRows = Opt("rows", ROWS)
    local total = cols * nRows
    local w, h, top = PanelSize(f, nRows)
    f:SetWidth(w)
    f:SetHeight(h)

    for i = 1, total do
        if not f.slots[i] then
            f.slots[i] = CreateSlot(f, i)
        end
    end
    for i = 1, table.getn(f.slots) do
        local slot = f.slots[i]
        if i <= total then
            local col = math.mod(i - 1, cols)
            local row = math.floor((i - 1) / cols)
            slot:SetWidth(size)
            slot:SetHeight(size)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", f, "TOPLEFT", f.pad + col * (size + gap), -top - row * (size + gap))
        else
            slot:Hide()
        end
    end
end

local function CreateEquipmentFrame()
    local fW = 6 + COLS * TILE_SIZE + (COLS - 1) * TILE_GAP + 6
    local fH = 24 + ROWS * TILE_SIZE + (ROWS - 1) * TILE_GAP + 6

    local round = B:IsRound()
    local f = CreateFrame("Frame", "BUI_Equipment", UIParent)
    f:SetWidth(fW)
    f:SetHeight(fH)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 28)
    f:SetFrameStrata("MEDIUM")
    if round then
        B:Panel(f)
        f.pad = 8
        f.headerPad = 28
    else
        B:Backdrop(f, 0.85)
        f.pad = 6
        f.headerPad = 24
    end

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(20)
    if round then
        hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -3)
        hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -3)
    else
        hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    end
    f.header = hdr

    local inset = (round and 8) or 4
    if not round then
        local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
        B:Solid(hdrBg, 0.04, 0.04, 0.04, 0.95)
        hdrBg:SetAllPoints(hdr)
    end

    local brandIcon = hdr:CreateTexture(nil, "ARTWORK")
    brandIcon:SetWidth(14)
    brandIcon:SetHeight(14)
    brandIcon:SetPoint("LEFT", hdr, "LEFT", inset, 0)
    brandIcon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    brandIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local titleFs = B:Font(hdr, 9, "LEFT")
    titleFs:SetPoint("LEFT", brandIcon, "RIGHT", 5, 0)
    titleFs:SetText(L["EQUIPMENT"])
    titleFs:SetTextColor(1.0, 0.90, 0.62)
    hdr.title = titleFs

    local countFs = B:Font(hdr, 9, "RIGHT")
    countFs:SetPoint("RIGHT", hdr, "RIGHT", -(inset + 2), 0)
    countFs:SetTextColor(0.85, 0.75, 0.45)
    countFs:SetText("(0/14)")
    hdr.count = countFs

    if not round then
        local rule = hdr:CreateTexture(nil, "ARTWORK")
        rule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
        rule:SetHeight(1)
        rule:SetTexture(B.WHITE)
        B:Accent(rule, "tex", 0.90)
    end

    -- Grid slots, built for the default 7 x 3 grid; more are added on demand.
    f.slots = {}
    LayoutSlots(f)

    B:RegisterMover(f, "equipment", L["Equipment / Items"], "BOTTOMLEFT", "BOTTOMLEFT", 400, 28)
    return f
end

-------------------------------------------------------------------------------
--  Item cache: rebuilt on inventory / bag events, drawn from the cache
-------------------------------------------------------------------------------
-- The scan walks every equipped slot and bag slot; it used to run 10 times a
-- second. Now it runs when BAG_UPDATE / UNIT_INVENTORY_CHANGED("player") /
-- PLAYER_ENTERING_WORLD flag it, when the scan inputs change (slot count, bags
-- option, preview), and as a slow safety net every RESCAN_FALLBACK seconds in
-- case the engine skips an event. Entry tables are reused between scans.
local RESCAN_FALLBACK = 2
local cache = {}
local cacheN = 0
local cacheDirty = true
local renderDirty = true
local lastScan = -RESCAN_FALLBACK
local lastMax, lastBags, lastPreview = nil, nil, nil

local function QualityFromLink(link)
    if not link then return nil end
    local _, _, colorCode = string.find(link, "|cff(%x%x%x%x%x%x)")
    if not colorCode then return nil end
    local hex = string.lower(colorCode)
    if hex == "9d9d9d" then return 0
    elseif hex == "ffffff" then return 1
    elseif hex == "1eff00" then return 2
    elseif hex == "0070dd" then return 3
    elseif hex == "a335ee" then return 4
    elseif hex == "ff8000" then return 5
    end
    return nil
end

-- Next cache entry with every field reset (entries are reused).
local function NextEntry()
    cacheN = cacheN + 1
    local e = cache[cacheN]
    if not e then
        e = {}
        cache[cacheN] = e
    end
    e.kind, e.slotId, e.bag, e.bagSlot = nil, nil, nil, nil
    e.texture, e.link, e.quality, e.count, e.demoData = nil, nil, nil, nil, nil
    return e
end

local function ScanItems(maxSlots, showBags, preview)
    cacheN = 0

    -- 1. Equipped inventory slots
    if type(GetInventoryItemTexture) == "function" then
        local nSlots = table.getn(INVENTORY_SLOTS)
        for i = 1, nSlots do
            if cacheN >= maxSlots then break end
            local slotId = INVENTORY_SLOTS[i]
            local tex = GetInventoryItemTexture("player", slotId)
            if tex and tex ~= "" then
                local link = (type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slotId)) or nil
                local quality = (type(GetInventoryItemQuality) == "function" and GetInventoryItemQuality("player", slotId)) or 1
                if (not quality or quality < 0) and link then
                    quality = QualityFromLink(link) or quality
                end
                local e = NextEntry()
                e.kind = "inv"
                e.slotId = slotId
                e.texture = tex
                e.link = link
                e.quality = quality or 1
            end
        end
    end

    -- 2. Bags if slots remain
    if showBags and cacheN < maxSlots and type(GetContainerNumSlots) == "function" and type(GetContainerItemInfo) == "function" then
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag) or 0
            for bSlot = 1, numSlots do
                if cacheN >= maxSlots then break end
                local tex, count = GetContainerItemInfo(bag, bSlot)
                if tex and tex ~= "" then
                    local link = (type(GetContainerItemLink) == "function" and GetContainerItemLink(bag, bSlot)) or nil
                    local e = NextEntry()
                    e.kind = "bag"
                    e.bag = bag
                    e.bagSlot = bSlot
                    e.texture = tex
                    e.link = link
                    e.quality = QualityFromLink(link) or 1
                    e.count = count
                end
            end
            if cacheN >= maxSlots then break end
        end
    end

    -- 3. Demo / unlocked preview
    if cacheN == 0 and preview then
        local nDemo = table.getn(DEMO_ITEMS)
        for dIdx = 1, nDemo do
            if cacheN >= maxSlots then break end
            local d = DEMO_ITEMS[dIdx]
            local e = NextEntry()
            e.kind = "demo"
            e.demoData = d
            e.texture = d.icon
            e.quality = d.quality
        end
    end
end

-- Forces a rescan on the next update (offline harness, other modules).
function mod:Invalidate()
    cacheDirty = true
end

function mod:Create()
    self.frame = CreateEquipmentFrame()

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("BAG_UPDATE")
    watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
        cacheDirty = true
    end)
    self.watcher = watcher
end

-- Grid size, slot size, fonts and header visibility.
function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    LayoutSlots(f)
    cacheDirty = true
    renderDirty = true

    local off = Opt("fontSize", 0)
    f.header.title.buiSize = 9 + off
    B:ApplyFont(f.header.title)
    f.header.count.buiSize = 9 + off
    B:ApplyFont(f.header.count)
    for i = 1, table.getn(f.slots) do
        f.slots[i].countFs.buiSize = 9 + off
        B:ApplyFont(f.slots[i].countFs)
    end

    if Opt("showHeader", true) then
        f.header:Show()
    else
        f.header:Hide()
    end
    if Opt("showCounter", true) then
        f.header.count:Show()
    else
        f.header.count:Hide()
    end
end

function mod:Update(state)
    local f = self.frame
    if not f then return end

    if not B:IsEnabled("equipment") then
        f:Hide()
        return
    end

    local maxSlots = SlotCount()
    local showBags = Opt("showBags", true) and true or false
    local preview = ((B.db and B.db.demo) or B.unlocked) and true or false
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if maxSlots ~= lastMax or showBags ~= lastBags or preview ~= lastPreview then
        cacheDirty = true
    end
    if not cacheDirty and now - lastScan >= RESCAN_FALLBACK then
        cacheDirty = true
    end
    if cacheDirty then
        ScanItems(maxSlots, showBags, preview)
        cacheDirty = false
        lastScan = now
        lastMax, lastBags, lastPreview = maxSlots, showBags, preview
        renderDirty = true
        self.scans = (self.scans or 0) + 1
    end
    if not renderDirty then return end
    renderDirty = false

    local items = cache
    local nItems = cacheN

    -- Update Header Count Badge
    f.header.count:SetText(string.format("(%d/%d)", nItems, maxSlots))

    local showEmpty = Opt("showEmpty", true)
    local qualityRing = Opt("qualityRing", true)
    local showStacks = Opt("showStacks", true)

    -- Without empty slots the panel shrinks to the filled rows.
    if not showEmpty then
        local cols = Opt("columns", COLS)
        local used = math.floor((nItems + cols - 1) / cols)
        if used < 1 then used = 1 end
        local _, h = PanelSize(f, used)
        f:SetHeight(h)
    else
        local _, h = PanelSize(f, Opt("rows", ROWS))
        f:SetHeight(h)
    end

    -- Render Slots
    for i = 1, maxSlots do
        local slot = f.slots[i]
        if slot then
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

                if qualityRing then
                    local q = itm.quality or 1
                    local qCol = QUALITY_COLORS[q] or QUALITY_COLORS[1]
                    local qr, qg, qb = qCol.r, qCol.g, qCol.b
                    if type(GetItemQualityColor) == "function" then
                        local cr, cg, cb = GetItemQualityColor(q)
                        if cr and cg and cb then
                            qr, qg, qb = cr, cg, cb
                        end
                    end
                    SetSlotColor(slot, qr, qg, qb, 1)
                elseif slot.ring then
                    SetSlotColor(slot, NEUTRAL_ROUND.r, NEUTRAL_ROUND.g, NEUTRAL_ROUND.b, NEUTRAL_ROUND.a)
                else
                    SetSlotEmpty(slot)
                end

                if showStacks and itm.count and itm.count > 1 then
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
                SetSlotEmpty(slot)
                if showEmpty then
                    slot:Show()
                else
                    slot:Hide()
                end
            end
        end
    end

    f:Show()
end

B:RegisterModule("equipment", mod)
