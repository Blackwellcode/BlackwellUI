-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Nameplates.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Cyberpunk-styled Nameplates in the manner of Plater / SurvivorPlates.
--  Features:
--    - Unit kind sizing: Normal (100x9), Elite (130x11), Guardian (150x12), Boss (170x14)
--    - 30% Execute Range marker line; bar turns gold when <= 30% HP
--    - Reaction & Kind colors: Bosses (Purple), Guardians (Cyan), Elites (Amber), Normal (Neon Red)
--    - Target frame highlight (1px accent border, accent outline in the round
--      style) and Target Debuffs (up to 6 with stacks)
--    - Round style: rounded health bar drawn over the (invisible) stock fill
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Nameplates"
mod.alwaysActive = false
mod.hint = "Coloured by reaction and unit kind. Show or hide them with V."
-- Plates belong to the game world (WorldFrame), not to a frame of ours.
mod.noLook = true

local EXECUTE_RANGE = 0.30
local EXECUTE_COLOR = { 1.00, 0.86, 0.25 }
local PLATE_DEBUFFS = 6
local DEBUFF_SIZE = 15

mod.options = {
    { type = "section", label = "Size" },
    { type = "range", key = "width", label = "Width", min = 60, max = 200, step = 5, default = 100, format = "%d px" },
    { type = "range", key = "height", label = "Height", min = 4, max = 20, step = 1, default = 9, format = "%d px" },
    { type = "toggle", key = "sizeByKind", label = "Bigger plates for elites and bosses", default = true },
    { type = "section", label = "Text" },
    { type = "toggle", key = "showName", label = "Show name", default = true },
    { type = "range", key = "nameSize", label = "Name font size", min = 7, max = 16, step = 1, default = 9, format = "%d px", depends = "showName" },
    { type = "toggle", key = "showLevel", label = "Show level", default = true },
    { type = "toggle", key = "goldLevel", label = "Gold level for elites and bosses", default = true, depends = "showLevel" },
    { type = "choice", key = "healthText", label = "Health text", default = "auto",
      values = {
          { value = "auto", label = "By unit kind" }, { value = "percent", label = "Percent" },
          { value = "value", label = "Current value" }, { value = "both", label = "Value and percent" },
          { value = "none", label = "Hidden" },
      } },
    { type = "section", label = "Colours" },
    { type = "toggle", key = "colorByKind", label = "Colour elites, guardians and bosses", default = true },
    { type = "toggle", key = "showExecute", label = "Execute range", hint = "Marker line and gold bar below the threshold.", default = true },
    { type = "range", key = "executeRange", label = "Execute threshold", min = 0.1, max = 0.5, step = 0.05, default = EXECUTE_RANGE, format = "pct", depends = "showExecute" },
    { type = "color", key = "executeColor", label = "Execute colour", default = { r = EXECUTE_COLOR[1], g = EXECUTE_COLOR[2], b = EXECUTE_COLOR[3] }, depends = "showExecute" },
    { type = "toggle", key = "targetHighlight", label = "Highlight the target", default = true },
    { type = "section", label = "Debuffs" },
    { type = "toggle", key = "showDebuffs", label = "Target debuffs", default = true },
    { type = "range", key = "maxDebuffs", label = "Max debuffs", min = 1, max = PLATE_DEBUFFS, step = 1, default = PLATE_DEBUFFS, format = "%d", depends = "showDebuffs" },
    { type = "range", key = "debuffSize", label = "Debuff size", min = 10, max = 24, step = 1, default = DEBUFF_SIZE, format = "%d px", depends = "showDebuffs" },
}

local function Opt(key, default)
    return B:ModOpt("nameplates", key, default)
end

-- Bumped by ApplyOptions: plates re-run their sizing on the next update.
local optVersion = 1

local KINDS = {
    normal   = { width = 100, height = 9,  nameSize = 9,  color = { 0.84, 0.20, 0.20 } },
    elite    = { width = 130, height = 11, nameSize = 11, color = { 1.00, 0.65, 0.12 } },
    guardian = { width = 150, height = 12, nameSize = 12, color = { 0.20, 0.75, 0.95 } },
    boss     = { width = 170, height = 14, nameSize = 13, color = { 0.72, 0.32, 1.00 } },
}

