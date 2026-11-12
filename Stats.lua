-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Stats.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Active Player Multipliers & Run Stats panel (Left Side).
--  - Round panel (round style) or dark translucent window with 1px border (sharp)
--  - Real-time multipliers parsed from AZS_STATS (Damage, CDR, Crit, Area, etc.)
--  - Gold/accent stat values
--  - Movable via /bui unlock (default TOPLEFT, 12, -140)
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
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
    { key = "pick",  label = "Pickup",      desc = "XP and gold attraction radius.", fmt = function(v) return string.format(L["%.0f yd"], v) end,             check = function(v) return v and v > 0 end },
    { key = "luck",  label = "Luck",        desc = "Odds of higher tier level-up upgrades.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "bp",    label = "Buff Power",  desc = "Bonus buff strength.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "big",   label = "Vs Elites",   desc = "Bonus damage against Elites & Bosses.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
    { key = "exe",   label = "Execute",     desc = "Bonus damage against targets below 30% HP.", fmt = function(v) return string.format("+%.0f%%", v * 100) end,       check = function(v) return v and v > 0 end },
}

-- Neutral value per stat: multipliers sit at 1, bonuses at 0. Used to colour
-- gains and losses.
local STAT_BASE = { dmg = 1, cm = 1, area = 1, spd = 1 }

mod.hint = "Damage, cooldown, crit, area and the other run multipliers."
mod.options = {
    { type = "section", label = "Layout" },
    { type = "range",  key = "width", label = "Width", min = 130, max = 320, step = 5, default = 170, format = "%d px" },
    { type = "range",  key = "rowHeight", label = "Row height", min = 11, max = 24, step = 1, default = 15, format = "%d px" },
    { type = "range",  key = "fontSize", label = "Text size", min = 7, max = 16, step = 1, default = 9, format = "%d" },
    { type = "range",  key = "maxRows", label = "Max rows", min = 1, max = 15, step = 1, default = 15, format = "%d" },
    { type = "toggle", db = "statsGrowUp", label = "Grow upwards (bottom edge stays in place)", default = false },
    { type = "toggle", key = "compact", label = "Compact layout", hint = "No header, tighter padding.", default = false },
    { type = "section", label = "Values" },
    { type = "toggle", key = "showZero", label = "Show inactive values", hint = "Also lists multipliers still at their base value.", default = false },
    { type = "toggle", key = "colorSign", label = "Colour gains and losses", hint = "Green above the base value, red below it.", default = false },
    { type = "color",  key = "valueColor", label = "Value colour", default = { r = 1.0, g = 0.84, b = 0.20 } },
    { type = "toggle", key = "showTooltips", label = "Show tooltips", default = true },
    { type = "section", label = "Rows" },
}
for i = 1, table.getn(STAT_DEFS) do
    local def = STAT_DEFS[i]
    table.insert(mod.options, { type = "toggle", key = "row_" .. def.key, label = def.label, default = true })
end

