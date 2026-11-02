-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Core.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Cyberpunk-grade HUD & Analytics Engine for Azeroth Survivors (WoW 1.12.1).
--  Lua 5.0 strict: no '#', no '%', no string methods, no '...'.
--  Script handlers use the 1.12 globals this / event / arg1.
-------------------------------------------------------------------------------

if not _G then
    _G = getfenv(0)
end

BlackwellUI = {}
local B = BlackwellUI
BlackwallUI = BlackwellUI -- Backwards compatibility alias

B.version = "2.8.1-azs"
B.media = "Interface\\AddOns\\BlackwellUI\\media\\"
B.WHITE = "Interface\\Buttons\\WHITE8X8"
B.SOLID = "Interface\\Buttons\\WHITE8X8"
B.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

B.modules = {}
B.moduleOrder = {}
B.movers = {}
B.moverOrder = {}
B.fontStrings = {}
B.bars = {}
B.accents = {}
B.backdrops = {}
B.unlocked = false
B.initialized = false
B.built = false

-------------------------------------------------------------------------------
--  Look: Cyberpunk Themes, Bar Textures, Fonts
-------------------------------------------------------------------------------
B.THEMES = {
    ["Blackwell"]     = { r = 0/255,   g = 229/255, b = 255/255 }, -- Neon Cyan (#00e5ff)
    ["Blackwall"]     = { r = 0/255,   g = 229/255, b = 255/255 }, -- Alias
    ["Crimson"]       = { r = 255/255, g = 0/255,   b = 85/255  }, -- Neon Pink/Red (#ff0055)
    ["Amber"]         = { r = 255/255, g = 184/255, b = 0/255   }, -- Cyber Gold/Amber (#ffb800)
    ["Emerald"]       = { r = 0/255,   g = 255/255, b = 136/255 }, -- Matrix Neon Green (#00ff88)
    ["Violet"]        = { r = 168/255, g = 85/255,  b = 247/255 }, -- Netrunner Violet (#a855f7)
    ["Monolith"]      = { r = 226/255, g = 232/255, b = 240/255 }, -- Cold Platinum (#e2e8f0)
    ["Class Colored"] = { class = true },
    ["Custom"]        = { custom = true },

    -- Legacy aliases
    ["Forever"]       = { r = 220/255, g = 167/255, b = 127/255 },
    ["Horde"]         = { r = 255/255, g = 90/255,  b = 31/255  },
    ["Alliance"]      = { r = 63/255,  g = 167/255, b = 255/255 },
    ["Midnight"]      = { r = 120/255, g = 65/255,  b = 200/255 },
    ["Dark"]          = { r = 1,       g = 1,       b = 1       },
}
B.THEME_ORDER = { "Blackwell", "Crimson", "Amber", "Emerald", "Violet", "Monolith", "Class Colored", "Custom" }

-- Only power-of-two textures: the 1.12 renderer rejects other sizes.
-- (atrocity.tga is 256x40 and was dropped; InitDB falls back to the default.)
B.BAR_TEXTURES = {
    ["Melli"]    = "Interface\\AddOns\\BlackwellUI\\media\\textures\\melli.tga",
    ["Flat"]     = "Interface\\Buttons\\WHITE8X8",
    ["Pixels"]   = "Interface\\AddOns\\BlackwellUI\\media\\textures\\pixels-fill.tga",
    ["Gradient"] = "Interface\\AddOns\\BlackwellUI\\media\\textures\\gradient-light.tga",
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
}
B.BAR_TEXTURE_ORDER = { "Melli", "Flat", "Pixels", "Gradient", "Blizzard" }

-- Bundled fonts are SIL OFL 1.1 (license texts next to them in media/fonts);
-- Friz Quadrata is the game client's own font and is not shipped.
B.FONTS = {
    ["Barlow"]        = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\BarlowSemiCondensed-Medium.ttf",
    ["Barlow Bold"]   = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\BarlowSemiCondensed-SemiBold.ttf",
    ["Fira Sans"]     = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\FiraSans Medium.ttf",
    ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
}
B.FONT_ORDER = { "Barlow", "Barlow Bold", "Fira Sans", "Friz Quadrata" }
-- Fonts removed in 2.7.2 (not redistributable) and their replacements.
B.FONT_RENAMED = { ["Expressway"] = "Barlow", ["Expressway Bold"] = "Barlow Bold", ["Homespun"] = "Barlow" }

B.CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Comprehensive cross-platform aliases (TitleCase, lowercase, German localizations)
local CLASS_ALIASES = {
    ["Warrior"] = "WARRIOR", ["warrior"] = "WARRIOR", ["Krieger"] = "WARRIOR", ["krieger"] = "WARRIOR", ["KRIEGER"] = "WARRIOR",
    ["Paladin"] = "PALADIN", ["paladin"] = "PALADIN",
    ["Hunter"]  = "HUNTER",  ["hunter"]  = "HUNTER",  ["Jäger"] = "HUNTER",   ["jäger"] = "HUNTER",   ["JÄGER"] = "HUNTER", ["Jaeger"] = "HUNTER", ["jaeger"] = "HUNTER", ["JAEGER"] = "HUNTER",
    ["Rogue"]   = "ROGUE",   ["rogue"]   = "ROGUE",   ["Schurke"] = "ROGUE",  ["schurke"] = "ROGUE",  ["SCHURKE"] = "ROGUE",
    ["Priest"]  = "PRIEST",  ["priest"]  = "PRIEST",  ["Priester"] = "PRIEST", ["priester"] = "PRIEST", ["PRIESTER"] = "PRIEST",
    ["Shaman"]  = "SHAMAN",  ["shaman"]  = "SHAMAN",  ["Schamane"] = "SHAMAN", ["schamane"] = "SHAMAN", ["SCHAMANE"] = "SHAMAN",
    ["Mage"]    = "MAGE",    ["mage"]    = "MAGE",    ["Magier"] = "MAGE",   ["magier"] = "MAGE",   ["MAGIER"] = "MAGE",
    ["Warlock"] = "WARLOCK", ["warlock"] = "WARLOCK", ["Hexenmeister"] = "WARLOCK", ["hexenmeister"] = "WARLOCK", ["HEXENMEISTER"] = "WARLOCK",
    ["Druid"]   = "DRUID",   ["druid"]   = "DRUID",   ["Druide"] = "DRUID",  ["druide"] = "DRUID",  ["DRUIDE"] = "DRUID",
}
for alias, target in pairs(CLASS_ALIASES) do
    B.CLASS_COLORS[alias] = B.CLASS_COLORS[target]
end

-- Unit kinds as AZS_UNITS / AZS_TARGET name them.
-- One colour per unit kind for target frame, elites & bosses list and
-- nameplates: boss red, rare guardian yellow, elite blue, normal mobs violet.
-- The Unit Frames page can change them (written in here by its ApplyOptions).
B.KIND_COLORS = {
    final    = { r = 0.86, g = 0.16, b = 0.42, label = "FINAL BOSS" },
    boss     = { r = 0.86, g = 0.20, b = 0.20, label = "BOSS" },
    elite    = { r = 0.25, g = 0.60, b = 1.00, label = "ELITE" },
    guardian = { r = 1.00, g = 0.78, b = 0.15, label = "GUARDIAN" },
    normal   = { r = 0.58, g = 0.42, b = 0.92, label = "" },
    dead     = { r = 0.40, g = 0.40, b = 0.40, label = "DEAD" },
}

function B:KindColor(kind)
    local c = self.KIND_COLORS[kind] or self.KIND_COLORS.normal
    return c.r, c.g, c.b
end

B.PHASE_COLORS = {
    ready    = { r = 0.70, g = 0.70, b = 0.70, label = "READY" },
    playing  = { r = 0.30, g = 0.90, b = 0.45, label = "PLAYING" },
    choosing = { r = 0.35, g = 0.75, b = 1.00, label = "CHOOSING" },
    paused   = { r = 1.00, g = 0.82, b = 0.20, label = "PAUSED" },
    dead     = { r = 1.00, g = 0.25, b = 0.25, label = "DEAD" },
    victory  = { r = 1.00, g = 0.84, b = 0.00, label = "VICTORY" },
}

-------------------------------------------------------------------------------
--  Saved Variables
-------------------------------------------------------------------------------
local DEFAULTS = {
    theme = "Blackwell",
    customAccent = { r = 0/255, g = 229/255, b = 255/255 },
    backdropAlpha = 0.85,
    barTexture = "Melli",
    font = "Barlow",
    fontScaleMod = 0,
    chatFontSize = 12,
    scale = 1.0,
    autoScale = true,
    demo = false,
    replaceHud = true,
    hideBanners = false,
    hideLoot = false,
    meterMode = "damage",
    mergeItemProcs = false,
    colorHealthByClass = true,
    showBuffBars = true,
    showGrid = true,
    -- Off by default: the alerts are class-agnostic (Overpower/Execute) and
    -- fire "ready" for spells the game casts automatically.
    sctAlerts = false,
    statsGrowUp = false,
    -- "auto" follows the game language (CVar azsLanguage); otherwise a code
    -- from B.LANGUAGES.
    language = "auto",
    pinCaches = true,
    pinLairs = true,
    pinEdge = "clamp",
    filterChatSpam = true,
    -- Look: "round" (default) or "sharp" (the angular style up to 2.7);
    -- frames are built in one style, so switching needs a /reload.
    uiStyle = "round",
    cornerRadius = 10,
    -- nil = the style's own panel colour; { r, g, b } once the player picks one.
    panelColor = false,
    fontOutline = "OUTLINE",
    tooltipScale = 0.82,
    tooltipAnchor = "hud",
    tooltipHideInCombat = false,
    tooltipReactionColor = true,
    welcomeMessage = true,
    -- Per-module settings: mod[moduleKey][optionKey] (see B:ModOpt).
    mod = {},
    modules = {
        actionbars = true,
        minimap = true,
        pins = true,
        unitframes = true,
        chat = true,
        castbar = true,
        build = true,
        meter = true,
        timer = true,
        databar = true,
        stats = true,
        nameplates = false,
        combattext = true,
        character = true,
        loot = true,
        rares = true,
        equipment = true,
    },
    positions = {},
    -- Original values of every stock CVar / option global the addon overrides
    -- (see "Managed stock state"); empty while nothing is overridden.
    stockCVars = {},
    stockGlobals = {},
}

local function MergeDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = MergeDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function B:InitDB()
    if self.initialized then return end
    if not BlackwellUIDB then
        if BlackwallUIDB then
            BlackwellUIDB = BlackwallUIDB
        end
    end
    local isUpgrade = (BlackwellUIDB ~= nil)
    BlackwellUIDB = MergeDefaults(DEFAULTS, BlackwellUIDB)
    self.db = BlackwellUIDB
    if not self.db.layoutVersion or self.db.layoutVersion < 12 then
        if self.db.layoutVersion and self.db.layoutVersion < 10 then
            self.db.positions = {}
            if self.db.modules then
                self.db.modules.nameplates = false
            end
            self.db.autoScale = true
            self.db.scale = self:GetOptimalScale()
        end
        if self.db.modules then
            if self.db.modules.combattext == nil then
                self.db.modules.combattext = true
            end
            self.db.modules.nameplates = false
        end
        self.db.replaceHud = true
        self.db.layoutVersion = 12
    end
    -- v14 repeats the v13 seeding: a v13 test build cleared the snapshot at
    -- logout while the client kept the zeroed CVars.
    if self.db.layoutVersion < 14 then
        if isUpgrade then
            -- Up to 2.6.7 the Blizzard bars were hidden whatever the toggle said,
            -- and stock CVars were zeroed without a snapshot. Keep the bars hidden
            -- now that the toggle works, and seed the snapshot so the next restore
            -- brings zeroed values back to the client default once.
            self.db.modules.actionbars = true
            self:SeedLegacyStockSnapshot()
        end
        self.db.layoutVersion = 14
    end
    if self.db.autoScale == nil then
        self.db.autoScale = true
    end
    if self.db.autoScale then
        self.db.scale = self:GetOptimalScale()
    end
    if not self.THEMES[self.db.theme] then self.db.theme = DEFAULTS.theme end
    if not self.BAR_TEXTURES[self.db.barTexture] then self.db.barTexture = DEFAULTS.barTexture end
    if self.FONT_RENAMED[self.db.font] then self.db.font = self.FONT_RENAMED[self.db.font] end
    if not self.FONTS[self.db.font] then self.db.font = DEFAULTS.font end
    if type(self.db.scale) ~= "number" or self.db.scale < 0.5 or self.db.scale > 2 then
        self.db.scale = 1.0
    end
    if type(self.db.backdropAlpha) ~= "number" or self.db.backdropAlpha < 0.2 or self.db.backdropAlpha > 1.0 then
        self.db.backdropAlpha = 0.85
    end
    if type(self.db.fontScaleMod) ~= "number" then
        self.db.fontScaleMod = 0
    end
    if type(self.db.chatFontSize) ~= "number" then
        self.db.chatFontSize = 12
    end
    if self.db.uiStyle ~= "round" and self.db.uiStyle ~= "sharp" then
        self.db.uiStyle = "round"
    end
    if type(self.db.cornerRadius) ~= "number" or self.db.cornerRadius < 2 or self.db.cornerRadius > 16 then
        self.db.cornerRadius = 10
    end
    if self.db.fontOutline ~= "OUTLINE" and self.db.fontOutline ~= "THICKOUTLINE" and self.db.fontOutline ~= "NONE" then
        self.db.fontOutline = "OUTLINE"
    end
    if type(self.db.tooltipScale) ~= "number" or self.db.tooltipScale < 0.5 or self.db.tooltipScale > 1.5 then
        self.db.tooltipScale = 0.82
    end
    if type(self.db.mod) ~= "table" then
        self.db.mod = {}
    end
    if type(self.db.language) ~= "string" or (self.db.language ~= "auto" and type(self.IsKnownLanguage) == "function" and not self:IsKnownLanguage(self.db.language)) then
        self.db.language = "auto"
    end
    if type(self.ApplyLocale) == "function" then
        self:ApplyLocale()
    end
    self.initialized = true
end

-------------------------------------------------------------------------------
--  Formatting (Lua 5.0 safe)
-------------------------------------------------------------------------------
function B:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ffBlackwellUI|r: " .. tostring(msg))
    end
end

function B:Num(v)
    return tonumber(v) or 0
end

function B:Short(v)
    local n = tonumber(v) or 0
    local a = n
    if a < 0 then a = -a end
    if a >= 1000000 then
        return string.format("%.2fM", n / 1000000)
    elseif a >= 10000 then
        return string.format("%.1fK", n / 1000)
    elseif a >= 1000 then
        return string.format("%.2fK", n / 1000)
    end
    return string.format("%d", math.floor(n + 0.5))
end

function B:Clock(sec)
    local s = math.floor(tonumber(sec) or 0)
    if s < 0 then s = 0 end
    return string.format("%d:%02d", math.floor(s / 60), math.mod(s, 60))
end

function B:Countdown(sec)
    local s = tonumber(sec) or 0
    if s <= 0 then return "" end
    if s < 10 then
        return string.format("%.1f", s)
    elseif s < 60 then
        return string.format("%d", math.floor(s + 0.5))
    end
    return string.format("%dm", math.floor(s / 60 + 0.5))
end

function B:Percent(cur, max)
    local c = tonumber(cur) or 0
    local m = tonumber(max) or 0
    if m <= 0 then return 0 end
    local p = c / m
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    return p
end

-- "rain_of_fire" -> "Rain Of Fire"; real names pass through unchanged.
function B:PrettyName(v)
    if v == nil then return "" end
    local s = tostring(v)
    if string.find(s, "_", 1, 1) and not string.find(s, " ", 1, 1) then
        s = string.gsub(s, "_", " ")
        s = string.gsub(s, "(%a)(%w*)", function(first, rest)
            return string.upper(first) .. rest
        end)
    end
    return s
end

-- Up to three letters for an icon-less tile: "Mortal Strike" -> "MS".
function B:Initials(v)
    local s = self:PrettyName(v)
    local out = ""
    local count = 0
    local pos = 1
    while count < 3 do
        local st, en, word = string.find(s, "(%a+)", pos)
        if not st then break end
        out = out .. string.upper(string.sub(word, 1, 1))
        count = count + 1
        pos = en + 1
    end
    if count == 1 then
        out = string.upper(string.sub(s, 1, 3))
    end
    return out
end

local function StripAccents(s)
    if not s or s == "" then return "" end
    s = string.gsub(s, "á", "a")
    s = string.gsub(s, "é", "e")
    s = string.gsub(s, "í", "i")
    s = string.gsub(s, "ó", "o")
    s = string.gsub(s, "ú", "u")
    s = string.gsub(s, "ñ", "n")
    s = string.gsub(s, "ü", "ue")
    s = string.gsub(s, "ä", "ae")
    s = string.gsub(s, "ö", "oe")
    s = string.gsub(s, "ß", "ss")
    s = string.gsub(s, "Á", "a")
    s = string.gsub(s, "É", "e")
    s = string.gsub(s, "Í", "i")
    s = string.gsub(s, "Ó", "o")
    s = string.gsub(s, "Ú", "u")
    s = string.gsub(s, "Ñ", "n")
    return s
end

local function CoreNormalize(name)
    if not name then return "" end
    local s = string.lower(name)
    s = StripAccents(s)
    s = string.gsub(s, "^%d+%.%s*", "")
    s = string.gsub(s, "%s*%([%w%s]+%)%s*$", "")
    s = string.gsub(s, "[%s%-%p]+", "_")
    s = string.gsub(s, "^_+", "")
    s = string.gsub(s, "_+$", "")
    return s
end

local MASTER_ABILITY_ICONS = {
    -- Warrior
    ["cleave"] = "Interface\\Icons\\Ability_Warrior_Cleave",
    ["whirlwind"] = "Interface\\Icons\\Ability_Whirlwind",
    ["thunder_clap"] = "Interface\\Icons\\Spell_Nature_ThunderClap",
    ["mortal_strike"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    ["execute"] = "Interface\\Icons\\INV_Sword_48",
    ["demo_shout"] = "Interface\\Icons\\Ability_Warrior_WarCry",
    ["demoralizing_shout"] = "Interface\\Icons\\Ability_Warrior_WarCry",
    ["battle_shout"] = "Interface\\Icons\\Ability_Warrior_BattleShout",
    ["bloodthirst"] = "Interface\\Icons\\Spell_Nature_BloodLust",
    ["rend"] = "Interface\\Icons\\Ability_Gouge",
    ["shield_slam"] = "Interface\\Icons\\INV_Shield_05",
    ["bloodrage"] = "Interface\\Icons\\Ability_Racial_BloodRage",
    ["charge"] = "Interface\\Icons\\Ability_Warrior_Charge",
    ["heroic_leap"] = "Interface\\Icons\\Ability_Warrior_Charge",
    ["bladestorm"] = "Interface\\Icons\\Ability_Whirlwind",
    ["deep_wounds"] = "Interface\\Icons\\Ability_BackStab",
    ["rampage"] = "Interface\\Icons\\Ability_Warrior_Rampage",
    ["flurry"] = "Interface\\Icons\\Ability_GhoulFrenzy",
    ["sweeping_strikes"] = "Interface\\Icons\\Ability_Rogue_SliceDice",
    ["enrage"] = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
    ["death_wish"] = "Interface\\Icons\\Spell_Shadow_DeathPact",
    ["last_stand"] = "Interface\\Icons\\Spell_Holy_AshesToAshes",
    ["shield_wall"] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
    ["retaliation"] = "Interface\\Icons\\Ability_Warrior_Challange",
    ["recklessness"] = "Interface\\Icons\\Ability_CriticalStrike",
    ["overpower"] = "Interface\\Icons\\Ability_MeleeDamage",
    ["slam"] = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    ["hamstring"] = "Interface\\Icons\\Ability_ShockWave",
    ["mocking_blow"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
    ["taunt"] = "Interface\\Icons\\Spell_Nature_Reincarnation",
    ["disarm"] = "Interface\\Icons\\Ability_Warrior_Disarm",
    ["pummel"] = "Interface\\Icons\\INV_Gauntlets_04",
    ["shield_bash"] = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    ["intercept"] = "Interface\\Icons\\Ability_Rogue_Sprint",
    ["berserker_rage"] = "Interface\\Icons\\Spell_Nature_AncestralGuardian",
    ["blood_frenzy"] = "Interface\\Icons\\Ability_Warrior_BloodFrenzy",
    ["second_wind"] = "Interface\\Icons\\Ability_Hunter_Harass",
    ["victory_rush"] = "Interface\\Icons\\Ability_Warrior_Devastate",
    ["devastate"] = "Interface\\Icons\\INV_Sword_11",
    ["shockwave"] = "Interface\\Icons\\Ability_Warrior_Shockwave",
    ["heroic_strike"] = "Interface\\Icons\\Ability_Rogue_Ambush",
    ["sunder_armor"] = "Interface\\Icons\\Ability_Warrior_Sunder",
    ["concussion_blow"] = "Interface\\Icons\\Ability_ThunderBolt",

    -- Paladin
    ["consecration"] = "Interface\\Icons\\Spell_Holy_InnerFire",
    ["exorcism"] = "Interface\\Icons\\Spell_Holy_Excorcism_02",
    ["hammer_of_wrath"] = "Interface\\Icons\\Ability_ThunderClap",
    ["holy_shock"] = "Interface\\Icons\\Spell_Holy_SearingLight",
    ["holy_wrath"] = "Interface\\Icons\\Spell_Holy_Excorcism",
    ["judgement"] = "Interface\\Icons\\Spell_Holy_RighteousFury",
    ["hammer_of_justice"] = "Interface\\Icons\\Spell_Holy_SealOfMight",
    ["holy_light"] = "Interface\\Icons\\Spell_Holy_HolyBolt",
    ["divine_shield"] = "Interface\\Icons\\Spell_Holy_DivineIntervention",
    ["holy_shield"] = "Interface\\Icons\\Spell_Holy_BlessingOfProtection",
    ["redemption"] = "Interface\\Icons\\Spell_Holy_Resurrection",
    ["blessing_of_freedom"] = "Interface\\Icons\\Spell_Holy_SealOfValor",

    -- Hunter
    ["auto_shot"] = "Interface\\Icons\\INV_Weapon_Bow_07",
    ["arcane_shot"] = "Interface\\Icons\\Ability_ImpalingBolt",
    ["multi_shot"] = "Interface\\Icons\\Ability_UpgradeMoonGlaive",
    ["serpent_sting"] = "Interface\\Icons\\Ability_Hunter_Quickshot",
    ["volley"] = "Interface\\Icons\\Ability_Marksmanship",
    ["explosive_trap"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["concussive_shot"] = "Interface\\Icons\\Spell_Frost_Stun",
    ["aimed_shot"] = "Interface\\Icons\\INV_Spear_07",
    ["immolation_trap"] = "Interface\\Icons\\Spell_Fire_FlameShock",
    ["frost_trap"] = "Interface\\Icons\\Spell_Frost_FreezingBreath",
    ["hunters_mark"] = "Interface\\Icons\\Ability_Hunter_SniperShot",
    ["aspect_of_the_cheetah"] = "Interface\\Icons\\Ability_Mount_JungleTiger",

    -- Rogue
    ["sinister_strike"] = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice",
    ["eviscerate"] = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    ["blade_flurry"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
    ["rupture"] = "Interface\\Icons\\Ability_Rogue_Rupture",
    ["kidney_shot"] = "Interface\\Icons\\Ability_Rogue_KidneyShot",
    ["gouge"] = "Interface\\Icons\\Ability_Gouge",
    ["ghostly_strike"] = "Interface\\Icons\\Spell_Shadow_Curse",
    ["adrenaline_rush"] = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
    ["backstab"] = "Interface\\Icons\\Ability_BackStab",
    ["slice_and_dice"] = "Interface\\Icons\\Ability_Rogue_SliceDice",
    ["seal_fate"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
    ["sprint"] = "Interface\\Icons\\Ability_Rogue_Sprint",

    -- Priest
    ["smite"] = "Interface\\Icons\\Spell_Holy_HolySmite",
    ["sw_pain"] = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    ["shadow_word_pain"] = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    ["mind_blast"] = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
    ["holy_nova"] = "Interface\\Icons\\Spell_Holy_HolyNova",
    ["pw_shield"] = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    ["power_word_shield"] = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    ["weakened_soul"] = "Interface\\Icons\\Spell_Holy_AshesToAshes",
    ["renew"] = "Interface\\Icons\\Spell_Holy_Renew",
    ["holy_fire"] = "Interface\\Icons\\Spell_Holy_SearingLight",
    ["mind_flay"] = "Interface\\Icons\\Spell_Shadow_SiphonMana",
    ["psychic_scream"] = "Interface\\Icons\\Spell_Shadow_PsychicScream",
    ["devouring_plague"] = "Interface\\Icons\\Spell_Shadow_BlackPlague",
    ["lightwell"] = "Interface\\Icons\\Spell_Holy_SummonLightwell",
    ["penance"] = "Interface\\Icons\\Spell_Holy_HolySmite",
    ["fade"] = "Interface\\Icons\\Spell_Magic_LesserInvisibilty",

    -- Shaman
    ["lightning_bolt"] = "Interface\\Icons\\Spell_Nature_Lightning",
    ["chain_lightning"] = "Interface\\Icons\\Spell_Nature_ChainLightning",
    ["earth_shock"] = "Interface\\Icons\\Spell_Nature_EarthShock",
    ["flame_shock"] = "Interface\\Icons\\Spell_Fire_FlameShock",
    ["frost_shock"] = "Interface\\Icons\\Spell_Frost_FrostShock",
    ["lightning_shield"] = "Interface\\Icons\\Spell_Nature_LightningShield",
    ["magma_totem"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["searing_totem"] = "Interface\\Icons\\Spell_Fire_SearingTotem",
    ["fire_nova"] = "Interface\\Icons\\Spell_Fire_SealOfFire",
    ["healing_wave"] = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    ["call_of_flame"] = "Interface\\Icons\\Spell_Fire_Immolation",
    ["ghost_wolf"] = "Interface\\Icons\\Spell_Nature_SpiritWolf",

    -- Mage
    ["fireball"] = "Interface\\Icons\\Spell_Fire_FlameBolt",
    ["frostbolt"] = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    ["arcane_missiles"] = "Interface\\Icons\\Spell_Nature_StarFall",
    ["frost_nova"] = "Interface\\Icons\\Spell_Frost_FrostNova",
    ["arcane_explosion"] = "Interface\\Icons\\Spell_Nature_WispSplode",
    ["blizzard"] = "Interface\\Icons\\Spell_Frost_IceStorm",
    ["flamestrike"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["fire_blast"] = "Interface\\Icons\\Spell_Fire_Fireball",
    ["cone_of_cold"] = "Interface\\Icons\\Spell_Frost_Glacier",
    ["blast_wave"] = "Interface\\Icons\\Spell_Holy_Excorcism_02",
    ["pyroblast"] = "Interface\\Icons\\Spell_Fire_Fireball02",
    ["ice_barrier"] = "Interface\\Icons\\Spell_Ice_Lament",
    ["polymorph"] = "Interface\\Icons\\Spell_Nature_Polymorph",
    ["arcane_power"] = "Interface\\Icons\\Spell_Nature_Lightning",
    ["blink"] = "Interface\\Icons\\Spell_Arcane_Blink",

    -- Warlock
    ["shadow_bolt"] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    ["corruption"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
    ["immolate"] = "Interface\\Icons\\Spell_Fire_Immolation",
    ["curse_of_agony"] = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    ["rain_of_fire"] = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    ["hellfire"] = "Interface\\Icons\\Spell_Fire_Incinerate",
    ["death_coil"] = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    ["searing_pain"] = "Interface\\Icons\\Spell_Fire_SoulBurn",
    ["drain_life"] = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
    ["fear"] = "Interface\\Icons\\Spell_Shadow_Possession",
    ["soul_fire"] = "Interface\\Icons\\Spell_Fire_Fireball02",

    -- Druid
    ["wrath"] = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    ["moonfire"] = "Interface\\Icons\\Spell_Nature_StarFall",
    ["starfire"] = "Interface\\Icons\\Spell_Arcane_StarFire",
    ["hurricane"] = "Interface\\Icons\\Spell_Nature_Cyclone",
    ["insect_swarm"] = "Interface\\Icons\\Spell_Nature_InsectSwarm",
    ["entangling_roots"] = "Interface\\Icons\\Spell_Nature_StrangleVines",
    ["rejuvenation"] = "Interface\\Icons\\Spell_Nature_Rejuvenation",
    ["regrowth"] = "Interface\\Icons\\Spell_Nature_ResistNature",
    ["thorns"] = "Interface\\Icons\\Spell_Nature_Thorns",
    ["swipe"] = "Interface\\Icons\\INV_Misc_MonsterClaw_03",
    ["faerie_fire"] = "Interface\\Icons\\Spell_Nature_FaerieFire",

    -- Racials
    ["blood_fury"] = "Interface\\Icons\\Racial_Orc_BerserkerStrength",
    ["berserking"] = "Interface\\Icons\\Racial_Troll_Berserk",
    ["war_stomp"] = "Interface\\Icons\\Ability_WarStomp",
    ["will_of_the_forsaken"] = "Interface\\Icons\\Spell_Shadow_RaiseDead",
    ["stoneform"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
    ["escape_artist"] = "Interface\\Icons\\Ability_Rogue_Trip",
    ["shadowmeld"] = "Interface\\Icons\\Ability_Ambush",
    ["perception"] = "Interface\\Icons\\Spell_Nature_Sleep",
}
B.MASTER_ABILITY_ICONS = MASTER_ABILITY_ICONS

local EXTRA_ABILITY_ICONS = {
    ["Pets"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["Pet"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["pets"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["pet"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["Pad"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["pad"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["Melee"] = "Interface\\Icons\\INV_Sword_04",
    ["Auto Attack"] = "Interface\\Icons\\INV_Sword_04",
    ["Damage Shield"] = "Interface\\Icons\\Spell_Nature_Thorns",
    ["Hot Streak"] = "Interface\\Icons\\Spell_Fire_Fireball02",
    ["Windfury"] = "Interface\\Icons\\Spell_Nature_Cyclone",
    ["Lightning Overload"] = "Interface\\Icons\\Spell_Nature_CallStorm",
    ["Shadowy Apparitions"] = "Interface\\Icons\\Spell_Shadow_Haunting",
    ["Seed of Corruption"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
    ["Maelstrom Weapon"] = "Interface\\Icons\\Spell_Nature_Lightning",
    ["Leech"] = "Interface\\Icons\\Spell_Shadow_LifeDrain",
    ["Onyxia Tooth Pendant"] = "Interface\\Icons\\INV_Jewelry_Necklace_09",
    ["Choker of the Fire Lord"] = "Interface\\Icons\\INV_Jewelry_Amulet_05",
    ["Choker of Enlightenment"] = "Interface\\Icons\\INV_Jewelry_Necklace_10",
    ["Prestor's Talisman of Connivery"] = "Interface\\Icons\\INV_Jewelry_Necklace_17",
    ["Animated Chain Necklace"] = "Interface\\Icons\\INV_Jewelry_Necklace_01",
    ["Woven Ivy Necklace"] = "Interface\\Icons\\INV_Misc_Herb_15",
    ["Amulet of the Darkmoon"] = "Interface\\Icons\\INV_Jewelry_Necklace_14",
    ["Jeklik's Opaline Talisman"] = "Interface\\Icons\\INV_Jewelry_Necklace_03",
    ["The Eye of Hakkar"] = "Interface\\Icons\\INV_Jewelry_Necklace_22",
    ["Medallion of Steadfast Might"] = "Interface\\Icons\\INV_Jewelry_Amulet_03",
    ["Amulet of Vek'nilash"] = "Interface\\Icons\\INV_Jewelry_Necklace_AhnQiraj_01",
    ["Pendant of the Fallen Dragon"] = "Interface\\Icons\\INV_Jewelry_Necklace_12",
    ["Malice Stone Pendant"] = "Interface\\Icons\\INV_Jewelry_Necklace_29",
    ["Infernal"] = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    ["Doomguard"] = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    ["Felguard"] = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    ["Divine Storm"] = "Interface\\Icons\\Spell_Holy_SealOfRighteousness",
    ["Imp"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
    ["Felhunter"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    ["Succubus"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
    ["Pit Lord"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
    ["Water Elemental"] = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    ["Treant"] = "Interface\\Icons\\Spell_Nature_ForceOfNature",
    ["Spirit Wolf"] = "Interface\\Icons\\Spell_Nature_SpiritWolf",
    ["Wolf"] = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
    ["Raptor"] = "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
    ["Amulet of the Ancients"] = "Interface\\Icons\\INV_Jewelry_Necklace_13",
    ["Amulet of the Inferno"] = "Interface\\Icons\\INV_Jewelry_Necklace_AhnQiraj_03",
    ["Arcane Fortitude"] = "Interface\\Icons\\Spell_Arcane_ArcaneResilience",
    ["Arcane Reach"] = "Interface\\Icons\\Spell_Arcane_StarFire",
    ["Archimtiros' Ring of Reckoning"] = "Interface\\Icons\\INV_Jewelry_Ring_40",
    ["Ardent Defender"] = "Interface\\Icons\\Spell_Holy_HolyProtection",
    ["Band of Accuria"] = "Interface\\Icons\\INV_Jewelry_Ring_15",
    ["Blackhand's Breadth"] = "Interface\\Icons\\INV_Misc_ArmorKit_09",
    ["Blessed Life"] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary",
    ["Blooddrinker's Band"] = "Interface\\Icons\\INV_Jewelry_Ring_49Naxxramas",
    ["Breath of the Black Dragon"] = "Interface\\Icons\\INV_Jewelry_Necklace_27Naxxramas",
    ["Call of the Elements"] = "Interface\\Icons\\Spell_Totem_WardOfDraining",
    ["Contagion"] = "Interface\\Icons\\Spell_Shadow_PlagueCloud",
    ["Dashing Scarlet Cloak"] = "Interface\\Icons\\INV_Misc_Cape_08",
    ["Daybreak"] = "Interface\\Icons\\Spell_Holy_Excorcism",
    ["Defias Bandana"] = "Interface\\Icons\\INV_Misc_Bandana_03",
    ["Demonic Empowerment"] = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    ["Demonic Supremacy"] = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde",
    ["Explosive Ammunition"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["Ferocious Inspiration"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["Fortified"] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
    ["Gnomish Goggles"] = "Interface\\Icons\\INV_Helmet_47",
    ["Gnomish Universal Remote"] = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    ["Gold-sniffer"] = "Interface\\Icons\\INV_Misc_Coin_01",
    ["Hallowed Ground"] = "Interface\\Icons\\Spell_Holy_SealOfProtection",
    ["Hammer of the Righteous"] = "Interface\\Icons\\Spell_Holy_BlessingOfProtection",
    ["Heart of the Earthshaker"] = "Interface\\Icons\\INV_Jewelry_Necklace_AhnQiraj_02",
    ["Heavy Dark Iron Ring"] = "Interface\\Icons\\INV_Jewelry_Ring_14",
    ["Heavy Shield"] = "Interface\\Icons\\INV_Shield_05",
    ["Holy Concentration"] = "Interface\\Icons\\Spell_Holy_SpellWarding",
    ["Holy Guidance"] = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    ["Horde Officer's Tabard"] = "Interface\\Icons\\INV_Misc_TabardPVP_03",
    ["Horn of the Warchief"] = "Interface\\Icons\\INV_Misc_Horn_01",
    ["Improved Berserker Stance"] = "Interface\\Icons\\Ability_Racial_Avatar",
    ["Improved Consecration"] = "Interface\\Icons\\Spell_Holy_InnerFire",
    ["Improved Ice Barrier"] = "Interface\\Icons\\Spell_Ice_Lament",
    ["Improved Multi-Shot"] = "Interface\\Icons\\Ability_UpgradeMoonGlaive",
    ["Improved Shield Slam"] = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    ["Improved Whirlwind"] = "Interface\\Icons\\Ability_Whirlwind",
    ["Insignia of the Horde"] = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02",
    ["Keen Eye"] = "Interface\\Icons\\INV_Misc_Spyglass_02",
    ["Kill Shot"] = "Interface\\Icons\\INV_Weapon_Rifle_08",
    ["Killing Spree"] = "Interface\\Icons\\Ability_Rogue_Sprint",
    ["Lifegiving Gem"] = "Interface\\Icons\\INV_Misc_Gem_Pearl_05",
    ["Light's Grace"] = "Interface\\Icons\\Spell_Holy_SearingLight",
    ["Long Leash"] = "Interface\\Icons\\Ability_Hunter_BeastCall",
    ["Major Soulstone"] = "Interface\\Icons\\INV_Misc_Orb_04",
    ["Mark of Fordring"] = "Interface\\Icons\\INV_Jewelry_Talisman_07",
    ["Master Dragonslayer's Ring"] = "Interface\\Icons\\INV_Jewelry_Ring_41",
    ["Medallion of the Bladestorm"] = "Interface\\Icons\\INV_Jewelry_Necklace_30Naxxramas",
    ["Mortal Wounds"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    ["Mutilate"] = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
    ["Onyxia Blood Talisman"] = "Interface\\Icons\\Spell_Shadow_LifeDrain",
    ["Opening Hand"] = "Interface\\Icons\\INV_Misc_Book_09",
    ["Pact of the Annihilan"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
    ["Pendant of the Plague"] = "Interface\\Icons\\INV_Jewelry_Necklace_18",
    ["Piercing Shots"] = "Interface\\Icons\\Ability_PierceDamage",
    ["Pristine Enchanted South Seas Kelp"] = "Interface\\Icons\\INV_Jewelry_Necklace_26",
    ["Protection"] = "Interface\\Icons\\Spell_Holy_DevotionAura",
    ["Purifying Power"] = "Interface\\Icons\\Spell_Holy_Purify",
    ["Quick Paws"] = "Interface\\Icons\\Ability_Hunter_Pet_Cat",
    ["Quick Strike Ring"] = "Interface\\Icons\\INV_Jewelry_Ring_07",
    ["Radiance"] = "Interface\\Icons\\Spell_Holy_HolyNova",
    ["Rapture"] = "Interface\\Icons\\Spell_Holy_PowerInfusion",
    ["Ring of Spell Power"] = "Interface\\Icons\\INV_Jewelry_Ring_38",
    ["Ring of the Devoured"] = "Interface\\Icons\\INV_Jewelry_Ring_AhnQiraj_05",
    ["Royal Seal of Eldre'Thalas"] = "Interface\\Icons\\INV_Jewelry_Talisman_10",
    ["Rune-hound"] = "Interface\\Icons\\INV_Misc_Rune_01",
    ["Sacred Duty"] = "Interface\\Icons\\Spell_Holy_DivineIntervention",
    ["Sanctified Light"] = "Interface\\Icons\\Spell_Holy_HealingFocus",
    ["Seal of the Damned"] = "Interface\\Icons\\INV_Jewelry_Ring_51Naxxramas",
    ["Second Thoughts"] = "Interface\\Icons\\Spell_Nature_TimeStop",
    ["Shadow Dance"] = "Interface\\Icons\\Spell_Shadow_LifeDrain",
    ["Shadow Embrace"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
    ["Shield Mastery"] = "Interface\\Icons\\Ability_Defend",
    ["Soul Devourer"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    ["Spiritual Attunement"] = "Interface\\Icons\\Spell_Holy_BlessedRecovery",
    ["Star of Mystaria"] = "Interface\\Icons\\INV_Enchant_EssenceMagicLarge",
    ["Stormcaller's Amulet"] = "Interface\\Icons\\INV_Jewelry_Necklace_16",
    ["Summon Infernal"] = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    ["Tabard of the Horde"] = "Interface\\Icons\\INV_Misc_TabardPVP_01",
    ["Talisman of the Tempest"] = "Interface\\Icons\\INV_Jewelry_Necklace_AhnQiraj_04",
    ["Talvash's Enhancing Necklace"] = "Interface\\Icons\\INV_Jewelry_Necklace_02",
    ["The Art of War"] = "Interface\\Icons\\Spell_Holy_Excorcism_02",
    ["The Eternal Talisman"] = "Interface\\Icons\\INV_Jewelry_Necklace_19",
    ["The Reaper's Amulet"] = "Interface\\Icons\\INV_Jewelry_Necklace_28Naxxramas",
    ["Tiny Gordok"] = "Interface\\Icons\\INV_Crown_01",
    ["Titan"] = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    ["Toxic Bloom"] = "Interface\\Icons\\Spell_Nature_NullifyPoison",
    ["Trauma"] = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    ["Tree of Life"] = "Interface\\Icons\\Spell_Nature_ResistNature",
    ["Veteran's Lessons"] = "Interface\\Icons\\INV_Misc_Book_11",
    ["Warsong Battle Tabard"] = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    ["Weighted Hammer"] = "Interface\\Icons\\Spell_Holy_SealOfMight",
    ["Wisp-herder"] = "Interface\\Icons\\Spell_Nature_WispSplode",
    ["Zul'Gurub Mask"] = "Interface\\Icons\\INV_Mask_02",
}
B.EXTRA_ABILITY_ICONS = EXTRA_ABILITY_ICONS

local LOCALIZED_SPELL_MAP = {
    -- Spanish (esES)
    ["rajar"] = "cleave",
    ["torbellino"] = "whirlwind",
    ["rafaga"] = "flurry",
    ["desenfreno"] = "rampage",
    ["ejecutar"] = "execute",
    ["heridas_profundas"] = "deep_wounds",
    ["golpe_mortal"] = "mortal_strike",
    ["atronar"] = "thunder_clap",
    ["grito_de_batalla"] = "battle_shout",
    ["grito_desmoralizador"] = "demoralizing_shout",
    ["sed_de_sangre"] = "bloodthirst",
    ["desgarrar"] = "rend",
    ["embate_con_escudo"] = "shield_slam",
    ["ira_sangrienta"] = "bloodrage",
    ["cargar"] = "charge",
    ["golpes_de_barrido"] = "sweeping_strikes",
    ["abrumar"] = "overpower",
    ["embate"] = "slam",
    ["seccionar"] = "hamstring",
    ["muro_de_escudo"] = "shield_wall",
    ["temeridad"] = "recklessness",
    ["ira_rabiosa"] = "berserker_rage",
    ["torbellino_de_acero"] = "bladestorm",
    ["filotormenta"] = "bladestorm",
    ["salto_heroico"] = "heroic_leap",
    ["provocar"] = "taunt",
    ["desarmar"] = "disarm",
    ["zurrar"] = "pummel",
    ["azote_de_escudo"] = "shield_bash",
    ["interceptar"] = "intercept",
    ["ola_de_choque"] = "shockwave",
    ["golpe_heroico"] = "heroic_strike",
    ["hender_armadura"] = "sunder_armor",
    ["golpe_de_conmocion"] = "concussion_blow",
    ["consagracion"] = "consecration",
    ["exorcismo"] = "exorcism",
    ["martillo_de_colera"] = "hammer_of_wrath",
    ["choque_sagrado"] = "holy_shock",
    ["colera_sagrada"] = "holy_wrath",
    ["sentencia"] = "judgement",
    ["martillo_de_justicia"] = "hammer_of_justice",
    ["luz_sagrada"] = "holy_light",
    ["escudo_divino"] = "divine_shield",
    ["escudo_sagrado"] = "holy_shield",
    ["disparo_automatico"] = "auto_shot",
    ["disparo_arcano"] = "arcane_shot",
    ["multidisparo"] = "multi_shot",
    ["picadura_de_serpiente"] = "serpent_sting",
    ["salva"] = "volley",
    ["trampa_explosiva"] = "explosive_trap",
    ["disparo_de_conmocion"] = "concussive_shot",
    ["disparo_de_punteria"] = "aimed_shot",
    ["golpe_siniestro"] = "sinister_strike",
    ["eviscerar"] = "eviscerate",
    ["aluvion_de_acero"] = "blade_flurry",
    ["ruptura"] = "rupture",
    ["golpe_en_los_rinones"] = "kidney_shot",
    ["gubia"] = "gouge",
    ["subidon_de_adrenalina"] = "adrenaline_rush",
    ["punalada"] = "backstab",
    ["hacer_picadillo"] = "slice_and_dice",
    ["bola_de_fuego"] = "fireball",
    ["descarga_de_escarcha"] = "frostbolt",
    ["misiles_arcanos"] = "arcane_missiles",
    ["nueva_de_escarcha"] = "frost_nova",
    ["deflagracion_arcana"] = "arcane_explosion",
    ["ventisca"] = "blizzard",
    ["fogonazo"] = "flamestrike",
    ["explosion_de_fuego"] = "fire_blast",
    ["piroexplosion"] = "pyroblast",
    ["barrera_de_hielo"] = "ice_barrier",
    ["polimorfia"] = "polymorph",
    ["castigo"] = "smite",
    ["palabra_de_sombras_dolor"] = "shadow_word_pain",
    ["explosion_mental"] = "mind_blast",
    ["nueva_sagrada"] = "holy_nova",
    ["palabra_de_poder_escudo"] = "power_word_shield",
    ["renovar"] = "renew",
    ["tortura_mental"] = "mind_flay",
    ["descarga_de_las_sombras"] = "shadow_bolt",
    ["corrupcion"] = "corruption",
    ["inmolar"] = "immolate",
    ["maldicion_de_agonia"] = "curse_of_agony",
    ["lluvia_de_fuego"] = "rain_of_fire",
    ["llamas_infernales"] = "hellfire",
    ["espiral_de_la_muerte"] = "death_coil",
    ["drenar_vida"] = "drain_life",
    ["colera"] = "wrath",
    ["fuego_lunar"] = "moonfire",
    ["fuego_estelar"] = "starfire",
    ["huracan"] = "hurricane",
    ["flagelo"] = "swipe",
    ["espinas"] = "thorns",
    ["rejuvenecimiento"] = "rejuvenation",
    ["recrecimiento"] = "regrowth",

    -- German (deDE)
    ["spalten"] = "cleave",
    ["wirbelwind"] = "whirlwind",
    ["donnerknall"] = "thunder_clap",
    ["toedlicher_stoss"] = "mortal_strike",
    ["hinrichten"] = "execute",
    ["demoralisierender_ruf"] = "demoralizing_shout",
    ["schlachtruf"] = "battle_shout",
    ["blutdurst"] = "bloodthirst",
    ["verwunden"] = "rend",
    ["schildschlag"] = "shield_slam",
    ["blutrausch"] = "bloodrage",
    ["sturmangriff"] = "charge",
    ["toben"] = "rampage",
    ["schlaghagel"] = "flurry",
    ["weitreichende_stoesse"] = "sweeping_strikes",
    ["ueberwaeltigen"] = "overpower",
    ["zerschmettern"] = "slam",
    ["kniesehne"] = "hamstring",
    ["schildwall"] = "shield_wall",
    ["tollkuehnheit"] = "recklessness",
    ["tiefe_wunden"] = "deep_wounds",
    ["klingensturm"] = "bladestorm",
    ["heldenhafter_stoss"] = "heroic_strike",
    ["ruestung_zerreissen"] = "sunder_armor",
    ["erschuetternder_schlag"] = "concussion_blow",
    ["weihe"] = "consecration",
    ["automatischer_schuss"] = "auto_shot",
    ["finsterer_stoss"] = "sinister_strike",
    ["ausweiden"] = "eviscerate",
    ["feuerball"] = "fireball",
    ["frostblitz"] = "frostbolt",
    ["schattenblitz"] = "shadow_bolt",
    ["verderbnis"] = "corruption",
    ["zorn"] = "wrath",
    ["mondfeuer"] = "moonfire",
}
B.LOCALIZED_SPELL_MAP = LOCALIZED_SPELL_MAP

local scannedSpellbook = {}
local scannedTalents = {}
local lastSpellScan = 0

local function ScanClientSpells()
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if now - lastSpellScan < 2 and lastSpellScan > 0 then return end
    lastSpellScan = now

    if type(GetSpellName) == "function" and type(GetSpellTexture) == "function" then
        local book = BOOKTYPE_SPELL or "spell"
        local i = 1
        while true do
            local name = GetSpellName(i, book)
            if not name then break end
            local tex = GetSpellTexture(i, book)
            if tex and tex ~= "" then
                scannedSpellbook[name] = tex
                local norm = CoreNormalize(name)
                if norm ~= "" then scannedSpellbook[norm] = tex end
            end
            i = i + 1
        end
    end

    if type(GetNumTalentTabs) == "function" and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
        local numTabs = GetNumTalentTabs() or 0
        for tab = 1, numTabs do
            local numTalents = GetNumTalents(tab) or 0
            for t = 1, numTalents do
                local tName, tTex = GetTalentInfo(tab, t)
                if tName and tTex and tTex ~= "" then
                    scannedTalents[tName] = tTex
                    local norm = CoreNormalize(tName)
                    if norm ~= "" then scannedTalents[norm] = tTex end
                end
            end
        end
    end
end

local PROC_CAST = {
    ["Pyroclasm"] = { "Blast Wave" },
    ["Hot Streak"] = { "Pyroblast" },
    ["Arcane Concentration"] = { "Arcane Explosion" },
    ["Shadowy Apparitions"] = { "Mind Blast" },
    ["Maelstrom Weapon"] = { "Chain Lightning" },
    ["Lightning Overload"] = { "Lightning Bolt", "Chain Lightning" },
    ["Windfury"] = { "Lightning Bolt", "Earth Shock", "Frost Shock" },
    ["Elemental Mastery"] = { "Chain Lightning" },
    ["Rampage"] = { "Whirlwind" },
    ["Flurry"] = { "Whirlwind", "Bloodthirst" },
    ["Bladestorm"] = { "Whirlwind" },
    ["Last Stand"] = { "Shield Slam" },
    ["Shockwave"] = { "Shield Slam" },
    ["Daybreak"] = { "Holy Wrath" },
    ["Hallowed Ground"] = { "Consecration" },
    ["Divine Intervention"] = { "Consecration" },
    ["The Art of War"] = { "Exorcism" },
    ["Frenzy"] = { "Multi-Shot" },
    ["Rapid Fire"] = { "Aimed Shot" },
    ["Counterattack"] = { "Explosive Trap" },
    ["Explosive Ammunition"] = { "Auto Shot", "Multi-Shot" },
    ["Mutilate"] = { "Sinister Strike", "Backstab" },
    ["Riposte"] = { "Ghostly Strike" },
    ["Killing Spree"] = { "Sinister Strike" },
    ["Blade Flurry"] = { "Sinister Strike", "Eviscerate" },
    ["Preparation"] = { "Gouge" },
    ["Shadow Dance"] = { "Backstab", "Eviscerate" },
    ["Chastise"] = { "Holy Nova" },
    ["Nightfall"] = { "Shadow Bolt" },
    ["Shadow Cleave"] = { "Shadow Bolt" },
    ["Conflagrate"] = { "Shadow Bolt", "Searing Pain" },
    ["Splitting Ice"] = { "Frostbolt" },
    ["Omen of Clarity"] = { "Starfire" },
    ["Starfall"] = { "Starfire" },
    ["Leader of the Pack"] = { "Swipe" },
    ["Nature's Grasp"] = { "Entangling Roots" },
    ["Sweeping Strikes"] = { "Cleave", "Mortal Strike", "Execute" },
}

local carriedItemIcons = {}
local lastCarriedScan = 0

local function ScanCarriedItems()
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if now - lastCarriedScan < 1 and lastCarriedScan > 0 then return end
    lastCarriedScan = now

    if type(GetInventoryItemLink) == "function" and type(GetInventoryItemTexture) == "function" then
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            local tex = GetInventoryItemTexture("player", slot)
            if link and tex and tex ~= "" then
                local _, _, name = string.find(link, "%[(.+)%]")
                if name then
                    carriedItemIcons[name] = tex
                    local norm = CoreNormalize(name)
                    if norm ~= "" then carriedItemIcons[norm] = tex end
                end
            end
        end
    end
    if type(GetContainerNumSlots) == "function" and type(GetContainerItemLink) == "function" and type(GetContainerItemInfo) == "function" then
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                local tex = GetContainerItemInfo(bag, slot)
                if link and tex and tex ~= "" then
                    local _, _, name = string.find(link, "%[(.+)%]")
                    if name then
                        carriedItemIcons[name] = tex
                        local norm = CoreNormalize(name)
                        if norm ~= "" then carriedItemIcons[norm] = tex end
                    end
                end
            end
        end
    end
end

-- Spell name -> "Interface\\Icons\\<file>" from SpellIcons.lua (generated from
-- the client's Spell.dbc). Exact name first, then a case-insensitive match;
-- the lower-case index is built once, on the first miss.
function B:SpellIconPath(name)
    if type(name) ~= "string" or type(self.SPELL_ICON_INDEX) ~= "table" then return nil end
    local idx = self.SPELL_ICON_INDEX[name]
    if not idx then
        if not self.spellIconLower then
            local map = {}
            for k, v in pairs(self.SPELL_ICON_INDEX) do
                map[string.lower(k)] = v
            end
            self.spellIconLower = map
        end
        idx = self.spellIconLower[string.lower(name)]
    end
    local file = idx and self.SPELL_ICON_FILES[idx]
    if file then
        return "Interface\\Icons\\" .. file
    end
    return nil
end

function B:GetAbilityIcon(nameOrId)
    if not nameOrId or nameOrId == "" then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local norm = CoreNormalize(nameOrId)

    -- Dynamic weapon icon for Melee / Weapon swings
    if norm == "melee" or norm == "attack" or norm == "auto_attack" or norm == "autoattack" or norm == "swing" or norm == "physical" or norm == "hero_melee" or norm == "cuerpo_a_cuerpo" or norm == "nahkampf" then
        if type(GetInventoryItemTexture) == "function" then
            local wTex = GetInventoryItemTexture("player", 16)
            if wTex and wTex ~= "" then return wTex end
        end
        return "Interface\\Icons\\INV_Sword_04"
    end

    -- Dynamic weapon icon for Ranged / Auto Shot
    if norm == "shoot" or norm == "auto_shot" or norm == "autoshot" or norm == "ranged" or norm == "bow" or norm == "disparo_automatico" or norm == "automatischer_schuss" then
        if type(GetInventoryItemTexture) == "function" then
            local rTex = GetInventoryItemTexture("player", 18)
            if rTex and rTex ~= "" then return rTex end
        end
        return "Interface\\Icons\\INV_Weapon_Bow_07"
    end

    -- Dynamic weapon icon for Wand
    if norm == "wand" or norm == "shoot_wand" then
        if type(GetInventoryItemTexture) == "function" then
            local wandTex = GetInventoryItemTexture("player", 18)
            if wandTex and wandTex ~= "" then return wandTex end
        end
        return "Interface\\Icons\\INV_Wand_01"
    end

    -- 1. Direct dictionary match
    if MASTER_ABILITY_ICONS[nameOrId] then return MASTER_ABILITY_ICONS[nameOrId] end
    if MASTER_ABILITY_ICONS[norm] then return MASTER_ABILITY_ICONS[norm] end

    -- 1b. Extra AZS Cards, Pets, Procs & Summons dictionary
    if EXTRA_ABILITY_ICONS[nameOrId] then return EXTRA_ABILITY_ICONS[nameOrId] end
    if EXTRA_ABILITY_ICONS[norm] then return EXTRA_ABILITY_ICONS[norm] end

    -- 1c. Carried / Equipped Items Scan
    ScanCarriedItems()
    if carriedItemIcons[nameOrId] then return carriedItemIcons[nameOrId] end
    if carriedItemIcons[norm] then return carriedItemIcons[norm] end

    -- 1d. Live Item Database Query (resolves any item by name or link in WoW database)
    if type(GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, _, i9, i10 = GetItemInfo(nameOrId)
        local itemTex = i10 or i9
        if itemTex and itemTex ~= "" then
            return itemTex
        end
        if norm ~= nameOrId then
            local _, _, _, _, _, _, _, _, n9, n10 = GetItemInfo(norm)
            local nTex = n10 or n9
            if nTex and nTex ~= "" then
                return nTex
            end
        end
    end

    -- 1e. Spell icon table generated from the client's Spell.dbc (SpellIcons.lua).
    --     Names the game shows in another language go through their English name.
    local dbIcon = self:SpellIconPath(nameOrId) or self:SpellIconPath(norm)
    if not dbIcon and type(self.EnglishAbilityName) == "function" then
        local english = self:EnglishAbilityName(nameOrId)
        if english then dbIcon = self:SpellIconPath(english) end
    end
    if dbIcon then
        return dbIcon
    end

    -- 1f. Compound spell names (e.g. "Pendant of the Plague: Moonfire")
    local _, _, left, right = string.find(nameOrId, "^(.-): (.+)$")
    if left and right and left ~= "" and right ~= "" then
        local spellTex = self:GetAbilityIcon(right)
        if spellTex and not string.find(spellTex, "QuestionMark", 1, true) then
            return spellTex
        end
        local itemTex = self:GetAbilityIcon(left)
        if itemTex and not string.find(itemTex, "QuestionMark", 1, true) then
            return itemTex
        end
    end

    -- 1g. Proc to Cast ability lookup (e.g. Hot Streak -> Pyroblast)
    local pTargets = PROC_CAST[nameOrId] or PROC_CAST[norm]
    if pTargets then
        local nTargets = table.getn(pTargets)
        for tIdx = 1, nTargets do
            local cand = pTargets[tIdx]
            if cand and cand ~= nameOrId then
                local candTex = self:GetAbilityIcon(cand)
                if candTex and not string.find(candTex, "QuestionMark", 1, true) then
                    return candTex
                end
            end
        end
    end

    -- 2. Localized spell translation (Spanish / German)
    local canon = LOCALIZED_SPELL_MAP[norm] or LOCALIZED_SPELL_MAP[nameOrId]
    if canon and MASTER_ABILITY_ICONS[canon] then
        return MASTER_ABILITY_ICONS[canon]
    end

    -- 3. Live Client Spellbook & Talents scan
    ScanClientSpells()
    if scannedSpellbook[nameOrId] then return scannedSpellbook[nameOrId] end
    if scannedSpellbook[norm] then return scannedSpellbook[norm] end
    if scannedTalents[nameOrId] then return scannedTalents[nameOrId] end
    if scannedTalents[norm] then return scannedTalents[norm] end

    -- 4. Prefix match in master dictionary (safe string.sub without pattern metacharacter hazards)
    if string.len(norm) >= 4 then
        local lenNorm = string.len(norm)
        for k, v in pairs(MASTER_ABILITY_ICONS) do
            local lenK = string.len(k)
            if (lenK >= lenNorm and string.sub(k, 1, lenNorm) == norm) or (lenNorm >= lenK and string.sub(norm, 1, lenK) == k) then
                return v
            end
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-------------------------------------------------------------------------------
--  Colours
-------------------------------------------------------------------------------
local CLASS_ID_MAP = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [11] = "DRUID",
}

function B:ResolveClassColor(token)
    if not token then return nil end
    if type(token) == "number" then
        token = CLASS_ID_MAP[token]
        if not token then return nil end
    end
    if type(token) ~= "string" then return nil end
    local clean = string.gsub(token, "%s", "")
    local num = tonumber(clean)
    if num and CLASS_ID_MAP[num] then
        clean = CLASS_ID_MAP[num]
    end
    return self.CLASS_COLORS[clean]
        or self.CLASS_COLORS[string.upper(clean)]
        or self.CLASS_COLORS[string.lower(clean)]
end

function B:GetClassColor()
    local c
    if AZS_ZONE then
        if type(AZS_ZONE.cname) == "string" and AZS_ZONE.cname ~= "" then
            c = self:ResolveClassColor(AZS_ZONE.cname)
        end
        if not c and AZS_ZONE.class then
            c = self:ResolveClassColor(AZS_ZONE.class)
        end
    end
    if not c then
        local loc, eng = UnitClass("player")
        c = self:ResolveClassColor(eng) or self:ResolveClassColor(loc)
    end
    if c then return c.r, c.g, c.b end
    return 0/255, 229/255, 255/255
end

function B:GetAccent()
    local tName = (self.db and self.db.theme) or "Blackwell"
    local t = self.THEMES[tName] or self.THEMES["Blackwell"]
    if t.class then
        return self:GetClassColor()
    elseif t.custom then
        local ca = (self.db and self.db.customAccent) or { r = 0, g = 229/255, b = 1 }
        return ca.r, ca.g, ca.b
    end
    return t.r, t.g, t.b
end

function B:GetBarTexture()
    return self.BAR_TEXTURES[(self.db and self.db.barTexture) or "Melli"] or self.WHITE
end

function B:GetFontPath()
    local name = (self.db and self.db.font) or "Barlow"
    local path = self.FONTS[name] or self.FALLBACK_FONT
    if type(self.FontForLanguage) == "function" then
        path = self:FontForLanguage(path, name)
    end
    return path
end
B.GetFont = B.GetFontPath

-- Bold variant for emphasis text (combat text, alerts), with the same
-- per-language glyph fallback as GetFontPath.
function B:GetBoldFontPath()
    local path = self.FONTS["Barlow Bold"] or self:GetFontPath()
    if type(self.FontForLanguage) == "function" then
        path = self:FontForLanguage(path, "Barlow Bold")
    end
    return path
end

-------------------------------------------------------------------------------
--  Widget factory (1.12 API only)
-------------------------------------------------------------------------------
function B:Solid(tex, r, g, b, a)
    tex:SetTexture(self.WHITE)
    tex:SetVertexColor(r, g, b)
    tex:SetAlpha(a or 1)
end

-- 1px edge just outside the frame, so the frame's own size stays exact.
function B:Border(f, r, g, b, a)
    local edges = f.buiEdges
    if edges then
        self:SetBorderColor(f, r, g, b, a)
        return
    end
    edges = {}
    local cr, cg, cb, ca = r or 0, g or 0, b or 0, a or 1
    local top = f:CreateTexture(nil, "BORDER")
    top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -1, 0)
    top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 1, 0)
    top:SetHeight(1)
    local bot = f:CreateTexture(nil, "BORDER")
    bot:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -1, 0)
    bot:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 1, 0)
    bot:SetHeight(1)
    local left = f:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    local right = f:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    edges[1] = top
    edges[2] = bot
    edges[3] = left
    edges[4] = right
    f.buiEdges = edges
    self:SetBorderColor(f, cr, cg, cb, ca)
end

function B:SetBorderColor(f, r, g, b, a)
    local edges = f.buiEdges
    if not edges then return end
    for i = 1, 4 do
        self:Solid(edges[i], r, g, b, a or 1)
    end
end

-- Style switch: "round" (default) or "sharp". Read when frames are built.
function B:IsRound()
    return not (self.db and self.db.uiStyle == "sharp")
end

-- Panel colour: the player's choice, else the style's own colour.
function B:GetPanelColor()
    local c = self.db and self.db.panelColor
    if type(c) == "table" and c.r then
        return c.r, c.g, c.b
    end
    if self:IsRound() then
        return self.PANEL_COLOR.r, self.PANEL_COLOR.g, self.PANEL_COLOR.b
    end
    return 0.055, 0.050, 0.045
end

-- Panel background in the active style. Every frame background goes through
-- here (B:Backdrop as well), so the style switch reaches the whole UI.
function B:Panel(f, radius)
    if self:IsRound() then
        return self:RoundPanel(f, radius)
    end
    return self:SharpBackdrop(f)
end

function B:Backdrop(f, alpha)
    if self:IsRound() then
        return self:RoundPanel(f)
    end
    return self:SharpBackdrop(f, alpha)
end

function B:SharpBackdrop(f, alpha)
    local bg = f.buiBg
    local a = (self.db and self.db.backdropAlpha) or alpha or 0.85
    local pr, pg, pb = self:GetPanelColor()
    if bg then
        self:Solid(bg, pr, pg, pb, a)
        self:Border(f, 0, 0, 0, 1)
        return bg
    end
    bg = f:CreateTexture(nil, "BACKGROUND")
    self:Solid(bg, pr, pg, pb, a)
    bg:SetAllPoints(f)
    f.buiBg = bg
    self:Border(f, 0, 0, 0, 1)
    table.insert(self.backdrops, { frame = f, bg = bg, baseAlpha = alpha or 0.85 })
    return bg
end

function B:ApplyFont(fs)
    local baseSize = fs.buiSize or 11
    local fontMod = (self.db and self.db.fontScaleMod) or 0
    local size = baseSize + fontMod
    if size < 7 then size = 7 end
    if size > 24 then size = 24 end
    -- Text made with the default "OUTLINE" follows the global outline setting.
    local flags = fs.buiFlags or "OUTLINE"
    if flags == "OUTLINE" and self.db and self.db.fontOutline then
        flags = self.db.fontOutline
        if flags == "NONE" then flags = "" end
    end
    fs:SetFont(self:GetFontPath(), size, flags)
    if not fs:GetFont() then
        fs:SetFont(self.FALLBACK_FONT, size, flags)
    end
    -- Without an outline a soft shadow keeps text readable over the world.
    if flags == "" and type(fs.SetShadowOffset) == "function" then
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    end
end

function B:Font(parent, size, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
    fs.buiSize = size or 11
    fs.buiFlags = "OUTLINE"
    self:ApplyFont(fs)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(1, 1, 1)
    table.insert(self.fontStrings, fs)
    return fs
end

function B:SetBarColor(sb, r, g, b)
    sb.buiR, sb.buiG, sb.buiB = r, g, b
    sb:SetStatusBarColor(r, g, b)
end

-- Laid-out size of a frame. For frames anchored by two points this engine's
-- GetWidth / GetHeight can report a stale value (measured: 220 for a bar
-- that spans 244 px), so the size comes from the edges once they are known.
function B:FrameSize(f)
    local w, h
    local l, r = f:GetLeft(), f:GetRight()
    if l and r then w = r - l else w = f:GetWidth() end
    local t, b = f:GetTop(), f:GetBottom()
    if t and b then h = t - b else h = f:GetHeight() end
    return w, h
end

-- Round style for a StatusBar: the engine's square fill is kept but drawn
-- fully transparent; a track and a fill drawn as rounded rectangles (made of
-- textures on the bar itself, so text on the bar stays on top) follow its
-- value, range and colour. The corner radius is half the bar height (round
-- caps) unless B:SetBarRadius gave the bar a smaller one, e.g. a health bar
-- that fills a whole unit frame. Sizes are read on every change.
function B:RoundifyStatusBar(sb)
    if sb.buiRoundFill then return end
    local roundTex = self.ROUND
    local white = self.WHITE
    -- Rounded rectangle: four disc quarters, two side strips and a middle.
    local function Shape(layer)
        local s = {}
        local function Part(tex, l, r, t, b)
            local p = sb:CreateTexture(nil, layer)
            p:SetTexture(tex)
            if l then p:SetTexCoord(l, r, t, b) end
            return p
        end
        s.tl = Part(roundTex, 0, 0.5, 0, 0.5)
        s.bl = Part(roundTex, 0, 0.5, 0.5, 1)
        s.tr = Part(roundTex, 0.5, 1, 0, 0.5)
        s.br = Part(roundTex, 0.5, 1, 0.5, 1)
        s.ls = Part(white)
        s.rs = Part(white)
        s.mid = Part(white)
        s.parts = { s.tl, s.bl, s.tr, s.br, s.ls, s.rs, s.mid }
        function s:SetColor(r, g, b, a)
            for i = 1, 7 do
                self.parts[i]:SetVertexColor(r, g, b)
                self.parts[i]:SetAlpha(a or 1)
            end
        end
        local function Put(p, x, y, w, h)
            if w < 0.5 or h < 0.5 then
                p:Hide()
                return
            end
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", sb, "TOPLEFT", x, -y)
            p:SetWidth(w)
            p:SetHeight(h)
            p:Show()
        end
        function s:Place(w, h, radius)
            local r = radius
            if r > h / 2 then r = h / 2 end
            if r > w / 2 then r = w / 2 end
            if r < 0 then r = 0 end
            local side = h - 2 * r
            Put(self.tl, 0, 0, r, r)
            Put(self.bl, 0, h - r, r, r)
            Put(self.ls, 0, r, r, side)
            Put(self.mid, r, 0, w - 2 * r, h)
            Put(self.tr, w - r, 0, r, r)
            Put(self.br, w - r, h - r, r, r)
            Put(self.rs, w - r, r, r, side)
        end
        function s:Hide()
            for i = 1, 7 do self.parts[i]:Hide() end
        end
        return s
    end

    if sb.buiBg then sb.buiBg:Hide() end
    local track = Shape("BACKGROUND")
    track:SetColor(1, 1, 1, 0.07)
    local fill = Shape("ARTWORK")
    fill:Hide()
    sb.buiRoundTrack = track
    sb.buiRoundFill = fill

    function sb:BuiLayoutRound()
        local w, h = B:FrameSize(self)
        if not w or not h or w <= 0 or h <= 0 then return end
        local r = self.buiRadius or (h / 2)
        self.buiRoundTrack:Place(w, h, r)
        local lo, hi = self:GetMinMaxValues()
        local v = self:GetValue() or 0
        local frac = 0
        if hi and lo and hi > lo then frac = (v - lo) / (hi - lo) end
        if frac <= 0 then
            self.buiRoundFill:Hide()
            return
        end
        if frac > 1 then frac = 1 end
        local fw = frac * w
        local minW = 2 * r
        if minW > h then minW = h end
        if fw < minW then fw = minW end
        self.buiRoundFill:Place(fw, h, r)
    end

    local origSetValue = sb.SetValue
    sb.SetValue = function(bar, v)
        origSetValue(bar, v)
        bar:BuiLayoutRound()
    end
    local origSetMinMax = sb.SetMinMaxValues
    sb.SetMinMaxValues = function(bar, lo, hi)
        origSetMinMax(bar, lo, hi)
        bar:BuiLayoutRound()
    end
    -- Colour goes to the round fill; the engine fill stays invisible.
    local origSetColor = sb.SetStatusBarColor
    sb.SetStatusBarColor = function(bar, r, g, b, a)
        origSetColor(bar, r, g, b, 0)
        bar.buiRoundFill:SetColor(r, g, b, a or 1)
        bar:BuiLayoutRound()
    end
    local origSetTexture = sb.SetStatusBarTexture
    sb.SetStatusBarTexture = function(bar, tex)
        origSetTexture(bar, tex)
        bar.buiRoundFill.mid:SetTexture(tex)
        origSetColor(bar, bar.buiR or 1, bar.buiG or 1, bar.buiB or 1, 0)
    end
    sb.buiRoundFill.mid:SetTexture(self:GetBarTexture())
    sb:BuiLayoutRound()
end

-- Corner radius for a round StatusBar (nil = half its height, round caps).
function B:SetBarRadius(sb, radius)
    sb.buiRadius = radius
    if sb.BuiLayoutRound then sb:BuiLayoutRound() end
end

-- Track colour of a round StatusBar (the part behind the fill).
function B:SetBarTrackColor(sb, r, g, b, a)
    if sb.buiRoundTrack then sb.buiRoundTrack:SetColor(r, g, b, a) end
end

-- Accent bars follow the theme on refresh.
function B:Bar(parent, name, r, g, b)
    local sb = CreateFrame("StatusBar", name, parent)
    sb:SetStatusBarTexture(self:GetBarTexture())
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(1)
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(sb)
    sb.buiBg = bg
    if self:IsRound() then
        self:RoundifyStatusBar(sb)
    else
        self:Solid(bg, 0, 0, 0, 0.55)
        self:Border(sb, 0, 0, 0, 1)
    end
    if r then
        self:SetBarColor(sb, r, g, b)
    else
        sb.buiAccent = true
        local ar, ag, ab = self:GetAccent()
        self:SetBarColor(sb, ar, ag, ab)
    end
    table.insert(self.bars, sb)
    return sb
end

-------------------------------------------------------------------------------
--  Round widgets (media\textures\round.tga, generated by tools/gen_textures.py)
--  The 1.12 renderer has no corner radius: corners are quarters of a white
--  disc, bar caps are its halves, dots use it whole.
-------------------------------------------------------------------------------
B.ROUND = "Interface\\AddOns\\BlackwellUI\\media\\textures\\round.tga"
B.PANEL_COLOR = { r = 0.063, g = 0.071, b = 0.086 }

-- Dot positions on a unit circle, clockwise from the top (gen_textures.py).
local RING_24 = {
    { 0.0000, 1.0000 }, { 0.2588, 0.9659 }, { 0.5000, 0.8660 }, { 0.7071, 0.7071 },
    { 0.8660, 0.5000 }, { 0.9659, 0.2588 }, { 1.0000, 0.0000 }, { 0.9659, -0.2588 },
    { 0.8660, -0.5000 }, { 0.7071, -0.7071 }, { 0.5000, -0.8660 }, { 0.2588, -0.9659 },
    { 0.0000, -1.0000 }, { -0.2588, -0.9659 }, { -0.5000, -0.8660 }, { -0.7071, -0.7071 },
    { -0.8660, -0.5000 }, { -0.9659, -0.2588 }, { -1.0000, 0.0000 }, { -0.9659, 0.2588 },
    { -0.8660, 0.5000 }, { -0.7071, 0.7071 }, { -0.5000, 0.8660 }, { -0.2588, 0.9659 },
}

-- Rounded panel background: four disc quarters, two edge strips and a
-- centre, laid out without overlap so the alpha stays even. Radius and
-- colour come from the Appearance settings; it follows "Background opacity"
-- unless fixedAlpha is given (tooltips keep their own opacity).
function B:RoundPanel(f, radius, fixedAlpha)
    local panel = f.buiRound
    if not panel then
        local rad = radius or (self.db and self.db.cornerRadius) or 10
        panel = { parts = {} }
        local function Part(round, l, rr, t, bb)
            local tex = f:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(round and self.ROUND or self.WHITE)
            if round then tex:SetTexCoord(l, rr, t, bb) end
            table.insert(panel.parts, tex)
            return tex
        end
        local tl = Part(true, 0, 0.5, 0, 0.5)
        tl:SetWidth(rad); tl:SetHeight(rad)
        tl:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        local tr = Part(true, 0.5, 1, 0, 0.5)
        tr:SetWidth(rad); tr:SetHeight(rad)
        tr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        local bl = Part(true, 0, 0.5, 0.5, 1)
        bl:SetWidth(rad); bl:SetHeight(rad)
        bl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        local br = Part(true, 0.5, 1, 0.5, 1)
        br:SetWidth(rad); br:SetHeight(rad)
        br:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        local top = Part(false)
        top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
        top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
        local bottom = Part(false)
        bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
        local centre = Part(false)
        centre:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -rad)
        centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, rad)
        function panel:SetAlpha(a)
            for i = 1, table.getn(self.parts) do self.parts[i]:SetAlpha(a) end
        end
        function panel:SetColor(cr, cg, cb)
            for i = 1, table.getn(self.parts) do self.parts[i]:SetVertexColor(cr, cg, cb) end
        end
        function panel:Show()
            for i = 1, table.getn(self.parts) do self.parts[i]:Show() end
        end
        function panel:Hide()
            for i = 1, table.getn(self.parts) do self.parts[i]:Hide() end
        end
        f.buiRound = panel
        panel.fixedAlpha = fixedAlpha
        table.insert(self.backdrops, { frame = f, bg = panel, baseAlpha = 0.85 })
    end
    panel:SetColor(self:GetPanelColor())
    panel:SetAlpha(panel.fixedAlpha or (self.db and self.db.backdropAlpha) or 0.85)
    return panel
end

-- Texture for round shapes in the active style (square in the sharp style).
function B:ShapeTexture()
    if self:IsRound() then return self.ROUND end
    return self.WHITE
end

-- Thin bar with round caps: a full-width track and a fill drawn on top.
-- bar:SetFill(0..1), bar:SetFillColor(r, g, b), bar:SetTrackColor(r, g, b, a).
-- Anchor it with two points (or SetWidth) so it knows its width; the layout
-- is redone on every SetFill, so callers set the fill each update.
function B:RoundBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(height)
    bar.buiHeight = height
    bar.buiFill = 0
    local shape = self:ShapeTexture()
    local function Strip(layer)
        local s = {}
        s.left = bar:CreateTexture(nil, layer)
        s.left:SetTexture(shape)
        s.left:SetTexCoord(0, 0.5, 0, 1)
        s.left:SetWidth(height / 2)
        s.left:SetHeight(height)
        s.left:SetPoint("LEFT", bar, "LEFT", 0, 0)
        s.mid = bar:CreateTexture(nil, layer)
        s.mid:SetTexture(self.WHITE)
        s.mid:SetHeight(height)
        s.mid:SetPoint("LEFT", s.left, "RIGHT", 0, 0)
        s.right = bar:CreateTexture(nil, layer)
        s.right:SetTexture(shape)
        s.right:SetTexCoord(0.5, 1, 0, 1)
        s.right:SetWidth(height / 2)
        s.right:SetHeight(height)
        s.right:SetPoint("LEFT", s.mid, "RIGHT", 0, 0)
        function s:SetColor(r, g, b, a)
            local parts = { self.left, self.mid, self.right }
            for i = 1, 3 do
                parts[i]:SetVertexColor(r, g, b)
                parts[i]:SetAlpha(a or 1)
            end
        end
        -- Total width w >= height; the middle shrinks to nothing at w == height.
        function s:Size(w)
            local mid = w - bar.buiHeight
            if mid < 0.5 then
                self.mid:Hide()
                self.right:ClearAllPoints()
                self.right:SetPoint("LEFT", self.left, "RIGHT", 0, 0)
            else
                self.mid:SetWidth(mid)
                self.mid:Show()
                self.right:ClearAllPoints()
                self.right:SetPoint("LEFT", self.mid, "RIGHT", 0, 0)
            end
        end
        function s:Show() self.left:Show(); self.right:Show() end
        function s:Hide() self.left:Hide(); self.mid:Hide(); self.right:Hide() end
        return s
    end
    bar.track = Strip("BORDER")
    bar.fill = Strip("ARTWORK")
    bar.track:SetColor(1, 1, 1, 0.10)
    bar.fill:SetColor(1, 1, 1, 1)
    bar.fill:Hide()

    function bar:Layout()
        local v = self.buiFill or 0
        -- An empty fill stays hidden even before the width is known.
        if v <= 0 then self.fill:Hide() end
        local w = B:FrameSize(self)
        if not w or w < self.buiHeight then return end
        self.track:Size(w)
        if v <= 0 then
            return
        end
        if v > 1 then v = 1 end
        local fw = v * w
        if fw < self.buiHeight then fw = self.buiHeight end
        self.fill:Show()
        self.fill:Size(fw)
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
    -- Changes the thickness after creation (options); caps follow.
    function bar:SetBarHeight(h)
        if not h or h <= 0 or h == self.buiHeight then return end
        self.buiHeight = h
        self:SetHeight(h)
        local strips = { self.track, self.fill }
        for i = 1, 2 do
            local s = strips[i]
            s.left:SetWidth(h / 2)
            s.left:SetHeight(h)
            s.mid:SetHeight(h)
            s.right:SetWidth(h / 2)
            s.right:SetHeight(h)
        end
        self:Layout()
    end
    return bar
end

-- Ring of 24 dots: ring:SetProgress(0..1, r, g, b) lights the first dots
-- clockwise from the top in that colour, the rest stay dim.
function B:DotRing(parent, size, dotSize)
    local ring = CreateFrame("Frame", nil, parent)
    ring:SetWidth(size)
    ring:SetHeight(size)
    ring.dots = {}
    local rad = (size - dotSize) / 2
    for i = 1, 24 do
        local p = RING_24[i]
        local d = ring:CreateTexture(nil, "ARTWORK")
        d:SetTexture(self:ShapeTexture())
        d:SetWidth(dotSize)
        d:SetHeight(dotSize)
        d:SetPoint("CENTER", ring, "CENTER", p[1] * rad, p[2] * rad)
        ring.dots[i] = d
    end
    function ring:SetProgress(p, r, g, b)
        local v = tonumber(p) or 0
        if v < 0 then v = 0 end
        if v > 1 then v = 1 end
        local lit = math.floor(v * 24 + 0.5)
        for i = 1, 24 do
            local d = self.dots[i]
            if i <= lit then
                d:SetVertexColor(r or 1, g or 1, b or 1)
                d:SetAlpha(1)
            else
                d:SetVertexColor(0.55, 0.57, 0.62)
                d:SetAlpha(0.28)
            end
        end
    end
    ring:SetProgress(0)
    return ring
end

-- Small round button with a centred label (meter header controls).
function B:RoundButton(parent, size, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(size)
    btn:SetHeight(size)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(self:ShapeTexture())
    bg:SetAllPoints(btn)
    btn.bg = bg
    local fs = self:Font(btn, 9, "CENTER")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetText(label or "")
    btn.fs = fs
    function btn:SetState(r, g, b, active)
        self.bg:SetVertexColor(r, g, b)
        self.bg:SetAlpha(active and 0.30 or 0.12)
        self.fs:SetTextColor(r, g, b)
    end
    btn:SetState(0.75, 0.75, 0.75, false)
    btn:EnableMouse(true)
    return btn
end

-- kind: "tex" (vertex colour) or "text" (text colour); refreshed with the theme.
function B:Accent(obj, kind, alpha)
    table.insert(self.accents, { obj = obj, kind = kind, alpha = alpha or 1 })
    self:PaintAccent(self.accents[table.getn(self.accents)])
end

function B:PaintAccent(entry)
    local r, g, b = self:GetAccent()
    if entry.kind == "text" then
        entry.obj:SetTextColor(r, g, b)
    else
        entry.obj:SetVertexColor(r, g, b)
        entry.obj:SetAlpha(entry.alpha)
    end
end

-- Panel header: dark strip, accent rule, title left, value right.
function B:Header(parent, title, height)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(height or 18)
    local inset = 6
    if self:IsRound() then
        -- Round style: no strip, the title sits inside the panel's padding.
        inset = 10
        h:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
        h:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -4)
    else
        h:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        h:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        local bg = h:CreateTexture(nil, "BACKGROUND")
        self:Solid(bg, 0.025, 0.022, 0.020, 0.95)
        bg:SetAllPoints(h)
        local rule = h:CreateTexture(nil, "ARTWORK")
        rule:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
        rule:SetHeight(1)
        rule:SetTexture(self.WHITE)
        self:Accent(rule, "tex", 0.8)
    end
    h.title = self:Font(h, 10, "LEFT")
    h.title:SetPoint("LEFT", h, "LEFT", inset, 0)
    h.title:SetText(title or "")
    h.title:SetTextColor(0.92, 0.92, 0.92)
    h.value = self:Font(h, 10, "RIGHT")
    h.value:SetPoint("RIGHT", h, "RIGHT", -inset, 0)
    self:Accent(h.value, "text")
    return h
end

-------------------------------------------------------------------------------
--  Movers (/bui unlock)
-------------------------------------------------------------------------------
function B:ApplyPosition(frame)
    local key = frame.buiKey
    local pos = self.db and self.db.positions[key]
    local d = frame.buiDefault
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint(d.point, UIParent, d.relPoint, d.x, d.y)
    end
end

-- Scale of a frame: the global UI scale for movable frames, times the
-- module's own scale setting (frame.buiModScale, set by ApplyModuleLook).
function B:FrameScale(frame)
    local s = frame.buiModScale or 1
    if frame.buiKey then s = s * ((self.db and self.db.scale) or 1) end
    return s
end

function B:RegisterMover(frame, key, label, point, relPoint, x, y)
    frame.buiKey = key
    frame.buiDefault = { point = point, relPoint = relPoint, x = x, y = y }
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScale(self:FrameScale(frame))
    self:ApplyPosition(frame)

    local ov = CreateFrame("Button", nil, frame)
    ov:SetAllPoints(frame)
    ov:SetFrameLevel(frame:GetFrameLevel() + 15)
    ov:EnableMouse(true)
    ov:RegisterForDrag("LeftButton")
    local tex = ov:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(ov)
    tex:SetTexture(self.WHITE)
    self:Accent(tex, "tex", 0.30)
    local txt = self:Font(ov, 11, "CENTER")
    txt:SetPoint("CENTER", ov, "CENTER", 0, 0)
    txt:SetText(label)
    ov:SetScript("OnDragStart", function()
        this:GetParent():StartMoving()
    end)
    ov:SetScript("OnDragStop", function()
        local f = this:GetParent()
        f:StopMovingOrSizing()
        local p, _, rp, px, py = f:GetPoint(1)
        if p then
            local k = f.buiKey
            B.db.positions[k] = {
                point = p,
                relPoint = rp or p,
                x = math.floor((px or 0) + 0.5),
                y = math.floor((py or 0) + 0.5),
            }
        end
    end)
    ov:Hide()
    frame.buiMover = ov
    self.movers[key] = frame
    table.insert(self.moverOrder, key)
end

-------------------------------------------------------------------------------
--  Edit Mode Alignment Grid
-------------------------------------------------------------------------------
local gridFrame = nil
local gridLines = {}

function B:GetAlignmentGrid()
    if gridFrame then return gridFrame end

    local f = CreateFrame("Frame", "BUI_AlignmentGrid", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:Hide()
    gridFrame = f
    return f
end

function B:UpdateAlignmentGrid()
    local f = self:GetAlignmentGrid()
    local w = (UIParent and UIParent:GetWidth()) or 1920
    local h = (UIParent and UIParent:GetHeight()) or 1080
    if w <= 0 then w = 1920 end
    if h <= 0 then h = 1080 end

    local midX = math.floor(w / 2)
    local midY = math.floor(h / 2)
    local step = 32
    local lineIdx = 0

    local function DrawLine(startX, startY, endX, endY, r, g, b, a, width, height)
        lineIdx = lineIdx + 1
        local tex = gridLines[lineIdx]
        if not tex then
            tex = f:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(B.WHITE)
            gridLines[lineIdx] = tex
        end
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", startX, startY)
        tex:SetWidth(width)
        tex:SetHeight(height)
        tex:SetVertexColor(r, g, b, a)
        tex:Show()
    end

    -- Center cross lines (Cyan Accent)
    DrawLine(midX - 1, 0, midX - 1, h, 0.0, 0.90, 1.0, 0.60, 2, h)
    DrawLine(0, midY - 1, w, midY - 1, 0.0, 0.90, 1.0, 0.60, w, 2)

    -- Vertical lines outward from center
    local countX = 0
    local x = midX + step
    while x < w do
        countX = countX + 1
        local isMajor = (math.mod(countX, 4) == 0)
        local a = isMajor and 0.20 or 0.08
        DrawLine(x, 0, x, h, 1.0, 1.0, 1.0, a, 1, h)
        x = x + step
    end
    countX = 0
    x = midX - step
    while x > 0 do
        countX = countX + 1
        local isMajor = (math.mod(countX, 4) == 0)
        local a = isMajor and 0.20 or 0.08
        DrawLine(x, 0, x, h, 1.0, 1.0, 1.0, a, 1, h)
        x = x - step
    end

    -- Horizontal lines outward from center
    local countY = 0
    local y = midY + step
    while y < h do
        countY = countY + 1
        local isMajor = (math.mod(countY, 4) == 0)
        local a = isMajor and 0.20 or 0.08
        DrawLine(0, y, w, y, 1.0, 1.0, 1.0, a, w, 1)
        y = y + step
    end
    countY = 0
    y = midY - step
    while y > 0 do
        countY = countY + 1
        local isMajor = (math.mod(countY, 4) == 0)
        local a = isMajor and 0.20 or 0.08
        DrawLine(0, y, w, y, 1.0, 1.0, 1.0, a, w, 1)
        y = y - step
    end

    -- Hide remaining lines if any
    local nLines = table.getn(gridLines)
    for i = lineIdx + 1, nLines do
        gridLines[i]:Hide()
    end
end

function B:SetAlignmentGridShown(shown)
    local f = self:GetAlignmentGrid()
    if shown and (self.db and self.db.showGrid ~= false) then
        self:UpdateAlignmentGrid()
        f:Show()
    else
        f:Hide()
    end
end

function B:SetUnlocked(flag)
    self.unlocked = flag and true or false
    for i = 1, table.getn(self.moverOrder) do
        local f = self.movers[self.moverOrder[i]]
        local ov = f.buiMover
        if ov then
            if self.unlocked then ov:Show() else ov:Hide() end
        end
    end
    self:SetAlignmentGridShown(self.unlocked)
    self:Tick()
end

function B:ResetPositions()
    self.db.positions = {}
    for i = 1, table.getn(self.moverOrder) do
        self:ApplyPosition(self.movers[self.moverOrder[i]])
    end
    self:Print(self.L["Positions reset."])
end

function B:GetScreenDimensions()
    local resWidth, resHeight
    if type(GetCurrentResolution) == "function" and type(GetScreenResolutions) == "function" then
        local idx = GetCurrentResolution()
        if idx and idx > 0 then
            local list = { GetScreenResolutions() }
            local str = list[idx]
            if str and str ~= "" then
                local _, _, w, h = string.find(str, "(%d+)x(%d+)")
                if w and h then
                    resWidth = tonumber(w)
                    resHeight = tonumber(h)
                end
            end
        end
    end
    if not resWidth or not resHeight or resWidth <= 0 or resHeight <= 0 then
        resWidth = (type(GetScreenWidth) == "function" and GetScreenWidth()) or (UIParent and UIParent:GetWidth()) or 1365
        resHeight = (type(GetScreenHeight) == "function" and GetScreenHeight()) or (UIParent and UIParent:GetHeight()) or 768
    end
    return resWidth, resHeight
end

function B:GetOptimalScale()
    local uiW = (UIParent and UIParent:GetWidth()) or (type(GetScreenWidth) == "function" and GetScreenWidth()) or 1365
    local uiH = (UIParent and UIParent:GetHeight()) or (type(GetScreenHeight) == "function" and GetScreenHeight()) or 768
    if uiW <= 0 then uiW = 1365 end
    if uiH <= 0 then uiH = 768 end

    -- Horizontal constraint: ensure dual meters (518px), target (310px from center),
    -- and 24px safety margin fit on the right half of the screen.
    local rightSpan = 518 + 310 + 24
    local scaleX = (uiW / 2) / rightSpan

    -- Vertical constraint: ensure right-side stack (Minimap 140, Timer 130, Encounters 180, gap 20 = 470px)
    -- and bottom meters (160px) + 30px safety margin fit vertically.
    local vertSpan = 470 + 160 + 30
    local scaleY = uiH / vertSpan

    local optimal = scaleX
    if scaleY < optimal then optimal = scaleY end

    -- Clamp optimal scale between 0.60 (smallest screens) and 1.05 (ultrawide / high-res)
    if optimal < 0.60 then optimal = 0.60 end
    if optimal > 1.05 then optimal = 1.05 end

    -- Round to 2 decimal places for clean, crisp rendering
    return math.floor(optimal * 100 + 0.5) / 100
end

function B:CheckResolution()
    if self.db and self.db.autoScale then
        local newScale = self:GetOptimalScale()
        if not self.db.scale or math.abs(newScale - self.db.scale) >= 0.01 then
            self.db.scale = newScale
            self:ApplyScale()
        end
    end
end

function B:ApplyScale()
    for i = 1, table.getn(self.moverOrder) do
        local f = self.movers[self.moverOrder[i]]
        f:SetScale(self:FrameScale(f))
        self:ApplyPosition(f)
    end
end

-------------------------------------------------------------------------------
--  Error reporting: one chat line per distinct error (not 10/s from the
--  ticker), forwarded once to the installed error handler (BugGrabber).
-------------------------------------------------------------------------------
function B:ReportError(key, err)
    if not self.reportedErrors then self.reportedErrors = {} end
    local msg = tostring(err)
    if self.reportedErrors[key] == msg then return end
    self.reportedErrors[key] = msg
    self:Print("|cffff5555[" .. tostring(key) .. "]|r " .. msg)
    if type(geterrorhandler) == "function" then
        local handler = geterrorhandler()
        if type(handler) == "function" then
            handler("BlackwellUI [" .. tostring(key) .. "]: " .. msg)
        end
    end
end

-------------------------------------------------------------------------------
--  Managed stock state. Every stock CVar / option global the addon overrides
--  is snapshotted once into BlackwellUIDB before the first write and written
--  back on restore. Restore touches only what was overridden, so a disabled
--  module, a logout or an uninstall leaves the client as the player had it.
-------------------------------------------------------------------------------
local NIL_SENTINEL = "__nil"

function B:SetManagedCVar(cv, value)
    if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then return end
    local ok, cur = pcall(GetCVar, cv)
    if not ok then
        self:ReportError("cvar " .. cv, cur)
        return
    end
    if cur == nil or cur == value then return end
    if self.db.stockCVars[cv] == nil then
        self.db.stockCVars[cv] = cur
    end
    local okSet, err = pcall(SetCVar, cv, value)
    if not okSet then self:ReportError("cvar " .. cv, err) end
end

-- keepSnapshot: write the original back but keep it recorded (logout path,
-- where the client may not persist the write; see RestoreAllStock).
function B:RestoreManagedCVar(cv, keepSnapshot)
    local orig = self.db.stockCVars[cv]
    if orig == nil then return end
    if not keepSnapshot then self.db.stockCVars[cv] = nil end
    if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then return end
    local ok, cur = pcall(GetCVar, cv)
    if not ok then
        self:ReportError("cvar " .. cv, cur)
        return
    end
    if cur ~= orig then
        local okSet, err = pcall(SetCVar, cv, orig)
        if not okSet then self:ReportError("cvar " .. cv, err) end
    end
end

function B:SetManagedGlobal(name, value)
    local cur = _G[name]
    if cur == value then return end
    if self.db.stockGlobals[name] == nil then
        if cur == nil then
            self.db.stockGlobals[name] = NIL_SENTINEL
        else
            self.db.stockGlobals[name] = cur
        end
    end
    _G[name] = value
end

function B:RestoreManagedGlobal(name, keepSnapshot)
    local orig = self.db.stockGlobals[name]
    if orig == nil then return end
    if not keepSnapshot then self.db.stockGlobals[name] = nil end
    if orig == NIL_SENTINEL then
        _G[name] = nil
    else
        _G[name] = orig
    end
end

-- Logout / reload: hand every overridden value back so the client can save
-- the player's own settings. The snapshot is kept: benilla was observed not
-- to rewrite config.toml after PLAYER_LOGOUT (in-game test 2026-11-01), so the
-- zeroed values may come back next session and must stay restorable.
function B:RestoreAllStock()
    if not self.db then return end
    for cv in pairs(self.db.stockCVars) do
        self:RestoreManagedCVar(cv, true)
    end
    for name in pairs(self.db.stockGlobals) do
        self:RestoreManagedGlobal(name, true)
    end
    -- HUD parts without a known CVar (banners, loot) go through the game API.
    if type(AZS_SetHudShown) == "function" and type(AZS_IsHudShown) == "function" then
        for i = 1, table.getn(self.HUD_PARTS) do
            local part = self.HUD_PARTS[i]
            if not self.HUD_CVARS[part] and AZS_IsHudShown(part) == false then
                AZS_SetHudShown(part, true)
            end
        end
    end
end

-- 2.6.7 and older zeroed CVars without a snapshot; for values that are "0"
-- now, assume the client default "1" as the original (one-time migration).
function B:SeedLegacyStockSnapshot()
    if type(GetCVar) ~= "function" then return end
    local list = {}
    for i = 1, table.getn(self.STOCK_COMBAT_CVARS) do
        table.insert(list, self.STOCK_COMBAT_CVARS[i])
    end
    for _, cv in pairs(self.HUD_CVARS) do
        table.insert(list, cv)
    end
    for i = 1, table.getn(list) do
        local cv = list[i]
        if self.db.stockCVars[cv] == nil then
            local ok, cur = pcall(GetCVar, cv)
            if not ok then
                self:ReportError("cvar " .. cv, cur)
            elseif cur == "0" then
                self.db.stockCVars[cv] = "1"
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Stock Combat Text & Floating Numbers Management
-------------------------------------------------------------------------------
B.STOCK_COMBAT_CVARS = {
    "CombatDamage",
    "CombatLogPeriodicSpells",
    "PetMeleeDamage",
    "PetSpellDamage",
}

B.STOCK_COMBAT_GLOBALS = {
    "SHOW_COMBAT_TEXT",
    "SHOW_COMBAT_STATE",
    "COMBAT_TEXT_SHOW_LOW_HEALTH_MANA",
    "COMBAT_TEXT_SHOW_AURAS",
    "COMBAT_TEXT_SHOW_AURA_FADE",
    "COMBAT_TEXT_SHOW_COMBAT_STATE",
    "COMBAT_TEXT_SHOW_DODGE_PARRY_MISS",
    "COMBAT_TEXT_SHOW_RESISTANCES",
    "COMBAT_TEXT_SHOW_REPUTATION",
    "COMBAT_TEXT_SHOW_REACTIVES",
    "COMBAT_TEXT_SHOW_FRIENDLY_NAMES",
    "COMBAT_TEXT_SHOW_COMBO_POINTS",
    "COMBAT_TEXT_SHOW_MANA",
    "COMBAT_TEXT_SHOW_HONOR_GAINED",
}

B.STOCK_COMBAT_EVENTS = {
    "COMBAT_TEXT_UPDATE",
    "UNIT_HEALTH",
    "UNIT_MANA",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD",
}

function B:SuppressStockCombatText()
    -- Cache original functions first before silencing
    if not self.origCombatText_AddMessage and type(CombatText_AddMessage) == "function" then
        self.origCombatText_AddMessage = CombatText_AddMessage
    end
    if not self.origCombatText_OnUpdate and type(CombatText_OnUpdate) == "function" then
        self.origCombatText_OnUpdate = CombatText_OnUpdate
    end
    if not self.origCombatText_OnEvent and type(CombatText_OnEvent) == "function" then
        self.origCombatText_OnEvent = CombatText_OnEvent
    end
    if not self.origCombatText_UpdateDisplayedMessages and type(CombatText_UpdateDisplayedMessages) == "function" then
        self.origCombatText_UpdateDisplayedMessages = CombatText_UpdateDisplayedMessages
    end

    if not self.dummyCombatText_AddMessage then
        self.dummyCombatText_AddMessage = function() end
        self.dummyCombatText_OnUpdate = function() end
        self.dummyCombatText_OnEvent = function() end
        self.dummyCombatText_UpdateDisplayedMessages = function() end
    end

    -- 1. Silence Blizzard CombatText frame once per frame instance (it can
    --    appear late if Blizzard_CombatText loads on demand); later calls
    --    only re-hide it.
    if CombatText and self.silencedCombatText ~= CombatText then
        if type(CombatText.UnregisterAllEvents) == "function" then
            CombatText:UnregisterAllEvents()
        end
        if type(CombatText.SetScript) == "function" then
            CombatText:SetScript("OnUpdate", nil)
            CombatText:SetScript("OnEvent", nil)
        end
        self.silencedCombatText = CombatText
    end
    if CombatText and type(CombatText.IsShown) == "function" and CombatText:IsShown() then
        CombatText:Hide()
    end
    CombatText_AddMessage = self.dummyCombatText_AddMessage
    CombatText_OnUpdate = self.dummyCombatText_OnUpdate
    CombatText_OnEvent = self.dummyCombatText_OnEvent
    CombatText_UpdateDisplayedMessages = self.dummyCombatText_UpdateDisplayedMessages

    -- 2. Stock option globals and CVars: snapshotted, written only on change
    for i = 1, table.getn(self.STOCK_COMBAT_GLOBALS) do
        self:SetManagedGlobal(self.STOCK_COMBAT_GLOBALS[i], "0")
    end
    for i = 1, table.getn(self.STOCK_COMBAT_CVARS) do
        self:SetManagedCVar(self.STOCK_COMBAT_CVARS[i], "0")
    end
end

function B:RestoreStockCombatText()
    -- 1. Restore Blizzard CombatText hooks
    if self.origCombatText_AddMessage and CombatText_AddMessage == self.dummyCombatText_AddMessage then
        CombatText_AddMessage = self.origCombatText_AddMessage
    end
    if self.origCombatText_OnUpdate and CombatText_OnUpdate == self.dummyCombatText_OnUpdate then
        CombatText_OnUpdate = self.origCombatText_OnUpdate
    end
    if self.origCombatText_OnEvent and CombatText_OnEvent == self.dummyCombatText_OnEvent then
        CombatText_OnEvent = self.origCombatText_OnEvent
    end
    if self.origCombatText_UpdateDisplayedMessages and CombatText_UpdateDisplayedMessages == self.dummyCombatText_UpdateDisplayedMessages then
        CombatText_UpdateDisplayedMessages = self.origCombatText_UpdateDisplayedMessages
    end

    -- 2. Restore CombatText frame and events, only if we silenced it
    if CombatText and self.silencedCombatText == CombatText then
        self.silencedCombatText = nil
        if self.origCombatText_OnEvent and type(CombatText.SetScript) == "function" then
            CombatText:SetScript("OnEvent", self.origCombatText_OnEvent)
            CombatText:SetScript("OnUpdate", self.origCombatText_OnUpdate)
        end
        if type(CombatText.RegisterEvent) == "function" then
            for i = 1, table.getn(self.STOCK_COMBAT_EVENTS) do
                local ev = self.STOCK_COMBAT_EVENTS[i]
                local ok, err = pcall(CombatText.RegisterEvent, CombatText, ev)
                if not ok then self:ReportError("combattext " .. ev, err) end
            end
        end
        if type(CombatText.Show) == "function" then
            CombatText:Show()
        end
    end

    -- 3. Stock option globals and CVars back to the player's own values.
    --    (SHOW_COMBAT_TEXT is an option global, not a CVar: never SetCVar it.)
    for i = 1, table.getn(self.STOCK_COMBAT_GLOBALS) do
        self:RestoreManagedGlobal(self.STOCK_COMBAT_GLOBALS[i])
    end
    for i = 1, table.getn(self.STOCK_COMBAT_CVARS) do
        self:RestoreManagedCVar(self.STOCK_COMBAT_CVARS[i])
    end
end

function B:SyncCombatText()
    if self:IsEnabled("combattext") then
        self:SuppressStockCombatText()
    else
        self:RestoreStockCombatText()
    end
end

-------------------------------------------------------------------------------
--  Stock run HUD (AZS_SetHudShown). The setting is a CVar the game keeps, so it
--  is written only when it differs from what we want: never in a loop.
-------------------------------------------------------------------------------
B.HUD_PARTS = { "clock", "bosses", "tally", "build", "meter", "banners", "loot", "flag", "levels", "revive" }
B.HUD_REPLACED_BY = {
    clock = "timer",
    bosses = "unitframes",
    tally = "databar",
    build = "build",
    meter = "meter",
    flag = "pins",
    levels = "build",
    revive = "castbar",
}
-- CVars behind the stock HUD parts (from config.toml); banners/loot are
-- reached only through AZS_SetHudShown.
B.HUD_CVARS = {
    clock = "hudClock",
    bosses = "hudBosses",
    tally = "hudTally",
    build = "hudBuild",
    meter = "hudMeter",
    flag = "hudFlag",
    levels = "hudLevels",
    revive = "hudRevive",
}

function B:WantStockHud(part)
    local mod = self.HUD_REPLACED_BY[part]
    -- The revive bar is an option of the always-on cast bar module.
    if part == "revive" and not self:ModOpt("castbar", "showRevive", true) then
        return true
    end
    if mod then
        return not (self.db.replaceHud and self:IsEnabled(mod))
    end
    if part == "banners" then return not self.db.hideBanners end
    if part == "loot" then return not self.db.hideLoot end
    return true
end

function B:SyncHud()
    if not self.db then return end
    self:SyncCombatText()

    -- Stock HUD CVars follow WantStockHud exactly (hidden part -> "0", shown
    -- part -> the player's snapshotted value), so they never disagree with
    -- AZS_SetHudShown below.
    for i = 1, table.getn(self.HUD_PARTS) do
        local part = self.HUD_PARTS[i]
        local cv = self.HUD_CVARS[part]
        if cv then
            if self:WantStockHud(part) then
                self:RestoreManagedCVar(cv)
            else
                self:SetManagedCVar(cv, "0")
            end
        end
    end

    if type(AZS_SetHudShown) == "function" and type(AZS_IsHudShown) == "function" then
        for i = 1, table.getn(self.HUD_PARTS) do
            local part = self.HUD_PARTS[i]
            local cur = AZS_IsHudShown(part)
            if cur ~= nil then
                local want = self:WantStockHud(part)
                if (cur and true or false) ~= want then
                    AZS_SetHudShown(part, want)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Run state: live AZS_* data, or a preview while /bui demo or unlocked
-------------------------------------------------------------------------------
local live = {}
local demo = nil
local demoStart = nil

local function BuildDemo()
    return {
        demo = true,
        active = true,
        phase = "playing",
        time = 0,
        length = 900,
        zone = { zname = "Duskwood", zsub = "Raven Hill", diff = 3, len = 900,
                 cname = "Warrior", hero = "Demo Hero" },
        run = { lvl = 24, xp = 1840, xpn = 2400, hp = 4120, hpm = 4850, sh = 960,
                gold = 1480, kills = 1842, lives = 2, rr = 3, chest = 450, dealt = 1845200, taken = 42800 },
        units = {
            { kind = "boss", id = 1, name = "Stitches", hp = 142500, hpm = 220000, state = 1 },
            { kind = "guardian", id = 2, name = "Shrine Warden", hp = 48000, hpm = 65000, state = 1 },
            { kind = "elite", id = 3, name = "Skeletal Fiend", hp = 12000, hpm = 18000, state = 0 },
            { kind = "elite", id = 4, name = "Rotting Ghoul", hp = 8400, hpm = 14000, state = 0 },
        },
        bosses = {
            { id = 1, name = "Stitches", hp = 142500, hpm = 220000, final = false, enraged = true },
        },
        guardians = {
            { id = 2, name = "Shrine Warden", hp = 48000, hpm = 65000, awake = true },
        },
        elites = {
            { id = 3, name = "Skeletal Fiend", hp = 12000, hpm = 18000 },
            { id = 4, name = "Rotting Ghoul", hp = 8400, hpm = 14000 },
        },
        schedule = {
            { index = 1, name = "Morbent's Herald", at = 135, final = 0, state = "dead" },
            { index = 2, name = "Stitches", at = 270, final = 0, state = "alive" },
            { index = 3, name = "Mor'Ladim", at = 405, final = 0, state = "due" },
            { index = 4, name = "Eliza", at = 540, final = 0, state = "due" },
            { index = 5, name = "Stalvan Mistmantle", at = 675, final = 0, state = "due" },
            { index = 6, name = "Morbent Fel", at = 900, final = 1, state = "due" },
        },
        upcoming = {},
        spells = {
            { key = "1", spell = "Whirlwind", rank = 7, cd = 0, cdmax = 4 },
            { key = "2", spell = "Thunder Clap", rank = 5, cd = 0, cdmax = 6 },
            { key = "3", spell = "Mortal Strike", rank = 6, cd = 0, cdmax = 5 },
            { key = "4", spell = "Bladestorm", rank = 3, cd = 0, cdmax = 18 },
            { key = "F", spell = "Heroic Leap", rank = 2, cd = 0, cdmax = 10 },
        },
        spellsAge = 0,
        buffs = {
            { spell = "6673", left = 12.8 },
            { spell = "23234", left = 9.0 },
            { spell = "Shrine of Haste", left = 18 },
            { spell = "Bloodlust", left = 9 },
        },
        buffsAge = 0,
        meter = {
            { name = "Whirlwind", dmg = 742000, dps = 1416, share = 40, proc = 0 },
            { name = "Bladestorm", dmg = 428000, dps = 816, share = 23, proc = 0 },
            { name = "Mortal Strike", dmg = 312000, dps = 595, share = 17, proc = 0 },
            { name = "Deep Wounds", dmg = 219000, dps = 418, share = 12, proc = 1 },
            { name = "Thunder Clap", dmg = 144200, dps = 275, share = 8, proc = 0 },
        },
        meterTotal = 1845200,
        meterDps = 3521,
        healing = {
            { name = "Flash of Light", dmg = 320000, dps = 610, share = 52, proc = 0 },
            { name = "Holy Light", dmg = 180000, dps = 343, share = 29, proc = 0 },
            { name = "Holy Shock", dmg = 115000, dps = 219, share = 19, proc = 0 },
        },
        healingTotal = 615000,
        healingDps = 1172,
        bossMeter = {
            { name = "Mortal Strike", dmg = 185000, dps = 353, share = 45, proc = 0 },
            { name = "Whirlwind", dmg = 120000, dps = 229, share = 29, proc = 0 },
            { name = "Deep Wounds", dmg = 68000, dps = 129, share = 16, proc = 1 },
            { name = "Bladestorm", dmg = 42000, dps = 80, share = 10, proc = 0 },
        },
        bossMeterTotal = 415000,
        bossMeterDps = 792,
        party = {
            { name = "Pierre", class = "warrior", dmg = 1845200, dps = 3521, share = 42, top = "Whirlwind", topdps = 1565 },
            { name = "Valandil", class = "mage", dmg = 1420000, dps = 2710, share = 32, top = "Blizzard", topdps = 1200 },
            { name = "Eluna", class = "priest", dmg = 620000, dps = 1183, share = 14, top = "Holy Nova", topdps = 650 },
            { name = "Sylvana", class = "rogue", dmg = 510000, dps = 973, share = 12, top = "Fan of Knives", topdps = 520 },
        },
        partyTotal = 4395200,
        partyDps = 8387,
        taken = {
            { source = "Stitches", dmg = 19400 },
            { source = "Skeletal Fiend", dmg = 12800 },
            { source = "Plague Cloud", dmg = 10600 },
        },
        lairs = {
            { index = 1, state = "asleep", name = "Bloodmage Thalnos", left = 0 },
            { index = 2, state = "awake", name = "Interrogator Vishas", left = 0 },
            { index = 3, state = "empty", name = "Ironspine", left = 102 },
            { index = 4, state = "empty", name = "Azshir the Sleepless", left = 255 },
        },
        lairsUpdated = GetTime(),
        target = { kind = "boss", name = "Stitches", hp = 142500, hpm = 220000, state = 1 },
    }
end

local function UpdateDemo()
    if not demo then
        demo = BuildDemo()
        demoStart = GetTime()
    end
    local t = GetTime() - demoStart
    demo.time = 412 + math.mod(t, 480)
    for i = 1, table.getn(demo.spells) do
        local sp = demo.spells[i]
        if i == 2 then
            sp.cd = 0
        else
            sp.cd = sp.cdmax - math.mod(t + i * 1.3, sp.cdmax)
        end
    end
    demo.buffs[1].left = 30 - math.mod(t, 30)
    demo.buffs[2].left = 15 - math.mod(t, 15)
    demo.buffs[3].left = 25 - math.mod(t, 25)
    demo.buffs[4].left = 12 - math.mod(t, 12)
    local up = {}
    for i = 1, table.getn(demo.schedule) do
        local b = demo.schedule[i]
        if b.state == "due" then
            table.insert(up, { index = b.index, name = b.name, at = b.at,
                left = b.at - demo.time, final = (b.final == 1) })
        end
    end
    demo.upcoming = up
    return demo
end

local function Age(stamp, phase)
    if phase ~= "playing" or not stamp then return 0 end
    local a = GetTime() - stamp
    if a < 0 then a = 0 end
    return a
end

local RUN_TABLE_KEYS = {
    "zone", "run", "bosses", "guardians", "elites", "units", "schedule", "upcoming",
    "spells", "buffs", "meter", "bossMeter", "healing", "party", "taken", "lairs", "revive",
}

local function ClearRunState(s)
    for i = 1, table.getn(RUN_TABLE_KEYS) do
        s[RUN_TABLE_KEYS[i]] = {}
    end
    s.target = { kind = "none" }
    s.time = 0
    s.meterTotal, s.meterDps = 0, 0
    s.bossMeterTotal, s.bossMeterDps = 0, 0
    s.healingTotal, s.healingDps = 0, 0
    s.partyTotal, s.partyDps = 0, 0
    s.lairsUpdated = nil
end

-- A run starts when play begins from no run / lobby / victory, when the run
-- clock jumps back, or after a death when the clock is near zero (a revive
-- keeps the clock running and is not a new run).
function B:DetectRunStart(phase, t)
    local prevPhase, prevTime = self.runPhase, self.runTime
    self.runPhase, self.runTime = phase, t
    if phase ~= "playing" and phase ~= "choosing" and phase ~= "paused" then return end
    local started = false
    if prevPhase == nil or prevPhase == "ready" or prevPhase == "victory" then
        started = true
    elseif prevTime and t + 2 < prevTime then
        started = true
    elseif prevPhase == "dead" and t < 5 then
        started = true
    end
    if started then self:FireRunStart() end
end

function B:FireRunStart()
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if type(mod.OnRunStart) == "function" then
            local ok, err = pcall(mod.OnRunStart, mod)
            if not ok then self:ReportError(mod.key, err) end
        end
    end
end

function B:HasApi()
    if type(AZS_GetPhase) == "function" or type(AZS_PHASE) == "string" then
        return true
    end
    if type(AZS_RUN) == "table" and (AZS_RUN.phase ~= nil or AZS_RUN.ph ~= nil) then
        return true
    end
    return false
end

function B:GetState()
    if self.db.demo or self.unlocked then
        return UpdateDemo()
    end
    local s = live
    s.demo = false
    if not self:HasApi() then
        s.active = false
        return s
    end
    local phase = nil
    if type(AZS_GetPhase) == "function" then
        phase = AZS_GetPhase()
    elseif type(AZS_PHASE) == "string" then
        phase = AZS_PHASE
    elseif AZS_RUN then
        phase = AZS_RUN.phase or AZS_RUN.ph
    end
    s.phase = phase
    s.active = (phase ~= nil)
    if not s.active then
        -- Leaving a run: drop its data once so always-active modules do not
        -- keep drawing the last run's units, target and party.
        if self.runPhase ~= nil then
            ClearRunState(s)
            self.runPhase = nil
        end
        return s
    end

    s.time = (type(AZS_GetRunTime) == "function" and AZS_GetRunTime()) or (AZS_RUN and tonumber(AZS_RUN.t)) or 0
    self:DetectRunStart(phase, tonumber(s.time) or 0)
    s.length = (type(AZS_GetRunLength) == "function" and AZS_GetRunLength()) or (AZS_RUN and tonumber(AZS_RUN.dur)) or 900
    s.zone = AZS_ZONE or {}
    s.run = AZS_RUN or {}
    s.bosses = (type(AZS_GetBosses) == "function" and AZS_GetBosses()) or {}
    s.guardians = (type(AZS_GetGuardians) == "function" and AZS_GetGuardians()) or {}
    local elites = {}
    local units = (type(AZS_UNITS) == "table" and AZS_UNITS) or {}
    for i = 1, table.getn(units) do
        local u = units[i]
        if type(u) == "table" and u.kind == "elite" then
            table.insert(elites, { id = u.id, name = u.name, hp = u.hp, hpm = u.hpm })
        end
    end
    s.elites = elites
    s.units = units
    s.schedule = AZS_SCHEDULE or {}
    s.upcoming = (type(AZS_GetUpcomingBosses) == "function" and AZS_GetUpcomingBosses()) or {}
    s.spells = AZS_SPELLS or {}
    s.spellsAge = Age(AZS_SPELLS_UPDATED, phase)
    s.buffs = AZS_BUFFS or {}
    s.buffsAge = Age(AZS_BUFFS_UPDATED, phase)
    local meter, total, dps = nil, 0, 0
    if type(AZS_GetMeter) == "function" then
        meter, total, dps = AZS_GetMeter()
    end
    s.meter = (type(meter) == "table" and meter) or (type(AZS_METER) == "table" and AZS_METER) or {}
    s.meterTotal = tonumber(total) or 0
    s.meterDps = tonumber(dps) or 0
    local bossMeter, bossTotal, bossDps = nil, 0, 0
    if type(AZS_GetBossMeter) == "function" then
        bossMeter, bossTotal, bossDps = AZS_GetBossMeter()
    end
    s.bossMeter = (type(bossMeter) == "table" and bossMeter) or (type(AZS_BOSSMETER) == "table" and AZS_BOSSMETER) or {}
    s.bossMeterTotal = tonumber(bossTotal) or 0
    s.bossMeterDps = tonumber(bossDps) or 0
    local healMeter, healTotal, healDps = nil, 0, 0
    if type(AZS_GetHealing) == "function" then
        healMeter, healTotal, healDps = AZS_GetHealing()
    end
    s.healing = (type(healMeter) == "table" and healMeter) or (type(AZS_HEALING) == "table" and AZS_HEALING) or {}
    s.healingTotal = tonumber(healTotal) or 0
    s.healingDps = tonumber(healDps) or 0
    local partyMeter, partyTotal, partyDps = nil, 0, 0
    if type(AZS_GetPartyMeter) == "function" then
        partyMeter, partyTotal, partyDps = AZS_GetPartyMeter()
    end
    s.party = (type(partyMeter) == "table" and partyMeter) or (type(AZS_PARTY) == "table" and AZS_PARTY) or {}
    s.partyTotal = tonumber(partyTotal) or 0
    s.partyDps = tonumber(partyDps) or 0
    s.taken = AZS_TAKEN or {}
    s.lairs = (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or (type(AZS_LAIRS) == "table" and AZS_LAIRS) or {}
    s.lairsUpdated = AZS_LAIRS_UPDATED
    s.revive = AZS_REVIVE or {}
    s.target = AZS_TARGET or { kind = "none" }
    return s
end

-------------------------------------------------------------------------------
--  Modules: one shared 10 Hz ticker drives every module
-------------------------------------------------------------------------------
-- mod = { label, Create(mod), Update(mod, state), frame }
-- Optional: mod.hint (one line for the options page), mod.options (list of
-- option entries, see Options.lua), mod.lookFrames (frames that follow the
-- module's scale / opacity / visibility; default { mod.frame }),
-- mod.noLook (no scale / opacity / visibility settings), mod:ApplyOptions()
-- (called after one of the module's settings changed).
function B:RegisterModule(key, mod)
    mod.key = key
    self.modules[key] = mod
    table.insert(self.moduleOrder, key)
end

-------------------------------------------------------------------------------
--  Per-module settings (B.db.mod[moduleKey][optionKey])
-------------------------------------------------------------------------------
function B:ModOpt(modKey, optKey, default)
    local t = self.db and self.db.mod and self.db.mod[modKey]
    if t and t[optKey] ~= nil then return t[optKey] end
    return default
end

function B:SetModOpt(modKey, optKey, value)
    if not self.db then return end
    if type(self.db.mod) ~= "table" then self.db.mod = {} end
    if type(self.db.mod[modKey]) ~= "table" then self.db.mod[modKey] = {} end
    self.db.mod[modKey][optKey] = value
end

function B:ResetModOpts(modKey)
    if self.db and type(self.db.mod) == "table" then
        self.db.mod[modKey] = nil
    end
end

function B:GetLookFrames(mod)
    if mod.noLook then return {} end
    if type(mod.lookFrames) == "table" then return mod.lookFrames end
    if mod.frame then return { mod.frame } end
    return {}
end

-- Scale from the module's settings; opacity and visibility run per tick.
function B:ApplyModuleLook(mod)
    local frames = self:GetLookFrames(mod)
    local scale = self:ModOpt(mod.key, "scale", 1)
    for i = 1, table.getn(frames) do
        if frames[i] and frames[i].SetScale then
            frames[i].buiModScale = scale
            frames[i]:SetScale(self:FrameScale(frames[i]))
            -- Saved positions are in the frame's own scale: re-place it.
            if frames[i].buiKey then self:ApplyPosition(frames[i]) end
        end
    end
end

-- "always", "combat" (only in combat), "nocombat", "mouseover" (faded until
-- the mouse is over it).
function B:ApplyModuleVisibility(mod)
    local frames = self:GetLookFrames(mod)
    if table.getn(frames) == 0 then return end
    local alpha = self:ModOpt(mod.key, "alpha", 1)
    local vis = self:ModOpt(mod.key, "visibility", "always")
    local factor = 1
    if not self.unlocked then
        if vis == "combat" or vis == "nocombat" then
            local inCombat = (type(UnitAffectingCombat) == "function") and UnitAffectingCombat("player")
            if (vis == "combat" and not inCombat) or (vis == "nocombat" and inCombat) then
                factor = 0
            end
        elseif vis == "mouseover" then
            factor = self:ModOpt(mod.key, "fadeAlpha", 0.15)
            if type(MouseIsOver) == "function" then
                for i = 1, table.getn(frames) do
                    local fr = frames[i]
                    if fr and fr:IsVisible() and MouseIsOver(fr) then
                        factor = 1
                        break
                    end
                end
            end
        end
    end
    for i = 1, table.getn(frames) do
        if frames[i] and frames[i].SetAlpha then
            frames[i]:SetAlpha(alpha * factor)
        end
    end
end

-- Called by the options page after a module setting changed.
function B:OnModuleOptionChanged(mod)
    self:ApplyModuleLook(mod)
    if type(mod.ApplyOptions) == "function" then
        local ok, err = pcall(mod.ApplyOptions, mod)
        if not ok then self:ReportError(mod.key, err) end
    end
    self:Tick()
end

function B:IsEnabled(key)
    return self.db and self.db.modules[key] ~= false
end

function B:BuildModules()
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if self:IsEnabled(mod.key) and not mod.frame then
            local ok, err = pcall(mod.Create, mod)
            if not ok then
                self:ReportError(mod.key, err)
            else
                mod.created = true
                self:ApplyModuleLook(mod)
                if type(mod.ApplyOptions) == "function" then
                    local okOpt, errOpt = pcall(mod.ApplyOptions, mod)
                    if not okOpt then self:ReportError(mod.key, errOpt) end
                end
            end
            if mod.frame then mod.frame:Hide() end
        end
    end
end

-- Modules that take over Blizzard frames (reloadOnToggle) stay as they were
-- built until /reload: hiding them at runtime would leave the player with no
-- chat / minimap / unit frames at all.
function B:IsModuleActive(mod)
    if mod.reloadOnToggle then return mod.created == true end
    return self:IsEnabled(mod.key)
end

function B:Tick()
    if not self.built then return end

    if self.db and self.db.autoScale then
        local curW = (UIParent and UIParent:GetWidth()) or 0
        local curH = (UIParent and UIParent:GetHeight()) or 0
        if curW > 0 and (curW ~= self.lastUiWidth or curH ~= self.lastUiHeight) then
            self.lastUiWidth = curW
            self.lastUiHeight = curH
            self:CheckResolution()
        end
    end

    -- Each module runs isolated: one failing module (or a failing AZS_* getter)
    -- reports once and no longer stops every module after it.
    local okState, s = pcall(self.GetState, self)
    if not okState then
        self:ReportError("state", s)
        return
    end
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod.frame then
            local shouldShow = self:IsModuleActive(mod) and (s.active or mod.alwaysActive)
            if shouldShow then
                if not mod.frame:IsShown() then mod.frame:Show() end
                if type(mod.Update) == "function" then
                    local ok, err = pcall(mod.Update, mod, s)
                    if not ok then self:ReportError(mod.key, err) end
                end
                self:ApplyModuleVisibility(mod)
            elseif mod.frame:IsShown() then
                mod.frame:Hide()
            end
        end
    end
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["BLACKWELLUI_RELOAD"] = {
    text = "BlackwellUI: this module replaces Blizzard frames. Reload the UI to restore them now?",
    button1 = "Reload",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function B:OnModulesChanged()
    -- Touch nameplate visibility only when the module toggle itself changed:
    -- 'V' (NAMEPLATES_ON) belongs to the player.
    local wantPlates = self:IsEnabled("nameplates")
    if self.lastNameplatesWanted ~= nil and self.lastNameplatesWanted ~= wantPlates then
        if wantPlates then
            if type(ShowNameplates) == "function" then ShowNameplates() end
        else
            if type(HideNameplates) == "function" then HideNameplates() end
        end
    end
    self.lastNameplatesWanted = wantPlates

    local needsReload = false
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod.reloadOnToggle and mod.created and not self:IsEnabled(mod.key) and not mod.reloadPrompted then
            mod.reloadPrompted = true
            needsReload = true
        end
    end
    if needsReload then
        if type(StaticPopup_Show) == "function" then
            -- Texts are set here: the dialog table is built before the locale loads.
            local dialog = StaticPopupDialogs["BLACKWELLUI_RELOAD"]
            if dialog then
                dialog.text = self.L["BlackwellUI: this module replaces Blizzard frames. Reload the UI to restore them now?"]
                dialog.button1 = self.L["Reload"]
                dialog.button2 = self.L["Later"]
            end
            StaticPopup_Show("BLACKWELLUI_RELOAD")
        else
            self:Print(self.L["Type /reload to restore the Blizzard frames of the disabled module."])
        end
    end

    self:BuildModules()
    self:SyncHud()
    self:Tick()
end

function B:RefreshTheme()
    local tex = self:GetBarTexture()
    local ar, ag, ab = self:GetAccent()
    local bAlpha = (self.db and self.db.backdropAlpha) or 0.85
    local pr, pg, pb = self:GetPanelColor()
    for i = 1, table.getn(self.backdrops) do
        local entry = self.backdrops[i]
        local bg = entry.bg
        if bg then
            if bg.SetColor then
                bg:SetColor(pr, pg, pb)
            elseif bg.SetVertexColor then
                bg:SetVertexColor(pr, pg, pb)
            end
            bg:SetAlpha(bg.fixedAlpha or bAlpha)
        end
    end
    for i = 1, table.getn(self.bars) do
        local sb = self.bars[i]
        sb:SetStatusBarTexture(tex)
        if sb.buiAccent then
            self:SetBarColor(sb, ar, ag, ab)
        else
            sb:SetStatusBarColor(sb.buiR, sb.buiG, sb.buiB)
        end
    end
    for i = 1, table.getn(self.fontStrings) do
        self:ApplyFont(self.fontStrings[i])
    end
    for i = 1, table.getn(self.accents) do
        self:PaintAccent(self.accents[i])
    end
    self:Tick()
end

-------------------------------------------------------------------------------
--  Tooltip Skin & Safe Anchor
-------------------------------------------------------------------------------
function B:InitTooltip()
    if self.tooltipInitialized then return end
    self.tooltipInitialized = true

    local function SkinTooltip(tt)
        if not tt then return end
        if B:IsRound() then
            -- Round style: the stock backdrop is cleared and a round panel
            -- drawn instead; an accent line under the top edge carries the
            -- class / reaction colour.
            tt:SetBackdrop(nil)
            B:RoundPanel(tt, nil, 0.94)
            if not tt.buiAccentLine then
                local line = tt:CreateTexture(nil, "BORDER")
                line:SetTexture(B.WHITE)
                line:SetHeight(2)
                local rad = (B.db and B.db.cornerRadius) or 10
                line:SetPoint("TOPLEFT", tt, "TOPLEFT", rad, -1)
                line:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -rad, -1)
                line:Hide()
                tt.buiAccentLine = line
            end
        else
            tt:SetBackdrop({
                bgFile = B.SOLID,
                edgeFile = B.SOLID,
                tile = false,
                tileSize = 0,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local pr, pg, pb = B:GetPanelColor()
            tt:SetBackdropColor(pr, pg, pb, 0.92)
            tt:SetBackdropBorderColor(0.20, 0.20, 0.20, 1.0)
        end
        if type(tt.SetScale) == "function" then
            tt:SetScale((B.db and B.db.tooltipScale) or 0.82)
        end
    end
    self.SkinTooltip = function(_, tt) SkinTooltip(tt) end

    -- Class / reaction colour: border (sharp) or accent line (round).
    local function ColorTooltip(tt, r, g, b)
        if B:IsRound() then
            if tt.buiAccentLine then
                tt.buiAccentLine:SetVertexColor(r, g, b)
                tt.buiAccentLine:Show()
            end
        else
            tt:SetBackdropBorderColor(r, g, b, 1.0)
        end
    end

    -- The accent line belongs to unit tooltips only.
    if type(GameTooltip.GetScript) == "function" then
        local origHide = GameTooltip:GetScript("OnHide")
        GameTooltip:SetScript("OnHide", function()
            if this.buiAccentLine then this.buiAccentLine:Hide() end
            if origHide then origHide() end
        end)
    end

    SkinTooltip(GameTooltip)
    SkinTooltip(ItemRefTooltip)

    if GameTooltipStatusBar then
        GameTooltipStatusBar:SetHeight(4)
        GameTooltipStatusBar:ClearAllPoints()
        GameTooltipStatusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -2)
        GameTooltipStatusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -2)
        GameTooltipStatusBar:SetStatusBarTexture(self:GetBarTexture())
    end

    -- Hook GameTooltip_SetDefaultAnchor to anchor cleanly under MeterFrame / right HUD stack
    if type(GameTooltip_SetDefaultAnchor) == "function" then
        local orig_Anchor = GameTooltip_SetDefaultAnchor
        GameTooltip_SetDefaultAnchor = function(tooltip, parent)
            orig_Anchor(tooltip, parent)
            local anchorMode = (B.db and B.db.tooltipAnchor) or "hud"
            if tooltip and parent and anchorMode == "cursor" then
                tooltip:SetOwner(parent, "ANCHOR_CURSOR")
                SkinTooltip(tooltip)
            elseif tooltip and parent and anchorMode == "default" then
                SkinTooltip(tooltip)
            elseif tooltip and parent then
                tooltip:ClearAllPoints()
                local anchorFrame = nil
                if BUI_EncounterFrame and BUI_EncounterFrame:IsShown() then
                    anchorFrame = BUI_EncounterFrame
                elseif BUI_TimerFrame and BUI_TimerFrame:IsShown() then
                    anchorFrame = BUI_TimerFrame
                end

                if anchorFrame then
                    tooltip:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -8)
                elseif BUI_BossMeterFrame and BUI_BossMeterFrame:IsShown() then
                    tooltip:SetPoint("BOTTOMRIGHT", BUI_BossMeterFrame, "TOPRIGHT", 0, 8)
                elseif BUI_MeterFrame and BUI_MeterFrame:IsShown() then
                    tooltip:SetPoint("BOTTOMRIGHT", BUI_MeterFrame, "TOPRIGHT", 0, 8)
                else
                    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 28)
                end
                SkinTooltip(tooltip)
            end
        end
    end

    local tooltipWatcher = CreateFrame("Frame")
    tooltipWatcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    tooltipWatcher:SetScript("OnEvent", function()
        if UnitExists("mouseover") and GameTooltip:IsShown() then
            if B.db and B.db.tooltipHideInCombat and type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then
                GameTooltip:Hide()
                return
            end
            SkinTooltip(GameTooltip)
            if B.db and B.db.tooltipReactionColor == false then return end
            if UnitIsPlayer("mouseover") then
                local loc, cl = UnitClass("mouseover")
                local cc = B:ResolveClassColor(cl) or B:ResolveClassColor(loc)
                if cc then
                    ColorTooltip(GameTooltip, cc.r, cc.g, cc.b)
                end
            else
                local reaction = UnitReaction("mouseover", "player")
                if reaction then
                    if reaction <= 2 then
                        ColorTooltip(GameTooltip, 0.85, 0.20, 0.20)
                    elseif reaction <= 4 then
                        ColorTooltip(GameTooltip, 0.85, 0.75, 0.20)
                    else
                        ColorTooltip(GameTooltip, 0.20, 0.80, 0.25)
                    end
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
--  Boot
-------------------------------------------------------------------------------
local boot = CreateFrame("Frame", "BlackwellUIBoot", UIParent)
BlackwallUIBoot = BlackwellUIBoot -- Compatibility alias
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("VARIABLES_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("DISPLAY_SIZE_CHANGED")
boot:RegisterEvent("UI_SCALE_CHANGED")
boot:RegisterEvent("PLAYER_LOGOUT")

-- Short greeting in the player's language, once per game session: GetTime()
-- keeps counting across /reload, so a reload within the hour stays quiet.
function B:ShowWelcome()
    if not self.db or self.db.welcomeMessage == false or not DEFAULT_CHAT_FRAME then return end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local last = tonumber(self.db.welcomeShownAt)
    if last and now >= last and now - last < 3600 then return end
    self.db.welcomeShownAt = now
    local r, g, b = self:GetAccent()
    local hex = string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    DEFAULT_CHAT_FRAME:AddMessage(hex .. self.L["Thanks for running BlackwellUI! GLHF out there and go wreck some bosses. o7"] .. "|r")
end

local function Build()
    B:InitDB()
    if not B.built then
        B:BuildModules()
        B.built = true
        B:RefreshTheme()
        B:InitTooltip()
        B:CheckResolution()
        B.lastNameplatesWanted = B:IsEnabled("nameplates")
        B:ShowWelcome()
    end
    B:SyncHud()
    B:Tick()
end

boot:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "BlackwellUI" or arg1 == "BlackwallUI" then B:InitDB() end
    elseif event == "VARIABLES_LOADED" then
        B:InitDB()
        B:SyncCombatText()
        B:SyncHud()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Build()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        B:CheckResolution()
    elseif event == "PLAYER_LOGOUT" then
        B:RestoreAllStock()
    end
end)

local acc = 0
local hudAcc = 0
boot:SetScript("OnUpdate", function()
    if not B.built then return end
    local dt = arg1 or 0
    acc = acc + dt
    hudAcc = hudAcc + dt
    if acc >= 0.1 then
        acc = 0
        B:Tick()
    end
    -- Re-check (compare only) every 5 seconds.
    if hudAcc >= 5 then
        hudAcc = 0
        B:SyncHud()
    end
end)
