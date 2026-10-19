-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Nameplates.lua
--  Cyberpunk-styled Nameplates (1px border, smooth statusbar, custom font, reaction colors).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local mod = {}
mod.label = "Nameplates"
mod.alwaysActive = true

local function SkinPlate(plate)
    if plate.buiSkinned then return end

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
                elseif tex and (string.find(tex, "Elite") or string.find(tex, "Dragon")) then
                    eliteIcon = r
                elseif tex and string.find(tex, "Boss") then
                    bossIcon = r
                elseif tex and (string.find(tex, "TargetingFrame") or string.find(tex, "RaidIcon")) then
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

    -- Value & Percentage
    local cur = healthBar:GetValue() or 0
    local minv, maxv = healthBar:GetMinMaxValues()
    if maxv and maxv > 0 then
        local pct = math.floor(cur / maxv * 100 + 0.5)
        hpFs:SetText(tostring(pct) .. "%")
    end

    -- Color enhancement (Cyberpunk neon tones)
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

    -- Target indicator border
    if UnitExists("target") and name and name:GetText() == UnitName("target") then
        local ar, ag, ab = B:GetAccent()
        B:Border(healthBar, ar, ag, ab, 1)
    else
        B:Border(healthBar, 0, 0, 0, 1)
    end

    -- Elite indicator
    if plate.eliteIcon and plate.eliteIcon:IsShown() and level then
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
            if c then
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
