-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Timer.lua
--  Run Clock, Phase badge, Zone info, Next Boss countdown & Boss Schedule.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Run Timer"

local MAX_SCHEDULE_ROWS = 8
local TIMER_WIDTH = 260

local guardianLairStatus = {}
local guardiansSlainBefore8 = 0
local lastRunResetTime = 0

local function UpdateGuardianGoal(runTime)
    if runTime < lastRunResetTime or runTime < 2 then
        guardiansSlainBefore8 = 0
        guardianLairStatus = {}
    end
    lastRunResetTime = runTime

    local lairs = (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or {}
    local nLairs = table.getn(lairs)
    for i = 1, nLairs do
        local lair = lairs[i]
        local idx = lair.index or i
        local isActive = (lair.active == true or lair.active == 1 or (lair.awake and tonumber(lair.awake) > 0))
        if guardianLairStatus[idx] == true and not isActive then
            if runTime <= 480 then
                guardiansSlainBefore8 = guardiansSlainBefore8 + 1
            end
        end
        guardianLairStatus[idx] = isActive
    end

    return guardiansSlainBefore8
end

function mod:Create()
    local f = CreateFrame("Frame", "BUI_TimerFrame", UIParent)
    EUI_TimerFrame = f -- Compatibility alias
    f:SetWidth(TIMER_WIDTH)
    f:SetHeight(120)
    B:Backdrop(f, 0.85)
    self.frame = f

    -- Top Header: Big Clock + Total length + Phase badge
    local timeFs = B:Font(f, 22, "LEFT")
    timeFs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    timeFs:SetTextColor(1, 1, 1)
    f.timeFs = timeFs

    local lengthFs = B:Font(f, 11, "LEFT")
    lengthFs:SetPoint("BOTTOMLEFT", timeFs, "BOTTOMRIGHT", 4, 3)
    lengthFs:SetTextColor(0.65, 0.65, 0.65)
    f.lengthFs = lengthFs

    local phaseFs = B:Font(f, 10, "RIGHT")
    phaseFs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -10)
    f.phaseFs = phaseFs

    -- Progress Bar (4 px)
    local pBar = B:Bar(f, nil)
    pBar:SetPoint("TOPLEFT", timeFs, "BOTTOMLEFT", 0, -4)
    pBar:SetWidth(TIMER_WIDTH - 16)
    pBar:SetHeight(4)
    f.pBar = pBar

    -- Zone & Difficulty info
    local zoneFs = B:Font(f, 9, "LEFT")
    zoneFs:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -5)
    zoneFs:SetWidth(TIMER_WIDTH - 16)
    zoneFs:SetHeight(12)
    zoneFs:SetTextColor(0.85, 0.85, 0.85)
    f.zoneFs = zoneFs

    -- Next Boss Countdown line
    local nextFs = B:Font(f, 9, "LEFT")
    nextFs:SetPoint("TOPLEFT", zoneFs, "BOTTOMLEFT", 0, -3)
    nextFs:SetWidth(TIMER_WIDTH - 16)
    nextFs:SetHeight(12)
    B:Accent(nextFs, "text")
    f.nextFs = nextFs

    -- Guardian Speedrun Goal line (Slay 4 before 8:00)
    local goalFs = B:Font(f, 9, "LEFT")
    goalFs:SetPoint("TOPLEFT", nextFs, "BOTTOMLEFT", 0, -3)
    goalFs:SetWidth(TIMER_WIDTH - 16)
    goalFs:SetHeight(12)
    f.goalFs = goalFs

    -- Schedule list separator line
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", goalFs, "BOTTOMLEFT", 0, -3)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -84)
    sep:SetHeight(1)
    sep:SetTexture(B.WHITE)
    B:Solid(sep, 0.2, 0.2, 0.2, 0.8)
    f.sep = sep

    -- Schedule rows
    local sRows = {}
    for i = 1, MAX_SCHEDULE_ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetWidth(TIMER_WIDTH - 16)
        r:SetHeight(12)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -88 - (i - 1) * 14)

        local leftFs = B:Font(r, 9, "LEFT")
        leftFs:SetPoint("LEFT", r, "LEFT", 0, 0)
        leftFs:SetWidth(155)
        leftFs:SetHeight(12)
        r.leftFs = leftFs

        local rightFs = B:Font(r, 9, "RIGHT")
        rightFs:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        rightFs:SetWidth(75)
        rightFs:SetHeight(12)
        r.rightFs = rightFs

        r:Hide()
        sRows[i] = r
    end
    f.sRows = sRows

    B:RegisterMover(f, "timer", "Run Timer & Boss Schedule", "TOPRIGHT", "TOPRIGHT", -12, -165)
