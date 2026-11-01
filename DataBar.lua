-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  DataBar.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Bottom telemetry & economy data bar (LVL, XP, KILLS, GOLD, CHEST, LIVES, RR, DMG, FPS).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Data Bar"
mod.hint = "Level, XP, kills per minute, gold, lives, damage and FPS along the bottom."

local BAR_WIDTH = 680
local BAR_HEIGHT = 20
local MIN_HEIGHT = 16
local SEP_SIZE = 3

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

-- opt: the module option that shows / hides the segment.
local SEGMENT_DEFS = {
    { key = "lvl",     label = "LVL",   opt = "showLvl" },
    { key = "xp",      label = "XP",    opt = "showXp" },
    { key = "kills",   label = "KILLS", opt = "showKills" },
    { key = "gold",    label = "GOLD",  opt = "showGold" },
    { key = "chest",   label = "CHEST", opt = "showChest" },
    { key = "lives",   label = "LIVES", opt = "showLives" },
    { key = "rerolls", label = "RR",    opt = "showRerolls" },
    { key = "dmg",     label = "DMG",   opt = "showDmg" },
    { key = "fps",     label = "FPS",   opt = "showFps" },
}

mod.options = {
    { type = "section", label = "Items" },
    { type = "toggle", key = "showLvl", label = "Level", default = true },
    { type = "toggle", key = "showXp", label = "Experience", default = true },
    { type = "toggle", key = "showKills", label = "Kills", default = true },
    { type = "toggle", key = "showPace", label = "Kills per minute", hint = "Kill pace over the last 20 seconds.", default = true, depends = "showKills" },
    { type = "toggle", key = "showGold", label = "Gold", default = true },
    { type = "toggle", key = "showChest", label = "Chest cost", default = true },
    { type = "toggle", key = "showLives", label = "Lives", default = true },
    { type = "toggle", key = "showRerolls", label = "Rerolls", default = true },
    { type = "toggle", key = "showDmg", label = "Damage dealt", default = true },
    { type = "toggle", key = "showFps", label = "FPS", default = true },
    { type = "section", label = "Layout" },
    { type = "choice", key = "widthMode", label = "Width", default = "custom",
      values = { { value = "custom", label = "Custom" }, { value = "full", label = "Full screen" } } },
    { type = "range", key = "width", label = "Custom width", min = 300, max = 1600, step = 10, default = 680, format = "%d px" },
    { type = "range", key = "height", label = "Height", min = 16, max = 32, step = 1, default = 20, format = "%d px" },
    { type = "range", key = "fontSize", label = "Font size", hint = "Added to the global font size.", min = -3, max = 6, step = 1, default = 0, format = "%d" },
    { type = "section", label = "Appearance" },
    { type = "toggle", key = "showLabels", label = "Show labels", default = true },
    { type = "toggle", key = "separators", label = "Separator dots", default = true },
    { type = "toggle", key = "accentValues", label = "Colour values by accent", hint = "Off shows the values in white.", default = true },
    { type = "toggle", key = "showXpBar", label = "XP progress line", default = true },
    { type = "range", key = "xpBarHeight", label = "XP line thickness", min = 2, max = 12, step = 1, default = 6, format = "%d px", depends = "showXpBar" },
}

-- XP line: 6 px above the bar in the round style, 2 px inside it (sharp).
local function XpDefault()
    if B:IsRound() then return 6 end
    return 2
end

local function Opt(key, default)
    return B:ModOpt("databar", key, default)
end

-- Bar width in the frame's own coordinate space.
local function BarWidth(f)
    if Opt("widthMode", "custom") == "full" then
        local scale = (f and f.GetScale and f:GetScale()) or 1
        if scale <= 0 then scale = 1 end
        local w = (UIParent:GetWidth() or BAR_WIDTH) / scale - 8
        if w < 300 then w = 300 end
        return math.floor(w)
    end
    return Opt("width", BAR_WIDTH)
end

function mod:Create()
    local f = CreateFrame("Frame", "BUI_DataBar", UIParent)
    f:SetWidth(BAR_WIDTH)
    f:SetHeight(BAR_HEIGHT)
    self.frame = f

    if B:IsRound() then
        -- The smallest bar height is 16, so a radius of 8 always fits.
        local rad = (B.db and B.db.cornerRadius) or 10
        if rad > MIN_HEIGHT / 2 then rad = MIN_HEIGHT / 2 end
        B:Panel(f, rad)

        -- XP line with round caps, sitting just above the bar.
        local xpBar = B:RoundBar(f, 6)
        xpBar:SetPoint("BOTTOMLEFT", f, "TOPLEFT", rad, 3)
        xpBar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -rad, 3)
        xpBar:SetTrackColor(1, 1, 1, 0.06)
        B:Accent(xpBar.fill.left, "tex")
        B:Accent(xpBar.fill.mid, "tex")
        B:Accent(xpBar.fill.right, "tex")
        f.xpBar = xpBar
    else
        B:Backdrop(f, 0.88)

        -- 2px XP progress bar at top of the bottom frame
        local xpBar = B:Bar(f, nil)
        xpBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        xpBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        xpBar:SetHeight(2)
        f.xpBar = xpBar
    end

    -- Container for segments
    local segContainer = CreateFrame("Frame", nil, f)
    segContainer:SetHeight(BAR_HEIGHT - 2)
    segContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -2)
    segContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 0)
    f.segContainer = segContainer

    local segs = {}
    local seps = {}
    local numSegs = table.getn(SEGMENT_DEFS)
    for i = 1, numSegs do
        local def = SEGMENT_DEFS[i]
        local sFrame = CreateFrame("Frame", nil, segContainer)
        sFrame:SetHeight(BAR_HEIGHT - 2)

        local lbl = B:Font(sFrame, 9, "LEFT")
        lbl:SetPoint("LEFT", sFrame, "LEFT", 0, 0)
        lbl:SetTextColor(0.60, 0.60, 0.60)
        lbl:SetText(L[def.label] .. " ")
        sFrame.lbl = lbl

        -- Value colour (accent or white) is set every Update.
        local val = B:Font(sFrame, 10, "LEFT")
        val:SetPoint("LEFT", lbl, "RIGHT", 2, 0)
        sFrame.val = val

        segs[i] = sFrame

        -- Separator dot drawn in the gap before this segment.
        local sep = segContainer:CreateTexture(nil, "ARTWORK")
        sep:SetTexture(B:ShapeTexture())
        sep:SetWidth(SEP_SIZE)
        sep:SetHeight(SEP_SIZE)
        sep:SetVertexColor(0.55, 0.57, 0.62)
        sep:SetAlpha(0.45)
        sep:Hide()
        seps[i] = sep
    end
    f.segs = segs
    f.seps = seps

    B:RegisterMover(f, "databar", L["Data Bar"], "BOTTOM", "BOTTOM", 0, 4)