-------------------------------------------------------------------------------
--  Azeroth Survivors Boss & Rare Dictionaries (Static Fallbacks)
-------------------------------------------------------------------------------
local BOSS_NAMES = {
    -- Elwynn Forest
    ["Hogger"] = true, ["Mother Fang"] = true, ["Rhahk'Zor"] = true, ["Mr. Smite"] = true, ["Edwin VanCleef"] = true,
    -- Duskwood
    ["Morbent's Herald"] = true, ["Naraxis"] = true, ["Mor'Ladim"] = true, ["Stitches"] = true,
    ["Lupos"] = true, ["Eliza"] = true, ["Stalvan Mistmantle"] = true, ["Morbent Fel"] = true,
    -- Warsong Gulch
    ["Doomguard Commander"] = true, ["Mannoroth's Herald"] = true, ["Varimathras"] = true, ["Lord Hel'nurath"] = true, ["Lord Kazzak"] = true,
    -- Arathi Basin
    ["Patchwerk"] = true, ["Lord Blackwood"] = true, ["Baron Rivendare"] = true, ["Anub'Rekhan"] = true, ["Kel'Thuzad"] = true,
    -- Feralas
    ["Zevrim Thornhoof"] = true, ["Alzzin the Wildshaper"] = true, ["Tendris Warpwood"] = true, ["Immol'thar"] = true, ["King Gordok"] = true,
    -- Gurubashi Arena
    ["High Priestess Jeklik"] = true, ["High Priest Venoxis"] = true, ["Bloodlord Mandokir"] = true, ["Jin'do the Hexxer"] = true, ["Hakkar the Soulflayer"] = true,
    -- Alterac Valley
    ["Korrak the Bloodrager"] = true, ["Ivus the Forest Lord"] = true, ["Lokholar the Ice Lord"] = true, ["Glacius the Frozen Titan"] = true, ["Azuregos"] = true,
    -- Blackrock Mountain
    ["General Angerforge"] = true, ["Warchief Rend Blackhand"] = true, ["Emperor Dagran Thaurissan"] = true, ["Majordomo Executus"] = true, ["Nefarian"] = true,
    -- Gates of Ahn'Qiraj
    ["Kurinnaxx"] = true, ["General Rajaxx"] = true, ["Princess Huhuran"] = true, ["Ossirian the Unscarred"] = true, ["C'Thun"] = true,
}

local RARE_NAMES = {
    -- Elwynn
    ["Kobold Taskmaster"] = true, ["Gruff Swiftbite"] = true, ["Bellygrub"] = true,
    -- Duskwood
    ["Nightbane Worgen Alpha"] = true, ["Carrion Recluse"] = true, ["Flesh Eating Abomination"] = true,
    ["Rotting Ghoul"] = true, ["Shrine Warden"] = true, ["Skeletal Fiend"] = true,
    -- Warsong
    ["Felguard Elite"] = true, ["Infernal"] = true, ["Doomguard"] = true,
    -- Arathi
    ["Crypt Fiend"] = true, ["Bone Golem"] = true, ["Death Knight Captain"] = true,
    -- Feralas
    ["Gordunni Brute"] = true, ["Warpwood Treant"] = true, ["Ironbark Protector"] = true,
    -- Gurubashi
    ["Gurubashi Berserker"] = true, ["Zulian Crocolisk"] = true, ["Gurubashi Champion"] = true,
    -- Alterac
    ["Alterac Yeti Lord"] = true, ["Mountain Giant"] = true, ["Winterax Warlord"] = true,
    -- Blackrock
    ["Core Hound"] = true, ["Black Drake"] = true, ["Molten Giant"] = true,
    -- Ahn'Qiraj
    ["Qiraji Champion"] = true, ["Anubisath Sentinel"] = true, ["Obsidian Destroyer"] = true,
}

-------------------------------------------------------------------------------
--  Dynamic AZS Unit Telemetry Cache
-------------------------------------------------------------------------------
local liveKinds = {}
local lastUnitsUpdated = nil
local lastScheduleUpdated = nil

local function RefreshLiveKinds()
    if AZS_UNITS and AZS_UNITS_UPDATED ~= lastUnitsUpdated then
        lastUnitsUpdated = AZS_UNITS_UPDATED
        local n = table.getn(AZS_UNITS)
        for i = 1, n do
            local u = AZS_UNITS[i]
            if type(u) == "table" then
                local uName = u.name or u[3]
                local uKind = u.kind or u[1]
                if uName and uName ~= "" and uKind then
                    if uKind == "boss" or uKind == "final" then
                        liveKinds[uName] = "boss"
                    elseif uKind == "guardian" then
                        liveKinds[uName] = "guardian"
                    elseif uKind == "elite" then
                        liveKinds[uName] = "elite"
                    end
                end
            end
        end
    end

    if AZS_SCHEDULE and AZS_SCHEDULE_UPDATED ~= lastScheduleUpdated then
        lastScheduleUpdated = AZS_SCHEDULE_UPDATED
        local n = table.getn(AZS_SCHEDULE)
        for i = 1, n do
            local b = AZS_SCHEDULE[i]
            if type(b) == "table" then
                local bName = b.name or b[3]
                if bName and bName ~= "" then
                    liveKinds[bName] = "boss"
                end
            end
        end
    end
