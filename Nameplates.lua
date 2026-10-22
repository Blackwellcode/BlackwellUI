-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Nameplates.lua
--  Cyberpunk-styled Nameplates (1px border, smooth statusbar, custom font, reaction colors).
--  Filter: Exclusively Bosses, Rares / Elites, and active player target.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Nameplates"
mod.alwaysActive = true

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
                    elseif uKind == "guardian" or uKind == "elite" then
                        liveKinds[uName] = "rare"
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

local function IsBossOrRare(plate, nameStr)
    RefreshLiveKinds()

    local isBoss = false
    local isRare = false

    -- 1. Skull Icon (Level -1 / Boss ?? in WoW 1.12)
    if plate.skullIcon and plate.skullIcon:IsShown() then
        isBoss = true
    end

    -- 2. Check name against dynamic and static databases
    if nameStr and nameStr ~= "" then
        local lk = liveKinds[nameStr]
        if lk == "boss" then
            isBoss = true
        elseif lk == "rare" then
            isRare = true
        elseif BOSS_NAMES[nameStr] then
            isBoss = true
        elseif RARE_NAMES[nameStr] then
            isRare = true
        end
    end

    -- 3. Check target classification if plate matches current target
    if not isBoss and not isRare and UnitExists("target") and nameStr and nameStr == UnitName("target") then
        if AZS_UnitKind then
            local k = AZS_UnitKind("target")
            if k == "boss" or k == "final" then
                isBoss = true
            elseif k == "guardian" or k == "elite" then
                isRare = true
            end
        end
        if not isBoss and not isRare then
            local c = UnitClassification("target")
            if c == "worldboss" then
                isBoss = true
            elseif c == "elite" or c == "rareelite" or c == "rare" then
                isRare = true
            end
        end
    end

    return isBoss, isRare, (isBoss or isRare)
end

local function UpdatePlate(plate)
    if not plate or not plate.buiSkinned or not plate:IsShown() then return end

    local healthBar = plate.healthBar
    local hpFs = plate.hpFs
    local name = plate.nameFs
    local level = plate.levelFs
    local nameStr = name and name:GetText()

    local isBoss, isRare, isImportant = IsBossOrRare(plate, nameStr)
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

    -- Value & Percentage
    local cur = healthBar:GetValue() or 0
    local minv, maxv = healthBar:GetMinMaxValues()
    if maxv and maxv > 0 then
        local pct = math.floor(cur / maxv * 100 + 0.5)
        hpFs:SetText(tostring(pct) .. "%")
    end

    -- Color enhancement: Bosses take Violet/Crimson, Rares take Amber/Gold, others standard
    if isBoss then
        B:SetBarColor(healthBar, 0.85, 0.20, 0.40)
    elseif isRare then
        B:SetBarColor(healthBar, 1.00, 0.65, 0.12)
    else
        local r, g, b = healthBar:GetStatusBarColor()
        if r and g and b then
            if r > 0.8 and g < 0.2 and b < 0.2 then
                -- Hostile: Neon Red
                B:SetBarColor(healthBar, 0.92, 0.15, 0.15)
            elseif r > 0.8 and g > 0.8 and b < 0.2 then
                -- Neutral: Cyber Gold
                B:SetBarColor(healthBar, 0.95, 0.78, 0.12)
            elseif g > 0.7 and r < 0.2 then
                -- Friendly: Cyber Green
                B:SetBarColor(healthBar, 0.15, 0.85, 0.35)
            elseif r > 0.4 and r < 0.6 and g > 0.4 and g < 0.6 and b > 0.4 and b < 0.6 then
                -- Tapped / Gray
                B:SetBarColor(healthBar, 0.50, 0.50, 0.50)
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

    -- Elite / Boss indicator text styling
    if (isBoss or isRare) and level then
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
    healthBar:SetWidth(120)
    healthBar:SetHeight(10)

    -- 1px Border
    B:Border(healthBar, 0, 0, 0, 1)

    -- Dark backdrop behind healthBar
    local bg = healthBar:CreateTexture(nil, "BACKGROUND")
    B:Solid(bg, 0.05, 0.05, 0.05, 0.85)
    bg:SetAllPoints(healthBar)
    healthBar.buiBg = bg

    -- Health percentage fontstring
    local hpFs = B:Font(healthBar, 8, "RIGHT")
    hpFs:SetPoint("RIGHT", healthBar, "RIGHT", -2, 0)
    plate.hpFs = hpFs

    -- Style Name font
    if nameFs then
        nameFs:SetFont(B:GetFontPath(), 9, "OUTLINE")
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
        castBar:SetWidth(120)
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
