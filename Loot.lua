-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Loot.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Cyberpunk Loot Drop Telemetry Log:
--  - Real-time drop logger for Azeroth Survivors equipment and chests
--  - Parses CHAT_MSG_LOOT with item quality detection and run timestamps
--  - Round card (or the sharp 1px-border look) with hover tooltips
--  - Alt-draggable and toggleable via options or /bw loot
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Loot Drop Log"
mod.hint = "Recent item drops with quality colours and run time."

-- Rows built once; "Max entries" shows up to this many.
local MAX_LOOT_ROWS = 20
local ROW_HEIGHT = 16
local LOOT_WIDTH = 220
local FADE_TIME = 3
local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local lootHistory = {}

local QUALITY_COLORS = {
    ["9d9d9d"] = { r = 0.62, g = 0.62, b = 0.62, q = 0 }, -- Poor / Gray
    ["ffffff"] = { r = 1.00, g = 1.00, b = 1.00, q = 1 }, -- Common / White
    ["1eff00"] = { r = 0.12, g = 1.00, b = 0.00, q = 2 }, -- Uncommon / Green
    ["0070dd"] = { r = 0.00, g = 0.44, b = 0.87, q = 3 }, -- Rare / Blue
    ["a335ee"] = { r = 0.64, g = 0.21, b = 0.93, q = 4 }, -- Epic / Purple
    ["ff8000"] = { r = 1.00, g = 0.50, b = 0.00, q = 5 }, -- Legendary / Orange
}

mod.options = {
    { type = "section", label = "Entries" },
    { type = "range", key = "maxRows", label = "Max entries", min = 1, max = 20, step = 1, default = 8, format = "%d" },
    { type = "range", key = "lifetime", label = "Entry lifetime", hint = "0 keeps entries until newer drops push them out.", min = 0, max = 300, step = 10, default = 0, format = "%d s" },
    { type = "toggle", key = "fadeOut", label = "Fade out", hint = "Entries fade during their last seconds (needs a lifetime).", default = true },
    { type = "choice", key = "minQuality", label = "Minimum quality", default = 0,
      values = {
          { value = 0, label = "Poor" },
          { value = 1, label = "Common" },
          { value = 2, label = "Uncommon" },
          { value = 3, label = "Rare" },
          { value = 4, label = "Epic" },
      } },
    { type = "section", label = "Layout" },
    { type = "range", key = "width", label = "Width", min = 160, max = 400, step = 10, default = 220, format = "%d px" },
    { type = "range", key = "rowHeight", label = "Row height", min = 12, max = 26, step = 1, default = 16, format = "%d px" },
    { type = "range", key = "fontSize", label = "Font size", hint = "Added to the global font size.", min = -3, max = 6, step = 1, default = 0, format = "%d" },
    { type = "choice", key = "growth", label = "Growth direction", default = "down",
      values = { { value = "down", label = "Down, newest on top" }, { value = "up", label = "Up, newest at the bottom" } } },
    { type = "section", label = "Elements" },
    { type = "toggle", key = "showIcons", label = "Show icons", default = true },
    { type = "toggle", key = "showQuantity", label = "Show quantity", default = true },
    { type = "toggle", key = "showTime", label = "Show run time", default = true },
    { type = "toggle", key = "qualityColor", label = "Colour names by quality", default = true },
}

local function Opt(key, default)
    return B:ModOpt("loot", key, default)
end

local function ItemIcon(link)
    if link and type(GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, _, tex = GetItemInfo(link)
        if type(tex) == "string" and tex ~= "" then return tex end
    end
    return ICON_FALLBACK
end

local lootWatcher = CreateFrame("Frame")
lootWatcher:RegisterEvent("CHAT_MSG_LOOT")
lootWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
lootWatcher:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_ENABLED" then
        return
    end

    local msg = arg1 or ""
    -- "You receive loot: |cffa335ee|Hitem:19019:0:0:0|h[Thunderfury, Blessed Blade of the Windseeker]|h|r."
    -- |cAARRGGBB: skip the alpha byte so the 6-digit RGB matches QUALITY_COLORS.
    local _, _, hexColor, itemLink, itemName = string.find(msg, "You receive loot: |c%x%x(%x%x%x%x%x%x)|H(item:[%d:]+)|h%[(.-)%]|h|r")
    if not itemName then
        _, _, itemLink, itemName = string.find(msg, "You receive loot: |H(item:[%d:]+)|h%[(.-)%]|h|r")
    end
    if not itemName then
        _, _, itemName = string.find(msg, "You receive loot: (.-)%.")
    end

    if itemName then
        local runT = 0
        if AZS_GetRunTime then
            runT = tonumber(AZS_GetRunTime()) or 0
        end

        local qColor = hexColor and QUALITY_COLORS[string.lower(hexColor)] or { r = 0.90, g = 0.90, b = 0.90, q = 1 }

        -- Stacks: "...|h|rx3." after the link.
        local qty = 1
        local _, _, qtyStr = string.find(msg, "|rx(%d+)")
        if qtyStr then qty = tonumber(qtyStr) or 1 end

        table.insert(lootHistory, 1, {
            name = itemName,
            link = itemLink,
            color = qColor,
            quality = qColor.q or 1,
            time = runT,
            seen = GetTime(),
            qty = qty,
        })

        while table.getn(lootHistory) > MAX_LOOT_ROWS do
            table.remove(lootHistory)
        end

        if mod.frame and mod.frame:IsShown() then
            mod:UpdateRows()
        end
    end
end)

