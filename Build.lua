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

-------------------------------------------------------------------------------
--  Magic Schools & Spell Colors (Cyberpunk / Authentic Azeroth Survivors)
-------------------------------------------------------------------------------
local SCHOOL_COLORS = {
    Holy     = { 1.00, 0.78, 0.15 },
    Fire     = { 1.00, 0.50, 0.10 },
    Frost    = { 0.30, 0.72, 1.00 },
    Nature   = { 0.30, 0.88, 0.25 },
    Shadow   = { 0.66, 0.38, 1.00 },
    Arcane   = { 1.00, 0.40, 0.85 },
    Physical = { 0.95, 0.27, 0.24 },
}

local SCHOOL_OF = {
    ["Consecration"] = "Holy", ["Exorcism"] = "Holy", ["Hammer of Wrath"] = "Holy", ["Holy Shock"] = "Holy",
    ["Holy Wrath"] = "Holy", ["Judgement"] = "Holy", ["Hammer of Justice"] = "Holy", ["Holy Light"] = "Holy",
    ["Divine Shield"] = "Holy", ["Holy Shield"] = "Holy", ["Redemption"] = "Holy", ["Smite"] = "Holy",
    ["Holy Nova"] = "Holy", ["Power Word: Shield"] = "Holy", ["Renew"] = "Holy", ["Holy Fire"] = "Holy",
    ["Shadow Word: Pain"] = "Shadow", ["Mind Blast"] = "Shadow", ["Mind Flay"] = "Shadow", ["Psychic Scream"] = "Shadow",
    ["Shadow Bolt"] = "Shadow", ["Corruption"] = "Shadow", ["Curse of Agony"] = "Shadow", ["Death Coil"] = "Shadow",
    ["Drain Life"] = "Shadow", ["Fear"] = "Shadow", ["Shadowmeld"] = "Shadow", ["Shadowburn"] = "Shadow",
    ["Flame Shock"] = "Fire", ["Magma Totem"] = "Fire", ["Searing Totem"] = "Fire", ["Fire Nova Totem"] = "Fire",
    ["Fireball"] = "Fire", ["Flamestrike"] = "Fire", ["Fire Blast"] = "Fire", ["Blast Wave"] = "Fire",
    ["Pyroblast"] = "Fire", ["Immolate"] = "Fire", ["Rain of Fire"] = "Fire", ["Hellfire"] = "Fire",
    ["Soul Fire"] = "Fire", ["Explosive Trap"] = "Fire", ["Immolation Trap"] = "Fire", ["Conflagrate"] = "Fire",
    ["Frost Shock"] = "Frost", ["Frostbolt"] = "Frost", ["Frost Nova"] = "Frost", ["Blizzard"] = "Frost",
    ["Cone of Cold"] = "Frost", ["Ice Barrier"] = "Frost", ["Frost Trap"] = "Frost", ["Freezing Trap"] = "Frost",
    ["Arcane Missiles"] = "Arcane", ["Arcane Explosion"] = "Arcane", ["Polymorph"] = "Arcane", ["Arcane Shot"] = "Arcane",
    ["Moonfire"] = "Arcane", ["Starfire"] = "Arcane", ["Hunter's Mark"] = "Arcane", ["Volley"] = "Arcane",
    ["Lightning Bolt"] = "Nature", ["Chain Lightning"] = "Nature", ["Earth Shock"] = "Nature", ["Lightning Shield"] = "Nature",
    ["Healing Wave"] = "Nature", ["Wrath"] = "Nature", ["Hurricane"] = "Nature", ["Entangling Roots"] = "Nature",
    ["Rejuvenation"] = "Nature", ["Regrowth"] = "Nature", ["Thorns"] = "Nature", ["Faerie Fire"] = "Nature",
    ["Serpent Sting"] = "Nature", ["Thunder Clap"] = "Nature",
    ["Cleave"] = "Physical", ["Whirlwind"] = "Physical", ["Mortal Strike"] = "Physical", ["Execute"] = "Physical",
    ["Rend"] = "Physical", ["Charge"] = "Physical", ["Intercept"] = "Physical", ["Heroic Leap"] = "Physical",
    ["Bladestorm"] = "Physical", ["Overpower"] = "Physical", ["Slam"] = "Physical", ["Sinister Strike"] = "Physical",
    ["Eviscerate"] = "Physical", ["Backstab"] = "Physical", ["Ambush"] = "Physical", ["Aimed Shot"] = "Physical",
    ["Multi-Shot"] = "Physical", ["Auto Shot"] = "Physical", ["Auto Attack"] = "Physical", ["Shoot"] = "Physical",
}

