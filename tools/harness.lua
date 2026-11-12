-- Offline behaviour harness for BlackwellUI Core.lua (Phase 0 logic).
-- Runs under Lua 5.4 with Lua 5.0 / WoW 1.12 polyfills and a mocked client.
-- Usage: lua harness.lua <path to Core.lua>

local corePath = arg[1]

-- Lua 5.0 / 1.12 polyfills
table.getn = function(t) return #t end
math.mod = math.fmod
getglobal = function(n) return _G[n] end
GetTime = function() return 1000 end

-- Mocked client state
local cvars, cvarWrites = {}, 0
local function resetCVars()
    cvars = {
        CombatDamage = "1", CombatLogPeriodicSpells = "1", PetMeleeDamage = "1", PetSpellDamage = "1",
        hudClock = "1", hudBosses = "1", hudTally = "1", hudBuild = "1", hudMeter = "1", hudFlag = "1", hudLevels = "1",
    }
    cvarWrites = 0
end
resetCVars()
GetCVar = function(n)
    if cvars[n] == nil then error("Couldn't find CVar named '" .. tostring(n) .. "'") end
    return cvars[n]
end
SetCVar = function(n, v)
    if cvars[n] == nil then error("Couldn't find CVar named '" .. tostring(n) .. "'") end
    cvars[n] = v
    cvarWrites = cvarWrites + 1
end

local chat = {}
local errorsHandled = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
geterrorhandler = function() return function(m) table.insert(errorsHandled, m) end end

local Frame = {}
Frame.__index = function(t, k)
    local v = rawget(Frame, k)
    if v ~= nil then return v end
    return function() end
end
function Frame.new() return setmetatable({ scripts = {}, shown = true }, Frame) end
function Frame:SetScript(n, f) self.scripts[n] = f end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:CreateTexture() return Frame.new() end
function Frame:CreateFontString() return Frame.new() end
local frames = {}
CreateFrame = function(_, name)
    local f = Frame.new()
    if name then _G[name] = f end
    table.insert(frames, f)
    return f
end
UIParent = Frame.new()
UIParent.GetWidth = function() return 0 end
UIParent.GetHeight = function() return 0 end

-- Load Core.lua
dofile(corePath)
local B = BlackwellUI
B.GetOptimalScale = function() return 1.0 end

local function fire(ev, a1)
    event, arg1 = ev, a1
    BlackwellUIBoot.scripts.OnEvent()
end

local pass, fail = 0, 0
local function check(name, cond)
    if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end
end

-- 1. Fresh install --------------------------------------------------------
BlackwellUIDB = nil
B.initialized = nil
B:InitDB()
check("fresh: layoutVersion 14", B.db.layoutVersion == 14)
check("fresh: empty snapshot", next(B.db.stockCVars) == nil)
check("fresh: actionbars default on", B.db.modules.actionbars == true)
check("fresh: meterMode valid", B.db.meterMode == "damage")

-- 2. Suppress with SCT + replaceHud -> snapshot + zero
B:SyncHud()
check("sct on: CombatDamage zeroed", cvars.CombatDamage == "0")
check("sct on: snapshot holds 1", B.db.stockCVars.CombatDamage == "1")
check("hud: hudClock zeroed", cvars.hudClock == "0")
local writes = cvarWrites
B:SyncHud()
check("idempotent: no writes on second sync", cvarWrites == writes)

-- 3. Pins off -> hudFlag back (old code forced 0 whenever replaceHud)
B.db.modules.pins = false
B:SyncHud()
check("pins off: hudFlag restored", cvars.hudFlag == "1")
check("pins off: hudFlag snapshot cleared", B.db.stockCVars.hudFlag == nil)

-- 4. SCT off -> restore, then player choice survives
B.db.modules.combattext = false
B:SyncHud()
check("sct off: CombatDamage restored", cvars.CombatDamage == "1")
cvars.PetMeleeDamage = "0" -- player turns pet numbers off in Blizzard options
B:SyncHud()
check("sct off: player choice not overwritten", cvars.PetMeleeDamage == "0")
check("sct off: SHOW_COMBAT_TEXT global restored", SHOW_COMBAT_TEXT == nil)

