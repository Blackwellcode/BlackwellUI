-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Stats.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Active Player Multipliers & Run Stats panel (Left Side).
--  - Sleek dark translucent window (0.05, 0.05, 0.05, 0.88) with 1px border
--  - Real-time multipliers parsed from AZS_STATS (Damage, CDR, Crit, Area, etc.)
--  - Gold/accent stat values
--  - Movable via /bui unlock (default TOPLEFT, 12, -140)
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Multipliers"

local PANEL_WIDTH = 170
local ROW_HEIGHT = 15
local MAX_STAT_ROWS = 15

local STAT_DEFS = {
    { key = "dmg",   label = "Damage",      desc = "All spell damage dealt.", fmt = function(v) return string.format("+%.0f%%", (v - 1) * 100) end, check = function(v) return v and v ~= 1 end },
    { key = "cd",    label = "Cooldowns",   desc = "Cooldown reduction.", fmt = function(v) return string.format("-%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "crit",  label = "Crit Chance", desc = "Critical strike chance.", fmt = function(v) return string.format("%.0f%%", v * 100) end,        check = function(v) return v and v > 0 end },
    { key = "cm",    label = "Crit Damage", desc = "Critical strike damage multiplier.", fmt = function(v) return string.format("%.0f%%", v * 100) end,        check = function(v) return v and v > 1 end },
    { key = "area",  label = "Area",        desc = "Spell area and range increase.", fmt = function(v) return string.format("+%.0f%%", (v - 1) * 100) end, check = function(v) return v and v ~= 1 end },
    { key = "spd",   label = "Speed",       desc = "Movement speed increase.", fmt = function(v) return string.format("+%.0f%%", (v - 1) * 100) end, check = function(v) return v and v ~= 1 end },
    { key = "echo",  label = "Echo",        desc = "Chance for spells to strike twice.", fmt = function(v) return string.format("%.0f%%", v * 100) end,        check = function(v) return v and v > 0 end },
    { key = "arm",   label = "Armor / DR",  desc = "Damage reduction.", fmt = function(v) return string.format("%.0f%%", v * 100) end,        check = function(v) return v and v > 0 end },
    { key = "lch",   label = "Lifesteal",   desc = "Percent of damage converted to healing.", fmt = function(v) return string.format("%.1f%%", v * 100) end,        check = function(v) return v and v > 0 end },
    { key = "heal",  label = "Kill Heal",   desc = "Flat health regained per kill.", fmt = function(v) return string.format("+%.0f", v) end,               check = function(v) return v and v > 0 end },
    { key = "pick",  label = "Pickup",      desc = "XP and gold attraction radius.", fmt = function(v) return string.format("%.0f yd", v) end,             check = function(v) return v and v > 0 end },
    { key = "luck",  label = "Luck",        desc = "Odds of higher tier level-up upgrades.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "bp",    label = "Buff Power",  desc = "Bonus buff strength.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "big",   label = "Vs Elites",   desc = "Bonus damage against Elites & Bosses.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "exe",   label = "Execute",     desc = "Bonus damage against targets below 30% HP.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
}

function mod:Create()
    local f = CreateFrame("Frame", "BUI_StatsFrame", UIParent)
    f:SetWidth(PANEL_WIDTH)
    f:SetHeight(120)
    B:Backdrop(f, 0.88)
    self.frame = f

    f.header = B:Header(f, "MULTIPLIERS", 18)

    local rows = {}
    for i = 1, MAX_STAT_ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetWidth(PANEL_WIDTH - 12)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -22 - (i - 1) * ROW_HEIGHT)
        r:EnableMouse(true)

        local lbl = B:Font(r, 9, "LEFT")
        lbl:SetPoint("LEFT", r, "LEFT", 2, 0)
        lbl:SetWidth(95)
        lbl:SetHeight(ROW_HEIGHT)
        lbl:SetTextColor(0.72, 0.72, 0.72)
        r.lbl = lbl

        local val = B:Font(r, 9, "RIGHT")
        val:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        val:SetWidth(55)
        val:SetHeight(ROW_HEIGHT)
        val:SetTextColor(1.0, 0.84, 0.20)
        r.val = val

        r:SetScript("OnEnter", function()
            if this.statLabel and this.statDesc then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(this.statLabel .. " " .. (this.statValue or ""), 1, 1, 1)
                GameTooltip:AddLine(this.statDesc, 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    B:RegisterMover(f, "stats", "Run Multipliers", "TOPLEFT", "TOPLEFT", 12, -140)
end

-- Growth direction: the edge the panel is anchored by stays put while rows are
-- added. Growing up anchors the bottom-left corner, growing down the top-left.
-- The converted anchor is saved as the panel's position, so it survives /reload.
function mod:ApplyGrowth()
    local f = self.frame
    if not f then return end
    local want = (B.db.statsGrowUp and "BOTTOMLEFT") or "TOPLEFT"
    local cur = f:GetPoint(1)
    if cur == want then return end
    local left = f:GetLeft()
    local edge = (want == "BOTTOMLEFT" and f:GetBottom()) or f:GetTop()
    if not left or not edge then return end
    -- GetLeft/GetTop/GetBottom and SetPoint offsets share the panel's own
    -- coordinate space; UIParent's top edge is converted into that space.
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
    B.db.positions[f.buiKey or "stats"] = pos
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

function mod:Update(state)
    local f = self.frame
    if CharacterFrame and CharacterFrame:IsShown() then
        f:Hide()
        return
    end
    local s = (type(AZS_STATS) == "table" and AZS_STATS) or nil

    -- Sample values only for preview; a live run without AZS_STATS shows nothing
    -- instead of numbers that look real.
    if not s and not ((state and state.demo) or B.unlocked) then
        f:Hide()
        return
    end
    if (state and state.demo) or B.unlocked then
        s = {
            dmg = 1.25,
            cd = 0.15,
            crit = 0.28,
            cm = 2.00,
            area = 1.30,
            spd = 1.20,
            echo = 0.35,
            arm = 0.22,
            lch = 0.05,
            heal = 120,
            pick = 18,
            luck = 0.15,
            bp = 0.20,
            big = 0.25,
            exe = 0.40,
        }
    end

    local activeList = {}
    local totalDefs = table.getn(STAT_DEFS)
    for i = 1, totalDefs do
        local def = STAT_DEFS[i]
        local rawVal = s[def.key]
        if def.check(rawVal) then
            local formatted = def.fmt(rawVal)
            table.insert(activeList, {
                label = def.label,
                val = formatted,
                desc = def.desc,
            })
        end
    end

    local nActive = table.getn(activeList)
    if nActive == 0 and not ((state and state.demo) or B.unlocked) then
        f:Hide()
    else
        f:Show()
        f.header.value:SetText(tostring(nActive))
        local shown = nActive
        if shown > MAX_STAT_ROWS then shown = MAX_STAT_ROWS end
        -- Re-anchor before resizing so the chosen edge stays fixed. Not while
        -- unlocked: the mover is dragging the frame then.
        if not B.unlocked then self:ApplyGrowth() end
        f:SetHeight(22 + shown * ROW_HEIGHT + 4)

        for i = 1, MAX_STAT_ROWS do
            local r = f.rows[i]
            if i <= shown then
                local item = activeList[i]
                r.lbl:SetText(item.label .. ":")
                r.val:SetText(item.val)
                r.statLabel = item.label
                r.statValue = item.val
                r.statDesc = item.desc
                r:Show()
            else
                r:Hide()
            end
        end
    end
end

B:RegisterModule("stats", mod)
