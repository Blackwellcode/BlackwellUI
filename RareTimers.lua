-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  RareTimers.lua
--  Cyberpunk Guardian & Rare Spawn Telemetry HUD:
--  - Monitors all rare & guardian lairs (AZS_LAIRS / AZS_GetLairs())
--  - Live status indicators: Fighting (Red), Alive (Green), Respawn Timer (Amber)
--  - Dynamic sorting: Active encounters on top, countdowns ordered by time
--  - Docked next to Minimap with independent mover registration
--  - Proximity tracking (distance in yards) and detailed hover tooltips
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Rare Spawn Timers"

local RARE_FRAME_WIDTH = 170
local MAX_RARE_ROWS = 10
local ROW_HEIGHT = 18
local ROW_GAP = 2
local SKULL_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

function mod:Create()
    local f = CreateFrame("Frame", "BUI_RareTimers", UIParent)
    EUI_RareTimers = f -- Compatibility alias
    self.frame = f

    f:SetWidth(RARE_FRAME_WIDTH)
    f:SetHeight(120)
    B:Backdrop(f, 0.88)

    ---------------------------------------------------------------------------
    --  Header (Height 20px)
    ---------------------------------------------------------------------------
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(20)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.header = hdr

    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    B:Solid(hdrBg, 0.04, 0.04, 0.04, 0.95)
    hdrBg:SetAllPoints(hdr)

    local rule = hdr:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetTexture(B.WHITE)
    B:Accent(rule, "tex", 0.90)
    hdr.rule = rule

    local skull = hdr:CreateTexture(nil, "ARTWORK")
    skull:SetWidth(14)
    skull:SetHeight(14)
    skull:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    skull:SetTexture(SKULL_ICON)
    hdr.skull = skull

    local titleFs = B:Font(hdr, 10, "LEFT")
    titleFs:SetPoint("LEFT", skull, "RIGHT", 5, 0)
    titleFs:SetWidth(95)
    titleFs:SetHeight(14)
    titleFs:SetTextColor(1.0, 0.90, 0.62)
    titleFs:SetText("RARE TIMERS")
    hdr.title = titleFs

    local valFs = B:Font(hdr, 9, "RIGHT")
    valFs:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
    valFs:SetTextColor(0.70, 0.92, 0.68)
    hdr.value = valFs

    ---------------------------------------------------------------------------
    --  Rows (up to MAX_RARE_ROWS)
    ---------------------------------------------------------------------------
    local rows = {}
    for i = 1, MAX_RARE_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetWidth(RARE_FRAME_WIDTH - 8)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 3, -(i - 1) * (ROW_HEIGHT + ROW_GAP) - 3)

        local rowBg = r:CreateTexture(nil, "BACKGROUND")
        B:Solid(rowBg, 0.08, 0.08, 0.10, 0.50)
        rowBg:SetAllPoints(r)
        r.rowBg = rowBg

        local rSkull = r:CreateTexture(nil, "ARTWORK")
        rSkull:SetWidth(12)
        rSkull:SetHeight(12)
        rSkull:SetPoint("LEFT", r, "LEFT", 3, 0)
        rSkull:SetTexture(SKULL_ICON)
        r.skull = rSkull

        local nameFs = B:Font(r, 9, "LEFT")
        nameFs:SetPoint("LEFT", rSkull, "RIGHT", 4, 0)
        nameFs:SetWidth(90)
        nameFs:SetHeight(14)
        nameFs:SetTextColor(0.95, 0.95, 0.95)
        r.nameFs = nameFs

        local statusFs = B:Font(r, 9, "RIGHT")
        statusFs:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        statusFs:SetWidth(50)
        statusFs:SetHeight(14)
        r.statusFs = statusFs

        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        B:Solid(hl, 1, 1, 1, 0.12)
        hl:SetAllPoints(r)

        r:EnableMouse(true)
        r:SetScript("OnEnter", function()
            local d = this.data
            if not d then return end
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(d.name or "Rare Guardian", 1, 1, 1)

            if d.state == "awake" then
                GameTooltip:AddLine("Status: In Combat (Awake)", 1.0, 0.35, 0.35)
            elseif d.state == "asleep" then
                GameTooltip:AddLine("Status: Alive / Spawned (At Lair)", 0.25, 0.90, 0.45)
            else
                local rem = d.left or 0
                if rem <= 0 then
                    GameTooltip:AddLine("Status: Due to Spawn", 1.0, 0.85, 0.20)
                else
                    GameTooltip:AddLine(string.format("Status: Respawns in %s", B:Clock(rem)), 1.0, 0.70, 0.20)
                end
            end

            if d.distance and d.distance > 0 then
                GameTooltip:AddLine(string.format("Distance: %d yards", math.floor(d.distance + 0.5)), 0.75, 0.85, 1.0)
            end

            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    f:Hide()
    -- Default placement: Docked next to Minimap (-196, -12)
    B:RegisterMover(f, "rares", "Rare Spawn Timers", "TOPRIGHT", "TOPRIGHT", -196, -12)
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
            local sName = l.name or ("Lair " .. tostring(l.index or i))
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
            if sState == "awake" then
                priority = 1
                aliveCount = aliveCount + 1
            elseif sState == "asleep" then
                priority = 2
                aliveCount = aliveCount + 1
            end

            table.insert(list, {
                index = l.index or i,
                name = sName,
                state = sState,
                left = left,
                distance = dist,
                priority = priority,
            })
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

    f.header.value:SetText(string.format("%d/%d Alive", aliveCount, totalLairs))

    local count = table.getn(list)
    local shown = 0

    for i = 1, MAX_RARE_ROWS do
        local r = f.rows[i]
        if i <= count then
            local item = list[i]
            r.data = item
            r.nameFs:SetText(item.name)

            if item.state == "awake" then
                r.skull:SetVertexColor(1.0, 0.25, 0.25)
                r.statusFs:SetText("|cffff3333FIGHT|r")
                r.rowBg:SetVertexColor(0.20, 0.05, 0.05, 0.60)
            elseif item.state == "asleep" then
                r.skull:SetVertexColor(0.25, 0.90, 0.45)
                r.statusFs:SetText("|cff00ff88ALIVE|r")
                r.rowBg:SetVertexColor(0.05, 0.15, 0.08, 0.60)
            else
                r.skull:SetVertexColor(0.60, 0.55, 0.45)
                if item.left <= 0 then
                    r.statusFs:SetText("|cffffcc00DUE|r")
                else
                    r.statusFs:SetText("|cffffaa00" .. B:Clock(item.left) .. "|r")
                end
                r.rowBg:SetVertexColor(0.08, 0.08, 0.10, 0.50)
            end

            r:Show()
            shown = shown + 1
        else
            r.data = nil
            r:Hide()
        end
    end

    local h = 24 + shown * (ROW_HEIGHT + ROW_GAP) + 4
    if h < 28 then h = 28 end
    f:SetHeight(h)
    f:Show()
end

B:RegisterModule("rares", mod)