-- 5. Logout restores everything still overridden
B.db.modules.combattext = true
B.db.modules.pins = true
cvars.PetMeleeDamage = "1"
B:SyncHud()
check("re-suppress: zeroed again", cvars.CombatDamage == "0" and cvars.hudFlag == "0")
fire("PLAYER_LOGOUT")
local allBack = true
for k, v in pairs(cvars) do if v ~= "1" then allBack = false; print("  not restored: " .. k .. "=" .. v) end end
check("logout: all CVars back to player values", allBack)
check("logout: snapshot kept", B.db.stockCVars.CombatDamage == "1" and B.db.stockGlobals.SHOW_COMBAT_TEXT ~= nil)
-- Client did not persist the logout writes: next session starts zeroed again.
cvars.CombatDamage = "0"
cvars.hudFlag = "0"
B:SyncHud()
check("next session: still zeroed, snapshot intact", cvars.CombatDamage == "0" and B.db.stockCVars.CombatDamage == "1")
B.db.modules.combattext = false
B.db.modules.pins = false
B:SyncHud()
check("next session: disable restores original", cvars.CombatDamage == "1" and cvars.hudFlag == "1")
B.db.modules.combattext = true
B.db.modules.pins = true
B:SyncHud()
fire("PLAYER_LOGOUT")

-- 6. Upgrade from 2.6.7 with already-zeroed CVars -> seeded once
resetCVars()
cvars.CombatDamage = "0"
cvars.hudMeter = "0"
BlackwellUIDB = { layoutVersion = 13, modules = { actionbars = false }, stockCVars = {} }
B.initialized = nil
B:InitDB()
check("upgrade: seeded CombatDamage", B.db.stockCVars.CombatDamage == "1")
check("upgrade: seeded hudMeter", B.db.stockCVars.hudMeter == "1")
check("upgrade: untouched values not seeded", B.db.stockCVars.PetSpellDamage == nil)
check("upgrade: bars stay hidden", B.db.modules.actionbars == true)
B.db.modules.combattext = false
B.db.modules.meter = false
B:SyncHud()
check("upgrade: restore to client default", cvars.CombatDamage == "1" and cvars.hudMeter == "1")

-- 7. Unknown CVar reports once instead of throwing
B:SetManagedCVar("SHOW_COMBAT_TEXT", "1")
B:SetManagedCVar("SHOW_COMBAT_TEXT", "1")
local n = 0
for i = 1, #errorsHandled do if string.find(errorsHandled[i], "SHOW_COMBAT_TEXT", 1, true) then n = n + 1 end end
check("unknown cvar: reported exactly once", n == 1)

-- 8. Tick isolation + run boundary
B.db.modules.combattext = true
local okMod = { frame = Frame.new(), updates = 0, runStarts = 0 }
function okMod:Create() end
function okMod:Update() self.updates = self.updates + 1 end
function okMod:OnRunStart() self.runStarts = self.runStarts + 1 end
local badMod = { frame = Frame.new() }
function badMod:Create() end
function badMod:Update() error("boom") end
B.moduleOrder = {}
B.modules = {}
B:RegisterModule("bad", badMod)
B:RegisterModule("ok", okMod)
B.db.modules.bad = true
B.db.modules.ok = true
B.built = true
B.db.demo = false
B.unlocked = false

local phase, runT = "ready", 0
AZS_GetPhase = function() return phase end
AZS_GetRunTime = function() return runT end
local okTick = pcall(B.Tick, B)
check("tick: survives failing module", okTick)
B:Tick()
check("tick: later module still updated", okMod.updates == 2)
local boom = 0
for i = 1, #errorsHandled do if string.find(errorsHandled[i], "boom", 1, true) then boom = boom + 1 end end
check("tick: failing module reported once", boom == 1)

check("run: ready is not a start", okMod.runStarts == 0)
phase, runT = "playing", 1
B:Tick()
check("run: ready -> playing starts", okMod.runStarts == 1)
runT = 300; B:Tick()
phase = "dead"; B:Tick()
phase, runT = "playing", 301; B:Tick()
check("run: revive is not a start", okMod.runStarts == 1)
phase, runT = "playing", 0; B:Tick()
check("run: clock jump back starts", okMod.runStarts == 2)
AZS_UNITS = { { kind = "elite", name = "X" } }
B:Tick()
check("run: units live", table.getn(B:GetState().units) == 1)
phase = nil; B:Tick()
check("run: leaving clears units", table.getn(B:GetState().units) == 0)