function mod:Create()
    local f = CreateFrame("Frame", "BUI_StatsFrame", UIParent)
    f:SetWidth(PANEL_WIDTH)
    f:SetHeight(120)
    -- Round style: rounded panel, inset header, rows on the header's inset.
    -- Sharp style: flat backdrop with 1px border and the dark header strip.
    B:Panel(f)
    self.frame = f
    self.round = B:IsRound()

    f.header = B:Header(f, L["MULTIPLIERS"], 18)

    local rows = {}
    for i = 1, MAX_STAT_ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(ROW_HEIGHT)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -22 - (i - 1) * ROW_HEIGHT)
        r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -22 - (i - 1) * ROW_HEIGHT)
        r:EnableMouse(true)

        local val = B:Font(r, 9, "RIGHT")
        val:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        val:SetWidth(55)
        val:SetHeight(ROW_HEIGHT)
        val:SetTextColor(1.0, 0.84, 0.20)
        r.val = val

        local lbl = B:Font(r, 9, "LEFT")
        lbl:SetPoint("LEFT", r, "LEFT", 2, 0)
        lbl:SetPoint("RIGHT", val, "LEFT", -2, 0)
        lbl:SetHeight(ROW_HEIGHT)
        lbl:SetTextColor(0.72, 0.72, 0.72)
        r.lbl = lbl

        r:SetScript("OnEnter", function()
            if this.statLabel and this.statDesc and B:ModOpt("stats", "showTooltips", true) then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(L[this.statLabel] .. " " .. (this.statValue or ""), 1, 1, 1)
                GameTooltip:AddLine(L[this.statDesc], 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        rows[i] = r
    end
    f.rows = rows

    B:RegisterMover(f, "stats", L["Run multipliers"], "TOPLEFT", "TOPLEFT", 12, -140)
end

-- Sizes, fonts, padding and header from the module settings. Safe to call
-- repeatedly; the row contents are filled by Update.
function mod:ApplyOptions()
    local f = self.frame
    if not f then return end
    local key = self.key
    local width = math.floor(tonumber(B:ModOpt(key, "width", 170)) or PANEL_WIDTH)
    local rowH = math.floor(tonumber(B:ModOpt(key, "rowHeight", 15)) or ROW_HEIGHT)
    local fontSize = math.floor(tonumber(B:ModOpt(key, "fontSize", 9)) or 9)
    local maxRows = math.floor(tonumber(B:ModOpt(key, "maxRows", 15)) or MAX_STAT_ROWS)
    if maxRows < 1 then maxRows = 1 end
    if maxRows > MAX_STAT_ROWS then maxRows = MAX_STAT_ROWS end
    local compact = B:ModOpt(key, "compact", false)

    -- Padding: the round panel needs room for its corners. Rows keep a 2px
    -- text inset of their own, so the round row edge lines the text up with
    -- the header title (inset 10).
    local rowSide = (self.round and 8) or 6
    local top = (self.round and 24) or 22
    local bottom = (self.round and 8) or 4
    if compact then
        rowSide = (self.round and 5) or 4
        top = (self.round and 6) or 4
        bottom = (self.round and 6) or 4
        f.header:Hide()
    else
        f.header:Show()
    end

    self.rowH = rowH
    self.padTop = top
    self.padBottom = bottom
    self.maxRows = maxRows

    f:SetWidth(width)
    local valW = math.floor(fontSize * 6 + 1)
    for i = 1, MAX_STAT_ROWS do
        local r = f.rows[i]
        r:SetHeight(rowH)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", rowSide, -top - (i - 1) * rowH)
        r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rowSide, -top - (i - 1) * rowH)
        r.lbl.buiSize = fontSize
        B:ApplyFont(r.lbl)
        r.lbl:SetHeight(rowH)
        r.val.buiSize = fontSize
        B:ApplyFont(r.val)
        r.val:SetWidth(valW)
        r.val:SetHeight(rowH)
        if i > maxRows then r:Hide() end
    end

    -- The "Grow upwards" switch is one of this module's options as well.
    if not B.unlocked then self:ApplyGrowth() end
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

    local key = self.key
    local showZero = B:ModOpt(key, "showZero", false)
    local colorSign = B:ModOpt(key, "colorSign", false)
    local vc = B:ModOpt(key, "valueColor", nil)
    local vr, vg, vb = 1.0, 0.84, 0.20
    if type(vc) == "table" and vc.r then vr, vg, vb = vc.r, vc.g, vc.b end

    local activeList = {}
    local totalDefs = table.getn(STAT_DEFS)
    for i = 1, totalDefs do
        local def = STAT_DEFS[i]
        local rawVal = s[def.key]
        if B:ModOpt(key, "row_" .. def.key, true) then
            local active = def.check(rawVal) and true or false
            if active or showZero then
                local num = tonumber(rawVal)
                local formatted = "-"
                local delta = 0
                if num then
                    formatted = def.fmt(num)
                    delta = num - (STAT_BASE[def.key] or 0)
                end
                table.insert(activeList, {
                    label = def.label,
                    val = formatted,
                    desc = def.desc,
                    delta = delta,
                    active = active,
                })
            end
        end
    end

    local nActive = table.getn(activeList)
    if nActive == 0 and not ((state and state.demo) or B.unlocked) then
        f:Hide()
    else
        f:Show()
        f.header.value:SetText(tostring(nActive))
        local maxRows = self.maxRows or MAX_STAT_ROWS
        local rowH = self.rowH or ROW_HEIGHT
        local shown = nActive
        if shown > maxRows then shown = maxRows end
        -- Re-anchor before resizing so the chosen edge stays fixed. Not while
        -- unlocked: the mover is dragging the frame then.
        if not B.unlocked then self:ApplyGrowth() end
        f:SetHeight((self.padTop or 22) + shown * rowH + (self.padBottom or 4))

        for i = 1, MAX_STAT_ROWS do
            local r = f.rows[i]
            if i <= shown then
                local item = activeList[i]
                r.lbl:SetText(L[item.label] .. ":")
                r.val:SetText(item.val)
                if not item.active then
                    r.val:SetTextColor(0.50, 0.50, 0.50)
                elseif colorSign and item.delta > 0 then
                    r.val:SetTextColor(0.35, 0.90, 0.45)
                elseif colorSign and item.delta < 0 then
                    r.val:SetTextColor(1.0, 0.35, 0.30)
                else
                    r.val:SetTextColor(vr, vg, vb)
                end
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
