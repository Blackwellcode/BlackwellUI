-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Nameplates.lua
--  Cyberpunk-styled Nameplates (1px border, smooth statusbar, custom font, reaction colors).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Nameplates"
mod.alwaysActive = true

-------------------------------------------------------------------------------
--  Azeroth Survivors Boss & Rare Dictionaries
-------------------------------------------------------------------------------
local BOSS_NAMES = {
    -- Elwynn Forest
    ["Hogger"] = true, ["Mother Fang"] = true, ["Rhahk'Zor"] = true, ["Mr. Smite"] = true, ["Edwin VanCleef"] = true,
    -- Duskwood
    ["Naraxis"] = true, ["Mor'Ladim"] = true, ["Stitches"] = true, ["Lupos"] = true, ["Morbent Fel"] = true,
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

local function IsBossOrRare(plate, nameStr)
    local isBoss = false
    local isRare = false

    if plate.bossIcon and plate.bossIcon:IsShown() then
        isBoss = true
    end
    if plate.eliteIcon and plate.eliteIcon:IsShown() then
        isRare = true
    end

    if nameStr and nameStr ~= "" then
        if BOSS_NAMES[nameStr] then
            isBoss = true
        elseif RARE_NAMES[nameStr] then
            isRare = true
        end

        -- Check live AZS units table if available
        if not isBoss and not isRare and AZS_UNITS and type(AZS_UNITS) == "table" then
            local nUnits = table.getn(AZS_UNITS)
            for i = 1, nUnits do
                local u = AZS_UNITS[i]
                if type(u) == "table" then
                    local uName = u.name or u[3]
                    local uKind = u.kind or u[1]
                    if uName and uName == nameStr then
                        if uKind == "boss" or uKind == "final" then
                            isBoss = true
                            break
                        elseif uKind == "elite" or uKind == "guardian" then
                            isRare = true
                            break
                        end
                    end
                end
            end
        end

        -- Check target classification if this plate is our current target
        if not isBoss and not isRare and UnitExists("target") and UnitName("target") == nameStr then
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

local function SkinPlate(plate)
    if not plate or plate.buiSkinned then return end
    if type(plate.GetRegions) ~= "function" or type(plate.GetChildren) ~= "function" then return end

    local regions = { plate:GetRegions() }
    local nRegions = table.getn(regions)
    local border, glow, nameFs, levelFs, bossIcon, raidIcon, eliteIcon

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
                elseif tex and (string.find(tex, "Elite", 1, true) or string.find(tex, "Dragon", 1, true)) then
                    eliteIcon = r
                elseif tex and string.find(tex, "Boss", 1, true) then
                    bossIcon = r
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
    plate.bossIcon = bossIcon
    plate.raidIcon = raidIcon
    plate.eliteIcon = eliteIcon

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
    end
end

local function UpdatePlate(plate)
    if not plate.buiSkinned or not plate:IsShown() then return end

    local healthBar = plate.healthBar
    local hpFs = plate.hpFs
    local name = plate.nameFs
    local level = plate.levelFs
    local nameStr = name and name:GetText()

    local isBoss, isRare, isImportant = IsBossOrRare(plate, nameStr)
    local isTarget = UnitExists("target") and nameStr and nameStr == UnitName("target")

    -- Filter: Only show Nameplates of Bosses and Rares (and player's current target)
    if not isImportant and not isTarget then
        if not plate.buiFiltered then
            healthBar:Hide()
            if name then name:Hide() end
            if level then level:Hide() end
            if hpFs then hpFs:Hide() end
            if plate.castBar then plate.castBar:Hide() end
            plate.buiFiltered = true
        end
        return
    elseif plate.buiFiltered then
        healthBar:Show()
        if name then name:Show() end
        if level then level:Show() end
        if hpFs then hpFs:Show() end
        plate.buiFiltered = nil
    end

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

    -- Target indicator border (safe re-coloring without creating new textures)
    if isTarget then
        local ar, ag, ab = B:GetAccent()
        B:SetBorderColor(healthBar, ar, ag, ab, 1)
    else
        B:SetBorderColor(healthBar, 0, 0, 0, 1)
    end

    -- Elite / Boss indicator text styling
    if (isBoss or isRare or (plate.eliteIcon and plate.eliteIcon:IsShown())) and level then
        level:SetTextColor(1.0, 0.82, 0.10)
    end
end

function mod:Create()
    local scanner = CreateFrame("Frame", "BUI_NameplateScanner", UIParent)
    local elapsed = 0
    scanner:SetScript("OnUpdate", function()
        local dt = arg1 or 0
        elapsed = elapsed + dt
        if elapsed < 0.10 then return end
        elapsed = 0

        if not B:IsEnabled("nameplates") then return end
        if not WorldFrame then return end

        local children = { WorldFrame:GetChildren() }
        local n = table.getn(children)
        for i = 1, n do
            local c = children[i]
            if c and c.IsShown and c:IsShown() then
                if not c.buiSkinned then
                    SkinPlate(c)
                end
                if c.buiSkinned then
                    UpdatePlate(c)
                end
            end
        end
    end)
    self.frame = scanner
    self.scanner = scanner
end

function mod:Update(state)
    -- Nameplates are driven via OnUpdate scanner
end

B:RegisterModule("nameplates", mod)
