-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  DataBar.lua
--  Bottom telemetry & economy data bar (LVL, XP, KILLS, GOLD, CHEST, LIVES, RR, DMG, FPS).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Data Bar"

local BAR_WIDTH = 680
local BAR_HEIGHT = 20

local killHistory = {}

local function GetKillPace(curKills)
    local now = GetTime()
    table.insert(killHistory, { t = now, kills = curKills })

    local cleaned = {}
    local n = table.getn(killHistory)
    local oldest = nil
    for i = 1, n do
        local snap = killHistory[i]
        if (now - snap.t) <= 20 then
            table.insert(cleaned, snap)
            if not oldest then oldest = snap end
        end
    end
    killHistory = cleaned

    if oldest and (now - oldest.t) >= 4.0 then
        local dt = now - oldest.t
        local dk = curKills - oldest.kills
        if dk < 0 then dk = 0 end
        local pace = math.floor((dk / dt) * 60 + 0.5)
        return pace
    end
    return nil
end

local SEGMENT_DEFS = {
    { key = "lvl",     label = "LVL" },
    { key = "xp",      label = "XP" },
    { key = "kills",   label = "KILLS" },
    { key = "gold",    label = "GOLD" },
    { key = "chest",   label = "CHEST" },
    { key = "lives",   label = "LIVES" },
    { key = "rerolls", label = "RR" },
    { key = "dmg",     label = "DMG" },
    { key = "fps",     label = "FPS" },
}

function mod:Create()
    local f = CreateFrame("Frame", "BUI_DataBar", UIParent)
    EUI_DataBar = f -- Compatibility alias
    f:SetWidth(BAR_WIDTH)
    f:SetHeight(BAR_HEIGHT)
    B:Backdrop(f, 0.88)
    self.frame = f

    -- 2px XP progress bar at top of the bottom frame
    local xpBar = B:Bar(f, nil)
    xpBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    xpBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    xpBar:SetHeight(2)
    f.xpBar = xpBar

    -- Container for segments
    local segContainer = CreateFrame("Frame", nil, f)
    segContainer:SetHeight(BAR_HEIGHT - 2)
    segContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -2)
    segContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 0)
    f.segContainer = segContainer

    local segs = {}
    local numSegs = table.getn(SEGMENT_DEFS)
    for i = 1, numSegs do
        local def = SEGMENT_DEFS[i]
        local sFrame = CreateFrame("Frame", nil, segContainer)
        sFrame:SetHeight(BAR_HEIGHT - 2)

        local lbl = B:Font(sFrame, 9, "LEFT")
        lbl:SetPoint("LEFT", sFrame, "LEFT", 0, 0)
        lbl:SetTextColor(0.60, 0.60, 0.60)
        lbl:SetText(def.label .. " ")
        sFrame.lbl = lbl

        local val = B:Font(sFrame, 10, "LEFT")
        val:SetPoint("LEFT", lbl, "RIGHT", 2, 0)
        B:Accent(val, "text")
        sFrame.val = val

        segs[i] = sFrame
    end
    f.segs = segs

    B:RegisterMover(f, "databar", "Data Bar", "BOTTOM", "BOTTOM", 0, 4)
end

function mod:Update(state)
    local f = self.frame
    local run = state.run or {}

    -- Safe fields only
    local lvl = tostring(run.lvl or 1)

    local xpCur = tonumber(run.xp) or 0
    local xpMax = tonumber(run.xpn) or 0
    local xpPct = 0
    if xpMax > 0 then
        xpPct = xpCur / xpMax
    end
    if xpPct > 1 then xpPct = 1 end
    local xpStr = string.format("%d%%", math.floor(xpPct * 100 + 0.5))
    f.xpBar:SetValue(xpPct)

    local rawKills = tonumber(run.kills) or 0
    local kills = tostring(rawKills)
    local pace = GetKillPace(rawKills)
    if pace and pace > 0 then
        if pace >= 120 then
            kills = string.format("%s |cff00ff88[%d/m]|r", tostring(rawKills), pace)
        elseif pace >= 80 then
            kills = string.format("%s |cff00e5ff[%d/m]|r", tostring(rawKills), pace)
        elseif pace >= 40 then
            kills = string.format("%s |cffffb800[%d/m]|r", tostring(rawKills), pace)
        else
            kills = string.format("%s |cff999999[%d/m]|r", tostring(rawKills), pace)
        end
    end
    local gold = tostring(run.gold or 0)
    local chestVal = tonumber(run.chest) or 0
    local chestStr = (chestVal > 0) and (tostring(chestVal) .. "g") or "--"
    local lives = tostring(run.lives or 0)
    local rerolls = tostring(run.rr or 0)
    local dmg = B:Short(run.dealt or 0)

    local fpsStr = "--"
    if type(GetFramerate) == "function" then
        local fps = GetFramerate()
        if fps and fps > 0 then
            fpsStr = tostring(math.floor(fps + 0.5))
        end
    end

    local values = {
        lvl,
        xpStr,
        kills,
        gold,
        chestStr,
        lives,
        rerolls,
        dmg,
        fpsStr,
    }

    local numSegs = table.getn(SEGMENT_DEFS)
    local totalW = 0
    local widths = {}

    for i = 1, numSegs do
        local s = f.segs[i]
        s.val:SetText(values[i])
        local w1 = s.lbl:GetStringWidth() or 20
        local w2 = s.val:GetStringWidth() or 20
        local w = w1 + w2 + 4
        widths[i] = w
        s:SetWidth(w)
        totalW = totalW + w
    end

    -- Distribute segments evenly across the bar
    local avail = (BAR_WIDTH - 12) - totalW
    local gap = 12
    if numSegs > 1 and avail > 0 then
        gap = math.floor(avail / (numSegs - 1))
        if gap < 6 then gap = 6 end
        if gap > 24 then gap = 24 end
    end

    local actualTotal = totalW + (numSegs - 1) * gap
    local curX = math.floor(((BAR_WIDTH - 12) - actualTotal) / 2)
    if curX < 0 then curX = 0 end

    for i = 1, numSegs do
        local s = f.segs[i]
        s:ClearAllPoints()
        s:SetPoint("LEFT", f.segContainer, "LEFT", curX, 0)
        curX = curX + widths[i] + gap
    end
end

B:RegisterModule("databar", mod)
