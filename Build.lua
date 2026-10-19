-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Build.lua
--  Cyberpunk Cooldown Manager / Active Build Spells & Aura Buff Tracker.
--  - Centered layout between Hero and Target frames
--  - 36x36 crisp square tiles with 1px black border
--  - Trimmed icons (0.08, 0.92, 0.08, 0.92) eliminating Blizzard borders
--  - Dark swipe cooldown overlay with bold Expressway countdown timer in center
--  - Stack / Rank number in bottom-right corner
--  - Full dictionary matching all Azeroth Survivors abilities
--  - Aura Buff Bars with square spell icons and full spell-color matching bars
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Build & Cooldowns"

local MAX_TILES = 8
local TILE_SIZE = 36
local TILE_GAP = 4
local MAX_BUFFS = 5
local BUFF_WIDTH = 220
local BUFF_HEIGHT = 16

local spellIcons = {}
local buffMax = {}

-------------------------------------------------------------------------------
--  Azeroth Survivors Master Ability Icons Dictionary
-------------------------------------------------------------------------------
local ABILITY_ICONS = {
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
    ["hurricane"] = "Interface\\Icons\\Spell_Nature_Lightning",
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

local function NormalizeName(str)
    if not str or str == "" then return "" end
    local s = string.lower(str)
    s = string.gsub(s, "^%d+%.%s*", "")
    s = string.gsub(s, "%s*%(.-%)", "")
    s = string.gsub(s, "%s+", "_")
    s = string.gsub(s, "%-+", "_")
    s = string.gsub(s, ":+", "")
    s = string.gsub(s, "'+", "")
    return s
end

local function GetAbilityIcon(nameOrId)
    if not nameOrId or nameOrId == "" then
        return nil
    end

    local norm = NormalizeName(nameOrId)

    -- Dynamic weapon icon for Melee / Weapon swings
    if norm == "melee" or norm == "attack" or norm == "auto_attack" or norm == "autoattack" or norm == "swing" or norm == "physical" or norm == "hero_melee" then
        if GetInventoryItemTexture then
            local wTex = GetInventoryItemTexture("player", 16)
            if wTex and wTex ~= "" then
                return wTex
            end
        end
        return "Interface\\Icons\\INV_Sword_04"
    end

    -- Dynamic weapon icon for Ranged / Auto Shot
    if norm == "shoot" or norm == "auto_shot" or norm == "autoshot" or norm == "ranged" or norm == "bow" then
        if GetInventoryItemTexture then
            local rTex = GetInventoryItemTexture("player", 18)
            if rTex and rTex ~= "" then
                return rTex
            end
        end
        return "Interface\\Icons\\INV_Weapon_Bow_07"
    end

    -- Dynamic weapon icon for Wand
    if norm == "wand" or norm == "shoot_wand" then
        if GetInventoryItemTexture then
            local wandTex = GetInventoryItemTexture("player", 18)
            if wandTex and wandTex ~= "" then
                return wandTex
            end
        end
        return "Interface\\Icons\\INV_Wand_01"
    end

    -- 1. Direct dictionary match
    if ABILITY_ICONS[nameOrId] then
        return ABILITY_ICONS[nameOrId]
    end
    if ABILITY_ICONS[norm] then
        return ABILITY_ICONS[norm]
    end

    -- 2. Scanned spellbook icons
    if spellIcons and spellIcons[nameOrId] then
        return spellIcons[nameOrId]
    end
    if spellIcons and spellIcons[norm] then
        return spellIcons[norm]
    end

    -- 3. Stripped trailing punctuation/rank
    local stripped = string.gsub(norm, "_+$", "")
    if ABILITY_ICONS[stripped] then
        return ABILITY_ICONS[stripped]
    end

    -- 4. Prefix search in dictionary
    if string.len(stripped) >= 4 then
        for k, v in pairs(ABILITY_ICONS) do
            if string.find(k, "^" .. stripped) then
                return v
            end
        end
    end

    -- 5. Spell Buff DB match
    if SPELL_BUFF_DB and SPELL_BUFF_DB[nameOrId] then
        return SPELL_BUFF_DB[nameOrId].icon
    end
    if SPELL_BUFF_DB and SPELL_BUFF_DB[norm] then
        return SPELL_BUFF_DB[norm].icon
    end

    return nil
end

B.GetAbilityIcon = function(self, nameOrId)
    local ic = GetAbilityIcon(nameOrId)
    if not ic and GetInventoryItemTexture then
        -- Last resort fallback for physical attacks: check mainhand
        local wTex = GetInventoryItemTexture("player", 16)
        if wTex and wTex ~= "" then return wTex end
    end
    return ic or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-------------------------------------------------------------------------------
--  Aura Buff Master Database (Spell IDs, Names, Icons, and Matching Colors)
-------------------------------------------------------------------------------
local SPELL_BUFF_DB = {
    -- Shrines
    ["shrine_of_haste"] = { name = "Shrine of Haste", icon = "Interface\\Icons\\Spell_Nature_BloodLust", color = { r = 1.00, g = 0.82, b = 0.00 } },
    ["shrine of haste"] = { name = "Shrine of Haste", icon = "Interface\\Icons\\Spell_Nature_BloodLust", color = { r = 1.00, g = 0.82, b = 0.00 } },
    ["shrine_of_damage"] = { name = "Shrine of Damage", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", color = { r = 1.00, g = 0.40, b = 0.10 } },
    ["shrine of damage"] = { name = "Shrine of Damage", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", color = { r = 1.00, g = 0.40, b = 0.10 } },
    ["shrine_of_power"] = { name = "Shrine of Power", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", color = { r = 1.00, g = 0.40, b = 0.10 } },
    ["shrine of power"] = { name = "Shrine of Power", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", color = { r = 1.00, g = 0.40, b = 0.10 } },
    ["shrine_of_protection"] = { name = "Shrine of Protection", icon = "Interface\\Icons\\INV_Shield_05", color = { r = 0.20, g = 0.60, b = 1.00 } },
    ["shrine of protection"] = { name = "Shrine of Protection", icon = "Interface\\Icons\\INV_Shield_05", color = { r = 0.20, g = 0.60, b = 1.00 } },
    ["shrine_of_healing"] = { name = "Shrine of Healing", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity", color = { r = 0.20, g = 0.90, b = 0.35 } },
    ["shrine of healing"] = { name = "Shrine of Healing", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity", color = { r = 0.20, g = 0.90, b = 0.35 } },

    -- Warrior Buffs & Shouts (Spell IDs 6673, 5242, 6192, 11549, 11550, 11551, 25289)
    ["6673"]  = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["5242"]  = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["6192"]  = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["11549"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["11550"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["11551"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["25289"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["battle_shout"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },
    ["battle shout"] = { name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", color = { r = 0.85, g = 0.50, b = 0.18 } },

    ["18499"] = { name = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian", color = { r = 0.90, g = 0.25, b = 0.15 } },
    ["berserker_rage"] = { name = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian", color = { r = 0.90, g = 0.25, b = 0.15 } },
    ["berserker rage"] = { name = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian", color = { r = 0.90, g = 0.25, b = 0.15 } },

    ["1719"]  = { name = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike", color = { r = 1.00, g = 0.15, b = 0.15 } },
    ["recklessness"] = { name = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike", color = { r = 1.00, g = 0.15, b = 0.15 } },

    ["12292"] = { name = "Death Wish", icon = "Interface\\Icons\\Spell_Shadow_DeathPact", color = { r = 0.80, g = 0.10, b = 0.20 } },
    ["death_wish"] = { name = "Death Wish", icon = "Interface\\Icons\\Spell_Shadow_DeathPact", color = { r = 0.80, g = 0.10, b = 0.20 } },
    ["death wish"] = { name = "Death Wish", icon = "Interface\\Icons\\Spell_Shadow_DeathPact", color = { r = 0.80, g = 0.10, b = 0.20 } },

    ["12328"] = { name = "Sweeping Strikes", icon = "Interface\\Icons\\Ability_Rogue_SliceDice", color = { r = 0.88, g = 0.40, b = 0.12 } },
    ["sweeping_strikes"] = { name = "Sweeping Strikes", icon = "Interface\\Icons\\Ability_Rogue_SliceDice", color = { r = 0.88, g = 0.40, b = 0.12 } },
    ["sweeping strikes"] = { name = "Sweeping Strikes", icon = "Interface\\Icons\\Ability_Rogue_SliceDice", color = { r = 0.88, g = 0.40, b = 0.12 } },

    ["2687"]  = { name = "Bloodrage", icon = "Interface\\Icons\\Ability_Racial_BloodRage", color = { r = 0.80, g = 0.15, b = 0.15 } },
    ["bloodrage"] = { name = "Bloodrage", icon = "Interface\\Icons\\Ability_Racial_BloodRage", color = { r = 0.80, g = 0.15, b = 0.15 } },

    ["871"]   = { name = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", color = { r = 0.45, g = 0.55, b = 0.70 } },
    ["shield_wall"] = { name = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", color = { r = 0.45, g = 0.55, b = 0.70 } },
    ["shield wall"] = { name = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", color = { r = 0.45, g = 0.55, b = 0.70 } },

    ["12975"] = { name = "Last Stand", icon = "Interface\\Icons\\Spell_Holy_AshesToAshes", color = { r = 0.90, g = 0.75, b = 0.25 } },
    ["last_stand"] = { name = "Last Stand", icon = "Interface\\Icons\\Spell_Holy_AshesToAshes", color = { r = 0.90, g = 0.75, b = 0.25 } },
    ["last stand"] = { name = "Last Stand", icon = "Interface\\Icons\\Spell_Holy_AshesToAshes", color = { r = 0.90, g = 0.75, b = 0.25 } },

    ["12880"] = { name = "Enrage", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", color = { r = 0.95, g = 0.20, b = 0.10 } },
    ["enrage"] = { name = "Enrage", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", color = { r = 0.95, g = 0.20, b = 0.10 } },

    ["12966"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },
    ["12967"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },
    ["12968"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },
    ["12969"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },
    ["12970"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },
    ["flurry"] = { name = "Flurry", icon = "Interface\\Icons\\Ability_GhoulFrenzy", color = { r = 0.90, g = 0.35, b = 0.10 } },

    -- Racials
    ["23234"] = { name = "Blood Fury", icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", color = { r = 0.90, g = 0.15, b = 0.15 } },
    ["20572"] = { name = "Blood Fury", icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", color = { r = 0.90, g = 0.15, b = 0.15 } },
    ["blood_fury"] = { name = "Blood Fury", icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", color = { r = 0.90, g = 0.15, b = 0.15 } },
    ["blood fury"] = { name = "Blood Fury", icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", color = { r = 0.90, g = 0.15, b = 0.15 } },

    ["26669"] = { name = "Berserking", icon = "Interface\\Icons\\Racial_Troll_Berserk", color = { r = 0.95, g = 0.40, b = 0.10 } },
    ["berserking"] = { name = "Berserking", icon = "Interface\\Icons\\Racial_Troll_Berserk", color = { r = 0.95, g = 0.40, b = 0.10 } },

    ["20594"] = { name = "Stoneform", icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength", color = { r = 0.65, g = 0.65, b = 0.65 } },
    ["stoneform"] = { name = "Stoneform", icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength", color = { r = 0.65, g = 0.65, b = 0.65 } },

    ["7744"]  = { name = "Will of the Forsaken", icon = "Interface\\Icons\\Spell_Shadow_RaiseDead", color = { r = 0.55, g = 0.25, b = 0.70 } },
    ["will_of_the_forsaken"] = { name = "Will of the Forsaken", icon = "Interface\\Icons\\Spell_Shadow_RaiseDead", color = { r = 0.55, g = 0.25, b = 0.70 } },

    -- Shaman / Bloodlust
    ["2825"]  = { name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust", color = { r = 0.95, g = 0.20, b = 0.05 } },
    ["bloodlust"] = { name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust", color = { r = 0.95, g = 0.20, b = 0.05 } },

    -- Rogue
    ["13750"] = { name = "Adrenaline Rush", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", color = { r = 0.95, g = 0.80, b = 0.15 } },
    ["adrenaline_rush"] = { name = "Adrenaline Rush", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", color = { r = 0.95, g = 0.80, b = 0.15 } },
    ["13877"] = { name = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", color = { r = 0.90, g = 0.70, b = 0.20 } },
    ["blade_flurry"] = { name = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", color = { r = 0.90, g = 0.70, b = 0.20 } },
    ["5171"]  = { name = "Slice and Dice", icon = "Interface\\Icons\\Ability_Rogue_SliceDice", color = { r = 0.85, g = 0.85, b = 0.25 } },
    ["slice_and_dice"] = { name = "Slice and Dice", icon = "Interface\\Icons\\Ability_Rogue_SliceDice", color = { r = 0.85, g = 0.85, b = 0.25 } },
    ["2983"]  = { name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint", color = { r = 0.30, g = 0.80, b = 0.90 } },
    ["sprint"] = { name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint", color = { r = 0.30, g = 0.80, b = 0.90 } },
    ["5277"]  = { name = "Evasion", icon = "Interface\\Icons\\Spell_Shadow_ShadowWard", color = { r = 0.40, g = 0.75, b = 0.40 } },
    ["evasion"] = { name = "Evasion", icon = "Interface\\Icons\\Spell_Shadow_ShadowWard", color = { r = 0.40, g = 0.75, b = 0.40 } },

    -- Priest
    ["17"]    = { name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", color = { r = 0.95, g = 0.85, b = 0.45 } },
    ["pw_shield"] = { name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", color = { r = 0.95, g = 0.85, b = 0.45 } },
    ["power_word_shield"] = { name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", color = { r = 0.95, g = 0.85, b = 0.45 } },
    ["1243"]  = { name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", color = { r = 0.90, g = 0.80, b = 0.50 } },
    ["power_word_fortitude"] = { name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", color = { r = 0.90, g = 0.80, b = 0.50 } },
    ["10060"] = { name = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", color = { r = 1.00, g = 0.85, b = 0.20 } },
    ["power_infusion"] = { name = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", color = { r = 1.00, g = 0.85, b = 0.20 } },
    ["139"]   = { name = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew", color = { r = 0.40, g = 0.90, b = 0.50 } },
    ["renew"] = { name = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew", color = { r = 0.40, g = 0.90, b = 0.50 } },

    -- Mage
    ["1459"]  = { name = "Arcane Intellect", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", color = { r = 0.35, g = 0.75, b = 1.00 } },
    ["arcane_intellect"] = { name = "Arcane Intellect", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", color = { r = 0.35, g = 0.75, b = 1.00 } },
    ["12042"] = { name = "Arcane Power", icon = "Interface\\Icons\\Spell_Nature_Lightning", color = { r = 0.40, g = 0.60, b = 1.00 } },
    ["arcane_power"] = { name = "Arcane Power", icon = "Interface\\Icons\\Spell_Nature_Lightning", color = { r = 0.40, g = 0.60, b = 1.00 } },
    ["11426"] = { name = "Ice Barrier", icon = "Interface\\Icons\\Spell_Ice_Lament", color = { r = 0.30, g = 0.70, b = 1.00 } },
    ["ice_barrier"] = { name = "Ice Barrier", icon = "Interface\\Icons\\Spell_Ice_Lament", color = { r = 0.30, g = 0.70, b = 1.00 } },
    ["12051"] = { name = "Evocation", icon = "Interface\\Icons\\Spell_Nature_Purge", color = { r = 0.30, g = 0.85, b = 0.95 } },
    ["evocation"] = { name = "Evocation", icon = "Interface\\Icons\\Spell_Nature_Purge", color = { r = 0.30, g = 0.85, b = 0.95 } },
    ["12043"] = { name = "Presence of Mind", icon = "Interface\\Icons\\Spell_Nature_EnchantArmor", color = { r = 0.60, g = 0.40, b = 0.95 } },
    ["presence_of_mind"] = { name = "Presence of Mind", icon = "Interface\\Icons\\Spell_Nature_EnchantArmor", color = { r = 0.60, g = 0.40, b = 0.95 } },

    -- Paladin
    ["19740"] = { name = "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", color = { r = 0.95, g = 0.65, b = 0.20 } },
    ["blessing_of_might"] = { name = "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", color = { r = 0.95, g = 0.65, b = 0.20 } },
    ["20217"] = { name = "Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_MageArmor", color = { r = 0.90, g = 0.85, b = 0.30 } },
    ["blessing_of_kings"] = { name = "Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_MageArmor", color = { r = 0.90, g = 0.85, b = 0.30 } },
    ["19742"] = { name = "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", color = { r = 0.40, g = 0.70, b = 0.95 } },
    ["blessing_of_wisdom"] = { name = "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", color = { r = 0.40, g = 0.70, b = 0.95 } },
    ["1044"]  = { name = "Blessing of Freedom", icon = "Interface\\Icons\\Spell_Holy_SealOfValor", color = { r = 0.95, g = 0.75, b = 0.15 } },
    ["blessing_of_freedom"] = { name = "Blessing of Freedom", icon = "Interface\\Icons\\Spell_Holy_SealOfValor", color = { r = 0.95, g = 0.75, b = 0.15 } },
    ["1022"]  = { name = "Blessing of Protection", icon = "Interface\\Icons\\Spell_Holy_BlessingOfProtection", color = { r = 0.90, g = 0.80, b = 0.30 } },
    ["blessing_of_protection"] = { name = "Blessing of Protection", icon = "Interface\\Icons\\Spell_Holy_BlessingOfProtection", color = { r = 0.90, g = 0.80, b = 0.30 } },
    ["642"]   = { name = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention", color = { r = 1.00, g = 0.92, b = 0.40 } },
    ["divine_shield"] = { name = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention", color = { r = 1.00, g = 0.92, b = 0.40 } },

    -- Druid
    ["22812"] = { name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", color = { r = 0.60, g = 0.45, b = 0.25 } },
    ["barkskin"] = { name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", color = { r = 0.60, g = 0.45, b = 0.25 } },
    ["29166"] = { name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning", color = { r = 0.30, g = 0.85, b = 0.95 } },
    ["innervate"] = { name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning", color = { r = 0.30, g = 0.85, b = 0.95 } },
    ["774"]   = { name = "Rejuvenation", icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", color = { r = 0.35, g = 0.85, b = 0.30 } },
    ["rejuvenation"] = { name = "Rejuvenation", icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", color = { r = 0.35, g = 0.85, b = 0.30 } },
    ["8936"]  = { name = "Regrowth", icon = "Interface\\Icons\\Spell_Nature_ResistNature", color = { r = 0.40, g = 0.90, b = 0.35 } },
    ["regrowth"] = { name = "Regrowth", icon = "Interface\\Icons\\Spell_Nature_ResistNature", color = { r = 0.40, g = 0.90, b = 0.35 } },
}

local COLOR_PALETTES = {
    { r = 0.85, g = 0.50, b = 0.18 }, -- Amber / Warrior
    { r = 0.90, g = 0.15, b = 0.15 }, -- Crimson / Berserk
    { r = 1.00, g = 0.40, b = 0.05 }, -- Fire Orange
    { r = 0.20, g = 0.70, b = 1.00 }, -- Frost Cyan
    { r = 0.20, g = 0.90, b = 0.35 }, -- Nature Emerald
    { r = 0.70, g = 0.30, b = 0.95 }, -- Shadow Purple
    { r = 0.95, g = 0.85, b = 0.35 }, -- Holy Gold
    { r = 0.30, g = 0.80, b = 0.90 }, -- Arcane Blue
}

local function GetSpellColor(name)
    local s = string.lower(name or "")
    if string.find(s, "haste") or string.find(s, "holy") or string.find(s, "light") or string.find(s, "divine") or string.find(s, "blessing") or string.find(s, "might") then
        return { r = 0.95, g = 0.82, b = 0.20 }
    elseif string.find(s, "blood") or string.find(s, "fury") or string.find(s, "rage") or string.find(s, "berserk") or string.find(s, "death") or string.find(s, "reckless") then
        return { r = 0.90, g = 0.15, b = 0.15 }
    elseif string.find(s, "damage") or string.find(s, "power") or string.find(s, "fire") or string.find(s, "flame") or string.find(s, "burn") then
        return { r = 1.00, g = 0.40, b = 0.05 }
    elseif string.find(s, "protection") or string.find(s, "defense") or string.find(s, "shield") or string.find(s, "wall") or string.find(s, "iron") or string.find(s, "armor") then
        return { r = 0.25, g = 0.60, b = 1.00 }
    elseif string.find(s, "healing") or string.find(s, "regen") or string.find(s, "nature") or string.find(s, "life") or string.find(s, "renew") or string.find(s, "growth") then
        return { r = 0.20, g = 0.90, b = 0.35 }
    elseif string.find(s, "frost") or string.find(s, "ice") or string.find(s, "cold") or string.find(s, "chill") or string.find(s, "barrier") then
        return { r = 0.25, g = 0.75, b = 1.00 }
    elseif string.find(s, "shadow") or string.find(s, "dark") or string.find(s, "curse") or string.find(s, "plague") or string.find(s, "void") then
        return { r = 0.65, g = 0.25, b = 0.85 }
    elseif string.find(s, "arcane") or string.find(s, "intellect") or string.find(s, "mana") or string.find(s, "mind") or string.find(s, "evo") then
        return { r = 0.40, g = 0.65, b = 1.00 }
    elseif string.find(s, "shout") or string.find(s, "strike") or string.find(s, "slam") or string.find(s, "flurry") or string.find(s, "enrage") then
        return { r = 0.85, g = 0.50, b = 0.18 }
    end

    local hash = 0
    for idx = 1, string.len(s) do
        hash = hash + string.byte(s, idx)
    end
    local palIdx = math.mod(hash, table.getn(COLOR_PALETTES)) + 1
    return COLOR_PALETTES[palIdx]
end

local scanTooltip = nil
local function ResolveBuffInfo(rawSpell, timeLeft)
    local key = tostring(rawSpell or "")

    -- 1. Exact match in SPELL_BUFF_DB
    if SPELL_BUFF_DB[key] then
        local entry = SPELL_BUFF_DB[key]
        return entry.name, entry.icon, entry.color
    end

    -- 2. Normalized match in SPELL_BUFF_DB
    local norm = NormalizeName(key)
    if SPELL_BUFF_DB[norm] then
        local entry = SPELL_BUFF_DB[norm]
        return entry.name, entry.icon, entry.color
    end

    -- 3. Dynamic in-game player aura scan (for active buffs on player)
    if type(GetPlayerBuff) == "function" and timeLeft then
        for bi = 0, 31 do
            local bIdx = GetPlayerBuff(bi, "HELPFUL")
            if bIdx and bIdx >= 0 then
                local dur = GetPlayerBuffTimeLeft(bIdx) or 0
                if math.abs(dur - timeLeft) <= 2.5 then
                    local tex = GetPlayerBuffTexture(bIdx)
                    if not scanTooltip then
                        scanTooltip = CreateFrame("GameTooltip", "BUI_BuffScanTooltip", UIParent, "GameTooltipTemplate")
                        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                    end
                    scanTooltip:ClearLines()
                    scanTooltip:SetPlayerBuff(bIdx)
                    local scannedName = BUI_BuffScanTooltipTextLeft1 and BUI_BuffScanTooltipTextLeft1:GetText()
                    if scannedName and scannedName ~= "" then
                        local col = GetSpellColor(scannedName)
                        return scannedName, tex, col
                    end
                end
            end
        end
    end

    -- 4. Ability icon lookup fallback
    local icon = GetAbilityIcon(key)
    if not icon then icon = GetAbilityIcon(norm) end
    if not icon then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end

    local displayName = key
    if tonumber(key) then
        displayName = "Spell " .. key
    else
        displayName = B:PrettyName(key)
    end

    local color = GetSpellColor(displayName)
    return displayName, icon, color
end

-------------------------------------------------------------------------------
--  Live Spellbook Scanner
-------------------------------------------------------------------------------
local spellIcons = {}
local spellBookIds = {}

local function ScanSpellbook()
    spellIcons = {}
    spellBookIds = {}
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
        if tex and tex ~= "" then
            spellIcons[name] = tex
            local norm = NormalizeName(name)
            spellIcons[norm] = tex
            spellBookIds[name] = i
            spellBookIds[norm] = i
            spellBookIds[string.lower(name)] = i
        end
        i = i + 1
    end
end

local spellbookWatcher = CreateFrame("Frame")
spellbookWatcher:RegisterEvent("SPELLS_CHANGED")
spellbookWatcher:SetScript("OnEvent", function()
    ScanSpellbook()
end)

function mod:Create()
    local f = CreateFrame("Frame", "BUI_BuildFrame", UIParent)
    EUI_BuildFrame = f -- Compatibility alias
    f:SetWidth(TILE_SIZE * 5 + TILE_GAP * 4)
    f:SetHeight(TILE_SIZE + 10)
    self.frame = f

    ScanSpellbook()

    ---------------------------------------------------------------------------
    --  Spell Tiles (Cooldown Manager Style)
    ---------------------------------------------------------------------------
    local tiles = {}
    for i = 1, MAX_TILES do
        local tile = CreateFrame("Button", nil, f)
        tile:SetWidth(TILE_SIZE)
        tile:SetHeight(TILE_SIZE)
        tile:EnableMouse(true)
        B:Backdrop(tile, 0.90)

        -- Icon texture (trimmed 0.08, 0.92, 0.08, 0.92 for clean flat square)
        local icon = tile:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tile.icon = icon

        -- Cooldown dark overlay (covers tile from bottom up)
        local cdOverlay = tile:CreateTexture(nil, "OVERLAY")
        B:Solid(cdOverlay, 0, 0, 0, 0.68)
        cdOverlay:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 1, 1)
        cdOverlay:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
        cdOverlay:SetHeight(0)
        cdOverlay:Hide()
        tile.cdOverlay = cdOverlay

        -- Cooldown countdown text (Expressway Bold, centered, size 13, outline)
        local cdFs = B:Font(tile, 13, "CENTER")
        cdFs:SetPoint("CENTER", tile, "CENTER", 0, 0)
        cdFs:SetTextColor(1, 1, 1)
        cdFs:Hide()
        tile.cdFs = cdFs

        -- Rank badge (bottom-right, gold accent)
        local rankFs = B:Font(tile, 10, "RIGHT")
        rankFs:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 1)
        rankFs:SetTextColor(1.0, 0.82, 0.10)
        rankFs:Hide()
        tile.rankFs = rankFs

        -- Tooltip handling (Full ability tooltip via GameTooltip:SetSpell)
        tile:SetScript("OnEnter", function()
            local sn = this.spellName
            if sn and sn ~= "" then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                local sId = spellBookIds[sn] or spellBookIds[NormalizeName(sn)] or spellBookIds[string.lower(sn)]
                if sId then
                    GameTooltip:SetSpell(sId, BOOKTYPE_SPELL)
                else
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(sn, 1, 1, 1)
                    if this.spellRank and tonumber(this.spellRank) and tonumber(this.spellRank) > 0 then
                        GameTooltip:AddLine("Rank " .. tostring(this.spellRank), 0.8, 0.8, 0.8)
                    end
                end
                if this.cdRest and this.cdRest > 0 then
                    GameTooltip:AddLine(string.format("Cooldown: %.1fs", this.cdRest), 1, 0.82, 0)
                end
                GameTooltip:Show()
            end
        end)

        tile:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        tile:Hide()
        tiles[i] = tile
    end
    f.tiles = tiles

    ---------------------------------------------------------------------------
    --  Buff Bars (stacked above the spell tiles with icons & spell colors)
    ---------------------------------------------------------------------------
    local buffContainer = CreateFrame("Frame", nil, f)
    buffContainer:SetWidth(BUFF_WIDTH)
    buffContainer:SetHeight(MAX_BUFFS * (BUFF_HEIGHT + 2))
    buffContainer:SetPoint("BOTTOM", f, "TOP", 0, 6)
    f.buffContainer = buffContainer

    local buffBars = {}
    for i = 1, MAX_BUFFS do
        local r = CreateFrame("Frame", nil, buffContainer)
        r:SetWidth(BUFF_WIDTH)
        r:SetHeight(BUFF_HEIGHT)
        r:SetPoint("BOTTOM", buffContainer, "BOTTOM", 0, (i - 1) * (BUFF_HEIGHT + 2))

        -- Square Icon tile on the left (16x16)
        local iconFrame = CreateFrame("Frame", nil, r)
        iconFrame:SetWidth(BUFF_HEIGHT)
        iconFrame:SetHeight(BUFF_HEIGHT)
        iconFrame:SetPoint("LEFT", r, "LEFT", 0, 0)
        B:Border(iconFrame, 0, 0, 0, 1)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon = icon

        -- Status bar on the right of the icon
        local bar = B:Bar(r, nil)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
        bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        r.bar = bar

        local nameFs = B:Font(bar, 9, "LEFT")
        nameFs:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameFs:SetWidth(150)
        nameFs:SetHeight(12)
        r.nameFs = nameFs

        local timeFs = B:Font(bar, 9, "RIGHT")
        timeFs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        timeFs:SetWidth(44)
        timeFs:SetHeight(12)
        r.timeFs = timeFs

        r:Hide()
        buffBars[i] = r
    end
    f.buffBars = buffBars

    -- Perfectly centered horizontally between Player (-240) and Target (+240) at Y = 140
    B:RegisterMover(f, "build", "Build & Cooldowns", "BOTTOM", "BOTTOM", 0, 140)
end

function mod:Update(state)
    local f = self.frame
    local spells = state.spells or {}
    local nSpells = table.getn(spells)
    if nSpells > MAX_TILES then nSpells = MAX_TILES end

    local spellsAge = state.spellsAge or 0

    -- Adjust width and position tiles centered
    local totalW = nSpells * TILE_SIZE + (nSpells > 1 and (nSpells - 1) * TILE_GAP or 0)
    if totalW < 100 then totalW = 100 end
    f:SetWidth(totalW)

    local startX = -totalW / 2 + TILE_SIZE / 2

    for i = 1, MAX_TILES do
        local tile = f.tiles[i]
        if i <= nSpells then
            local sp = spells[i]
            local spName = sp.spell or ""
            local spKey = sp.key or ""
            tile.spellName = (spName ~= "" and spName) or tostring(spKey)
            tile.spellRank = sp.rank

            tile:ClearAllPoints()
            local offsetX = startX + (i - 1) * (TILE_SIZE + TILE_GAP)
            tile:SetPoint("BOTTOM", f, "BOTTOM", offsetX, 0)
            tile:Show()

            -- Rank badge in bottom-right corner
            if sp.rank and tonumber(sp.rank) and tonumber(sp.rank) > 0 then
                tile.rankFs:SetText(tostring(sp.rank))
                tile.rankFs:Show()
            else
                tile.rankFs:Hide()
            end

            -- Resolve Icon Texture (Authentic WoW Icon)
            local lookup = (spName ~= "" and spName) or tostring(spKey)
            local iconTex = GetAbilityIcon(lookup)
            if not iconTex and spKey ~= "" then
                iconTex = GetAbilityIcon(spKey)
            end
            if not iconTex then
                iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
            end

            tile.icon:SetTexture(iconTex)
            tile.icon:Show()

            -- Cooldown calculations
            local cd = tonumber(sp.cd) or 0
            local cdmax = tonumber(sp.cdmax) or 0
            local rest = cd - spellsAge
            if rest < 0 then rest = 0 end
            tile.cdRest = rest

            if rest > 0 then
                -- Dark swipe height
                if cdmax > 0 then
                    local pct = rest / cdmax
                    if pct > 1 then pct = 1 end
                    local h = math.floor(pct * (TILE_SIZE - 2) + 0.5)
                    tile.cdOverlay:SetHeight(h)
                else
                    tile.cdOverlay:SetHeight(TILE_SIZE - 2)
                end
                tile.cdOverlay:Show()

                -- Countdown format
                if rest >= 60 then
                    local m = math.floor(rest / 60)
                    local s = math.floor(math.mod(rest, 60))
                    tile.cdFs:SetText(string.format("%d:%02d", m, s))
                elseif rest >= 3 then
                    tile.cdFs:SetText(string.format("%d", math.ceil(rest)))
                else
                    tile.cdFs:SetText(string.format("%.1f", rest))
                end
                tile.cdFs:Show()
            else
                tile.cdOverlay:Hide()
                tile.cdFs:Hide()
            end
        else
            tile:Hide()
        end
    end

    ---------------------------------------------------------------------------
    --  Buff Bars Update (Square Icons, Resolved Spell Names & Matching Colors)
    ---------------------------------------------------------------------------
    local buffs = state.buffs or {}
    local nBuffs = table.getn(buffs)
    local buffsAge = state.buffsAge or 0

    local maxRows = MAX_BUFFS
    if nBuffs < maxRows then maxRows = nBuffs end

    for i = 1, MAX_BUFFS do
        local r = f.buffBars[i]
        if i <= maxRows then
            local b = buffs[i]
            local rawSpell = b.spell or "Buff"
            local left = (tonumber(b.left) or 0) - buffsAge
            if left < 0 then left = 0 end

            local spName, iconTex, color = ResolveBuffInfo(rawSpell, left)

            if not buffMax[spName] or buffMax[spName] < left then
                buffMax[spName] = left
            end
            local bMax = buffMax[spName]
            if bMax <= 0 then bMax = 1 end

            local pct = left / bMax
            if pct > 1 then pct = 1 end
            r.bar:SetValue(pct)

            -- Set the matching color of the spell on the whole bar and dark tint on background
            B:SetBarColor(r.bar, color.r, color.g, color.b)
            local bg = r.bar.buiBg or r.bar.euiBg
            if bg then
                bg:SetVertexColor(color.r * 0.25, color.g * 0.25, color.b * 0.25)
                bg:SetAlpha(0.85)
            end

            -- Set icon texture
            r.icon:SetTexture(iconTex)

            -- Set clean spell name and duration text
            r.nameFs:SetText(spName)
            if left >= 60 then
                local m = math.floor(left / 60)
                local s = math.floor(math.mod(left, 60))
                r.timeFs:SetText(string.format("%d:%02d", m, s))
            else
                r.timeFs:SetText(string.format("%.1fs", left))
            end

            r:Show()
        else
            r:Hide()
        end
    end
end

B:RegisterModule("build", mod)
