-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Nameplates.lua
--  Cyberpunk-styled Nameplates in the manner of Plater / SurvivorPlates.
--  Features:
--    - Unit kind sizing: Normal (100x9), Elite (130x11), Guardian (150x12), Boss (170x14)
--    - 30% Execute Range marker line; bar turns gold when <= 30% HP
--    - Reaction & Kind colors: Bosses (Purple), Guardians (Cyan), Elites (Amber), Normal (Neon Red)
--    - Target frame highlight (1px accent border) and Target Debuffs (up to 6 with stacks)
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Nameplates"
mod.alwaysActive = false

local EXECUTE_RANGE = 0.30
local EXECUTE_COLOR = { 1.00, 0.86, 0.25 }
local PLATE_DEBUFFS = 6
local DEBUFF_SIZE = 15

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

    if not isTarget then
        for i = 1, PLATE_DEBUFFS do
            if debuffs[i] then debuffs[i]:Hide() end
        end
        return
    end

    for i = 1, PLATE_DEBUFFS do
        local df = debuffs[i]
        local tex, count = UnitDebuff("target", i)
        if tex then
            df:ClearAllPoints()
            df:SetPoint("BOTTOMLEFT", plate.healthBar, "TOPLEFT", (i - 1) * (DEBUFF_SIZE + 2), lift)
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

local function UpdatePlate(plate)
    if not plate or not plate.buiSkinned or not plate:IsShown() then return end

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
    if not healthBar:IsShown() then healthBar:Show() end
    healthBar:SetAlpha(1)
    if name and not name:IsShown() then name:Show() name:SetAlpha(1) end
    if level and not level:IsShown() then level:Show() level:SetAlpha(1) end
    if hpFs and not hpFs:IsShown() then hpFs:Show() hpFs:SetAlpha(1) end

    -- Sizing update if kind changed
    if plate.buiKind ~= kind then
        plate.buiKind = kind
        healthBar:SetWidth(cfg.width)
        healthBar:SetHeight(cfg.height)
        if plate.marker then
            plate.marker:SetHeight(cfg.height)
            plate.marker:ClearAllPoints()
            plate.marker:SetPoint("LEFT", healthBar, "LEFT", cfg.width * EXECUTE_RANGE, 0)
        end
        if name then
            name:SetFont(B:GetFontPath(), cfg.nameSize, "OUTLINE")
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", healthBar, "TOP", 0, 3)
        end
        if hpFs then
            hpFs:SetFont(B:GetFontPath(), math.max(8, cfg.height - 1), "OUTLINE")
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
    if maxv and (maxv - minv == 100 or maxv <= 1) then
        hpFs:SetText(tostring(pct) .. "%")
    elseif kind == "normal" then
        hpFs:SetText(B:Short(cur))
    else
        hpFs:SetText(B:Short(cur) .. " / " .. B:Short(maxv) .. "  " .. tostring(pct) .. "%")
    end

    -- Execute Marker & Color logic
    if share <= EXECUTE_RANGE then
        -- Execute threshold: gold color and hide marker line
        if plate.marker then plate.marker:Hide() end
        B:SetBarColor(healthBar, EXECUTE_COLOR[1], EXECUTE_COLOR[2], EXECUTE_COLOR[3])
    else
        if plate.marker then plate.marker:Show() end
        if kind == "boss" or kind == "guardian" or kind == "elite" then
            B:SetBarColor(healthBar, cfg.color[1], cfg.color[2], cfg.color[3])
        else
            local r, g, b = healthBar:GetStatusBarColor()
            if r and g and b then
                if r > 0.8 and g < 0.2 and b < 0.2 then
                    -- Hostile: Neon Red
                    B:SetBarColor(healthBar, cfg.color[1], cfg.color[2], cfg.color[3])
                elseif r > 0.8 and g > 0.8 and b < 0.2 then
                    -- Neutral: Cyber Gold
                    B:SetBarColor(healthBar, 0.95, 0.78, 0.12)
                elseif g > 0.7 and r < 0.2 then
                    -- Friendly: Cyber Green
                    B:SetBarColor(healthBar, 0.15, 0.85, 0.35)
                elseif r > 0.4 and r < 0.6 and g > 0.4 and g < 0.6 and b > 0.4 and b < 0.6 then
                    -- Tapped / Gray
                    B:SetBarColor(healthBar, 0.50, 0.50, 0.50)
                else
                    B:SetBarColor(healthBar, cfg.color[1], cfg.color[2], cfg.color[3])
                end
            else
                B:SetBarColor(healthBar, cfg.color[1], cfg.color[2], cfg.color[3])
            end
        end
    end

    -- Target indicator border
    if isTarget then
        local ar, ag, ab = B:GetAccent()
        B:SetBorderColor(healthBar, ar, ag, ab, 1)
    else
        B:SetBorderColor(healthBar, 0, 0, 0, 1)
    end

    -- Target Debuffs
    local lift = (name and name:IsShown()) and (cfg.nameSize + 7) or 4
    UpdatePlateDebuffs(plate, isTarget, lift)

    -- Elite / Boss indicator text styling
    if (kind ~= "normal") and level then
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

    -- 1px Border
    B:Border(healthBar, 0, 0, 0, 1)

    -- Dark backdrop behind healthBar
    local bg = healthBar:CreateTexture(nil, "BACKGROUND")
    B:Solid(bg, 0.05, 0.05, 0.05, 0.85)
    bg:SetAllPoints(healthBar)
    healthBar.buiBg = bg

    -- Execute Range Marker Line (1px vertical overlay)
    local marker = healthBar:CreateTexture(nil, "OVERLAY")
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
        B:Border(df, 0, 0, 0, 1)
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
    local hpFs = B:Font(healthBar, 8, "RIGHT")
    hpFs:SetPoint("RIGHT", healthBar, "RIGHT", -2, 0)
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
        B:Border(castBar, 0, 0, 0, 1)
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
    if B:IsEnabled("nameplates") then
        if type(ShowNameplates) == "function" then ShowNameplates() end
    else
        if type(HideNameplates) == "function" then HideNameplates() end
    end

    local scanner = CreateFrame("Frame", "BUI_NameplateScanner", UIParent)
    scanner:SetScript("OnUpdate", function()
        if not B:IsEnabled("nameplates") then return end
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
        if B:IsEnabled("nameplates") then
            if type(ShowNameplates) == "function" then ShowNameplates() end
        else
            if type(HideNameplates) == "function" then HideNameplates() end
        end
    end)

    self.frame = scanner
    self.scanner = scanner
end

function mod:Update(state)
    if B:IsEnabled("nameplates") then
        if type(ShowNameplates) == "function" then ShowNameplates() end
    else
        if type(HideNameplates) == "function" then HideNameplates() end
    end
end

B:RegisterModule("nameplates", mod)