end

-- Sizes and fonts; segment visibility and colours are read every Update.
function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    local h = Opt("height", BAR_HEIGHT)
    f:SetHeight(h)
    f:SetWidth(BarWidth(f))
    f.segContainer:SetHeight(h - 2)

    local off = Opt("fontSize", 0)
    for i = 1, table.getn(f.segs) do
        local s = f.segs[i]
        s:SetHeight(h - 2)
        s.lbl.buiSize = 9 + off
        B:ApplyFont(s.lbl)
        s.val.buiSize = 10 + off
        B:ApplyFont(s.val)
    end

    if Opt("showXpBar", true) then
        f.xpBar:Show()
    else
        f.xpBar:Hide()
    end
    for i = 1, table.getn(self.options) do
        if self.options[i].key == "xpBarHeight" then self.options[i].default = XpDefault() end
    end
    local xpH = Opt("xpBarHeight", XpDefault())
    if type(f.xpBar.SetBarHeight) == "function" then
        f.xpBar:SetBarHeight(xpH)
    else
        f.xpBar:SetHeight(xpH)
    end
end

function mod:Update(state)
    local f = self.frame
    local run = state.run or {}

    -- Full-screen width follows resolution and scale changes.
    local barW = BarWidth(f)
    if math.abs((f:GetWidth() or 0) - barW) >= 1 then
        f:SetWidth(barW)
    end

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
    if type(f.xpBar.SetFill) == "function" then
        f.xpBar:SetFill(xpPct)
    else
        f.xpBar:SetValue(xpPct)
    end

    local rawKills = tonumber(run.kills) or 0
    local kills = tostring(rawKills)
    local pace = GetKillPace(rawKills)
    if pace and pace > 0 and Opt("showPace", true) then
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

    local showLabels = Opt("showLabels", true)
    local vr, vg, vb = 0.92, 0.92, 0.92
    if Opt("accentValues", true) then
        vr, vg, vb = B:GetAccent()
    end

    local numSegs = table.getn(SEGMENT_DEFS)
    local totalW = 0
    local widths = {}
    local visible = {}
    local nVisible = 0

    for i = 1, numSegs do
        local s = f.segs[i]
        if Opt(SEGMENT_DEFS[i].opt, true) then
            s.val:SetText(values[i])
            s.val:SetTextColor(vr, vg, vb)
            local w1 = 0
            s.val:ClearAllPoints()
            if showLabels then
                s.lbl:Show()
                w1 = s.lbl:GetStringWidth() or 20
                s.val:SetPoint("LEFT", s.lbl, "RIGHT", 2, 0)
            else
                s.lbl:Hide()
                s.val:SetPoint("LEFT", s, "LEFT", 0, 0)
            end
            local w2 = s.val:GetStringWidth() or 20
            local w = w1 + w2 + 4
            widths[i] = w
            s:SetWidth(w)
            s:Show()
            totalW = totalW + w
            nVisible = nVisible + 1
            visible[nVisible] = i
        else
            s:Hide()
        end
        f.seps[i]:Hide()
    end

    -- Distribute segments evenly across the bar
    local inner = barW - 12
    local avail = inner - totalW
    local gap = 12
    if nVisible > 1 and avail > 0 then
        gap = math.floor(avail / (nVisible - 1))
        if gap < 6 then gap = 6 end
        if gap > 24 then gap = 24 end
    end

    local actualTotal = totalW
    if nVisible > 1 then actualTotal = totalW + (nVisible - 1) * gap end
    local curX = math.floor((inner - actualTotal) / 2)
    if curX < 0 then curX = 0 end

    local separators = Opt("separators", true)
    for n = 1, nVisible do
        local i = visible[n]
        local s = f.segs[i]
        if n > 1 and separators then
            local sep = f.seps[i]
            sep:ClearAllPoints()
            sep:SetPoint("CENTER", f.segContainer, "LEFT", math.floor(curX - gap / 2), 0)
            sep:Show()
        end
        s:ClearAllPoints()
        s:SetPoint("LEFT", f.segContainer, "LEFT", curX, 0)
        curX = curX + widths[i] + gap
    end
end

B:RegisterModule("databar", mod)
