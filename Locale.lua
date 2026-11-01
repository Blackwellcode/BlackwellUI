-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Locale.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Language detection and the L[] string table.
--  - The game keeps its UI language in the CVar azsLanguage (en, de, fr, es,
--    pt, pl, cs, ro, tr, ru, uk, zh, ja, ko) and sets it on every start.
--    GetLocale() is always enUS in this engine and is only a fallback.
--  - L["English text"] returns the translation, or the English text itself.
--  - Translations register through B:RegisterLocale (Locales\*.lua).
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI

-- Game languages in the game's own order, with their native names.
B.LANGUAGES = {
    { code = "en", name = "English" },
    { code = "de", name = "Deutsch" },
    { code = "fr", name = "Fran\195\167ais" },
    { code = "es", name = "Espa\195\177ol" },
    { code = "pt", name = "Portugu\195\170s (Brasil)" },
    { code = "pl", name = "Polski" },
    { code = "cs", name = "\196\140e\197\161tina" },
    { code = "ro", name = "Rom\195\162n\196\131" },
    { code = "tr", name = "T\195\188rk\195\167e" },
    { code = "ru", name = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185" },
    { code = "uk", name = "\208\163\208\186\209\128\208\176\209\151\208\189\209\129\209\140\208\186\208\176" },
    { code = "zh", name = "\231\174\128\228\189\147\228\184\173\230\150\135" },
    { code = "ja", name = "\230\151\165\230\156\172\232\170\158" },
    { code = "ko", name = "\237\149\156\234\181\173\236\150\180" },
}

local KNOWN = {}
for i = 1, table.getn(B.LANGUAGES) do
    KNOWN[B.LANGUAGES[i].code] = B.LANGUAGES[i]
end

-- WoW client locales mapped onto game languages (fallback only).
local FROM_WOW_LOCALE = {
    enUS = "en", enGB = "en", deDE = "de", frFR = "fr", esES = "es", esMX = "es",
    ptBR = "pt", ruRU = "ru", koKR = "ko", zhCN = "zh", zhTW = "zh",
}

-- Scripts the bundled fonts cannot draw. CJK falls back to the engine's own
-- font automatically; Cyrillic does not (tested in-game 2026-11-01).
B.LANGUAGE_NEEDS_CYRILLIC = { ru = true, uk = true }
B.FONTS_WITHOUT_CYRILLIC = { ["Barlow"] = true, ["Barlow Bold"] = true }

B.LOCALES = {}
B.L = setmetatable({}, { __index = function(_, key) return key end })

function B:RegisterLocale(code, strings)
    if KNOWN[code] and type(strings) == "table" then
        self.LOCALES[code] = strings
    end
end

-- The language the game itself is running in.
function B:DetectGameLanguage()
    if type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, "azsLanguage")
        if ok and type(value) == "string" and KNOWN[value] then
            return value
        end
    end
    if type(GetLocale) == "function" then
        local mapped = FROM_WOW_LOCALE[GetLocale()]
        if mapped then return mapped end
    end
    return "en"
end

function B:GetLanguageName(code)
    local entry = KNOWN[code]
    return (entry and entry.name) or tostring(code)
end

function B:IsKnownLanguage(code)
    return KNOWN[code] ~= nil
end

-- Picks the language (saved override or game language) and fills L. Frames
-- read L when they are built, so a change after login needs a /reload.
function B:ApplyLocale()
    local wanted = self.db and self.db.language
    self.GAME_LANG = self:DetectGameLanguage()
    if wanted and wanted ~= "auto" and KNOWN[wanted] then
        self.LANG = wanted
    else
        self.LANG = self.GAME_LANG
    end
    local L = self.L
    for k in pairs(L) do
        rawset(L, k, nil)
    end
    local strings = self.LOCALES[self.LANG]
    if strings then
        for k, v in pairs(strings) do
            if type(v) == "string" and v ~= "" then
                rawset(L, k, v)
            end
        end
    end
end

