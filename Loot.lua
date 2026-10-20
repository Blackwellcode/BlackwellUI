-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Loot.lua
--  Cyberpunk Loot Drop Telemetry Log:
--  - Real-time drop logger for Azeroth Survivors equipment and chests
--  - Parses CHAT_MSG_LOOT with item quality detection and run timestamps
--  - Sleek dark translucent matrix with 1px border and hover tooltips
--  - Alt-draggable and toggleable via options or /bw loot
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Loot Drop Log"

local MAX_LOOT_ROWS = 8
local ROW_HEIGHT = 16
local LOOT_WIDTH = 220

local lootHistory = {}

local QUALITY_COLORS = {
    ["9d9d9d"] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor / Gray
    ["ffffff"] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common / White
    ["1eff00"] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon / Green
    ["0070dd"] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare / Blue
    ["a335ee"] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic / Purple
    ["ff8000"] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary / Orange
}

local lootWatcher = CreateFrame("Frame")
lootWatcher:RegisterEvent("CHAT_MSG_LOOT")
lootWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
lootWatcher:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_ENABLED" then
        return
    end

    local msg = arg1 or ""
    -- "You receive loot: |cffa335ee|Hitem:19019:0:0:0|h[Thunderfury, Blessed Blade of the Windseeker]|h|r."
    local _, _, hexColor, itemLink, itemName = string.find(msg, "You receive loot: |c(%x+)|H(item:[%d:]+)|h%[(.-)%]|h|r")
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

        local qColor = hexColor and QUALITY_COLORS[string.lower(hexColor)] or { r = 0.90, g = 0.90, b = 0.90 }

        table.insert(lootHistory, 1, {
            name = itemName,
            link = itemLink,
            color = qColor,
            time = runT,
        })

        while table.getn(lootHistory) > MAX_LOOT_ROWS do
            table.remove(lootHistory)
        end

        if mod.frame and mod.frame:IsShown() then
            mod:UpdateRows()
        end
    end
end)

function mod:UpdateRows()
    local f = self.frame
    if not f then return end

    local nItems = table.getn(lootHistory)
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
            f:SetHeight(24)
            return
        end
    end

    f:Show()
    f.header.value:SetText(tostring(nItems))

    local shown = 0
    for i = 1, MAX_LOOT_ROWS do
        local r = f.rows[i]
        if i <= nItems then
            local it = lootHistory[i]
            r.timeFs:SetText(string.format("[%s]", B:Clock(it.time)))
            r.nameFs:SetText(it.name)
            r.nameFs:SetTextColor(it.color.r, it.color.g, it.color.b)

            r.itemLink = it.link
            r.itemName = it.name
            r.itemColor = it.color

            r:Show()
            shown = shown + 1
        else
            r:Hide()
        end
    end

    local h = 22 + shown * ROW_HEIGHT + 4
    if h < 26 then h = 26 end
    f:SetHeight(h)
end

function mod:Create()
    local f = CreateFrame("Frame", "BUI_LootFrame", UIParent)
    f:SetWidth(LOOT_WIDTH)
    f:SetHeight(120)
    B:Backdrop(f, 0.88)
    self.frame = f

    -- Header
    f.header = B:Header(f, "LOOT LOG", 18)

    local rows = {}
    for i = 1, MAX_LOOT_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetWidth(LOOT_WIDTH - 8)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -20 - (i - 1) * ROW_HEIGHT)

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
            GameTooltip:Hide()
        end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    f:Hide()
    B:RegisterMover(f, "loot", "Loot Drop Log", "TOPLEFT", "TOPLEFT", 12, -180)
end

function mod:Update(state)
    if B.db and B.db.hideLoot then
        if self.frame then self.frame:Hide() end
        return
    end
    self:UpdateRows()
end

B:RegisterModule("loot", mod)