-- 9. reloadOnToggle modules keep running when disabled until /reload
local chatMod = { frame = Frame.new(), reloadOnToggle = true, alwaysActive = true, created = true }
function chatMod:Create() end
B:RegisterModule("chatlike", chatMod)
B.db.modules.chatlike = false
chatMod.frame:Show()
B:Tick()
check("reloadOnToggle: frame stays shown", chatMod.frame:IsShown())
okMod.frame:Show()
B.db.modules.ok = false
B:Tick()
check("normal module: hidden when disabled", not okMod.frame:IsShown())

-- 10. Loot quality pattern (Loot.lua)
local msg = "You receive loot: |cffa335ee|Hitem:19019:0:0:0|h[Thunderfury]|h|r."
local _, _, hex = string.find(msg, "You receive loot: |c%x%x(%x%x%x%x%x%x)|H(item:[%d:]+)|h%[(.-)%]|h|r")
check("loot: 6-digit quality hex", hex == "a335ee")

-- 11. Own spell icon table (SpellIcons.lua next to Core.lua)
local dir = string.match(corePath, "^(.*)[/\\]") or "."
dofile(dir .. "/SpellIcons.lua")
check("icons: Fireball", B:SpellIconPath("Fireball") == "Interface\\Icons\\Spell_Fire_FlameBolt")
check("icons: case-insensitive", B:SpellIconPath("frostbolt") == "Interface\\Icons\\Spell_Frost_FrostBolt02")
check("icons: unknown -> nil", B:SpellIconPath("No Such Spell 123") == nil)
check("icons: non-string -> nil", B:SpellIconPath(42) == nil)

-- 12. Removed fonts migrate to Barlow
BlackwellUIDB = { layoutVersion = 14, font = "Expressway Bold", modules = {} }
B.initialized = nil
B:InitDB()
check("fonts: Expressway Bold -> Barlow Bold", B.db.font == "Barlow Bold")
BlackwellUIDB = { layoutVersion = 14, font = "Homespun", modules = {} }
B.initialized = nil
B:InitDB()
check("fonts: Homespun -> Barlow", B.db.font == "Barlow")

-- 13. Localisation core (Locale.lua, AbilityNames.lua)
cvars.azsLanguage = "de"
GetLocale = function() return "enUS" end
dofile(dir .. "/Locale.lua")
dofile(dir .. "/AbilityNames.lua")
check("l10n: game language from azsLanguage", B:DetectGameLanguage() == "de")
cvars.azsLanguage = "xx"
check("l10n: unknown CVar value -> GetLocale fallback", B:DetectGameLanguage() == "en")
GetLocale = function() return "frFR" end
check("l10n: GetLocale frFR -> fr", B:DetectGameLanguage() == "fr")
cvars.azsLanguage = nil -- GetCVar now errors (unknown CVar): must fall back, not throw
check("l10n: missing CVar handled", B:DetectGameLanguage() == "fr")
cvars.azsLanguage = "de"
B:RegisterLocale("de", { ["Damage"] = "Schaden", ["%d alive"] = "%d am Leben" })
B:RegisterLocale("xx", { ["Damage"] = "nope" })
B.db.language = "auto"
B:ApplyLocale()
local L = B.L
check("l10n: L translates", L["Damage"] == "Schaden" and B.LANG == "de")
check("l10n: L falls back to English", L["Untranslated text"] == "Untranslated text")
check("l10n: format key", string.format(L["%d alive"], 3) == "3 am Leben")
check("l10n: unknown code ignored", B.LOCALES.xx == nil)
B.db.language = "en"
B:ApplyLocale()
check("l10n: override en clears translations", L["Damage"] == "Damage" and B.LANG == "en")
B.db.language = "ru"
B:ApplyLocale()
B.db.font = "Barlow"
check("l10n: ru swaps Barlow for Fira Sans", B:GetFontPath() == B.FONTS["Fira Sans"])
check("l10n: ru bold font has Cyrillic", B:GetBoldFontPath() == B.FONTS["Fira Sans"])
B.db.language = "de"
B:ApplyLocale()
check("l10n: de keeps Barlow", B:GetFontPath() == B.FONTS["Barlow"])
check("l10n: ability name in active language", B:AbilityName("fireball") == "Feuerball")
check("l10n: unknown ability id -> nil", B:AbilityName("no_such_ability") == nil)
check("l10n: Polish name -> English", B:EnglishAbilityName("Kula Ognia") == "Fireball")
check("l10n: case-insensitive reverse", B:EnglishAbilityName("feuerball") == "Fireball")
check("l10n: icon via localized name", B:GetAbilityIcon("Feuerball") == "Interface\\Icons\\Spell_Fire_FlameBolt")
B.db.language = "xx"
B.initialized = nil
BlackwellUIDB = B.db
B:InitDB()
check("l10n: invalid saved language reset to auto", B.db.language == "auto")
local names = 0
for i = 1, table.getn(B.LANGUAGES) do if B.LANGUAGES[i].name and B.LANGUAGES[i].name ~= "" then names = names + 1 end end
check("l10n: 14 languages listed", table.getn(B.LANGUAGES) == 14 and names == 14)
check("l10n: Russian native name decodes", B:GetLanguageName("ru") == "\208\160\209\131\209\129\209\129\208\186\208\184\208\185")

