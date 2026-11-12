-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  RareTimers.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Cyberpunk Guardian & Rare Spawn Telemetry HUD:
--  - Monitors all rare & guardian lairs (AZS_LAIRS / AZS_GetLairs())
--  - Live status indicators: Fighting (Red), Alive (Green), Respawn Timer (Amber)
--  - Dynamic sorting: Active encounters on top, countdowns ordered by time
--  - Docked next to Minimap with independent mover registration
--  - Proximity tracking (distance in yards) and detailed hover tooltips
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Rare Spawn Timers"

local RARE_FRAME_WIDTH = 170
local MAX_RARE_ROWS = 10
local ROW_HEIGHT = 16
local ROW_GAP = 2
local PAD = 12
local SKULL_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

function mod:Create()
    local f = CreateFrame("Frame", "BUI_RareTimers", UIParent)
    self.frame = f

    f:SetWidth(RARE_FRAME_WIDTH)
    f:SetHeight(120)
    B:Panel(f)

    ---------------------------------------------------------------------------
    --  Header: skull, muted title, alive count
    ---------------------------------------------------------------------------
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(16)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -8)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -8)
    f.header = hdr

    local skull = hdr:CreateTexture(nil, "ARTWORK")
    skull:SetWidth(12)
    skull:SetHeight(12)
    skull:SetPoint("LEFT", hdr, "LEFT", 0, 0)
    skull:SetTexture(SKULL_ICON)
    skull:SetVertexColor(0.85, 0.80, 0.65)
    hdr.skull = skull

    local titleFs = B:Font(hdr, 9, "LEFT")
    titleFs:SetPoint("LEFT", skull, "RIGHT", 5, 0)
    titleFs:SetPoint("RIGHT", hdr, "RIGHT", -50, 0)
    titleFs:SetHeight(14)
    titleFs:SetTextColor(0.62, 0.61, 0.57)
    titleFs:SetText(L["RARE TIMERS"])
    hdr.title = titleFs

    local valFs = B:Font(hdr, 9, "RIGHT")
    valFs:SetPoint("RIGHT", hdr, "RIGHT", 0, 0)
    valFs:SetTextColor(0.70, 0.92, 0.68)
    hdr.value = valFs

    ---------------------------------------------------------------------------
    --  Rows (up to MAX_RARE_ROWS)
    ---------------------------------------------------------------------------
    local rows = {}
    for i = 1, MAX_RARE_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -(i - 1) * (ROW_HEIGHT + ROW_GAP) - 4)
        r:SetPoint("TOPRIGHT", hdr, "BOTTOMRIGHT", 0, -(i - 1) * (ROW_HEIGHT + ROW_GAP) - 4)

        -- Round status dot: red fight, green alive, amber countdown
        local dot = r:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(B.ROUND)
        dot:SetWidth(7)
        dot:SetHeight(7)
        dot:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.dot = dot

        local nameFs = B:Font(r, 9, "LEFT")
        nameFs:SetPoint("LEFT", dot, "RIGHT", 7, 0)
        nameFs:SetPoint("RIGHT", r, "RIGHT", -52, 0)
        nameFs:SetHeight(14)
        nameFs:SetTextColor(0.92, 0.91, 0.87)
        r.nameFs = nameFs

        local statusFs = B:Font(r, 9, "RIGHT")
        statusFs:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        statusFs:SetWidth(50)
        statusFs:SetHeight(14)
        r.statusFs = statusFs

        -- Hover tint, shown from OnEnter: this engine draws the HIGHLIGHT
        -- layer all the time, not only under the mouse.
        local hl = r:CreateTexture(nil, "BACKGROUND")
        B:Solid(hl, 1, 1, 1, 0.06)
        hl:SetAllPoints(r)
        hl:Hide()
        r.hl = hl

        r:EnableMouse(true)
        r:SetScript("OnEnter", function()
            this.hl:Show()
            local d = this.data
            if not d then return end
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(d.name or L["Rare Guardian"], 1, 1, 1)

            if d.state == "awake" then
                GameTooltip:AddLine(L["Status: In Combat (Awake)"], 1.0, 0.35, 0.35)
            elseif d.state == "asleep" then
                GameTooltip:AddLine(L["Status: Alive / Spawned (At Lair)"], 0.25, 0.90, 0.45)
            else
                local rem = d.left or 0
                if rem <= 0 then
                    GameTooltip:AddLine(L["Status: Due to Spawn"], 1.0, 0.85, 0.20)
                else
                    GameTooltip:AddLine(string.format(L["Status: Respawns in %s"], B:Clock(rem)), 1.0, 0.70, 0.20)
                end
            end

            if d.distance and d.distance > 0 then
                GameTooltip:AddLine(string.format(L["Distance: %d yards"], math.floor(d.distance + 0.5)), 0.75, 0.85, 1.0)
            end

            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function()
            this.hl:Hide()
            GameTooltip:Hide()
        end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    f:Hide()
    -- Default placement: Docked next to Minimap (-196, -12)
    B:RegisterMover(f, "rares", L["Rare Spawn Timers"], "TOPRIGHT", "TOPRIGHT", -196, -12)
end

function mod:Update(state)
    local f = self.frame
    if not f then return end

    local rawLairs = state.lairs or (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or (type(AZS_LAIRS) == "table" and AZS_LAIRS)
    local isDemo = (state and state.demo) or B.unlocked

    if isDemo then
        rawLairs = {
            { index = 1, state = "asleep", name = "Bloodmage Thalnos", left = 0, dist = 65 },
            { index = 2, state = "awake", name = "Interrogator Vishas", left = 0, dist = 120 },
            { index = 3, state = "empty", name = "Ironspine", left = 102, dist = 210 },
            { index = 4, state = "empty", name = "Azshir the Sleepless", left = 255, dist = 340 },
        }
    end

    if type(rawLairs) ~= "table" or table.getn(rawLairs) == 0 then
        f:Hide()
        return
    end
    local onlyAlive = B:ModOpt("rares", "onlyAlive", false)
    local showDistance = B:ModOpt("rares", "showDistance", false)
    local maxRows = B:ModOpt("rares", "maxRows", MAX_RARE_ROWS)

    local now = GetTime()
    local updated = state.lairsUpdated or AZS_LAIRS_UPDATED or now
    local delta = now - updated
    if delta < 0 then delta = 0 end

    -- Player position for distance calculation
    local hx, hy = nil, nil
    if state and state.run then
        hx = tonumber(state.run.px)
        hy = tonumber(state.run.py)
    end
    if not hx and type(AZS_RUN) == "table" then
        hx = tonumber(AZS_RUN.px)
        hy = tonumber(AZS_RUN.py)
    end

    local list = {}
    local aliveCount = 0
    local totalLairs = table.getn(rawLairs)

    for i = 1, totalLairs do
        local l = rawLairs[i]
        if type(l) == "table" then
            local sName = l.name or string.format(L["Lair %s"], tostring(l.index or i))
            local sState = l.state or "empty"
            local left = tonumber(l.left) or 0
            if left > 0 then
                left = left - delta
                if left < 0 then left = 0 end
            end

            local dist = l.dist
            if not dist and hx and hy and l.x and l.y then
                local lx = tonumber(l.x)
                local ly = tonumber(l.y)
                if lx and ly then
                    local dx = lx - hx
                    local dy = ly - hy
                    dist = math.sqrt(dx * dx + dy * dy)
                end
            end

            local priority = 3
            local skip = onlyAlive and sState ~= "awake" and sState ~= "asleep"
            if sState == "awake" then
                priority = 1
                aliveCount = aliveCount + 1
            elseif sState == "asleep" then
                priority = 2
                aliveCount = aliveCount + 1
            end

            if not skip then table.insert(list, {
                index = l.index or i,
                name = sName,
                state = sState,
                left = left,
                distance = dist,
                priority = priority,
            }) end
        end
    end

    if table.getn(list) == 0 then
        f:Hide()
        return
    end

    -- Sorting: Fighting (1) -> Alive (2) -> Empty/Countdown ascending (3)
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        if a.priority == 3 then
            return a.left < b.left
        end
        return (a.distance or 9999) < (b.distance or 9999)
    end)

    f.header.value:SetText(string.format(L["%d/%d Alive"], aliveCount, totalLairs))

    local count = table.getn(list)
    local shown = 0

    for i = 1, MAX_RARE_ROWS do
        local r = f.rows[i]
        if i <= count and i <= maxRows then
            local item = list[i]
            r.data = item
            if showDistance and item.distance and item.distance > 0 then
                r.nameFs:SetText(string.format("%s |cff8d8a80%d|r", item.name, math.floor(item.distance + 0.5)))
            else
                r.nameFs:SetText(item.name)
            end

            if item.state == "awake" then
                r.dot:SetVertexColor(1.0, 0.25, 0.25)
                r.dot:SetAlpha(1)
                r.statusFs:SetText("|cffff3333" .. L["FIGHT"] .. "|r")
            elseif item.state == "asleep" then
                r.dot:SetVertexColor(0.25, 0.90, 0.45)
                r.dot:SetAlpha(1)
                r.statusFs:SetText("|cff00ff88" .. L["ALIVE"] .. "|r")
            else
                if item.left <= 0 then
                    r.dot:SetVertexColor(1.0, 0.80, 0.0)
                    r.dot:SetAlpha(1)
                    r.statusFs:SetText("|cffffcc00" .. L["DUE"] .. "|r")
                else
                    r.dot:SetVertexColor(1.0, 0.67, 0.0)
                    r.dot:SetAlpha(0.55)
                    r.statusFs:SetText("|cffffaa00" .. B:Clock(item.left) .. "|r")
                end
            end

            r:Show()
            shown = shown + 1
        else
            r.data = nil
            r:Hide()
        end
    end

    local headerH = (B:ModOpt("rares", "showHeader", true) and 28) or 6
    local h = headerH + shown * (ROW_HEIGHT + ROW_GAP) + 6
    if h < 34 then h = 34 end
    f:SetHeight(h)
    f:Show()
end

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
mod.hint = "Rare guardians and their lairs: fighting, alive or the respawn countdown."
mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "width", label = "Width", min = 140, max = 280, step = 10, default = RARE_FRAME_WIDTH, format = "%d px" },
    { type = "range", key = "maxRows", label = "Rows shown", min = 1, max = MAX_RARE_ROWS, step = 1, default = MAX_RARE_ROWS, format = "%d" },
    { type = "toggle", key = "showHeader", label = "Title row", default = true },
    { type = "section", label = "Content" },
    { type = "toggle", key = "onlyAlive", label = "Only spawned rares", hint = "Hides lairs that are still counting down.", default = false },
    { type = "toggle", key = "showDistance", label = "Distance after the name", default = false },
}

function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    f:SetWidth(B:ModOpt("rares", "width", RARE_FRAME_WIDTH))
    local showHeader = B:ModOpt("rares", "showHeader", true)
    if showHeader then f.header:Show() else f.header:Hide() end
    -- Rows hang under the title row, or straight under the top padding.
    for i = 1, MAX_RARE_ROWS do
        local r = f.rows[i]
        local y = -(i - 1) * (ROW_HEIGHT + ROW_GAP)
        r:ClearAllPoints()
        if showHeader then
            r:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, y - 4)
            r:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, y - 4)
        else
            r:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 6)
            r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y - 6)
        end
    end
end

B:RegisterModule("rares", mod)