end

local function GetUnitKind(plate, nameStr)
    RefreshLiveKinds()

    -- 1. Skull Icon (Level -1 / Boss ?? in WoW 1.12)
    if plate.skullIcon and plate.skullIcon:IsShown() then
        return "boss"
    end

    -- 2. Check target classification if plate matches current target
    if UnitExists("target") and nameStr and nameStr == UnitName("target") then
        if AZS_UnitKind then
            local k = AZS_UnitKind("target")
            if k == "boss" or k == "final" then
                return "boss"
            elseif k == "guardian" then
                return "guardian"
            elseif k == "elite" then
                return "elite"
            end
        end
        local c = UnitClassification("target")
        if c == "worldboss" then
            return "boss"
        elseif c == "elite" or c == "rareelite" or c == "rare" then
            return "elite"
        end
    end

    -- 3. Check name against dynamic and static databases
    if nameStr and nameStr ~= "" then
        local lk = liveKinds[nameStr]
        if lk == "boss" then
            return "boss"
        elseif lk == "guardian" then
            return "guardian"
        elseif lk == "elite" or lk == "rare" then
            return "elite"
        elseif BOSS_NAMES[nameStr] then
            return "boss"
        elseif RARE_NAMES[nameStr] then
            return "elite"
        end
    end

    return "normal"
end

local function UpdatePlateDebuffs(plate, isTarget, lift)
    local debuffs = plate.debuffs
    if not debuffs then return end

    if not isTarget or not Opt("showDebuffs", true) then
        for i = 1, PLATE_DEBUFFS do
            if debuffs[i] then debuffs[i]:Hide() end
        end
        return
    end

    local maxShown = math.floor(Opt("maxDebuffs", PLATE_DEBUFFS))
    local size = Opt("debuffSize", DEBUFF_SIZE)
    for i = 1, PLATE_DEBUFFS do
        local df = debuffs[i]
        local tex, count = nil, nil
        if i <= maxShown then
            tex, count = UnitDebuff("target", i)
        end
        if tex then
            if df.buiSize ~= size then
                df.buiSize = size
                df:SetWidth(size)
                df:SetHeight(size)
            end
            df:ClearAllPoints()
            df:SetPoint("BOTTOMLEFT", plate.healthBar, "TOPLEFT", (i - 1) * (size + 2), lift)
            df.icon:SetTexture(tex)
            if count and count > 1 then
                df.count:SetText(tostring(count))
            else
                df.count:SetText("")
            end
            df:Show()
        else
            df:Hide()
        end
    end
end

local function HideAllPlates()
    if not WorldFrame then return end
    local children = { WorldFrame:GetChildren() }
    local n = table.getn(children)
    for i = 1, n do
        local c = children[i]
        if c and c.buiSkinned then
            if c.healthBar and c.healthBar:IsShown() then c.healthBar:Hide() end
            if c.nameFs and c.nameFs:IsShown() then c.nameFs:Hide() end
            if c.levelFs and c.levelFs:IsShown() then c.levelFs:Hide() end
            if c.hpFs and c.hpFs:IsShown() then c.hpFs:Hide() end
            if c.marker and c.marker:IsShown() then c.marker:Hide() end
            if c.castBar and c.castBar:IsShown() then c.castBar:Hide() end
            if c.debuffs then
                for d = 1, PLATE_DEBUFFS do
                    if c.debuffs[d] and c.debuffs[d]:IsShown() then c.debuffs[d]:Hide() end
                end
            end
        end
    end
end

local function IsOwnColor(sb, r, g, b)
    if not sb.buiR then return false end
    return math.abs(r - sb.buiR) < 0.01 and math.abs(g - sb.buiG) < 0.01 and math.abs(b - sb.buiB) < 0.01
end