-- Drops entries past their lifetime (0 = no limit).
local function ExpireEntries()
    local life = Opt("lifetime", 0)
    if life <= 0 then return end
    local now = GetTime()
    local n = table.getn(lootHistory)
    while n > 0 do
        local it = lootHistory[n]
        if it.seen and (now - it.seen) >= life then
            table.remove(lootHistory, n)
            n = n - 1
        else
            break
        end
    end
end

function mod:UpdateRows()
    local f = self.frame
    if not f then return end

    ExpireEntries()

    local maxRows = Opt("maxRows", 8)
    local minQ = Opt("minQuality", 0)
    local list = {}
    local nList = 0
    local nHist = table.getn(lootHistory)
    for i = 1, nHist do
        local it = lootHistory[i]
        if (it.quality or 1) >= minQ and nList < maxRows then
            nList = nList + 1
            list[nList] = it
        end
    end

    local nItems = nList
    if nItems == 0 then
        if not B.unlocked then
            f:Hide()
            return
        else
            f:Show()
            f.header.value:SetText("0")
            for i = 1, MAX_LOOT_ROWS do
                f.rows[i]:Hide()
            end
            f:SetHeight(f.topPad + 2)
            return
        end
    end

    f:Show()
    f.header.value:SetText(tostring(nItems))

    local rowH = Opt("rowHeight", ROW_HEIGHT)
    local life = Opt("lifetime", 0)
    local fade = Opt("fadeOut", true) and life > 0
    local showIcons = Opt("showIcons", true)
    local showQty = Opt("showQuantity", true)
    local showTime = Opt("showTime", true)
    local qualityColor = Opt("qualityColor", true)
    local up = (Opt("growth", "down") == "up")
    local now = GetTime()

    local shown = 0
    for i = 1, MAX_LOOT_ROWS do
        local r = f.rows[i]
        if i <= nItems then
            -- Growing up puts the newest entry in the bottom row.
            local idx = i
            if up then idx = nItems - i + 1 end
            local it = list[idx]
            if showTime then
                r.timeFs:SetText(string.format("[%s]", B:Clock(it.time)))
            end
            local text = it.name
            if showQty and it.qty and it.qty > 1 then
                text = text .. " x" .. tostring(it.qty)
            end
            r.nameFs:SetText(text)
            if qualityColor then
                r.nameFs:SetTextColor(it.color.r, it.color.g, it.color.b)
            else
                r.nameFs:SetTextColor(0.90, 0.90, 0.90)
            end
            if showIcons then
                r.icon:SetTexture(ItemIcon(it.link))
            end

            local a = 1
            if fade and it.seen then
                local left = life - (now - it.seen)
                if left < FADE_TIME then
                    a = left / FADE_TIME
                    if a < 0.1 then a = 0.1 end
                end
            end
            r:SetAlpha(a)

            r.itemLink = it.link
            r.itemName = it.name
            r.itemColor = it.color

            r:Show()
            shown = shown + 1
        else
            r:Hide()
        end
    end

    local h = f.topPad + shown * rowH + f.bottomPad
    if h < f.topPad + 4 then h = f.topPad + 4 end
    f:SetHeight(h)
end

-- Growth direction: the edge the log is anchored by stays put while rows are
-- added (as in Stats.lua). The converted anchor is saved as the position.
function mod:ApplyGrowth()
    local f = self.frame
    if not f then return end
    local want = ((Opt("growth", "down") == "up") and "BOTTOMLEFT") or "TOPLEFT"
    local cur = f:GetPoint(1)
    if cur == want then return end
    local left = f:GetLeft()
    local edge = (want == "BOTTOMLEFT" and f:GetBottom()) or f:GetTop()
    if not left or not edge then return end
    local y = edge
    if want == "TOPLEFT" then
        local ratio = 1
        if type(f.GetEffectiveScale) == "function" and type(UIParent.GetEffectiveScale) == "function" then
            ratio = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
        end
        y = edge - (UIParent:GetTop() or UIParent:GetHeight()) * ratio
    end
    local pos = {
        point = want,
        relPoint = want,
        x = math.floor(left + 0.5),
        y = math.floor(y + 0.5),
    }
    B.db.positions[f.buiKey or "loot"] = pos
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