-------------------------------------------------------------------------------
--  Azeroth Survivors & Vanilla Spell ID to Canonical Name Master Lookup
-------------------------------------------------------------------------------
local SPELL_ID_TO_NAME = {
    -- Warrior
    ["845"] = "Cleave",
    ["1680"] = "Whirlwind",
    ["6343"] = "Thunder Clap",
    ["8198"] = "Thunder Clap",
    ["8204"] = "Thunder Clap",
    ["8205"] = "Thunder Clap",
    ["11580"] = "Thunder Clap",
    ["11581"] = "Thunder Clap",
    ["12294"] = "Mortal Strike",
    ["21551"] = "Mortal Strike",
    ["21552"] = "Mortal Strike",
    ["21553"] = "Mortal Strike",
    ["5308"] = "Execute",
    ["20658"] = "Execute",
    ["20660"] = "Execute",
    ["20661"] = "Execute",
    ["20662"] = "Execute",
    ["772"] = "Rend",
    ["6546"] = "Rend",
    ["6547"] = "Rend",
    ["6548"] = "Rend",
    ["11572"] = "Rend",
    ["11573"] = "Rend",
    ["11574"] = "Rend",
    ["100"] = "Charge",
    ["6178"] = "Charge",
    ["11578"] = "Charge",
    ["20252"] = "Intercept",
    ["6544"] = "Heroic Leap",
    ["46924"] = "Bladestorm",
    ["1719"] = "Recklessness",
    ["12292"] = "Death Wish",
    ["12328"] = "Sweeping Strikes",
    ["2687"] = "Bloodrage",
    ["6673"] = "Battle Shout",
    ["5242"] = "Battle Shout",
    ["6192"] = "Battle Shout",
    ["11549"] = "Battle Shout",
    ["11550"] = "Battle Shout",
    ["11551"] = "Battle Shout",
    ["25289"] = "Battle Shout",
    ["1160"] = "Demoralizing Shout",
    ["6190"] = "Demoralizing Shout",
    ["11554"] = "Demoralizing Shout",
    ["11555"] = "Demoralizing Shout",
    ["11556"] = "Demoralizing Shout",
    ["871"] = "Shield Wall",
    ["12975"] = "Last Stand",
    ["12880"] = "Enrage",
    ["12966"] = "Flurry",
    ["12967"] = "Flurry",
    ["12968"] = "Flurry",
    ["12969"] = "Flurry",
    ["12970"] = "Flurry",
    ["7384"] = "Overpower",
    ["7887"] = "Overpower",
    ["11584"] = "Overpower",
    ["11585"] = "Overpower",
    ["1464"] = "Slam",
    ["8820"] = "Slam",
    ["11604"] = "Slam",
    ["11605"] = "Slam",
    ["1715"] = "Hamstring",
    ["7372"] = "Hamstring",
    ["7373"] = "Hamstring",
    ["694"] = "Mocking Blow",
    ["355"] = "Taunt",
    ["676"] = "Disarm",
    ["6552"] = "Pummel",
    ["72"] = "Shield Bash",
    ["18499"] = "Berserker Rage",
    ["23881"] = "Bloodthirst",
    ["23892"] = "Bloodthirst",
    ["23893"] = "Bloodthirst",
    ["23894"] = "Bloodthirst",
    ["23922"] = "Shield Slam",
    ["12721"] = "Deep Wounds",

    -- Paladin
    ["26573"] = "Consecration",
    ["20116"] = "Consecration",
    ["20922"] = "Consecration",
    ["20923"] = "Consecration",
    ["20924"] = "Consecration",
    ["24239"] = "Consecration",
    ["879"] = "Exorcism",
    ["5614"] = "Exorcism",
    ["5615"] = "Exorcism",
    ["10312"] = "Exorcism",
    ["10313"] = "Exorcism",
    ["10314"] = "Exorcism",
    ["24275"] = "Hammer of Wrath",
    ["24274"] = "Hammer of Wrath",
    ["20473"] = "Holy Shock",
    ["20929"] = "Holy Shock",
    ["20930"] = "Holy Shock",
    ["2812"] = "Holy Wrath",
    ["10318"] = "Holy Wrath",
    ["20271"] = "Judgement",
    ["853"] = "Hammer of Justice",
    ["5588"] = "Hammer of Justice",
    ["5589"] = "Hammer of Justice",
    ["10308"] = "Hammer of Justice",
    ["635"] = "Holy Light",
    ["639"] = "Holy Light",
    ["647"] = "Holy Light",
    ["1026"] = "Holy Light",
    ["1042"] = "Holy Light",
    ["3472"] = "Holy Light",
    ["10328"] = "Holy Light",
    ["10329"] = "Holy Light",
    ["25292"] = "Holy Light",
    ["19750"] = "Flash of Light",
    ["19939"] = "Flash of Light",
    ["19940"] = "Flash of Light",
    ["19941"] = "Flash of Light",
    ["19942"] = "Flash of Light",
    ["19943"] = "Flash of Light",
    ["642"] = "Divine Shield",
    ["1020"] = "Divine Shield",
    ["20925"] = "Holy Shield",
    ["20927"] = "Holy Shield",
    ["20928"] = "Holy Shield",
    ["1044"] = "Blessing of Freedom",
    ["1022"] = "Blessing of Protection",

    -- Hunter
    ["75"] = "Auto Shot",
    ["3044"] = "Arcane Shot",
    ["14281"] = "Arcane Shot",
    ["14282"] = "Arcane Shot",
    ["14283"] = "Arcane Shot",
    ["14284"] = "Arcane Shot",
    ["14285"] = "Arcane Shot",
    ["14286"] = "Arcane Shot",
    ["14287"] = "Arcane Shot",
    ["2643"] = "Multi-Shot",
    ["14288"] = "Multi-Shot",
    ["14289"] = "Multi-Shot",
    ["14290"] = "Multi-Shot",
    ["25294"] = "Multi-Shot",
    ["1978"] = "Serpent Sting",
    ["13549"] = "Serpent Sting",
    ["13550"] = "Serpent Sting",
    ["13551"] = "Serpent Sting",
    ["13552"] = "Serpent Sting",
    ["13553"] = "Serpent Sting",
    ["13554"] = "Serpent Sting",
    ["13555"] = "Serpent Sting",
    ["25295"] = "Serpent Sting",
    ["1510"] = "Volley",
    ["14294"] = "Volley",
    ["14295"] = "Volley",
    ["13813"] = "Explosive Trap",
    ["14316"] = "Explosive Trap",
    ["14317"] = "Explosive Trap",
    ["5116"] = "Concussive Shot",
    ["19434"] = "Aimed Shot",
    ["20900"] = "Aimed Shot",
    ["20901"] = "Aimed Shot",
    ["20902"] = "Aimed Shot",
    ["20903"] = "Aimed Shot",
    ["20904"] = "Aimed Shot",
    ["1130"] = "Hunter's Mark",
    ["14323"] = "Distracting Shot",
    ["13809"] = "Frost Trap",
    ["14311"] = "Freezing Trap",
    ["13795"] = "Immolation Trap",
    ["19263"] = "Deterrence",
    ["19574"] = "Bestial Wrath",

    -- Rogue
    ["1752"] = "Sinister Strike",
    ["1757"] = "Sinister Strike",
    ["1758"] = "Sinister Strike",
    ["1759"] = "Sinister Strike",
    ["1760"] = "Sinister Strike",
    ["8621"] = "Sinister Strike",
    ["11293"] = "Sinister Strike",
    ["11294"] = "Sinister Strike",
    ["2098"] = "Eviscerate",
    ["6715"] = "Eviscerate",
    ["6716"] = "Eviscerate",
    ["6717"] = "Eviscerate",
    ["6718"] = "Eviscerate",
    ["8623"] = "Eviscerate",
    ["8624"] = "Eviscerate",
    ["11299"] = "Eviscerate",
    ["11300"] = "Eviscerate",
    ["13877"] = "Blade Flurry",
    ["1943"] = "Rupture",
    ["2077"] = "Rupture",
    ["2078"] = "Rupture",
    ["11267"] = "Rupture",
    ["11268"] = "Rupture",
    ["11269"] = "Rupture",
    ["1776"] = "Gouge",
    ["1777"] = "Gouge",
    ["8629"] = "Gouge",
    ["11285"] = "Gouge",
    ["11286"] = "Gouge",
    ["13750"] = "Adrenaline Rush",
    ["53"] = "Backstab",
    ["2589"] = "Backstab",
    ["2590"] = "Backstab",
    ["2591"] = "Backstab",
    ["8721"] = "Backstab",
    ["11279"] = "Backstab",
    ["11280"] = "Backstab",
    ["11281"] = "Backstab",
    ["5171"] = "Slice and Dice",
    ["6774"] = "Slice and Dice",
    ["8676"] = "Ambush",
    ["8724"] = "Ambush",
    ["8725"] = "Ambush",
    ["11265"] = "Ambush",
    ["11266"] = "Ambush",
    ["14177"] = "Cold Blood",
    ["11305"] = "Sprint",
    ["1856"] = "Vanish",

    -- Priest
    ["585"] = "Smite",
    ["591"] = "Smite",
    ["598"] = "Smite",
    ["984"] = "Smite",
    ["1004"] = "Smite",
    ["6060"] = "Smite",
    ["10933"] = "Smite",
    ["10934"] = "Smite",
    ["589"] = "Shadow Word: Pain",
    ["594"] = "Shadow Word: Pain",
    ["970"] = "Shadow Word: Pain",
    ["992"] = "Shadow Word: Pain",
    ["2767"] = "Shadow Word: Pain",
    ["10892"] = "Shadow Word: Pain",
    ["10893"] = "Shadow Word: Pain",
    ["10894"] = "Shadow Word: Pain",
    ["8092"] = "Mind Blast",
    ["8102"] = "Mind Blast",
    ["8103"] = "Mind Blast",
    ["8104"] = "Mind Blast",
    ["8105"] = "Mind Blast",
    ["8106"] = "Mind Blast",
    ["10945"] = "Mind Blast",
    ["10946"] = "Mind Blast",
    ["10947"] = "Mind Blast",
    ["15237"] = "Holy Nova",
    ["15430"] = "Holy Nova",
    ["15431"] = "Holy Nova",
    ["27799"] = "Holy Nova",
    ["27800"] = "Holy Nova",
    ["27801"] = "Holy Nova",
    ["17"] = "Power Word: Shield",
    ["592"] = "Power Word: Shield",
    ["600"] = "Power Word: Shield",
    ["3747"] = "Power Word: Shield",
    ["6065"] = "Power Word: Shield",
    ["6066"] = "Power Word: Shield",
    ["10898"] = "Power Word: Shield",
    ["10899"] = "Power Word: Shield",
    ["10900"] = "Power Word: Shield",
    ["10901"] = "Power Word: Shield",
    ["139"] = "Renew",
    ["6074"] = "Renew",
    ["6075"] = "Renew",
    ["6076"] = "Renew",
    ["6077"] = "Renew",
    ["6078"] = "Renew",
    ["10927"] = "Renew",
    ["10928"] = "Renew",
    ["10929"] = "Renew",
    ["25299"] = "Renew",
    ["15407"] = "Mind Flay",
    ["17311"] = "Mind Flay",
    ["17312"] = "Mind Flay",
    ["17313"] = "Mind Flay",
    ["17314"] = "Mind Flay",
    ["18807"] = "Mind Flay",
    ["8122"] = "Psychic Scream",
    ["14914"] = "Holy Fire",

    -- Shaman
    ["403"] = "Lightning Bolt",
    ["529"] = "Lightning Bolt",
    ["548"] = "Lightning Bolt",
    ["915"] = "Lightning Bolt",
    ["943"] = "Lightning Bolt",
    ["6041"] = "Lightning Bolt",
    ["10391"] = "Lightning Bolt",
    ["10392"] = "Lightning Bolt",
    ["15207"] = "Lightning Bolt",
    ["15208"] = "Lightning Bolt",
    ["421"] = "Chain Lightning",
    ["930"] = "Chain Lightning",
    ["2860"] = "Chain Lightning",
    ["10605"] = "Chain Lightning",
    ["8042"] = "Earth Shock",
    ["8044"] = "Earth Shock",
    ["8045"] = "Earth Shock",
    ["8046"] = "Earth Shock",
    ["10412"] = "Earth Shock",
    ["10413"] = "Earth Shock",
    ["10414"] = "Earth Shock",
    ["8024"] = "Flame Shock",
    ["8027"] = "Flame Shock",
    ["8030"] = "Flame Shock",
    ["10447"] = "Flame Shock",
    ["10448"] = "Flame Shock",
    ["29228"] = "Flame Shock",
    ["8056"] = "Frost Shock",
    ["8058"] = "Frost Shock",
    ["10472"] = "Frost Shock",
    ["10473"] = "Frost Shock",
    ["324"] = "Lightning Shield",
    ["325"] = "Lightning Shield",
    ["905"] = "Lightning Shield",
    ["945"] = "Lightning Shield",
    ["8134"] = "Lightning Shield",
    ["10431"] = "Lightning Shield",
    ["10432"] = "Lightning Shield",
    ["8004"] = "Healing Wave",
    ["8008"] = "Healing Wave",
    ["8010"] = "Healing Wave",
    ["10395"] = "Healing Wave",
    ["10396"] = "Healing Wave",
    ["1064"] = "Chain Heal",
    ["10622"] = "Chain Heal",
    ["10623"] = "Chain Heal",
    ["3599"] = "Searing Totem",
    ["8190"] = "Magma Totem",
    ["1535"] = "Fire Nova Totem",

    -- Mage
    ["133"] = "Fireball",
    ["143"] = "Fireball",
    ["145"] = "Fireball",
    ["3140"] = "Fireball",
    ["8400"] = "Fireball",
    ["8401"] = "Fireball",
    ["8402"] = "Fireball",
    ["10148"] = "Fireball",
    ["10149"] = "Fireball",
    ["10150"] = "Fireball",
    ["10151"] = "Fireball",
    ["116"] = "Frostbolt",
    ["205"] = "Frostbolt",
    ["837"] = "Frostbolt",
    ["7322"] = "Frostbolt",
    ["8406"] = "Frostbolt",
    ["8407"] = "Frostbolt",
    ["8408"] = "Frostbolt",
    ["10179"] = "Frostbolt",
    ["10180"] = "Frostbolt",
    ["10181"] = "Frostbolt",
    ["5143"] = "Arcane Missiles",
    ["5144"] = "Arcane Missiles",
    ["5145"] = "Arcane Missiles",
    ["8416"] = "Arcane Missiles",
    ["8417"] = "Arcane Missiles",
    ["10211"] = "Arcane Missiles",
    ["10212"] = "Arcane Missiles",
    ["122"] = "Frost Nova",
    ["865"] = "Frost Nova",
    ["6131"] = "Frost Nova",
    ["10230"] = "Frost Nova",
    ["1449"] = "Arcane Explosion",
    ["8437"] = "Arcane Explosion",
    ["8438"] = "Arcane Explosion",
    ["8439"] = "Arcane Explosion",
    ["10201"] = "Arcane Explosion",
    ["10202"] = "Arcane Explosion",
    ["10"] = "Blizzard",
    ["6141"] = "Blizzard",
    ["8427"] = "Blizzard",
    ["10185"] = "Blizzard",
    ["10186"] = "Blizzard",
    ["10187"] = "Blizzard",
    ["2120"] = "Flamestrike",
    ["2121"] = "Flamestrike",
    ["8422"] = "Flamestrike",
    ["8423"] = "Flamestrike",
    ["10215"] = "Flamestrike",
    ["10216"] = "Flamestrike",
    ["11366"] = "Pyroblast",
    ["12505"] = "Pyroblast",
    ["12522"] = "Pyroblast",
    ["12523"] = "Pyroblast",
    ["12524"] = "Pyroblast",
    ["12525"] = "Pyroblast",
    ["12526"] = "Pyroblast",
    ["18809"] = "Pyroblast",
    ["2136"] = "Fire Blast",
    ["2137"] = "Fire Blast",
    ["2138"] = "Fire Blast",
    ["8412"] = "Fire Blast",
    ["8413"] = "Fire Blast",
    ["10197"] = "Fire Blast",
    ["10199"] = "Fire Blast",
    ["120"] = "Cone of Cold",
    ["8492"] = "Cone of Cold",
    ["10159"] = "Cone of Cold",
    ["10160"] = "Cone of Cold",
    ["10161"] = "Cone of Cold",
    ["11426"] = "Ice Barrier",
    ["13031"] = "Ice Barrier",
    ["13032"] = "Ice Barrier",
    ["13033"] = "Ice Barrier",
    ["118"] = "Polymorph",

    -- Warlock
    ["686"] = "Shadow Bolt",
    ["695"] = "Shadow Bolt",
    ["705"] = "Shadow Bolt",
    ["1088"] = "Shadow Bolt",
    ["1106"] = "Shadow Bolt",
    ["7641"] = "Shadow Bolt",
    ["11659"] = "Shadow Bolt",
    ["11660"] = "Shadow Bolt",
    ["11661"] = "Shadow Bolt",
    ["25307"] = "Shadow Bolt",
    ["172"] = "Corruption",
    ["6222"] = "Corruption",
    ["6223"] = "Corruption",
    ["7648"] = "Corruption",
    ["11671"] = "Corruption",
    ["11672"] = "Corruption",
    ["25311"] = "Corruption",
    ["348"] = "Immolate",
    ["707"] = "Immolate",
    ["1094"] = "Immolate",
    ["2941"] = "Immolate",
    ["11665"] = "Immolate",
    ["11667"] = "Immolate",
    ["11668"] = "Immolate",
    ["25309"] = "Immolate",
    ["980"] = "Curse of Agony",
    ["1014"] = "Curse of Agony",
    ["6217"] = "Curse of Agony",
    ["11711"] = "Curse of Agony",
    ["11712"] = "Curse of Agony",
    ["11713"] = "Curse of Agony",
    ["5740"] = "Rain of Fire",
    ["6219"] = "Rain of Fire",
    ["11677"] = "Rain of Fire",
    ["11678"] = "Rain of Fire",
    ["1949"] = "Hellfire",
    ["11683"] = "Hellfire",
    ["11684"] = "Hellfire",
    ["6789"] = "Death Coil",
    ["17925"] = "Death Coil",
    ["17926"] = "Death Coil",
    ["689"] = "Drain Life",
    ["699"] = "Drain Life",
    ["709"] = "Drain Life",
    ["7651"] = "Drain Life",
    ["11699"] = "Drain Life",
    ["11700"] = "Drain Life",
    ["5782"] = "Fear",
    ["6215"] = "Fear",
    ["17877"] = "Shadowburn",
    ["17962"] = "Conflagrate",
    ["6353"] = "Soul Fire",

    -- Druid
    ["8921"] = "Moonfire",
    ["8924"] = "Moonfire",
    ["8925"] = "Moonfire",
    ["8926"] = "Moonfire",
    ["8927"] = "Moonfire",
    ["8928"] = "Moonfire",
    ["8929"] = "Moonfire",
    ["9833"] = "Moonfire",
    ["9834"] = "Moonfire",
    ["9835"] = "Moonfire",
    ["2912"] = "Starfire",
    ["8949"] = "Starfire",
    ["8950"] = "Starfire",
    ["8951"] = "Starfire",
    ["9875"] = "Starfire",
    ["9876"] = "Starfire",
    ["25298"] = "Starfire",
    ["5176"] = "Wrath",
    ["5177"] = "Wrath",
    ["5178"] = "Wrath",
    ["5179"] = "Wrath",
    ["5180"] = "Wrath",
    ["6780"] = "Wrath",
    ["8905"] = "Wrath",
    ["9912"] = "Wrath",
    ["774"] = "Rejuvenation",
    ["1058"] = "Rejuvenation",
    ["1430"] = "Rejuvenation",
    ["2090"] = "Rejuvenation",
    ["2091"] = "Rejuvenation",
    ["3627"] = "Rejuvenation",
    ["8910"] = "Rejuvenation",
    ["9839"] = "Rejuvenation",
    ["9840"] = "Rejuvenation",
    ["9841"] = "Rejuvenation",
    ["25299"] = "Rejuvenation",
    ["8936"] = "Regrowth",
    ["8938"] = "Regrowth",
    ["8939"] = "Regrowth",
    ["8940"] = "Regrowth",
    ["8941"] = "Regrowth",
    ["9750"] = "Regrowth",
    ["9856"] = "Regrowth",
    ["9857"] = "Regrowth",
    ["9858"] = "Regrowth",
    ["5185"] = "Healing Touch",
    ["467"] = "Thorns",
    ["339"] = "Entangling Roots",
    ["6807"] = "Maul",
    ["5221"] = "Shred",
    ["1079"] = "Rip",
    ["779"] = "Swipe",

    -- Racials
    ["20572"] = "Blood Fury",
    ["20594"] = "Stoneform",
    ["20549"] = "War Stomp",
    ["20577"] = "Cannibalize",
    ["20580"] = "Shadowmeld",
    ["20554"] = "Berserking",
    ["26297"] = "Berserking",
    ["28730"] = "Arcane Torrent",
    ["20552"] = "Escape Artist",
    ["20575"] = "Will of the Forsaken",
    ["20550"] = "Perception",
}