-- 14. Shipped translations: every Locales file in the TOC loads, registers,
-- translates, and survives string.format with the key's own placeholders.
B.LOCALES = {}
local toc = io.open(dir .. "/BlackwellUI.toc"):read("a")
local tocLocales = {}
for code in string.gmatch(toc, "Locales\\(%a+)%.lua") do table.insert(tocLocales, code) end
check("l10n: TOC lists 13 locale files", #tocLocales == 13)
for _, code in ipairs(tocLocales) do dofile(dir .. "/Locales/" .. code .. ".lua") end
local registered = 0
for code in pairs(B.LOCALES) do registered = registered + 1 end
check("l10n: 13 locales registered", registered == 13)
local formatFail, notTranslated = {}, {}
for _, code in ipairs(tocLocales) do
    B.db.language = code
    B:ApplyLocale()
    if B.LANG ~= code or L["Cancel"] == "Cancel" then table.insert(notTranslated, code) end
    for k, v in pairs(B.LOCALES[code] or {}) do
        local args = {}
        for conv in string.gmatch(k, "%%[-+ #0]*%d*%.?%d*([sdf])") do
            table.insert(args, conv == "s" and "x" or 1)
        end
        if #args > 0 then
            local ok = pcall(string.format, v, table.unpack(args))
            if not ok then table.insert(formatFail, code .. ": " .. v) end
        end
    end
end
check("l10n: every locale applies and translates", #notTranslated == 0)
check("l10n: every format string formats", #formatFail == 0)
for _, m in ipairs(formatFail) do print("  format fail " .. m) end
B.db.language = "auto"
B:ApplyLocale()

-- 15. Game tooltip wording (GameStrings.lua): templates match the game's text
dofile(dir .. "/GameStrings.lua")
local m, pos = B:GameMatch("crit", "13% chance to crit for 228% damage", "en", nil, true)
check("tip: en crit", m and m.p == "13" and m.crit == "228" and pos == 1)
m = B:GameMatch("crit", "13% Chance auf kritischen Treffer f\195\188r 228% Schaden", "de", nil, true)
check("tip: de crit", m and m.p == "13" and m.crit == "228")
m = B:GameMatch("crit", "%13 \197\159ansla %228 hasarla kritik", "tr", nil, true)
check("tip: tr crit (percent before number)", m and m.p == "13" and m.crit == "228")
m = B:GameMatch("cooldown", "\208\146\208\190\209\129\209\129\209\130\208\176\208\189\208\190\208\178\208\187\208\181\208\189\208\184\208\181: 1.5 \209\129\208\181\208\186.", "ru")
check("tip: ru cooldown", m and m.s == "1.5")
check("tip: en cooldown", B:GameMatch("cooldown", "1.5 sec cooldown", "en") ~= nil)
check("tip: de cooldown not English", B:GameMatch("cooldown", "1.5 sec cooldown", "de") == nil)
m, pos = B:GameMatch("damage", "Trifft den n\195\164chsten Feind f\195\188r 84 Schaden (Feuer).", "de", { school = "Feuer" })
check("tip: de damage school (fixed)", m and m.dmg == "84" and pos ~= nil)
check("tip: de damage wrong school", B:GameMatch("damage", "84 Schaden (Feuer).", "de", { school = "Frost" }) == nil)
m = B:GameMatch("damage", "\237\153\148\236\151\188 \237\148\188\237\149\180 84", "ko", { school = B:GameString("school_Fire", "ko") })
check("tip: ko damage (school before number)", m and m.dmg == "84")
check("tip: escape magic chars", B:GameMatch("crit", "13x chance to crit for 228x damage", "en", nil, true) == nil)
check("tip: GameFormat rank de", B:GameFormat("rank", "de", { n = 3 }) == "Rang 3")
check("tip: unknown lang -> English", B:GameString("automatic", "xx") == "Automatic")
check("tip: zh list separator", B:GameString("list_sep", "zh") == "\227\128\129")
B.GAME_LANG = "de"
local tl = B:TooltipLanguages()
check("tip: tooltip languages game then en", tl[1] == "de" and tl[2] == "en" and #tl == 2)
B.GAME_LANG = "en"
check("tip: tooltip languages en only", #B:TooltipLanguages() == 1)

-- 16. Style switch, panel colour, per-module settings, visibility
B.db.uiStyle = "round"
check("style: round by default", B:IsRound() == true)
B.db.uiStyle = "sharp"
check("style: sharp", B:IsRound() == false)
B.db.panelColor = false
local pr, pg, pb = B:GetPanelColor()
check("style: sharp keeps the classic panel colour", math.abs(pr - 0.055) < 0.001 and math.abs(pb - 0.045) < 0.001)
B.db.uiStyle = "round"
pr = B:GetPanelColor()
check("style: round panel colour", math.abs(pr - B.PANEL_COLOR.r) < 0.001)
B.db.panelColor = { r = 0.2, g = 0.3, b = 0.4 }
pr, pg, pb = B:GetPanelColor()
check("style: custom panel colour wins", pr == 0.2 and pg == 0.3 and pb == 0.4)
B.db.panelColor = false
check("modopt: default when unset", B:ModOpt("meter", "rows", 8) == 8)
B:SetModOpt("meter", "rows", 5)
check("modopt: stored value", B:ModOpt("meter", "rows", 8) == 5 and B.db.mod.meter.rows == 5)
B:SetModOpt("meter", "showIcons", false)
check("modopt: false is a value, not unset", B:ModOpt("meter", "showIcons", true) == false)
B:ResetModOpts("meter")
check("modopt: reset", B:ModOpt("meter", "rows", 8) == 8 and B.db.mod.meter == nil)
-- visibility: alpha * factor on the look frames
local vf = { alpha = 1, scale = 1, shown = true }
function vf:SetAlpha(a) self.alpha = a end
function vf:SetScale(s) self.scale = s end
function vf:IsVisible() return self.shown end
local vmod = { key = "vistest", frame = vf }
B.unlocked = false
B:SetModOpt("vistest", "alpha", 0.5)
B:ApplyModuleVisibility(vmod)
check("vis: opacity applied", math.abs(vf.alpha - 0.5) < 0.001)
B:SetModOpt("vistest", "visibility", "combat")
UnitAffectingCombat = function() return nil end
B:ApplyModuleVisibility(vmod)
check("vis: combat-only hidden out of combat", vf.alpha == 0)
UnitAffectingCombat = function() return 1 end
B:ApplyModuleVisibility(vmod)
check("vis: combat-only shown in combat", math.abs(vf.alpha - 0.5) < 0.001)
B:SetModOpt("vistest", "visibility", "mouseover")
MouseIsOver = function() return nil end
B:ApplyModuleVisibility(vmod)
check("vis: mouseover faded", math.abs(vf.alpha - 0.5 * 0.15) < 0.001)
MouseIsOver = function() return 1 end
B:ApplyModuleVisibility(vmod)
check("vis: mouseover full under the mouse", math.abs(vf.alpha - 0.5) < 0.001)
B.unlocked = true
MouseIsOver = function() return nil end
B:ApplyModuleVisibility(vmod)
check("vis: edit mode always shows", math.abs(vf.alpha - 0.5) < 0.001)
B.unlocked = false
B:SetModOpt("vistest", "scale", 1.25)
B:ApplyModuleLook(vmod)
check("look: scale applied", vf.scale == 1.25)
check("look: noLook has no frames", table.getn(B:GetLookFrames({ key = "x", frame = vf, noLook = true })) == 0)
B:ResetModOpts("vistest")

print(string.format("PASS %d  FAIL %d", pass, fail))
if fail > 0 then os.exit(1) end