end

function mod:Update(state)
    local f = self.frame
    local runTime = state.time or 0
    local runLength = state.length or 900
    if runLength <= 0 then runLength = 900 end

    -- Clock & Length
    f.timeFs:SetText(B:Clock(runTime))
    f.lengthFs:SetText("/ " .. B:Clock(runLength))

    -- Progress Bar
    local pct = B:Percent(runTime, runLength)
    f.pBar:SetValue(pct)

    -- Phase
    local ph = state.phase or "ready"
    local pInfo = B.PHASE_COLORS[ph] or B.PHASE_COLORS["ready"]
    f.phaseFs:SetText(pInfo.label)
    f.phaseFs:SetTextColor(pInfo.r, pInfo.g, pInfo.b)

    -- Zone & Difficulty
    local zone = state.zone or {}
    local zName = zone.zname or "Azeroth"
    if zone.zsub and zone.zsub ~= "" then
        zName = zName .. " - " .. zone.zsub
    end
    if zone.diff then
        zName = zName .. "  (Diff " .. tostring(zone.diff) .. ")"
    end
    f.zoneFs:SetText(zName)

    -- Next Boss line
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

    if nextName and nextLeft and nextLeft > 0 then
        f.nextFs:SetText(string.format("Next: %s in %s", nextName, B:Clock(nextLeft)))
    elseif nextName then
        f.nextFs:SetText(string.format("Next: %s (Now)", nextName))
    else
        f.nextFs:SetText("Next Boss: None")
    end

    -- Guardian 8:00 Speedrun Goal
    local slainCount = UpdateGuardianGoal(runTime)
    if f.goalFs then
        if slainCount >= 4 then
            f.goalFs:SetText(string.format("GOAL: %d/4 Guardians [ACHIEVED]", slainCount))
            f.goalFs:SetTextColor(0.0, 1.0, 0.45)
        elseif runTime < 480 then
            local rem = 480 - runTime
            f.goalFs:SetText(string.format("GOAL: %d/4 Guardians (Left: %s)", slainCount, B:Clock(rem)))
            f.goalFs:SetTextColor(1.0, 0.82, 0.15)
        else
            f.goalFs:SetText(string.format("GOAL: %d/4 Guardians [EXPIRED]", slainCount))
            f.goalFs:SetTextColor(0.55, 0.55, 0.55)
        end
    end

    -- Schedule List
    local schedule = state.schedule or {}
    local count = table.getn(schedule)
    local shownRows = 0

    for i = 1, MAX_SCHEDULE_ROWS do
        local r = f.sRows[i]
        if i <= count then
            local item = schedule[i]
            local atSec = tonumber(item.at) or 0
            local isFinal = (item.final == 1 or item.final == true)

            local title = string.format("%s %s", B:Clock(atSec), item.name or "Boss")
            r.leftFs:SetText(title)

            if isFinal then
                local kf = B.KIND_COLORS["final"]
                r.leftFs:SetTextColor(kf.r, kf.g, kf.b)
            elseif item.state == "due" then
                r.leftFs:SetTextColor(1, 1, 1)
            else
                -- neutral grey for past/other states
                r.leftFs:SetTextColor(0.55, 0.55, 0.55)
            end

            if item.state == "due" then
                local diff = atSec - runTime
                if diff > 0 then
                    r.rightFs:SetText("in " .. B:Clock(diff))
                    r.rightFs:SetTextColor(0.9, 0.9, 0.9)
                else
                    r.rightFs:SetText("Due")
                    r.rightFs:SetTextColor(1, 0.3, 0.3)
                end
            else
                r.rightFs:SetText(item.state or "")
                r.rightFs:SetTextColor(0.55, 0.55, 0.55)
            end

            r:Show()
            shownRows = shownRows + 1
        else
            r:Hide()
        end
    end

    if shownRows > 0 then
        f:SetHeight(89 + shownRows * 14 + 6)
    else
        f:SetHeight(89)
    end
end

B:RegisterModule("timer", mod)