-- Blizzard reaction colours: red hostile, yellow neutral, green/blue friendly, grey tapped.
local function ClassifyReaction(r, g, b)
    if r > 0.8 and g < 0.2 and b < 0.2 then return "hostile" end
    if r > 0.8 and g > 0.8 and b < 0.2 then return "neutral" end
    if g > 0.7 and r < 0.2 then return "friendly" end
    if b > 0.8 and r < 0.2 and g < 0.2 then return "friendly" end
    if r > 0.4 and r < 0.6 and g > 0.4 and g < 0.6 and b > 0.4 and b < 0.6 then return "tapped" end
    return "hostile"
end

-- Round style helpers: the visible bar is a rounded PlateBar over the stock fill.
local function HideStockFill(healthBar)
    if type(healthBar.GetStatusBarTexture) == "function" then
        local t = healthBar:GetStatusBarTexture()
        if t then t:SetAlpha(0) end
    end
end

local function PaintBar(plate, r, g, b)
    B:SetBarColor(plate.healthBar, r, g, b)
    if plate.rbar then
        plate.rbar:SetFillColor(r, g, b, 1)
        -- SetStatusBarColor may bring the fill alpha back: hide it again.
        HideStockFill(plate.healthBar)
    end
end

-- Rounded plate bar (round style only). Like B:RoundBar, but its height can
-- change, since plates resize with the unit kind: bar:SetBarHeight(h),
-- bar:SetFill(0..1), bar:SetFillColor(r, g, b, a), bar:SetTrackColor(r, g, b, a).
local function PlateBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    local function Strip(layer, spanning)
        local st = {}
        st.left = bar:CreateTexture(nil, layer)
        st.left:SetTexture(B.ROUND)
        st.left:SetTexCoord(0, 0.5, 0, 1)
        st.left:SetPoint("LEFT", bar, "LEFT", 0, 0)
        st.mid = bar:CreateTexture(nil, layer)
        st.mid:SetTexture(B.WHITE)
        st.mid:SetPoint("LEFT", st.left, "RIGHT", 0, 0)
        st.right = bar:CreateTexture(nil, layer)
        st.right:SetTexture(B.ROUND)
        st.right:SetTexCoord(0.5, 1, 0, 1)
        if spanning then
            -- Full width: anchored to both edges, needs no width math.
            st.right:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            st.mid:SetPoint("RIGHT", st.right, "LEFT", 0, 0)
        else
            st.right:SetPoint("LEFT", st.mid, "RIGHT", 0, 0)
        end
        st.parts = { st.left, st.mid, st.right }
        function st:SetColor(r, g, b, a)
            for i = 1, 3 do
                self.parts[i]:SetVertexColor(r, g, b)
                self.parts[i]:SetAlpha(a or 1)
            end
        end
        function st:SetStripHeight(h)
            self.left:SetWidth(h / 2)
            self.left:SetHeight(h)
            self.mid:SetHeight(h)
            self.right:SetWidth(h / 2)
            self.right:SetHeight(h)
        end
        return st
    end
    bar.track = Strip("BORDER", true)
    bar.fill = Strip("ARTWORK", false)
    bar.track:SetColor(1, 1, 1, 0.10)
    bar.fill:SetColor(1, 1, 1, 1)
    bar.buiFill = 0

    function bar:SetBarHeight(h)
        if self.buiHeight == h then return end
        self.buiHeight = h
        self:SetHeight(h)
        self.track:SetStripHeight(h)
        self.fill:SetStripHeight(h)
        self:Layout()
    end
    function bar:Layout()
        local w = self:GetWidth()
        local h = self.buiHeight or 1
        local v = self.buiFill or 0
        if not w or w < h or v <= 0 then
            for i = 1, 3 do self.fill.parts[i]:Hide() end
            return
        end
        if v > 1 then v = 1 end
        local mid = v * w - h
        self.fill.left:Show()
        self.fill.right:Show()
        if mid < 0.5 then
            self.fill.mid:Hide()
            self.fill.right:ClearAllPoints()
            self.fill.right:SetPoint("LEFT", self.fill.left, "RIGHT", 0, 0)
        else
            self.fill.mid:SetWidth(mid)
            self.fill.mid:Show()
            self.fill.right:ClearAllPoints()
            self.fill.right:SetPoint("LEFT", self.fill.mid, "RIGHT", 0, 0)
        end
    end
    function bar:SetFill(v)
        self.buiFill = tonumber(v) or 0
        self:Layout()
    end
    function bar:SetFillColor(r, g, b, a)
        self.fill:SetColor(r, g, b, a)
    end
    function bar:SetTrackColor(r, g, b, a)
        self.track:SetColor(r, g, b, a)
    end
    bar:SetBarHeight(height)
    return bar