local KEY_NAMES = {
    ["sw_pain"] = "Shadow Word: Pain",
    ["pw_shield"] = "Power Word: Shield",
    ["demo_shout"] = "Demoralizing Shout",
    ["hunters_mark"] = "Hunter's Mark",
}

local function ResolveSpellKeyToName(key, spell)
    if spell and spell ~= "" and not tonumber(spell) then
        return spell
    end
    local kStr = tostring(key or "")
    if SPELL_ID_TO_NAME[kStr] then
        return SPELL_ID_TO_NAME[kStr]
    end
    if KEY_NAMES[kStr] then
        return KEY_NAMES[kStr]
    end
    if string.find(kStr, "_") then
        local name = string.gsub(kStr, "_", " ")
        local first = true
        return (string.gsub(name, "(%a)([%w']*)", function(initial, rest)
            local word = initial .. rest
            if not first and (word == "of" or word == "the" or word == "and") then
                return string.lower(word)
            end
            first = false
            return string.upper(initial) .. rest
        end))
    end
    if spell and spell ~= "" then
        return spell
    end
    return kStr
end


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

local ABILITY_DESCRIPTIONS = {
    ["cleave"] = { name = "Cleave", cost = "20 Rage", range = "Melee Range", cast = "Instant", desc = "A sweeping attack that strikes the target and an additional nearby ally, dealing weapon damage plus bonus damage." },
    ["whirlwind"] = { name = "Whirlwind", cost = "25 Rage", range = "8 yd radius", cast = "Instant", desc = "In a whirlwind of steel, attacks up to 4 nearby enemies, dealing weapon damage." },
    ["mortal_strike"] = { name = "Mortal Strike", cost = "30 Rage", range = "Melee Range", cast = "Instant", desc = "A vicious strike that deals weapon damage and wounds the target, reducing healing received by 50% for 10 sec." },
    ["thunder_clap"] = { name = "Thunder Clap", cost = "20 Rage", range = "8 yd radius", cast = "Instant", desc = "Blasts nearby enemies with thunder, increasing the time between their attacks by 10% and dealing Nature damage." },
    ["demo_shout"] = { name = "Demoralizing Shout", cost = "10 Rage", range = "10 yd radius", cast = "Instant", desc = "Reduces the melee attack power of all nearby enemies for 30 sec." },
    ["demoralizing_shout"] = { name = "Demoralizing Shout", cost = "10 Rage", range = "10 yd radius", cast = "Instant", desc = "Reduces the melee attack power of all nearby enemies for 30 sec." },
    ["battle_shout"] = { name = "Battle Shout", cost = "10 Rage", range = "20 yd radius", cast = "Instant", desc = "Increases the melee attack power of party members within 20 yards for 2 min." },
    ["bloodthirst"] = { name = "Bloodthirst", cost = "30 Rage", range = "Melee Range", cast = "Instant", desc = "Instantly attack the target for damage. In addition, the next 5 successful melee attacks restore health." },
    ["rend"] = { name = "Rend", cost = "10 Rage", range = "Melee Range", cast = "Instant", desc = "Wounds the target causing them to bleed for physical damage over 15 sec." },
    ["shield_slam"] = { name = "Shield Slam", cost = "20 Rage", range = "Melee Range", cast = "Instant", desc = "Slams the target with your shield, dealing damage modified by shield block value and dispelling 1 magic effect." },
    ["execute"] = { name = "Execute", cost = "15 Rage", range = "Melee Range", cast = "Instant", desc = "Attempts to finish off a wounded enemy, dealing massive physical damage. Only usable on enemies with less than 20% health." },
    ["bloodrage"] = { name = "Bloodrage", cost = "Health", range = "Self", cast = "Instant", desc = "Generates Rage immediately and over time at the cost of health." },
    ["charge"] = { name = "Charge", cost = "None", range = "8-25 yd range", cast = "Instant", desc = "Charges an enemy, generating Rage and stunning it for 1 sec." },
    ["rampage"] = { name = "Rampage", cost = "20 Rage", range = "Self", cast = "Instant", desc = "Goes on a rampage, increasing attack power and causing successful melee attacks to increase attack power further." },
    ["flurry"] = { name = "Flurry", cost = "Passive", range = "Self", cast = "Passive", desc = "Increases attack speed by 30% for your next 3 swings after dealing a critical strike." },
    ["sweeping_strikes"] = { name = "Sweeping Strikes", cost = "30 Rage", range = "Self", cast = "Instant", desc = "Your next 5 melee attacks strike an additional nearby opponent." },
    ["consecration"] = { name = "Consecration", cost = "Mana", range = "8 yd radius", cast = "Instant", desc = "Consecrates the land beneath the caster, dealing Holy damage over 8 sec to all enemies who enter the area." },
    ["exorcism"] = { name = "Exorcism", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Causes Holy damage to an Undead or Demon target." },
    ["hammer_of_wrath"] = { name = "Hammer of Wrath", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Hurls a hammer that strikes an enemy for Holy damage. Only usable on enemies with less than 20% health." },
    ["holy_shock"] = { name = "Holy Shock", cost = "Mana", range = "20 yd range", cast = "Instant", desc = "Blasts the target with Holy energy, causing Holy damage to an enemy or healing an ally." },
    ["holy_wrath"] = { name = "Holy Wrath", cost = "Mana", range = "10 yd radius", cast = "Instant", desc = "Sends bolts of holy power in all directions, causing Holy damage to all Undead and Demon targets and stunning them." },
    ["judgement"] = { name = "Judgement", cost = "Mana", range = "10 yd range", cast = "Instant", desc = "Unleashes the energy of a Seal upon an enemy, dealing damage or applying a debilitating judgement." },
    ["hammer_of_justice"] = { name = "Hammer of Justice", cost = "Mana", range = "10 yd range", cast = "Instant", desc = "Stuns the target for up to 6 sec." },
    ["divine_shield"] = { name = "Divine Shield", cost = "Mana", range = "Self", cast = "Instant", desc = "Protects the paladin from all damage and spells for 12 sec, but reduces attack speed by 50%." },
    ["auto_shot"] = { name = "Auto Shot", cost = "None", range = "8-35 yd range", cast = "Ranged", desc = "Continuously shoots the target with the equipped ranged weapon." },
    ["arcane_shot"] = { name = "Arcane Shot", cost = "Mana", range = "8-35 yd range", cast = "Instant", desc = "An instant shot that causes Arcane damage." },
    ["multi_shot"] = { name = "Multi-Shot", cost = "Mana", range = "8-35 yd range", cast = "Instant", desc = "Fires several missiles, hitting up to 3 targets for physical damage." },
    ["serpent_sting"] = { name = "Serpent Sting", cost = "Mana", range = "8-35 yd range", cast = "Instant", desc = "Stings the target, causing Nature damage over 15 sec." },
    ["volley"] = { name = "Volley", cost = "Mana", range = "35 yd range", cast = "Channeled", desc = "Continuously fires a volley of ammo into the target area, dealing damage to all targets every second for 6 sec." },
    ["explosive_trap"] = { name = "Explosive Trap", cost = "Mana", range = "Melee Range", cast = "Instant", desc = "Places a fire trap that explodes when an enemy approaches, causing Fire damage and burning nearby enemies." },
    ["concussive_shot"] = { name = "Concussive Shot", cost = "Mana", range = "8-35 yd range", cast = "Instant", desc = "Dazes the target, slowing movement speed by 50% for 4 sec." },
    ["aimed_shot"] = { name = "Aimed Shot", cost = "Mana", range = "8-35 yd range", cast = "3 sec cast", desc = "An aimed shot that increases ranged damage and reduces healing done to the target by 50%." },
    ["sinister_strike"] = { name = "Sinister Strike", cost = "45 Energy", range = "Melee Range", cast = "Instant", desc = "A vicious strike that deals physical weapon damage to the target." },
    ["eviscerate"] = { name = "Eviscerate", cost = "35 Energy", range = "Melee Range", cast = "Instant", desc = "Finishing move that causes damage per combo point." },
    ["blade_flurry"] = { name = "Blade Flurry", cost = "25 Energy", range = "Self", cast = "Instant", desc = "Increases attack speed by 20%. In addition, attacks strike an additional nearby opponent." },
    ["rupture"] = { name = "Rupture", cost = "25 Energy", range = "Melee Range", cast = "Instant", desc = "Finishing move that causes damage over time based on combo points." },
    ["gouge"] = { name = "Gouge", cost = "45 Energy", range = "Melee Range", cast = "Instant", desc = "Causes damage and incapacitates the opponent for up to 4 sec. Must be facing target." },
    ["adrenaline_rush"] = { name = "Adrenaline Rush", cost = "None", range = "Self", cast = "Instant", desc = "Increases energy regeneration rate by 100% for 15 sec." },
    ["backstab"] = { name = "Backstab", cost = "60 Energy", range = "Melee Range", cast = "Instant", desc = "Backstab the target, causing 150% weapon damage plus additional damage. Must be behind the target." },
    ["slice_and_dice"] = { name = "Slice and Dice", cost = "25 Energy", range = "Self", cast = "Instant", desc = "Finishing move that increases melee attack speed by 30%." },
    ["smite"] = { name = "Smite", cost = "Mana", range = "30 yd range", cast = "2.5 sec cast", desc = "Smites an enemy for Holy damage." },
    ["sw_pain"] = { name = "Shadow Word: Pain", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "A word of darkness that causes Shadow damage over 18 sec." },
    ["shadow_word_pain"] = { name = "Shadow Word: Pain", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "A word of darkness that causes Shadow damage over 18 sec." },
    ["mind_blast"] = { name = "Mind Blast", cost = "Mana", range = "30 yd range", cast = "1.5 sec cast", desc = "Blasts the target with shadowy energy for Shadow damage." },
    ["holy_nova"] = { name = "Holy Nova", cost = "Mana", range = "10 yd radius", cast = "Instant", desc = "Causes an explosion of holy light, dealing Holy damage to all nearby enemies and healing nearby party members." },
    ["pw_shield"] = { name = "Power Word: Shield", cost = "Mana", range = "40 yd range", cast = "Instant", desc = "Draws on the soul of the friendly target to shield them, absorbing damage for 30 sec." },
    ["renew"] = { name = "Renew", cost = "Mana", range = "40 yd range", cast = "Instant", desc = "Heals the target for health over 15 sec." },
    ["mind_flay"] = { name = "Mind Flay", cost = "Mana", range = "20 yd range", cast = "Channeled", desc = "Assaults the target's mind with Shadow energy, causing Shadow damage over 3 sec and slowing movement speed by 50%." },
    ["lightning_bolt"] = { name = "Lightning Bolt", cost = "Mana", range = "30 yd range", cast = "3 sec cast", desc = "Casts a bolt of lightning at the target for Nature damage." },
    ["chain_lightning"] = { name = "Chain Lightning", cost = "Mana", range = "30 yd range", cast = "2.5 sec cast", desc = "Hurls a lightning bolt at the enemy, dealing Nature damage and then jumping to nearby enemies." },
    ["earth_shock"] = { name = "Earth Shock", cost = "Mana", range = "20 yd range", cast = "Instant", desc = "Instantly shocks the target with concussive force, causing Nature damage and interrupting spellcasting." },
    ["flame_shock"] = { name = "Flame Shock", cost = "Mana", range = "20 yd range", cast = "Instant", desc = "Instantly burns the enemy with Fire damage and additional Fire damage over 12 sec." },
    ["frost_shock"] = { name = "Frost Shock", cost = "Mana", range = "20 yd range", cast = "Instant", desc = "Instantly shocks the target with frost, dealing Frost damage and slowing movement speed by 50% for 8 sec." },
    ["lightning_shield"] = { name = "Lightning Shield", cost = "Mana", range = "Self", cast = "Instant", desc = "Surrounds the caster with 3 balls of lightning that damage attackers." },
    ["fireball"] = { name = "Fireball", cost = "Mana", range = "35 yd range", cast = "3 sec cast", desc = "Hurls a fiery ball that causes Fire damage and burns the target for additional Fire damage over 8 sec." },
    ["frostbolt"] = { name = "Frostbolt", cost = "Mana", range = "30 yd range", cast = "2.5 sec cast", desc = "Launches a bolt of frost at the enemy, causing Frost damage and slowing movement speed by 40% for 9 sec." },
    ["arcane_missiles"] = { name = "Arcane Missiles", cost = "Mana", range = "30 yd range", cast = "Channeled", desc = "Launches magical missiles at the enemy, dealing Arcane damage every second for 5 sec." },
    ["frost_nova"] = { name = "Frost Nova", cost = "Mana", range = "10 yd radius", cast = "Instant", desc = "Blasts enemies near the caster for Frost damage and freezes them in place for up to 8 sec." },
    ["arcane_explosion"] = { name = "Arcane Explosion", cost = "Mana", range = "10 yd radius", cast = "Instant", desc = "Causes an explosion of arcane magic around the caster, dealing Arcane damage to all targets within 10 yds." },
    ["blizzard"] = { name = "Blizzard", cost = "Mana", range = "30 yd range", cast = "Channeled", desc = "Ice shards pelt the target area, dealing Frost damage over 8 sec and slowing movement speed by 30%." },
    ["flamestrike"] = { name = "Flamestrike", cost = "Mana", range = "30 yd range", cast = "3 sec cast", desc = "Calls down a pillar of fire, burning all enemies in the area for Fire damage and additional Fire damage over 8 sec." },
    ["pyroblast"] = { name = "Pyroblast", cost = "Mana", range = "35 yd range", cast = "6 sec cast", desc = "Hurls an immense fiery boulder that causes huge Fire damage and burns the target over 12 sec." },
    ["shadow_bolt"] = { name = "Shadow Bolt", cost = "Mana", range = "30 yd range", cast = "3 sec cast", desc = "Sends a shadowy bolt at the enemy, causing Shadow damage." },
    ["corruption"] = { name = "Corruption", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Corrupts the target, causing Shadow damage over 18 sec." },
    ["immolate"] = { name = "Immolate", cost = "Mana", range = "30 yd range", cast = "2 sec cast", desc = "Burns the enemy for Fire damage and an additional Fire damage over 15 sec." },
    ["curse_of_agony"] = { name = "Curse of Agony", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Curses the target with agony, causing Shadow damage over 24 sec." },
    ["rain_of_fire"] = { name = "Rain of Fire", cost = "Mana", range = "30 yd range", cast = "Channeled", desc = "Calls down a fiery rain to burn enemies in the area of effect for Fire damage over 8 sec." },
    ["hellfire"] = { name = "Hellfire", cost = "Mana", range = "Self", cast = "Channeled", desc = "Ignites the area surrounding the caster, dealing Fire damage to both enemies and the caster every second for 15 sec." },
    ["death_coil"] = { name = "Death Coil", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Causes the enemy target to flee in terror for 3 sec and deals Shadow damage, healing the caster for 100% of damage dealt." },
    ["drain_life"] = { name = "Drain Life", cost = "Mana", range = "20 yd range", cast = "Channeled", desc = "Drains health from the target over 5 sec, transferring health to the caster." },
    ["moonfire"] = { name = "Moonfire", cost = "Mana", range = "30 yd range", cast = "Instant", desc = "Burns the enemy for Arcane damage and then an additional Arcane damage over 12 sec." },
    ["starfire"] = { name = "Starfire", cost = "Mana", range = "30 yd range", cast = "3.5 sec cast", desc = "Causes Arcane damage to the target." },
    ["hurricane"] = { name = "Hurricane", cost = "Mana", range = "30 yd range", cast = "Channeled", desc = "Creates a violent storm in the target area, dealing Nature damage to enemies every second for 10 sec." },
    ["swipe"] = { name = "Swipe", cost = "20 Rage", range = "Melee Range", cast = "Instant", desc = "Swipes nearby enemies, dealing physical damage to up to 3 targets." },
}

local function GetAbilityIcon(nameOrId)
    if not nameOrId or nameOrId == "" then
        return nil
    end

    local norm = NormalizeName(nameOrId)

    -- Resolve spell ID or key alias to canonical name if needed
    local idResolved = SPELL_ID_TO_NAME[nameOrId] or SPELL_ID_TO_NAME[norm] or KEY_NAMES[nameOrId]
    if idResolved then
        local idNorm = NormalizeName(idResolved)
        if ABILITY_ICONS[idNorm] then return ABILITY_ICONS[idNorm] end
        if ABILITY_ICONS[idResolved] then return ABILITY_ICONS[idResolved] end
    end

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

    -- 4. Prefix search in dictionary (safe string.sub without pattern metacharacter hazards)
    if string.len(stripped) >= 4 then
        local lenS = string.len(stripped)
        for k, v in pairs(ABILITY_ICONS) do
            if string.len(k) >= lenS and string.sub(k, 1, lenS) == stripped then
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
    local book = BOOKTYPE_SPELL or "spell"
    local i = 1
    while true do
        local name, rank = GetSpellName(i, book)
        if not name then break end
        local tex = GetSpellTexture(i, book)
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
spellbookWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
spellbookWatcher:SetScript("OnEvent", function()
    ScanSpellbook()
end)

-------------------------------------------------------------------------------
--  Realtime DoT, Debuff & Totem Tracking Engine
-------------------------------------------------------------------------------
local dotTicks = {}    -- [normSpell] = { timestamp1, timestamp2, ... }
local shoutCasts = {}  -- [normSpell] = { at = time, last = time, count = N }
local fearHits = {}    -- [normSpell] = { timestamp1, timestamp2, ... }

local FEAR_NAMES = {
    ["psychic_scream"] = 3.5,
    ["intimidating_shout"] = 3.5,
    ["howl_of_terror"] = 3.5,
    ["fear"] = 3.5,
}

local dotWatcher = CreateFrame("Frame")
dotWatcher:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
dotWatcher:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
dotWatcher:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
dotWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
dotWatcher:SetScript("OnEvent", function()
    local msg = arg1 or ""
    local ev = event
    if ev == "PLAYER_REGEN_ENABLED" then
        dotTicks = {}
        shoutCasts = {}
        fearHits = {}
        return
    end

    if ev == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        local _, _, spell, target = string.find(msg, "^Your (.-) hits (.-) for %d+")
        if not spell then
            _, _, spell, target = string.find(msg, "^Your (.-) crits (.-) for %d+")
        end
        if spell then
            local norm = NormalizeName(spell)
            local now = GetTime()
            if norm == "demoralizing_shout" or norm == "demo_shout" then
                local cast = shoutCasts[norm]
                if not cast or (now - cast.last > 0.6) then
                    cast = { at = now, last = now, count = 0 }
                    shoutCasts[norm] = cast
                end
                cast.last = now
                cast.count = cast.count + 1
            elseif FEAR_NAMES[norm] then
                if not fearHits[norm] then fearHits[norm] = {} end
                table.insert(fearHits[norm], now)
            end
        end
        return
    end

    local _, _, spell = string.find(msg, " suffers %d+ .- from your (.-)%.")
    if not spell then
        _, _, spell = string.find(msg, " suffers %d+ .- damage from your (.-)%.")
    end
    if spell then
        local norm = NormalizeName(spell)
        if not dotTicks[norm] then dotTicks[norm] = {} end
        table.insert(dotTicks[norm], GetTime())
    end
end)

local function GetActiveDotCount(normSpell)
    if not normSpell or normSpell == "" then return 0 end
    local now = GetTime()

    if normSpell == "demoralizing_shout" or normSpell == "demo_shout" then
        local cast = shoutCasts["demoralizing_shout"] or shoutCasts["demo_shout"]
        if cast and (now - cast.at <= 6.0) then
            return cast.count
        end
        return 0
    end

    if FEAR_NAMES[normSpell] then
        local fList = fearHits[normSpell]
        if fList then
            local dur = FEAR_NAMES[normSpell]
            local valid = 0
            local cleaned = {}
            local n = table.getn(fList)
            for i = 1, n do
                local t = fList[i]
                if (now - t) <= dur then
                    table.insert(cleaned, t)
                    valid = valid + 1
                end
            end
            fearHits[normSpell] = cleaned
            return valid
        end
        return 0
    end

    local tList = dotTicks[normSpell]
    if tList then
        local cleaned = {}
        local n = table.getn(tList)
        local countInWindow = 0
        local lastTick = 0
        for i = 1, n do
            local t = tList[i]
            if (now - t) <= 2.5 then
                table.insert(cleaned, t)
                if t > lastTick then lastTick = t end
                if (now - t) <= 2.0 then
                    countInWindow = countInWindow + 1
                end
            end
        end
        dotTicks[normSpell] = cleaned

        if countInWindow > 0 and (now - lastTick <= 2.5) then
            local haste = tonumber(AZS_STATS and AZS_STATS.doth) or 0
            if haste < 0 then haste = 0 end
            local interval = 1.0 / (1.0 + haste)
            local expectedTicksPerMob = 2.0 / interval
            if expectedTicksPerMob <= 0 then expectedTicksPerMob = 2.0 end
            local mobs = math.floor((countInWindow / expectedTicksPerMob) + 0.5)
            if mobs < 1 then mobs = 1 end
            return mobs
        end
    end

    return 0
end

-------------------------------------------------------------------------------
--  Action Bar Slot Scanner & Dynamic Ability Tooltip Engine (Cyberpunk Style)
-------------------------------------------------------------------------------
local actionScan = CreateFrame("GameTooltip", "BUI_BuildScanTooltip", UIParent, "GameTooltipTemplate")
actionScan:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetActionSlotInfo(slot)
    if not (HasAction and HasAction(slot)) then
        return nil, nil, nil
    end
    actionScan:SetOwner(WorldFrame, "ANCHOR_NONE")
    actionScan:ClearLines()
    actionScan:SetAction(slot)
    local name = BUI_BuildScanTooltipTextLeft1 and BUI_BuildScanTooltipTextLeft1:GetText() or nil
    local rank = BUI_BuildScanTooltipTextRight1 and BUI_BuildScanTooltipTextRight1:GetText() or nil
    local tex = GetActionTexture and GetActionTexture(slot) or nil
    actionScan:Hide()
    return name, rank, tex
end

local function FindSpellActionSlot(index, spKey, spName, totalSpells)
    -- In Azeroth Survivors:
    -- Slotted spells occupy action slots 1 to 6.
    -- The racial spell occupies action slot 12.
    if totalSpells and index == totalSpells and totalSpells > 1 then
        if HasAction and HasAction(12) then
            return 12
        end
    end
    if HasAction and HasAction(index) then
        return index
    end
    -- Fallback: scan slots 1..12 to find matching name or texture
    local normTarget = NormalizeName(spName or spKey or "")
    if normTarget ~= "" and HasAction then
        for s = 1, 12 do
            if HasAction(s) then
                local aName = GetActionSlotInfo(s)
                if aName and NormalizeName(aName) == normTarget then
                    return s
                end
            end
        end
    end
    if index <= 6 then
        return index
    elseif totalSpells and index == totalSpells then
        return 12
    end
    return index
end

-------------------------------------------------------------------------------
--  Tooltip Line Counting & Cyberpunk Separators (WoW 1.12.1 Safe)
-------------------------------------------------------------------------------
local function GetTooltipNumLines(tip)
    if not tip then return 0 end
    if type(tip.NumLines) == "function" then
        local ok, n = pcall(tip.NumLines, tip)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    local name = tip:GetName()
    if not name then return 0 end
    local count = 0
    for i = 1, 30 do
        local fs = getglobal(name .. "TextLeft" .. i)
        if fs and fs:IsShown() and fs:GetText() and fs:GetText() ~= "" then
            count = i
        else
            break
        end
    end
    return count
end

if GameTooltip and not GameTooltip.NumLines then
    GameTooltip.NumLines = function(self)
        return GetTooltipNumLines(self)
    end
end

local activeBuildTile = nil
local writtenSignature = nil

local function Signature()
    local num = GetTooltipNumLines(GameTooltip)
    if num < 1 then return "" end
    local parts = {}
    for l = 1, num do
        local left = getglobal("GameTooltipTextLeft" .. l)
        local right = getglobal("GameTooltipTextRight" .. l)
        local lText = (left and left:GetText()) or ""
        local rText = (right and right:IsShown() and right:GetText()) or ""
        table.insert(parts, lText .. "~" .. rText)
    end
    return table.concat(parts, "^")
end

-- Thin 1px rule separators across GameTooltip
local tooltipRules = {}
local tooltipRulesUsed = 0

local function HideRules()
    for i = 1, table.getn(tooltipRules) do
        tooltipRules[i]:Hide()
    end
    tooltipRulesUsed = 0
end

local function AddRule(lineIndex, color)
    if not lineIndex or lineIndex <= 0 then return end
    tooltipRulesUsed = tooltipRulesUsed + 1
    local rule = tooltipRules[tooltipRulesUsed]
    if not rule then
        rule = GameTooltip:CreateTexture(nil, "ARTWORK")
        rule:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        rule:SetHeight(1)
        tooltipRules[tooltipRulesUsed] = rule
    end
    local text = getglobal("GameTooltipTextLeft" .. lineIndex)
    if text then
        rule:ClearAllPoints()
        rule:SetPoint("LEFT", text, "LEFT", 0, 0)
        rule:SetPoint("RIGHT", GameTooltip, "RIGHT", -10, 0)
        rule:SetVertexColor(color[1], color[2], color[3], 0.55)
        rule:Show()
    end
end

local function Plain(text)
    if not text then return "" end
    local s = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    return s
end

local function Hex(c)
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

local function Capital(text)
    if not text or text == "" then return "" end
    return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local function SplitCommaList(text)
    local items = {}
    if not text or text == "" then return items end
    local pos = 1
    local len = string.len(text)
    while pos <= len do
        local s, e = string.find(text, ",", pos, true)
        local piece = string.sub(text, pos, (s or (len + 1)) - 1)
        piece = string.gsub(piece, "^%s+", "")
        piece = string.gsub(piece, "%s+$", "")
        if piece ~= "" then
            table.insert(items, piece)
        end
        if not s then break end
        pos = e + 1
    end
    return items
end

local function SplitLines(text)
    local lines = {}
    if not text or text == "" then return lines end
    local pos = 1
    local len = string.len(text)
    while pos <= len do
        local s, e = string.find(text, "\n", pos, true)
        local piece = string.sub(text, pos, (s or (len + 1)) - 1)
        table.insert(lines, piece)
        if not s then break end
        pos = e + 1
    end
    return lines
end

local function HighlightText(text, school, schoolColor)
    text = string.gsub(text, "(%d[%d%.]*)(%%?)( ?)(%a*)", function(num, pct, sp, word)
        if pct ~= "" then
            return "|cffffc214" .. num .. "%|r" .. sp .. word
        elseif school and word == school then
            return Hex(schoolColor) .. num .. sp .. word .. "|r"
        elseif word == "sec" then
            return "|cff8cccff" .. num .. sp .. word .. "|r"
        elseif word == "yd" then
            return "|cff99f2bf" .. num .. sp .. word .. "|r"
        end
        return "|cffffffff" .. num .. "|r" .. sp .. word
    end)
    if school then
        text = string.gsub(text, school .. "|r damage", school .. " damage|r")
    end
    text = string.gsub(text, "|cffffffff([%d%.]+)|r damage", Hex(schoolColor) .. "%1 damage|r")
    for _, lead in pairs({ "[Hh]eals you for ", "Absorbs the next ", "Absorbs up to ", "Shields you against ", "Restores " }) do
        local s, e = string.find(text, lead)
        if s then
            text = string.gsub(text, lead .. "|cffffffff", lead .. "|cff4dff70")
        end
    end
    return text
end

local function ReadTooltipData(tip)
    local count = GetTooltipNumLines(tip)
    if count < 2 then return nil end

    local titleFs = getglobal("GameTooltipTextLeft1")
    local rankFs = getglobal("GameTooltipTextRight1")
    local rawTitle = titleFs and titleFs:GetText() or ""
    local title = Plain(rawTitle)
    if title == "" then return nil end

    -- Guard against re-reading already-formatted tooltips:
    if string.find(rawTitle, "|c", 1, true) then
        return nil
    end
    local line2Fs = getglobal("GameTooltipTextLeft2")
    local line2Text = line2Fs and line2Fs:GetText() or ""
    if string.find(line2Text, "·", 1, true) or string.find(line2Text, "|c", 1, true) then
        return nil
    end

    local rank = (rankFs and rankFs:IsShown()) and Plain(rankFs:GetText()) or nil

    local ability = {
        title = title,
        rank = rank,
        stats = {},
        description = {},
        sections = {},
        other = {},
        cast = nil,
        cooldown = nil,
        crit = nil,
    }

    local castLine = nil
    for line = 2, count do
        local lFs = getglobal("GameTooltipTextLeft" .. line)
        local rFs = getglobal("GameTooltipTextRight" .. line)
        local leftText = lFs and Plain(lFs:GetText()) or ""
        local rightText = (rFs and rFs:IsShown()) and Plain(rFs:GetText()) or ""

        if string.find(rightText, "cooldown", 1, true) or leftText == "Automatic" or leftText == "Passive" or string.find(leftText, "cast", 1, true) or string.find(leftText, "Instant", 1, true) or string.find(leftText, "Channeled", 1, true) or string.find(leftText, "Ranged", 1, true) then
            castLine = line
            ability.cast = (leftText ~= "") and leftText or "Instant"
            ability.cooldown = (rightText ~= "") and rightText or nil
            break
        end
    end

    local descStart = 2
    if castLine then
        for line = 2, castLine - 1 do
            local lFs = getglobal("GameTooltipTextLeft" .. line)
            local text = lFs and Plain(lFs:GetText()) or ""
            if text ~= "" then
                table.insert(ability.stats, text)
            end
        end
        descStart = castLine + 1
    end

    for line = descStart, count do
        local lFs = getglobal("GameTooltipTextLeft" .. line)
        local fullText = lFs and (lFs:GetText() or "") or ""
        local split = SplitLines(fullText)
        for p = 1, table.getn(split) do
            local text = Plain(split[p])
            if text ~= "" then
                local sUp, eUp = string.find(text, "^Upgrades: ")
                local sBon, eBon = string.find(text, "^Your bonuses: ")
                local sTal, eTal = string.find(text, "^Talents: ")
                local sCr, eCr, cPct, dPct = string.find(text, "^(%d+%%) chance to crit for (%d+%%) damage")

                if sUp then
                    local items = SplitCommaList(string.sub(text, eUp + 1))
                    table.insert(ability.sections, { title = "Upgrades", color = { 1.00, 0.82, 0.30 }, items = items })
                elseif sBon then
                    local items = SplitCommaList(string.sub(text, eBon + 1))
                    table.insert(ability.sections, { title = "Your bonuses", color = { 0.12, 1.00, 0.20 }, items = items })
                elseif sTal then
                    local items = SplitCommaList(string.sub(text, eTal + 1))
                    table.insert(ability.sections, { title = "Talents", color = { 0.44, 0.84, 1.00 }, items = items })
                elseif sCr then
                    ability.crit = cPct .. " crit · " .. dPct .. " dmg"
                else
                    table.insert(ability.description, text)
                end
            end
        end
    end

    return ability
end

local function FormatBlackwellAbilityTooltip(tip, cdRest, cdMax)
    local ability = ReadTooltipData(tip)
    if not ability then return false end

    HideRules()
    tip:ClearLines()

    local name = ability.title
    local school = SCHOOL_OF[name] or "Physical"
    for index = 1, table.getn(ability.description) do
        local d = ability.description[index]
        local s, e, word = string.find(d, "(%a+) damage")
        if word and SCHOOL_COLORS[word] then
            school = word
            break
        end
    end
    local tint = SCHOOL_COLORS[school] or SCHOOL_COLORS["Physical"]
    local what = school .. " damage"

    -- Title & Rank
    local rankStr = ability.rank or ""
    if rankStr ~= "" then
        tip:AddDoubleLine(name, rankStr, tint[1], tint[2], tint[3], 0.60, 0.60, 0.60)
    else
        tip:AddLine(name, tint[1], tint[2], tint[3])
    end

    -- Subtitle: School & Cast mode / Cooldown
    local castMode = ability.cast or "Instant"
    local cdText = ability.cooldown or ""
    if cdText ~= "" then
        cdText = string.gsub(cdText, "^([%d%.]+ sec)", "|cff8cccff%1|r")
    end
    tip:AddDoubleLine(Hex(tint) .. what .. "|r · " .. castMode, cdText, 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)

    -- Stats: Range / Radius / Crits
    local statStr = table.concat(ability.stats, " · ")
    if statStr ~= "" then
        statStr = string.gsub(statStr, "([%d%.]+ yd)", "|cff99f2bf%1|r")
    end
    local critStr = ability.crit or ""
    if critStr ~= "" then
        critStr = string.gsub(critStr, "(%d+%%)", "|cffffc214%1|r")
    end
    if statStr ~= "" or critStr ~= "" then
        tip:AddDoubleLine(statStr, critStr, 0.65, 0.65, 0.65, 1.00, 0.82, 0.10)
    end

    -- Rule / Divider before description
    if table.getn(ability.description) > 0 then
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), tint)
        for index = 1, table.getn(ability.description) do
            local highlighted = HighlightText(ability.description[index], school, tint)
            tip:AddLine(highlighted, 0.78, 0.78, 0.78, 1)
        end
    end

    -- Upgrades, Bonuses, Talents sections
    for s = 1, table.getn(ability.sections) do
        local sec = ability.sections[s]
        local col = sec.color
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), col)
        tip:AddLine(sec.title, col[1], col[2], col[3])
        for it = 1, table.getn(sec.items) do
            local itemText = sec.items[it]
            local sVal, eVal, val, lbl = string.find(itemText, "^([%+%-]?[%d%.]+%%?) (.+)$")
            if val and lbl then
                tip:AddDoubleLine("  " .. Capital(lbl), val, 0.65, 0.65, 0.65, col[1], col[2], col[3])
            else
                tip:AddLine("  " .. itemText, col[1], col[2], col[3], 1)
            end
        end
    end

    -- Remaining cooldown
    if cdRest and cdRest > 0 then
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), { 0.0, 0.90, 1.0 })
        tip:AddLine(string.format("Cooldown remaining: %.1fs", cdRest), 0.0, 0.90, 1.0)
    elseif cdMax and cdMax > 0 then
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), { 0.60, 0.60, 0.60 })
        tip:AddLine(string.format("Cooldown: %.1fs", cdMax), 0.60, 0.60, 0.60)
    end

    tip:Show()
    writtenSignature = Signature()
    return true