-- Ability names (AbilityNames.lua, generated from the game's language data).
-- AbilityName: game ability id (AZS_SPELLS key) -> name in the active language.
function B:AbilityName(key)
    local row = self.ABILITY_NAMES and self.ABILITY_NAMES[key]
    if not row then return nil end
    return row[self.LANG] or row[1]
end

-- EnglishAbilityName: an ability name in any game language -> English name,
-- so icon lookups (SpellIcons.lua is English) work whatever the game shows.
function B:EnglishAbilityName(name)
    if type(name) ~= "string" or type(self.ABILITY_NAMES) ~= "table" then return nil end
    if not self.abilityReverse then
        local map = {}
        for _, row in pairs(self.ABILITY_NAMES) do
            local english = row[1]
            for _, localized in pairs(row) do
                if type(localized) == "string" then
                    map[string.lower(localized)] = english
                end
            end
        end
        self.abilityReverse = map
    end
    return self.abilityReverse[string.lower(name)]
end

-- Game wording (GameStrings.lua, generated from the game's language data).
-- The game writes spell tooltips in the game language, which can differ from
-- BlackwellUI's language when the player overrides it, so tooltip parsing
-- tries the game language first and English second.
function B:GameString(id, lang)
    local row = self.GAME_STRINGS and self.GAME_STRINGS[id]
    if not row then return nil end
    return row[lang or self.LANG] or row[1]
end

function B:TooltipLanguages()
    local game = self.GAME_LANG or "en"
    if game == "en" then return { "en" } end
    return { game, "en" }
end

-- Placeholders that always hold a number in the game's templates.
local NUMERIC_PLACEHOLDER = { p = true, crit = true, s = true, n = true, dmg = true, v = true, rank = true, ranks = true }

local function EscapePattern(text)
    return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Template -> Lua pattern. Placeholders named in `fixed` become that literal
-- text; the others become captures, returned in template order as `names`.
local patternCache = {}
local function TemplatePattern(template, fixed)
    local cacheKey = template
    if fixed then
        for k, v in pairs(fixed) do cacheKey = cacheKey .. "\1" .. k .. "=" .. v end
    end
    local cached = patternCache[cacheKey]
    if cached then return cached.pattern, cached.names end
    local names = {}
    local pattern = string.gsub(EscapePattern(template), "{(%w+)}", function(name)
        if fixed and fixed[name] then
            return EscapePattern(fixed[name])
        end
        table.insert(names, name)
        if NUMERIC_PLACEHOLDER[name] then
            return "([%d%.,]+)"
        end
        return "(.-)"
    end)
    patternCache[cacheKey] = { pattern = pattern, names = names }
    return pattern, names
end

-- Matches game template `id` (in `lang`) against text. Returns the captures
-- by placeholder name and the match start, or nil. anchored: match at start.
function B:GameMatch(id, text, lang, fixed, anchored)
    local template = self:GameString(id, lang)
    if not template or type(text) ~= "string" then return nil end
    local pattern, names = TemplatePattern(template, fixed)
    if anchored then pattern = "^" .. pattern end
    local found = { string.find(text, pattern) }
    if not found[1] then return nil end
    local values = {}
    for i = 1, table.getn(names) do
        values[names[i]] = found[i + 2]
    end
    return values, found[1]
end

-- Fills a game template with values, e.g. GameFormat("rank", nil, { n = 2 }).
function B:GameFormat(id, lang, values)
    local template = self:GameString(id, lang)
    if not template then return nil end
    return (string.gsub(template, "{(%w+)}", function(name)
        local v = values and values[name]
        if v == nil then return "" end
        return tostring(v)
    end))
end

-- Font for the active language: fonts without Cyrillic glyphs give way to
-- Fira Sans for Russian and Ukrainian.
function B:FontForLanguage(path, fontName)
    if self.LANGUAGE_NEEDS_CYRILLIC[self.LANG] and self.FONTS_WITHOUT_CYRILLIC[fontName] then
        return self.FONTS["Fira Sans"] or path
    end
    return path
end

B.GAME_LANG = B:DetectGameLanguage()
B.LANG = B.GAME_LANG