end

-- Width, height and name size for a unit kind under the current options.
local function KindSize(kind)
    local cfg = KINDS[kind] or KINDS.normal
    local base = KINDS.normal
    local w = Opt("width", base.width)
    local h = Opt("height", base.height)
    local n = Opt("nameSize", base.nameSize)
    if Opt("sizeByKind", true) and cfg ~= base then
        w = math.floor(w * cfg.width / base.width + 0.5)
        h = math.floor(h * cfg.height / base.height + 0.5)
        n = n + (cfg.nameSize - base.nameSize)
    end
    return w, h, n
end

local function UpdatePlate(plate)
    if not plate or not plate.buiSkinned then return end

    -- When enemy nameplates are turned off ('V' key sets NAMEPLATES_ON = nil), hide all elements
    if not NAMEPLATES_ON or not B:IsEnabled("nameplates") then
        if plate.healthBar and plate.healthBar:IsShown() then plate.healthBar:Hide() end
        if plate.nameFs and plate.nameFs:IsShown() then plate.nameFs:Hide() end
        if plate.levelFs and plate.levelFs:IsShown() then plate.levelFs:Hide() end
        if plate.hpFs and plate.hpFs:IsShown() then plate.hpFs:Hide() end
        if plate.marker and plate.marker:IsShown() then plate.marker:Hide() end
        if plate.castBar and plate.castBar:IsShown() then plate.castBar:Hide() end
        if plate.debuffs then
            for d = 1, PLATE_DEBUFFS do
                if plate.debuffs[d] and plate.debuffs[d]:IsShown() then plate.debuffs[d]:Hide() end
            end
        end
        return
    end

    if not plate:IsShown() then return end

    local healthBar = plate.healthBar
    local hpFs = plate.hpFs
    local name = plate.nameFs
    local level = plate.levelFs
    local nameStr = name and name:GetText()

    local kind = GetUnitKind(plate, nameStr)
    local cfg = KINDS[kind] or KINDS.normal

    local isTarget = false
    if UnitExists("target") and nameStr and nameStr == UnitName("target") then
        local a = plate:GetAlpha()
        if a and a >= 0.95 then
            isTarget = true
        end
    end

    -- Ensure unsuppressed and visible for all mobs
    if plate.buiFiltered then
        plate.buiFiltered = nil
    end
    local showName = Opt("showName", true)
    local showLevel = Opt("showLevel", true)
    local healthMode = Opt("healthText", "auto")
    local executeRange = Opt("executeRange", EXECUTE_RANGE)
    local showExecute = Opt("showExecute", true)

    if not healthBar:IsShown() then healthBar:Show() end
    healthBar:SetAlpha(1)
    if name then
        if showName then
            if not name:IsShown() then name:Show() name:SetAlpha(1) end
        elseif name:IsShown() then
            name:Hide()
        end
    end
    if level then
        if showLevel then
            if not level:IsShown() then level:Show() level:SetAlpha(1) end
        elseif level:IsShown() then
            level:Hide()
        end
    end
    if hpFs then
        if healthMode ~= "none" then
            if not hpFs:IsShown() then hpFs:Show() hpFs:SetAlpha(1) end
        elseif hpFs:IsShown() then
            hpFs:Hide()
        end
    end

    -- Sizing update if kind or the options changed
    local width, height, nameSize = KindSize(kind)
    if plate.buiKind ~= kind or plate.buiOptVer ~= optVersion then
        plate.buiKind = kind
        plate.buiOptVer = optVersion
        healthBar:SetWidth(width)
        healthBar:SetHeight(height)
        if plate.rbar then
            plate.rbar:SetBarHeight(height)
            plate.buiFillShare = nil
        end
        if plate.rglow then
            plate.rglow:SetBarHeight(height + 4)
            plate.rglow:SetFill(0)
        end
        if plate.marker then
            plate.marker:SetHeight(height)
            plate.marker:ClearAllPoints()
            plate.marker:SetPoint("LEFT", healthBar, "LEFT", width * executeRange, 0)
        end
        if name then
            name:SetFont(B:GetFontPath(), nameSize, "OUTLINE")
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", healthBar, "TOP", 0, 3)
        end
        if hpFs then
            hpFs:SetFont(B:GetFontPath(), math.max(8, height - 1), "OUTLINE")
        end
        if plate.castBar then
            plate.castBar:SetWidth(width)
        end
    end

    -- Value & Percentage
    local cur = healthBar:GetValue() or 0
    local minv, maxv = healthBar:GetMinMaxValues()
    local share = 1.0
    if maxv and maxv > minv then
        share = (cur - minv) / (maxv - minv)
    end
    if share < 0 then share = 0 end
    if share > 1 then share = 1 end

    local pct = math.floor(share * 100 + 0.5)
    local pctOnly = maxv and (maxv - minv == 100 or maxv <= 1)
    if healthMode == "none" then
        hpFs:SetText("")
    elseif pctOnly or healthMode == "percent" then
        hpFs:SetText(tostring(pct) .. "%")
    elseif healthMode == "value" or (healthMode == "auto" and kind == "normal") then
        hpFs:SetText(B:Short(cur))
    else
        hpFs:SetText(B:Short(cur) .. " / " .. B:Short(maxv) .. "  " .. tostring(pct) .. "%")
    end

    -- Round bar fill: relaid only when the share or the width changed.
    if plate.rbar then
        local w = healthBar:GetWidth() or 0
        if plate.buiFillShare ~= share or plate.buiFillWidth ~= w then
            plate.buiFillShare = share
            plate.buiFillWidth = w
            plate.rbar:SetFill(share)
        end
    end

    -- Execute Marker & Color logic
    if showExecute and share <= executeRange then
        -- Execute threshold: gold color and hide marker line
        if plate.marker then plate.marker:Hide() end
        local ec = Opt("executeColor", nil)
        if type(ec) == "table" and ec.r then
            PaintBar(plate, ec.r, ec.g, ec.b)
        else
            PaintBar(plate, EXECUTE_COLOR[1], EXECUTE_COLOR[2], EXECUTE_COLOR[3])
        end
    else
        if plate.marker then
            if showExecute then plate.marker:Show() else plate.marker:Hide() end
        end
        if Opt("colorByKind", true) and (kind == "boss" or kind == "guardian" or kind == "elite") then
            -- Same colours as the target frame and the elites & bosses list.
            local kr, kg, kb = B:KindColor(kind)
            PaintBar(plate, kr, kg, kb)
        else
            -- Once recoloured, GetStatusBarColor returns our own colour. Classify
            -- only a colour the engine wrote and keep that reaction otherwise.
            local r, g, b = healthBar:GetStatusBarColor()
            if r and g and b and not IsOwnColor(healthBar, r, g, b) then
                healthBar.buiReaction = ClassifyReaction(r, g, b)
            end
            local reaction = healthBar.buiReaction
            local normal = KINDS.normal.color
            if reaction == "neutral" then
                PaintBar(plate, 0.95, 0.78, 0.12)
            elseif reaction == "friendly" then
                PaintBar(plate, 0.15, 0.85, 0.35)
            elseif reaction == "tapped" then
                PaintBar(plate, 0.50, 0.50, 0.50)
            elseif Opt("colorByKind", true) then
                local kr, kg, kb = B:KindColor("normal")
                PaintBar(plate, kr, kg, kb)
            else
                PaintBar(plate, normal[1], normal[2], normal[3])
            end
        end
    end

    -- Target indicator: 1px border (sharp) or accent outline (round)
    local highlight = isTarget and Opt("targetHighlight", true)
    if highlight then
        local ar, ag, ab = B:GetAccent()
        B:SetBorderColor(healthBar, ar, ag, ab, 1)
        if plate.rglow then
            plate.rglow:SetTrackColor(ar, ag, ab, 0.9)
            if not plate.rglow:IsShown() then
                plate.rglow:Show()
                plate.rglow:SetFill(0)
            end
        end
    else
        B:SetBorderColor(healthBar, 0, 0, 0, 1)
        if plate.rglow and plate.rglow:IsShown() then plate.rglow:Hide() end
    end

    -- Target Debuffs
    local lift = (name and name:IsShown()) and (nameSize + 7) or 4
    UpdatePlateDebuffs(plate, isTarget, lift)

    -- Elite / Boss indicator text styling
    if (kind ~= "normal") and level and Opt("goldLevel", true) then
        level:SetTextColor(1.0, 0.82, 0.10)
    end