function mod:Create()
    local f = CreateFrame("Frame", "BUI_LootFrame", UIParent)
    f:SetWidth(LOOT_WIDTH)
    f:SetHeight(120)
    self.frame = f

    local round = B:IsRound()
    if round then
        B:Panel(f)
        f.topPad = 26
        f.bottomPad = 8
        f.sidePad = 8
    else
        B:Backdrop(f, 0.88)
        f.topPad = 22
        f.bottomPad = 4
        f.sidePad = 4
    end

    -- Header
    f.header = B:Header(f, L["LOOT LOG"], 18)

    local rows = {}
    for i = 1, MAX_LOOT_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetWidth(LOOT_WIDTH - 2 * f.sidePad)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", f.sidePad, -(f.topPad - 2) - (i - 1) * ROW_HEIGHT)

        -- Hover tint, shown from OnEnter: this engine draws the HIGHLIGHT
        -- layer all the time, not only under the mouse.
        local hl = r:CreateTexture(nil, "BACKGROUND")
        B:Solid(hl, 1, 1, 1, (round and 0.06) or 0.10)
        hl:SetAllPoints(r)
        hl:Hide()
        r.hl = hl

        local icon = r:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", r, "LEFT", 2, 0)
        icon:SetWidth(ROW_HEIGHT - 2)
        icon:SetHeight(ROW_HEIGHT - 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon = icon

        local timeFs = B:Font(r, 9, "LEFT")
        timeFs:SetPoint("LEFT", r, "LEFT", 2, 0)
        timeFs:SetWidth(38)
        timeFs:SetHeight(ROW_HEIGHT)
        timeFs:SetTextColor(0.55, 0.55, 0.58)
        r.timeFs = timeFs

        local nameFs = B:Font(r, 9, "LEFT")
        nameFs:SetPoint("LEFT", timeFs, "RIGHT", 4, 0)
        nameFs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        nameFs:SetHeight(ROW_HEIGHT)
        r.nameFs = nameFs

        r:EnableMouse(true)
        r:SetScript("OnEnter", function()
            if this.hl then this.hl:Show() end
            if this.itemLink and GameTooltip.SetHyperlink then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(this.itemLink)
                GameTooltip:Show()
            elseif this.itemName then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                local c = this.itemColor or { r = 1, g = 1, b = 1 }
                GameTooltip:AddLine(this.itemName, c.r, c.g, c.b)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function()
            if this.hl then this.hl:Hide() end
            GameTooltip:Hide()
        end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    f:Hide()
    B:RegisterMover(f, "loot", L["Loot Drop Log"], "TOPLEFT", "TOPLEFT", 12, -180)
end

-- Width, row height, fonts and which row elements are laid out.
function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    local w = Opt("width", LOOT_WIDTH)
    local rowH = Opt("rowHeight", ROW_HEIGHT)
    local off = Opt("fontSize", 0)
    local showIcons = Opt("showIcons", true)
    local showTime = Opt("showTime", true)
    f:SetWidth(w)

    for i = 1, MAX_LOOT_ROWS do
        local r = f.rows[i]
        r:SetWidth(w - 2 * f.sidePad)
        r:SetHeight(rowH)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", f.sidePad, -(f.topPad - 2) - (i - 1) * rowH)

        r.timeFs.buiSize = 9 + off
        B:ApplyFont(r.timeFs)
        r.nameFs.buiSize = 9 + off
        B:ApplyFont(r.nameFs)
        r.timeFs:SetHeight(rowH)
        r.nameFs:SetHeight(rowH)

        r.icon:SetWidth(rowH - 2)
        r.icon:SetHeight(rowH - 2)
        local anchor = r
        local anchorPoint = "LEFT"
        local x = 2
        if showIcons then
            r.icon:Show()
            anchor = r.icon
            anchorPoint = "RIGHT"
            x = 4
        else
            r.icon:Hide()
        end
        r.timeFs:ClearAllPoints()
        r.nameFs:ClearAllPoints()
        if showTime then
            r.timeFs:SetPoint("LEFT", anchor, anchorPoint, x, 0)
            r.timeFs:Show()
            r.nameFs:SetPoint("LEFT", r.timeFs, "RIGHT", 4, 0)
        else
            r.timeFs:Hide()
            r.nameFs:SetPoint("LEFT", anchor, anchorPoint, x, 0)
        end
        r.nameFs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r:SetAlpha(1)
    end

    self:ApplyGrowth()
    self:UpdateRows()
end

-- hideLoot hides the game's own loot pop-ups (Core:WantStockHud); this log is
-- controlled by its module toggle only.
function mod:Update(state)
    self:UpdateRows()
end

B:RegisterModule("loot", mod)
