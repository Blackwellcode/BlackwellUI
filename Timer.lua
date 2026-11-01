-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Timer.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Run Clock, Phase badge, Zone info, Next Boss countdown & Boss Schedule.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Run Timer"

local MAX_SCHEDULE_ROWS = 8
local TIMER_WIDTH = 260
local PAD = 12
local CARD_GAP = 6
local MAIN_HEIGHT = 102
local SCHEDULE_ROW = 15
local RING_SIZE = 44
-- Ring colour while the next boss is on its way / due now.
local RING_COLOR = { r = 0.94, g = 0.48, b = 0.24 }

local guardianLairStatus = {}
local guardiansSlainBefore8 = 0
local lastRunResetTime = 0

local function UpdateGuardianGoal(runTime)
    if runTime < lastRunResetTime or runTime < 2 then
        guardiansSlainBefore8 = 0
        guardianLairStatus = {}
    end
    lastRunResetTime = runTime

    local lairs = (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or (type(AZS_LAIRS) == "table" and AZS_LAIRS) or {}
    local nLairs = table.getn(lairs)
    for i = 1, nLairs do
        local lair = lairs[i]
        if type(lair) == "table" then
            local idx = lair.index or i
            -- Lairs report state = "awake" | "asleep" | "empty" (as read by Pins and
            -- RareTimers); active/awake are older field shapes kept as fallback.
            local awakeNum = tonumber(lair.awake)
            local isActive = (lair.state == "awake" or lair.active == true or lair.active == 1
                or lair.awake == true or (awakeNum ~= nil and awakeNum > 0))
            -- A kill empties the lair; awake -> asleep is a reset, not a kill.
            local slain = (lair.state == nil or lair.state == "empty")
            if guardianLairStatus[idx] == true and not isActive and slain then
                if runTime <= 480 then
                    guardiansSlainBefore8 = guardiansSlainBefore8 + 1
                end
            end
            guardianLairStatus[idx] = isActive
        end
    end

    return guardiansSlainBefore8
end

function mod:Create()
    -- Outer frame: mover target and anchor for the encounter list. It holds
    -- two round cards: the run card and the boss schedule card.
    local f = CreateFrame("Frame", "BUI_TimerFrame", UIParent)
    f:SetWidth(TIMER_WIDTH)
    f:SetHeight(MAIN_HEIGHT)
    self.frame = f

    local main = CreateFrame("Frame", nil, f)
    main:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    main:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    main:SetHeight(MAIN_HEIGHT)
    B:Panel(main)
    f.main = main

    -- Run clock, total length and phase pill
    local timeFs = B:Font(main, 20, "LEFT")
    timeFs:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -9)
    timeFs:SetTextColor(0.95, 0.94, 0.90)
    f.timeFs = timeFs

    local lengthFs = B:Font(main, 10, "LEFT")
    lengthFs:SetPoint("BOTTOMLEFT", timeFs, "BOTTOMRIGHT", 4, 2)
    lengthFs:SetTextColor(0.55, 0.54, 0.50)
    f.lengthFs = lengthFs

    local phasePill = B:RoundBar(main, 16)
    phasePill:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, -11)
    phasePill:SetWidth(60)
    f.phasePill = phasePill

    local phaseFs = B:Font(phasePill, 9, "CENTER")
    phaseFs:SetPoint("CENTER", phasePill, "CENTER", 0, 0)
    f.phaseFs = phaseFs

    -- Thin run progress line
    local pBar = B:RoundBar(main, 3)
    pBar:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -36)
    pBar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, -36)
    pBar:SetTrackColor(1, 1, 1, 0.08)
    B:Accent(pBar.fill.left, "tex")
    B:Accent(pBar.fill.mid, "tex")
    B:Accent(pBar.fill.right, "tex")
    f.pBar = pBar

    -- Countdown ring to the next boss, time in its centre
    local ring = B:DotRing(main, RING_SIZE, 4)
    ring:SetPoint("TOPLEFT", main, "TOPLEFT", PAD - 2, -46)
    f.ring = ring

    local ringFs = B:Font(ring, 10, "CENTER")
    ringFs:SetPoint("CENTER", ring, "CENTER", 0, 0)
    f.ringFs = ringFs

    -- Next boss name, zone line and guardian goal next to the ring
    local nextFs = B:Font(main, 12, "LEFT")
    nextFs:SetPoint("TOPLEFT", ring, "TOPRIGHT", 8, -2)
    nextFs:SetPoint("RIGHT", main, "RIGHT", -PAD, 0)
    nextFs:SetHeight(15)
    nextFs:SetTextColor(0.95, 0.94, 0.90)
    f.nextFs = nextFs

    local zoneFs = B:Font(main, 9, "LEFT")
    zoneFs:SetPoint("TOPLEFT", nextFs, "BOTTOMLEFT", 0, -1)
    zoneFs:SetPoint("RIGHT", main, "RIGHT", -PAD, 0)
    zoneFs:SetHeight(12)
    zoneFs:SetTextColor(0.58, 0.57, 0.53)
    f.zoneFs = zoneFs

    local goalFs = B:Font(main, 9, "LEFT")
    goalFs:SetPoint("TOPLEFT", zoneFs, "BOTTOMLEFT", 0, -1)
    goalFs:SetPoint("RIGHT", main, "RIGHT", -PAD, 0)
    goalFs:SetHeight(12)
    f.goalFs = goalFs

    -- Schedule card below the run card
    local sched = CreateFrame("Frame", nil, f)
    sched:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -CARD_GAP)
    sched:SetPoint("TOPRIGHT", main, "BOTTOMRIGHT", 0, -CARD_GAP)
    sched:SetHeight(40)
    B:Panel(sched)
    f.sched = sched

    local sRows = {}
    for i = 1, MAX_SCHEDULE_ROWS do
        local r = CreateFrame("Frame", nil, sched)
        r:SetHeight(12)
        r:SetPoint("TOPLEFT", sched, "TOPLEFT", PAD, -9 - (i - 1) * SCHEDULE_ROW)
        r:SetPoint("TOPRIGHT", sched, "TOPRIGHT", -PAD, -9 - (i - 1) * SCHEDULE_ROW)

        local dot = r:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(B.ROUND)
        dot:SetWidth(6)
        dot:SetHeight(6)
        dot:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.dot = dot

        local leftFs = B:Font(r, 9, "LEFT")
        leftFs:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        leftFs:SetPoint("RIGHT", r, "RIGHT", -70, 0)
        leftFs:SetHeight(12)
        r.leftFs = leftFs

        local rightFs = B:Font(r, 9, "RIGHT")
        rightFs:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        rightFs:SetWidth(68)
        rightFs:SetHeight(12)
        r.rightFs = rightFs

        r:Hide()
        sRows[i] = r
    end
    f.sRows = sRows

    B:RegisterMover(f, "timer", L["Run Timer & Boss Schedule"], "TOPRIGHT", "TOPRIGHT", -12, -165)
