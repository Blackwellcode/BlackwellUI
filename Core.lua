-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Core.lua
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
EllesmereUI = BlackwellUI -- Backwards compatibility alias
local E = BlackwellUI

B.version = "2.5.0-azs"
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
    ["EllesmereUI"]   = { r = 12/255,  g = 210/255, b = 157/255 },
    ["Forever"]       = { r = 220/255, g = 167/255, b = 127/255 },
    ["Horde"]         = { r = 255/255, g = 90/255,  b = 31/255  },
    ["Alliance"]      = { r = 63/255,  g = 167/255, b = 255/255 },
    ["Midnight"]      = { r = 120/255, g = 65/255,  b = 200/255 },
    ["Dark"]          = { r = 1,       g = 1,       b = 1       },
}
B.THEME_ORDER = { "Blackwell", "Crimson", "Amber", "Emerald", "Violet", "Monolith", "Class Colored", "Custom" }

-- Only power-of-two textures: the 1.12 renderer rejects other sizes.
B.BAR_TEXTURES = {
    ["Melli"]    = "Interface\\AddOns\\BlackwellUI\\media\\textures\\melli.tga",
    ["Atrocity"] = "Interface\\AddOns\\BlackwellUI\\media\\textures\\atrocity.tga",
    ["Flat"]     = "Interface\\Buttons\\WHITE8X8",
    ["Pixels"]   = "Interface\\AddOns\\BlackwellUI\\media\\textures\\pixels-fill.tga",
    ["Gradient"] = "Interface\\AddOns\\BlackwellUI\\media\\textures\\gradient-light.tga",
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
}
B.BAR_TEXTURE_ORDER = { "Melli", "Atrocity", "Flat", "Pixels", "Gradient", "Blizzard" }

B.FONTS = {
    ["Expressway"]      = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\Expressway.TTF",
    ["Expressway Bold"] = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\Expressway Bold.ttf",
    ["Fira Sans"]       = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\FiraSans Medium.ttf",
    ["Homespun"]        = "Interface\\AddOns\\BlackwellUI\\media\\fonts\\Homespun.ttf",
    ["Friz Quadrata"]   = "Fonts\\FRIZQT__.TTF",
}
B.FONT_ORDER = { "Expressway", "Expressway Bold", "Fira Sans", "Homespun", "Friz Quadrata" }

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

-- Unit kinds as AZS_UNITS / AZS_TARGET name them.
B.KIND_COLORS = {
    final    = { r = 0.80, g = 0.25, b = 1.00, label = "FINAL BOSS" },
    boss     = { r = 0.90, g = 0.20, b = 0.20, label = "BOSS" },
    elite    = { r = 1.00, g = 0.76, b = 0.20, label = "ELITE" },
    guardian = { r = 0.30, g = 0.60, b = 1.00, label = "GUARDIAN" },
    normal   = { r = 0.70, g = 0.70, b = 0.70, label = "" },
    dead     = { r = 0.40, g = 0.40, b = 0.40, label = "DEAD" },
}

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
    font = "Expressway",
    fontScaleMod = 0,
    chatFontSize = 12,
    scale = 1.0,
    autoScale = true,
    demo = false,
    replaceHud = true,
    hideBanners = false,
    hideLoot = false,
    meterMode = "done",
    colorHealthByClass = true,
    pinCaches = true,
    pinLairs = true,
    pinEdge = "clamp",
    filterChatSpam = true,
    modules = {
        actionbars = false,
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
    },
    positions = {},
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
        elseif EllesmereUIDB then
            BlackwellUIDB = EllesmereUIDB
        end
    end
    BlackwellUIDB = MergeDefaults(DEFAULTS, BlackwellUIDB)
    self.db = BlackwellUIDB
    if not self.db.layoutVersion or self.db.layoutVersion < 11 then
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
        end
        self.db.layoutVersion = 11
    end
    if self.db.autoScale == nil then
        self.db.autoScale = true
    end
    if self.db.autoScale then
        self.db.scale = self:GetOptimalScale()
    end
    if not self.THEMES[self.db.theme] then self.db.theme = DEFAULTS.theme end
    if not self.BAR_TEXTURES[self.db.barTexture] then self.db.barTexture = DEFAULTS.barTexture end
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
function B:GetClassColor()
    local token
    if AZS_ZONE and type(AZS_ZONE.cname) == "string" then
        token = string.upper((string.gsub(AZS_ZONE.cname, "%s", "")))
    end
    if not token or not self.CLASS_COLORS[token] then
        local _, t = UnitClass("player")
        token = t
    end
    local c = token and self.CLASS_COLORS[token]
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
    return self.FONTS[(self.db and self.db.font) or "Expressway"] or self.FALLBACK_FONT