end

local function RenderFallbackTooltip(tip, nameOrId, rank, cdRest, cdMax)
    HideRules()
    tip:ClearLines()

    local resolved = ResolveSpellKeyToName(nameOrId, nameOrId)
    local norm = NormalizeName(resolved)
    local info = ABILITY_DESCRIPTIONS[norm] or ABILITY_DESCRIPTIONS[nameOrId]
    local school = SCHOOL_OF[resolved] or "Physical"
    local tint = SCHOOL_COLORS[school] or SCHOOL_COLORS["Physical"]

    local title = (info and info.name) or resolved or "Ability"
    local rankStr = (rank and tonumber(rank) and tonumber(rank) > 0) and ("Rank " .. tostring(rank)) or nil

    if rankStr then
        tip:AddDoubleLine(title, rankStr, tint[1], tint[2], tint[3], 0.60, 0.60, 0.60)
    else
        tip:AddLine(title, tint[1], tint[2], tint[3])
    end

    if info then
        local what = Hex(tint) .. school .. " damage|r"
        local cast = info.cast or "Instant"
        local cost = info.cost or ""
        tip:AddDoubleLine(what .. " · " .. cast, cost, 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)

        if info.range and info.range ~= "" then
            tip:AddLine(string.gsub(info.range, "([%d%.]+ yd)", "|cff99f2bf%1|r"), 0.65, 0.65, 0.65, 1)
        end

        if info.desc and info.desc ~= "" then
            tip:AddLine(" ")
            AddRule(GetTooltipNumLines(tip), tint)
            local highlighted = HighlightText(info.desc, school, tint)
            tip:AddLine(highlighted, 0.78, 0.78, 0.78, 1)
        end
    end

    if cdRest and cdRest > 0 then
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), { 0.0, 0.90, 1.0 })
        tip:AddLine(string.format("Cooldown remaining: %.1fs", cdRest), 0.0, 0.90, 1.0)
    elseif cdMax and cdMax > 0 then
        tip:AddLine(" ")
        AddRule(GetTooltipNumLines(tip), { 0.60, 0.60, 0.60 })
        tip:AddLine(string.format("Cooldown: %.1fs", cdMax), 0.60, 0.60, 0.60)
    end

    tip:Show()
    writtenSignature = Signature()