end

local function SkinPlate(plate)
    if not plate or plate.buiSkinned then return end
    if type(plate.GetRegions) ~= "function" or type(plate.GetChildren) ~= "function" then return end

    local regions = { plate:GetRegions() }
    local nRegions = table.getn(regions)
    local border, glow, nameFs, levelFs, skullIcon, raidIcon

    for i = 1, nRegions do
        local r = regions[i]
        if r and r.GetObjectType then
            local oType = r:GetObjectType()
            if oType == "Texture" then
                local tex = r:GetTexture()
                if tex == "Interface\\Tooltips\\Nameplate-Border" then
                    border = r
                elseif tex == "Interface\\Tooltips\\Nameplate-Glow" then
                    glow = r
                elseif tex and string.find(tex, "Skull", 1, true) then
                    skullIcon = r
                elseif tex and (string.find(tex, "TargetingFrame", 1, true) or string.find(tex, "RaidIcon", 1, true)) then
                    raidIcon = r
                end
            elseif oType == "FontString" then
                if not nameFs then
                    nameFs = r
                else
                    levelFs = r
                end
            end
        end
    end

    if not border then return end

    -- Find child StatusBar frames
    local children = { plate:GetChildren() }
    local nChildren = table.getn(children)
    local healthBar, castBar
    for i = 1, nChildren do
        local c = children[i]
        if c and type(c.GetStatusBarTexture) == "function" then
            if not healthBar then
                healthBar = c
            else
                castBar = c
            end
        end
    end

    if not healthBar then return end

    plate.buiSkinned = true

    -- Hide default blizzard textures
    border:SetAlpha(0)
    if glow then glow:SetAlpha(0) end

    plate.healthBar = healthBar
    plate.nameFs = nameFs
    plate.levelFs = levelFs
    plate.skullIcon = skullIcon
    plate.raidIcon = raidIcon

    -- Reskin HealthBar
    healthBar:SetStatusBarTexture(B:GetBarTexture())
    healthBar:ClearAllPoints()
    healthBar:SetPoint("CENTER", plate, "CENTER", 0, 0)
    healthBar:SetWidth(KINDS.normal.width)
    healthBar:SetHeight(KINDS.normal.height)

    local round = B:IsRound()
    local overlay = healthBar
    if round then
        -- Round style: accent outline (target) below a rounded bar that
        -- replaces the stock fill; marker and text sit on the rounded bar.
        local glowBar = PlateBar(healthBar, KINDS.normal.height + 4)
        glowBar:SetPoint("LEFT", healthBar, "LEFT", -2, 0)
        glowBar:SetPoint("RIGHT", healthBar, "RIGHT", 2, 0)
        glowBar:SetFrameLevel(healthBar:GetFrameLevel() + 1)
        glowBar:EnableMouse(false)
        glowBar:SetFill(0)
        glowBar:Hide()
        plate.rglow = glowBar

        local rbar = PlateBar(healthBar, KINDS.normal.height)
        rbar:SetPoint("LEFT", healthBar, "LEFT", 0, 0)
        rbar:SetPoint("RIGHT", healthBar, "RIGHT", 0, 0)
        rbar:SetFrameLevel(healthBar:GetFrameLevel() + 2)
        rbar:EnableMouse(false)
        rbar:SetTrackColor(0.05, 0.05, 0.05, 0.85)
        plate.rbar = rbar
        overlay = rbar
        HideStockFill(healthBar)
    else
        -- 1px Border
        B:Border(healthBar, 0, 0, 0, 1)

        -- Dark backdrop behind healthBar
        local bg = healthBar:CreateTexture(nil, "BACKGROUND")
        B:Solid(bg, 0.05, 0.05, 0.05, 0.85)
        bg:SetAllPoints(healthBar)
        healthBar.buiBg = bg
    end

    -- Execute Range Marker Line (1px vertical overlay)
    local marker = overlay:CreateTexture(nil, "OVERLAY")
    marker:SetWidth(1)
    marker:SetHeight(KINDS.normal.height)
    marker:SetTexture(B.WHITE)
    marker:SetVertexColor(1, 1, 1, 0.45)
    marker:SetPoint("LEFT", healthBar, "LEFT", KINDS.normal.width * EXECUTE_RANGE, 0)
    plate.marker = marker

    -- Target Debuffs Array (6 frames)
    local debuffs = {}
    for d = 1, PLATE_DEBUFFS do
        local df = CreateFrame("Frame", nil, healthBar)
        df:SetWidth(DEBUFF_SIZE)
        df:SetHeight(DEBUFF_SIZE)
        if not round then B:Border(df, 0, 0, 0, 1) end
        local icon = df:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(df)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        df.icon = icon
        local countFs = B:Font(df, 8, "RIGHT")
        countFs:SetPoint("BOTTOMRIGHT", df, "BOTTOMRIGHT", 1, -1)
        countFs:SetTextColor(1, 1, 1)
        df.count = countFs
        df:Hide()
        table.insert(debuffs, df)
    end
    plate.debuffs = debuffs

    -- Health percentage fontstring
    local hpFs = B:Font(overlay, 8, "RIGHT")
    hpFs:SetPoint("RIGHT", healthBar, "RIGHT", round and -4 or -2, 0)
    plate.hpFs = hpFs

    -- Style Name font
    if nameFs then
        nameFs:SetFont(B:GetFontPath(), KINDS.normal.nameSize, "OUTLINE")
        nameFs:ClearAllPoints()
        nameFs:SetPoint("BOTTOM", healthBar, "TOP", 0, 3)
    end

    -- Style Level font
    if levelFs then
        levelFs:SetFont(B:GetFontPath(), 8, "OUTLINE")
        levelFs:ClearAllPoints()
        levelFs:SetPoint("RIGHT", healthBar, "LEFT", -3, 0)
    end

    -- Style Raid Icon
    if raidIcon then
        raidIcon:ClearAllPoints()
        raidIcon:SetPoint("BOTTOM", healthBar, "TOP", 0, 14)
    end

    -- Style CastBar if present
    if castBar and type(castBar.SetStatusBarTexture) == "function" then
        castBar:SetStatusBarTexture(B:GetBarTexture())
        castBar:ClearAllPoints()
        castBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -4)
        castBar:SetWidth(KINDS.normal.width)
        castBar:SetHeight(8)
        if not round then B:Border(castBar, 0, 0, 0, 1) end
        local cbg = castBar:CreateTexture(nil, "BACKGROUND")
        B:Solid(cbg, 0.05, 0.05, 0.05, 0.85)
        cbg:SetAllPoints(castBar)
        plate.castBar = castBar
    end

    -- Update plate when shown
    healthBar:SetScript("OnShow", function()
        UpdatePlate(plate)
    end)

    -- Attach per-frame watcher child frame for instantaneous response to movement/targeting
    local watcher = CreateFrame("Frame", nil, plate)
    watcher:SetScript("OnUpdate", function()
        UpdatePlate(plate)
    end)
    plate.buiWatcher = watcher

    -- Initial evaluation
    UpdatePlate(plate)