end
B.GetFont = B.GetFontPath

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
    local edges = f.buiEdges or f.euiEdges
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
    f.euiEdges = edges
    self:SetBorderColor(f, cr, cg, cb, ca)
end

function B:SetBorderColor(f, r, g, b, a)
    local edges = f.buiEdges or f.euiEdges
    if not edges then return end
    for i = 1, 4 do
        self:Solid(edges[i], r, g, b, a or 1)
    end
end

function B:Backdrop(f, alpha)
    local bg = f.buiBg or f.euiBg
    local a = (self.db and self.db.backdropAlpha) or alpha or 0.85
    if bg then
        self:Solid(bg, 0.055, 0.050, 0.045, a)
        self:Border(f, 0, 0, 0, 1)
        return bg
    end
    bg = f:CreateTexture(nil, "BACKGROUND")
    self:Solid(bg, 0.055, 0.050, 0.045, a)
    bg:SetAllPoints(f)
    f.buiBg = bg
    f.euiBg = bg
    self:Border(f, 0, 0, 0, 1)
    table.insert(self.backdrops, { frame = f, bg = bg, baseAlpha = alpha or 0.85 })
    return bg
end

function B:ApplyFont(fs)
    local baseSize = fs.buiSize or fs.euiSize or 11
    local fontMod = (self.db and self.db.fontScaleMod) or 0
    local size = baseSize + fontMod
    if size < 7 then size = 7 end
    if size > 24 then size = 24 end
    fs:SetFont(self:GetFontPath(), size, fs.buiFlags or fs.euiFlags or "OUTLINE")
    if not fs:GetFont() then
        fs:SetFont(self.FALLBACK_FONT, size, fs.buiFlags or fs.euiFlags or "OUTLINE")
    end
end