end

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

        -- DoT / Active Debuff Counter badge (top-right corner, bold)
        local dotFs = B:Font(tile, 10, "RIGHT")
        dotFs:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -2, -1)
        dotFs:SetTextColor(1.0, 0.40, 0.20)
        dotFs:Hide()
        tile.dotFs = dotFs

        tile.isBUIBuildTile = true

        -- Tooltip handling (Full Cyberpunk ability tooltip with dynamic updates)
        tile:SetScript("OnEnter", function()
            activeBuildTile = this
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            local hasActionData = false
            if this.actionSlot and HasAction and HasAction(this.actionSlot) and GameTooltip.SetAction then
                GameTooltip:SetAction(this.actionSlot)
                hasActionData = (GetTooltipNumLines(GameTooltip) >= 2)
            end

            if not hasActionData and this.spellName and spellBookIds and GameTooltip.SetSpell then
                local sId = spellBookIds[this.spellName] or spellBookIds[NormalizeName(this.spellName)]
                if sId then
                    GameTooltip:ClearLines()
                    GameTooltip:SetSpell(sId, BOOKTYPE_SPELL or "spell")
                    hasActionData = (GetTooltipNumLines(GameTooltip) >= 2)
                end
            end

            if hasActionData then
                FormatBlackwellAbilityTooltip(GameTooltip, this.cdRest, this.cdMax)
            else
                RenderFallbackTooltip(GameTooltip, this.spellName or this.spellKey, this.spellRank, this.cdRest, this.cdMax)
            end
            GameTooltip:Show()
            writtenSignature = Signature()
        end)

        tile:SetScript("OnLeave", function()
            activeBuildTile = nil
            writtenSignature = nil
            HideRules()
            GameTooltip:Hide()
        end)

        tile:Hide()
        tiles[i] = tile
    end
    f.tiles = tiles

    -- Live Tooltip Watcher: only updates if external game engine rewrites tooltip
    local tipWatcher = CreateFrame("Frame", nil, f)
    tipWatcher:SetScript("OnUpdate", function()
        if not GameTooltip:IsVisible() or not activeBuildTile then
            if tooltipRulesUsed > 0 then
                HideRules()
            end
            writtenSignature = nil
            return
        end
        local sig = Signature()
        if sig == writtenSignature or sig == "" then
            return
        end
        local owner = activeBuildTile
        if owner and owner.isBUIBuildTile then
            local ok = FormatBlackwellAbilityTooltip(GameTooltip, owner.cdRest, owner.cdMax)
            if ok then
                writtenSignature = Signature()
            end
        end
    end)

    local origTipHide = GameTooltip.Hide
    GameTooltip.Hide = function(self)
        activeBuildTile = nil
        writtenSignature = nil
        HideRules()
        if origTipHide then
            return origTipHide(self)
        end
    end

    if type(GameTooltip.GetScript) == "function" then
        local origTipOnHide = GameTooltip:GetScript("OnHide")
        GameTooltip:SetScript("OnHide", function()
            activeBuildTile = nil
            HideRules()
            if origTipOnHide then
                origTipOnHide()
            end
        end)
    end

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

    ---------------------------------------------------------------------------
    --  Stored Level-Up Button (Cyberpunk pulse style)
    ---------------------------------------------------------------------------
    local lvlUpBtn = CreateFrame("Button", "BUI_LevelUpButton", f)
    lvlUpBtn:SetWidth(180)
    lvlUpBtn:SetHeight(22)
    lvlUpBtn:SetPoint("BOTTOM", f, "TOP", 0, 4)
    B:Backdrop(lvlUpBtn, 0.92)
    B:Border(lvlUpBtn, 1.0, 0.82, 0.10, 1)

    local lvlUpFs = B:Font(lvlUpBtn, 10, "CENTER")
    lvlUpFs:SetPoint("CENTER", lvlUpBtn, "CENTER", 0, 0)
    lvlUpFs:SetTextColor(1.0, 0.88, 0.30)
    lvlUpBtn.fs = lvlUpFs

    lvlUpBtn:EnableMouse(true)
    if lvlUpBtn.RegisterForClicks then
        lvlUpBtn:RegisterForClicks("LeftButtonUp")
    end
    lvlUpBtn:SetScript("OnClick", function()
        if AZS_OpenStoredLevels then
            AZS_OpenStoredLevels()
        end
    end)
    lvlUpBtn:SetScript("OnEnter", function()
        B:Border(this, 0.0, 0.90, 1.0, 1)
        this.fs:SetTextColor(0.0, 0.90, 1.0)
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Level Up Choices Ready", 1.0, 0.82, 0.10)
        GameTooltip:AddLine("Click or press [Y] to choose your talent cards.", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    lvlUpBtn:SetScript("OnLeave", function()
        B:Border(this, 1.0, 0.82, 0.10, 1)
        this.fs:SetTextColor(1.0, 0.88, 0.30)
        GameTooltip:Hide()
    end)
    lvlUpBtn:Hide()
    f.lvlUpBtn = lvlUpBtn

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
        local sp = (i <= nSpells) and spells[i]
        if sp and type(sp) == "table" then
            local rawName = sp.spell or ""
            local rawKey = tostring(sp.key or "")
            local resolvedName = ResolveSpellKeyToName(rawKey, rawName)
            tile.spellName = resolvedName
            tile.spellKey = rawKey
            tile.spellRank = sp.rank
            tile.actionSlot = FindSpellActionSlot(i, rawKey, resolvedName, nSpells)

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

            -- Resolve Icon Texture (Priority: Action Bar Slot Texture -> Dictionary -> Fallback)
            local iconTex = nil
            if tile.actionSlot and HasAction and HasAction(tile.actionSlot) and GetActionTexture then
                iconTex = GetActionTexture(tile.actionSlot)
            end
            if not iconTex or iconTex == "" then
                iconTex = GetAbilityIcon(resolvedName) or GetAbilityIcon(rawKey)
            end
            if not iconTex or iconTex == "" then
                iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
            end

            tile.icon:SetTexture(iconTex)
            tile.icon:Show()

            -- DoT / Active Debuff Counter badge in top-right corner
            local normName = NormalizeName(resolvedName)
            local dotCount = GetActiveDotCount(normName)
            if dotCount > 0 then
                tile.dotFs:SetText(tostring(dotCount))
                local dotCol = GetSpellColor(resolvedName)
                tile.dotFs:SetTextColor(dotCol.r, dotCol.g, dotCol.b)
                tile.dotFs:Show()
            else
                tile.dotFs:Hide()
            end

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
        local b = (i <= maxRows) and buffs[i]
        if b and type(b) == "table" then
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

    -- Update Stored Level-Ups Button
    if f.lvlUpBtn then
        local stored = (AZS_GetStoredLevels and tonumber(AZS_GetStoredLevels())) or 0
        if stored > 0 then
            f.lvlUpBtn.fs:SetText(string.format("LEVEL UP READY (%d) [Y]", stored))
            if maxRows > 0 and f.buffBars[1] and f.buffBars[1]:IsShown() then
                f.lvlUpBtn:ClearAllPoints()
                f.lvlUpBtn:SetPoint("BOTTOM", f.buffContainer, "TOP", 0, 4)
            else
                f.lvlUpBtn:ClearAllPoints()
                f.lvlUpBtn:SetPoint("BOTTOM", f, "TOP", 0, 4)
            end
            f.lvlUpBtn:Show()
        else
            f.lvlUpBtn:Hide()
        end
    end
end

B:RegisterModule("build", mod)