end

function mod:Create()
    -- At startup, ensure plates stay hidden if module is disabled or NAMEPLATES_ON is nil
    if not B:IsEnabled("nameplates") or not NAMEPLATES_ON then
        if type(HideNameplates) == "function" then HideNameplates() end
        HideAllPlates()
    end

    local scanner = CreateFrame("Frame", "BUI_NameplateScanner", UIParent)
    scanner:SetScript("OnUpdate", function()
        if not B:IsEnabled("nameplates") or not NAMEPLATES_ON then return end
        if not WorldFrame then return end

        local children = { WorldFrame:GetChildren() }
        local n = table.getn(children)
        for i = 1, n do
            local c = children[i]
            if c and c.IsShown and c:IsShown() then
                if not c.buiSkinned then
                    SkinPlate(c)
                else
                    UpdatePlate(c)
                end
            end
        end
    end)

    scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
    scanner:SetScript("OnEvent", function()
        if not B:IsEnabled("nameplates") or not NAMEPLATES_ON then
            if type(HideNameplates) == "function" then HideNameplates() end
            HideAllPlates()
        end
    end)

    -- Hook ShowNameplates & HideNameplates so pressing 'V' cleanly controls NAMEPLATES_ON and visibility
    if type(ShowNameplates) == "function" and not mod.origShowNameplates then
        mod.origShowNameplates = ShowNameplates
        ShowNameplates = function()
            _G.NAMEPLATES_ON = 1
            mod.origShowNameplates()
        end
    end
    if type(HideNameplates) == "function" and not mod.origHideNameplates then
        mod.origHideNameplates = HideNameplates
        HideNameplates = function()
            _G.NAMEPLATES_ON = nil
            mod.origHideNameplates()
            HideAllPlates()
        end
    end

    self.frame = scanner
    self.scanner = scanner
end

function mod:ApplyOptions()
    optVersion = optVersion + 1
end

function mod:Update(state)
    -- Never force ShowNameplates() here! Visibility is toggled by the player via 'V' (NAMEPLATES_ON).
    if not B:IsEnabled("nameplates") or not NAMEPLATES_ON then
        HideAllPlates()
    end
end

-- Unit kinds are keyed by name; names from the previous run must not leak.
function mod:OnRunStart()
    for k in pairs(liveKinds) do liveKinds[k] = nil end
end

B:RegisterModule("nameplates", mod)