end

-- Share of the wait between the previous scheduled boss and the next one.
local function CountdownProgress(schedule, runTime, nextLeft)
    local nextAt = runTime + nextLeft
    local prevAt = 0
    for i = 1, table.getn(schedule) do
        local at = tonumber(schedule[i].at) or 0
        if at < nextAt - 0.5 and at > prevAt then
            prevAt = at
        end
    end
    local span = nextAt - prevAt
    if span <= 0 then return 1 end
    return 1 - nextLeft / span
end

function mod:Update(state)
    local f = self.frame
    local runTime = state.time or 0
    local runLength = state.length or 900
    if runLength <= 0 then runLength = 900 end

    -- Clock & Length
    f.timeFs:SetText(B:Clock(runTime))
    f.lengthFs:SetText("/ " .. B:Clock(runLength))

    -- Run progress
    f.pBar:SetFill(B:Percent(runTime, runLength))

    -- Phase pill, sized to its text
    local ph = state.phase or "ready"
    local pInfo = B.PHASE_COLORS[ph] or B.PHASE_COLORS["ready"]
    f.phaseFs:SetText(L[pInfo.label])
    f.phaseFs:SetTextColor(pInfo.r, pInfo.g, pInfo.b)
    f.phasePill:SetWidth(math.floor(f.phaseFs:GetStringWidth() + 16))
    f.phasePill:SetTrackColor(pInfo.r, pInfo.g, pInfo.b, 0.18)
    f.phasePill:SetFill(0)

    -- Zone & Difficulty
    local zone = state.zone or {}
    local zName = zone.zname or "Azeroth"
    if zone.zsub and zone.zsub ~= "" then
        zName = zName .. " - " .. zone.zsub
    end
    if zone.diff then
        zName = string.format(L["%s  (Diff %s)"], zName, tostring(zone.diff))
    end
    f.zoneFs:SetText(zName)

    -- Next boss: name next to the ring, countdown inside it
    local schedule = state.schedule or {}
    local upcoming = state.upcoming or {}
    local nextName, nextLeft
    if table.getn(upcoming) > 0 then
        nextName = upcoming[1].name
        nextLeft = upcoming[1].left
    else
        local run = state.run or {}
        if run.nbn and run.nbn ~= "" then
            nextName = run.nbn
            nextLeft = run.nb
        end
    end

    local rc = B:ModOpt("timer", "ringColor", RING_COLOR)
    if nextName and nextLeft and nextLeft > 0 then
        f.nextFs:SetText(nextName)
        f.ringFs:SetText(B:Clock(nextLeft))
        f.ringFs:SetTextColor(rc.r, rc.g, rc.b)
        f.ring:SetProgress(CountdownProgress(schedule, runTime, nextLeft), rc.r, rc.g, rc.b)
    elseif nextName then
        f.nextFs:SetText(string.format(L["Next: %s (Now)"], nextName))
        f.ringFs:SetText(L["Due"])
        f.ringFs:SetTextColor(1, 0.3, 0.3)
        f.ring:SetProgress(1, 1, 0.3, 0.3)
    else
        f.nextFs:SetText(L["Next Boss: None"])
        f.ringFs:SetText("")
        f.ring:SetProgress(0)
    end

    -- Guardian 8:00 Speedrun Goal
    local slainCount = UpdateGuardianGoal(runTime)
    if f.goalFs then
        if slainCount >= 4 then
            f.goalFs:SetText(string.format(L["GOAL: %d/4 Guardians [ACHIEVED]"], slainCount))
            f.goalFs:SetTextColor(0.0, 1.0, 0.45)
        elseif runTime < 480 then
            local rem = 480 - runTime
            f.goalFs:SetText(string.format(L["GOAL: %d/4 Guardians (Left: %s)"], slainCount, B:Clock(rem)))
            f.goalFs:SetTextColor(1.0, 0.82, 0.15)
        else
            f.goalFs:SetText(string.format(L["GOAL: %d/4 Guardians [EXPIRED]"], slainCount))
            f.goalFs:SetTextColor(0.55, 0.55, 0.55)
        end
    end

    -- Schedule card
    local count = table.getn(schedule)
    local shownRows = 0
    local maxRows = B:ModOpt("timer", "scheduleRows", MAX_SCHEDULE_ROWS)
    if not B:ModOpt("timer", "showSchedule", true) then maxRows = 0 end

    for i = 1, MAX_SCHEDULE_ROWS do
        local r = f.sRows[i]
        if i <= count and i <= maxRows then
            local item = schedule[i]
            local atSec = tonumber(item.at) or 0
            local isFinal = (item.final == 1 or item.final == true)

            r.leftFs:SetText(string.format("%s  %s", B:Clock(atSec), item.name or L["Boss"]))

            if isFinal then
                local kf = B.KIND_COLORS["final"]
                r.leftFs:SetTextColor(kf.r, kf.g, kf.b)
                r.dot:SetVertexColor(kf.r, kf.g, kf.b)
                r.dot:SetAlpha(1)
            elseif item.state == "due" then
                r.leftFs:SetTextColor(0.92, 0.91, 0.87)
                r.dot:SetVertexColor(rc.r, rc.g, rc.b)
                r.dot:SetAlpha(1)
            else
                -- past/other states stay grey
                r.leftFs:SetTextColor(0.55, 0.55, 0.55)
                r.dot:SetVertexColor(0.55, 0.55, 0.55)
                r.dot:SetAlpha(0.6)
            end

            if item.state == "due" then
                local diff = atSec - runTime
                if diff > 0 then
                    r.rightFs:SetText(string.format(L["in %s"], B:Clock(diff)))
                    r.rightFs:SetTextColor(0.85, 0.84, 0.80)
                else
                    r.rightFs:SetText(L["Due"])
                    r.rightFs:SetTextColor(1, 0.3, 0.3)
                end
            else
                r.rightFs:SetText(L[item.state or ""])
                r.rightFs:SetTextColor(0.55, 0.55, 0.55)
            end

            r:Show()
            shownRows = shownRows + 1
        else
            r:Hide()
        end
    end

    if shownRows > 0 then
        local schedH = 9 + shownRows * SCHEDULE_ROW + 6
        f.sched:SetHeight(schedH)
        f.sched:Show()
        f:SetHeight(MAIN_HEIGHT + CARD_GAP + schedH)
    else
        f.sched:Hide()
        f:SetHeight(MAIN_HEIGHT)
    end