function B:Font(parent, size, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
    fs.buiSize = size or 11
    fs.euiSize = fs.buiSize
    fs.buiFlags = "OUTLINE"
    fs.euiFlags = fs.buiFlags
    self:ApplyFont(fs)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(1, 1, 1)
    table.insert(self.fontStrings, fs)
    return fs
end

function B:SetBarColor(sb, r, g, b)
    sb.buiR, sb.buiG, sb.buiB = r, g, b
    sb.euiR, sb.euiG, sb.euiB = r, g, b
    sb:SetStatusBarColor(r, g, b)
end

-- Accent bars follow the theme on refresh.
function B:Bar(parent, name, r, g, b)
    local sb = CreateFrame("StatusBar", name, parent)
    sb:SetStatusBarTexture(self:GetBarTexture())
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    self:Solid(bg, 0, 0, 0, 0.55)
    bg:SetAllPoints(sb)
    sb.buiBg = bg
    sb.euiBg = bg
    self:Border(sb, 0, 0, 0, 1)
    if r then
        self:SetBarColor(sb, r, g, b)
    else
        sb.buiAccent = true
        sb.euiAccent = true
        local ar, ag, ab = self:GetAccent()
        self:SetBarColor(sb, ar, ag, ab)
    end
    table.insert(self.bars, sb)
    return sb
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
    h.title = self:Font(h, 10, "LEFT")
    h.title:SetPoint("LEFT", h, "LEFT", 6, 0)
    h.title:SetText(title or "")
    h.title:SetTextColor(0.92, 0.92, 0.92)
    h.value = self:Font(h, 10, "RIGHT")
    h.value:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    self:Accent(h.value, "text")
    return h
end

-------------------------------------------------------------------------------
--  Movers (/bui unlock)
-------------------------------------------------------------------------------
function B:ApplyPosition(frame)
    local key = frame.buiKey or frame.euiKey
    local pos = self.db and self.db.positions[key]
    local d = frame.buiDefault or frame.euiDefault
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint(d.point, UIParent, d.relPoint, d.x, d.y)
    end
end

function B:RegisterMover(frame, key, label, point, relPoint, x, y)
    frame.buiKey = key
    frame.euiKey = key
    frame.buiDefault = { point = point, relPoint = relPoint, x = x, y = y }
    frame.euiDefault = frame.buiDefault
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScale(self.db.scale)
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
            local k = f.buiKey or f.euiKey
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
    frame.euiMover = ov
    self.movers[key] = frame
    table.insert(self.moverOrder, key)
end

function B:SetUnlocked(flag)
    self.unlocked = flag and true or false
    for i = 1, table.getn(self.moverOrder) do
        local f = self.movers[self.moverOrder[i]]
        local ov = f.buiMover or f.euiMover
        if ov then
            if self.unlocked then ov:Show() else ov:Hide() end
        end
    end
    self:Tick()
end

function B:ResetPositions()
    self.db.positions = {}
    for i = 1, table.getn(self.moverOrder) do
        self:ApplyPosition(self.movers[self.moverOrder[i]])
    end
    self:Print("Positions reset.")
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
        f:SetScale(self.db.scale)
        self:ApplyPosition(f)
    end
end

-------------------------------------------------------------------------------
--  Stock Combat Text & Floating Numbers Suppression
-------------------------------------------------------------------------------
B.STOCK_COMBAT_CVARS = {
    "SHOW_COMBAT_TEXT",
    "enableFloatingCombatText",
    "fctCombatState",
    "fctDamage",
    "fctHealing",
    "fctAuras",
    "fctReactives",
    "fctLowManaHealth",
    "fctComboPoints",
    "fctEnergyGains",
    "fctPeriodicEnergyGains",
    "fctHonorGains",
    "fctReputation",
    "fctSpellMechanics",
    "fctAll",
    "fctTargetMode",
    "fctFriendlyHealers",
    "CombatDamage",
    "CombatLogPeriodicSpells",
    "PetMeleeDamage",
    "CombatHealing",
}

function B:SuppressStockCombatText()
    -- 1. Silence Blizzard CombatText frame
    if CombatText then
        if type(CombatText.UnregisterAllEvents) == "function" then
            CombatText:UnregisterAllEvents()
        end
        if type(CombatText.Hide) == "function" then
            CombatText:Hide()
        end
        if type(CombatText.SetScript) == "function" then
            CombatText:SetScript("OnUpdate", nil)
            CombatText:SetScript("OnEvent", nil)
        end
    end
    if type(CombatText_AddMessage) == "function" then
        CombatText_AddMessage = function() end
    end
    if type(CombatText_OnUpdate) == "function" then
        CombatText_OnUpdate = function() end
    end
    if type(CombatText_OnEvent) == "function" then
        CombatText_OnEvent = function() end
    end
    if type(CombatText_UpdateDisplayedMessages) == "function" then
        CombatText_UpdateDisplayedMessages = function() end
    end

    -- 2. Zero-out stock CVars (only if non-zero to prevent redundant engine writes)
    if type(GetCVar) == "function" and type(SetCVar) == "function" then
        local n = table.getn(self.STOCK_COMBAT_CVARS)
        for i = 1, n do
            local cv = self.STOCK_COMBAT_CVARS[i]
            local val = GetCVar(cv)
            if val and val ~= "0" then
                SetCVar(cv, "0")
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Stock run HUD (AZS_SetHudShown). The setting is a CVar the game keeps, so it
--  is written only when it differs from what we want: never in a loop.
-------------------------------------------------------------------------------
B.HUD_PARTS = { "clock", "bosses", "tally", "build", "meter", "banners", "loot" }
B.HUD_REPLACED_BY = {
    clock = "timer",
    bosses = "unitframes",
    tally = "databar",
    build = "build",
    meter = "meter",
}

function B:WantStockHud(part)
    local mod = self.HUD_REPLACED_BY[part]
    if mod then
        return not (self.db.replaceHud and self:IsEnabled(mod))
    end
    if part == "banners" then return not self.db.hideBanners end
    if part == "loot" then return not self.db.hideLoot end
    return true
end

function B:SyncHud()
    if not self.db then return end
    self:SuppressStockCombatText()
    if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return end
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
        bossMeter = {
            { name = "Mortal Strike", dmg = 185000, dps = 353, share = 45, proc = 0 },
            { name = "Whirlwind", dmg = 120000, dps = 229, share = 29, proc = 0 },
            { name = "Deep Wounds", dmg = 68000, dps = 129, share = 16, proc = 1 },
            { name = "Bladestorm", dmg = 42000, dps = 80, share = 10, proc = 0 },
        },
        bossMeterTotal = 415000,
        bossMeterDps = 792,
        taken = {
            { source = "Stitches", dmg = 19400 },
            { source = "Skeletal Fiend", dmg = 12800 },
            { source = "Plague Cloud", dmg = 10600 },
        },
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

function B:HasApi()
    return (type(AZS_GetPhase) == "function" or type(AZS_PHASE) == "string" or (type(AZS_RUN) == "table" and AZS_RUN.phase ~= nil)) and type(AZS_RUN) == "table"
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
    elseif AZS_RUN and AZS_RUN.phase then
        phase = AZS_RUN.phase
    end
    s.phase = phase
    s.active = (phase ~= nil)
    if not s.active then return s end

    s.time = (type(AZS_GetRunTime) == "function" and AZS_GetRunTime()) or (AZS_RUN and tonumber(AZS_RUN.t)) or 0
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
    s.taken = AZS_TAKEN or {}
    s.target = AZS_TARGET or { kind = "none" }
    return s
end

-------------------------------------------------------------------------------
--  Modules: one shared 10 Hz ticker drives every module
-------------------------------------------------------------------------------
-- mod = { label, Create(mod), Update(mod, state), frame }
function B:RegisterModule(key, mod)
    mod.key = key
    self.modules[key] = mod
    table.insert(self.moduleOrder, key)
end

function B:IsEnabled(key)
    return self.db and self.db.modules[key] ~= false
end

function B:BuildModules()
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if self:IsEnabled(mod.key) and not mod.frame then
            mod:Create()
            if mod.frame then mod.frame:Hide() end
        end
    end
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

    local s = self:GetState()
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod.frame then
            local shouldShow = self:IsEnabled(mod.key) and (s.active or mod.alwaysActive)
            if shouldShow then
                if not mod.frame:IsShown() then mod.frame:Show() end
                mod:Update(s)
            elseif mod.frame:IsShown() then
                mod.frame:Hide()
            end
        end
    end
end

function B:OnModulesChanged()
    if self:IsEnabled("nameplates") then
        if type(ShowNameplates) == "function" then ShowNameplates() end
    else
        if type(HideNameplates) == "function" then HideNameplates() end
    end
    local sct = self.modules["combattext"]
    if sct and type(sct.Update) == "function" then
        sct:Update()
    end
    self:BuildModules()
    self:SyncHud()
    self:Tick()
end

function B:RefreshTheme()
    local tex = self:GetBarTexture()
    local ar, ag, ab = self:GetAccent()
    local bAlpha = (self.db and self.db.backdropAlpha) or 0.85
    for i = 1, table.getn(self.backdrops) do
        local entry = self.backdrops[i]
        if entry.bg then
            entry.bg:SetAlpha(bAlpha)
        end
    end
    for i = 1, table.getn(self.bars) do
        local sb = self.bars[i]
        sb:SetStatusBarTexture(tex)
        if sb.buiAccent or sb.euiAccent then
            self:SetBarColor(sb, ar, ag, ab)
        else
            sb:SetStatusBarColor(sb.buiR or sb.euiR, sb.buiG or sb.euiG, sb.buiB or sb.euiB)
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
        tt:SetBackdrop({
            bgFile = B.SOLID,
            edgeFile = B.SOLID,
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        tt:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
        tt:SetBackdropBorderColor(0.20, 0.20, 0.20, 1.0)
        if type(tt.SetScale) == "function" then
            tt:SetScale(0.82)
        end
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
            if tooltip and parent then
                tooltip:ClearAllPoints()
                local anchorFrame = nil
                if BUI_EncounterFrame and BUI_EncounterFrame:IsShown() then
                    anchorFrame = BUI_EncounterFrame
                elseif BUI_TimerFrame and BUI_TimerFrame:IsShown() then
                    anchorFrame = BUI_TimerFrame
                elseif EUI_EncounterFrame and EUI_EncounterFrame:IsShown() then
                    anchorFrame = EUI_EncounterFrame
                elseif EUI_TimerFrame and EUI_TimerFrame:IsShown() then
                    anchorFrame = EUI_TimerFrame
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
            SkinTooltip(GameTooltip)
            if UnitIsPlayer("mouseover") then
                local _, cl = UnitClass("mouseover")
                local cc = cl and B.CLASS_COLORS[cl]
                if cc then
                    GameTooltip:SetBackdropBorderColor(cc.r, cc.g, cc.b, 1.0)
                end
            else
                local reaction = UnitReaction("mouseover", "player")
                if reaction then
                    if reaction <= 2 then
                        GameTooltip:SetBackdropBorderColor(0.85, 0.20, 0.20, 1.0)
                    elseif reaction <= 4 then
                        GameTooltip:SetBackdropBorderColor(0.85, 0.75, 0.20, 1.0)
                    else
                        GameTooltip:SetBackdropBorderColor(0.20, 0.80, 0.25, 1.0)
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
EllesmereUIBoot = BlackwellUIBoot -- Compatibility alias
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("VARIABLES_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("DISPLAY_SIZE_CHANGED")
boot:RegisterEvent("UI_SCALE_CHANGED")

local function Build()
    B:InitDB()
    if not B.built then
        B:BuildModules()
        B.built = true
        B:RefreshTheme()
        B:InitTooltip()
        B:CheckResolution()
    end
    if B:IsEnabled("nameplates") then
        if type(ShowNameplates) == "function" then ShowNameplates() end
    else
        if type(HideNameplates) == "function" then HideNameplates() end
    end
    B:SyncHud()
    B:Tick()
end

boot:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "BlackwellUI" or arg1 == "BlackwallUI" or arg1 == "EllesmereUI" then B:InitDB() end
    elseif event == "VARIABLES_LOADED" then
        B:InitDB()
        B:SuppressStockCombatText()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Build()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        B:CheckResolution()
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