end

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
mod.hint = "Time, next boss, boss schedule and the 4 Guardians before 8:00 goal."
mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "width", label = "Width", min = 200, max = 360, step = 10, default = TIMER_WIDTH, format = "%d px" },
    { type = "section", label = "Run card" },
    { type = "toggle", key = "showProgress", label = "Run progress line", default = true },
    { type = "toggle", key = "showPhase", label = "Phase badge", default = true },
    { type = "toggle", key = "showRing", label = "Countdown ring", hint = "Dots fill up until the next boss arrives.", default = true },
    { type = "color", key = "ringColor", label = "Ring colour", default = { r = RING_COLOR.r, g = RING_COLOR.g, b = RING_COLOR.b }, depends = "showRing" },
    { type = "toggle", key = "showZone", label = "Zone and difficulty", default = true },
    { type = "toggle", key = "showGoal", label = "Guardian goal", default = true },
    { type = "section", label = "Boss schedule" },
    { type = "toggle", key = "showSchedule", label = "Boss schedule", default = true },
    { type = "range", key = "scheduleRows", label = "Rows shown", min = 1, max = MAX_SCHEDULE_ROWS, step = 1, default = MAX_SCHEDULE_ROWS, format = "%d", depends = "showSchedule" },
}

function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    f:SetWidth(B:ModOpt("timer", "width", TIMER_WIDTH))
    if B:ModOpt("timer", "showProgress", true) then f.pBar:Show() else f.pBar:Hide() end
    if B:ModOpt("timer", "showPhase", true) then f.phasePill:Show() else f.phasePill:Hide() end
    if B:ModOpt("timer", "showZone", true) then f.zoneFs:Show() else f.zoneFs:Hide() end
    if B:ModOpt("timer", "showGoal", true) then f.goalFs:Show() else f.goalFs:Hide() end
    -- Without the ring the boss name moves to the left edge.
    f.nextFs:ClearAllPoints()
    if B:ModOpt("timer", "showRing", true) then
        f.ring:Show()
        f.nextFs:SetPoint("TOPLEFT", f.ring, "TOPRIGHT", 8, -2)
    else
        f.ring:Hide()
        f.nextFs:SetPoint("TOPLEFT", f.main, "TOPLEFT", PAD, -46)
    end
    f.nextFs:SetPoint("RIGHT", f.main, "RIGHT", -PAD, 0)
end

B:RegisterModule("timer", mod)
