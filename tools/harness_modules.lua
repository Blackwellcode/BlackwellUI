-- Offline module harness for BlackwellUI: loads every file of the TOC in
-- order against a mocked 1.12 client and checks the event-driven / pooled
-- module paths (tick coalescing, equipment cache, meter row pool, unit
-- frame aura filter, cooldown scan, nameplate scanner, slash aliases).
-- Runs under Lua 5.4 with Lua 5.0 / WoW 1.12 polyfills.
-- Usage: lua tools/harness_modules.lua <addon dir>

local dir = arg[1] or "."

-- Lua 5.0 / 1.12 polyfills
table.getn = function(t) return #t end
table.setn = function() end
math.mod = math.fmod
string.gfind = string.gmatch
getglobal = function(n) return _G[n] end
setglobal = function(n, v) _G[n] = v end
local now = 1000
GetTime = function() return now end
time = os.time
date = os.date

-- Mocked client ------------------------------------------------------------
local cvars = { azsLanguage = "en", CombatDamage = "1", CombatLogPeriodicSpells = "1", PetMeleeDamage = "1",
    PetSpellDamage = "1", hudClock = "1", hudBosses = "1", hudTally = "1", hudBuild = "1", hudMeter = "1",
    hudFlag = "1", hudLevels = "1", hudRevive = "1" }
GetCVar = function(n)
    if cvars[n] == nil then error("Couldn't find CVar named '" .. tostring(n) .. "'") end
    return cvars[n]
end
SetCVar = function(n, v)
    if cvars[n] == nil then error("Couldn't find CVar named '" .. tostring(n) .. "'") end
    cvars[n] = v
end
GetLocale = function() return "enUS" end

local chat = {}
local handled = {}
geterrorhandler = function() return function(m) table.insert(handled, m) end end

-- Every widget is a Mock: known getters return plausible values, every other
-- method is a no-op. Scripts and registered events are recorded.
local Mock = {}
local allFrames = {}
local GETTERS = {
    GetWidth = 100, GetHeight = 20, GetLeft = 0, GetRight = 100, GetTop = 20, GetBottom = 0,
    GetScale = 1, GetEffectiveScale = 1, GetAlpha = 1, GetFrameLevel = 1, GetStringWidth = 40,
    GetStringHeight = 10, GetNumPoints = 1, GetFrameStrata = "MEDIUM", GetObjectType = "Frame",
    GetText = "", GetValue = 0, GetNumChildren = 0, GetID = 0, GetVerticalScroll = 0,
    GetVerticalScrollRange = 0, GetHorizontalScroll = 0, GetHorizontalScrollRange = 0,
}
Mock.__index = function(t, k)
    local v = rawget(Mock, k)
    if v ~= nil then return v end
    if GETTERS[k] ~= nil then
        local g = GETTERS[k]
        return function() return g end
    end
    -- Widget methods are CamelCase; lower-case keys are addon fields (nil).
    if type(k) == "string" and string.find(k, "^%u") then return function() end end
    return nil
end
local function NewMock(name)
    local m = setmetatable({ scripts = {}, events = {}, shown = true, name = name }, Mock)
    table.insert(allFrames, m)
    if name then _G[name] = m end
    return m
end
function Mock:SetScript(n, f) self.scripts[n] = f end
function Mock:GetScript(n) return self.scripts[n] end
function Mock:HookScript(n, f) self.scripts[n] = f end
function Mock:RegisterEvent(e) self.events[e] = true end
function Mock:UnregisterEvent(e) self.events[e] = nil end
function Mock:UnregisterAllEvents() self.events = {} end
function Mock:IsShown() return self.shown end
function Mock:IsVisible() return self.shown end
function Mock:Show() self.shown = true end
function Mock:Hide() self.shown = false end
function Mock:SetText(t) self.text = t; self.setTextCount = (self.setTextCount or 0) + 1 end
function Mock:GetText() return self.text or "" end
function Mock:GetName() return self.name end
function Mock:GetParent() return UIParent end
function Mock:GetChildren() return end
function Mock:GetRegions() return end
function Mock:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Mock:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function Mock:GetStatusBarTexture() return NewMock() end
function Mock:GetMinMaxValues() return 0, 1 end
function Mock:CreateTexture() return NewMock() end
function Mock:CreateFontString() return NewMock() end
function Mock:SetTexture(tex) self.texture = tex end
function Mock:GetTexture() return self.texture end
CreateFrame = function(_, name) return NewMock(name) end

UIParent = NewMock("UIParent")
WorldFrame = NewMock("WorldFrame")
Minimap = NewMock("Minimap")
GameTooltip = NewMock("GameTooltip")
GameTooltip.NumLines = function() return 0 end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
ChatFrame1 = NewMock("ChatFrame1")
StaticPopupDialogs = {}
local popups = {}
StaticPopup_Show = function(key) table.insert(popups, key) end
SlashCmdList = {}
NUM_CHAT_WINDOWS = 7
RAID_CLASS_COLORS = {}
BOOKTYPE_SPELL = "spell"
UnitName = function(u) return (u == "player") and "Tester" or nil end
UnitExists = function(u) return u == "player" end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 10 end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitMana = function() return 50 end
UnitManaMax = function() return 100 end
UnitPowerType = function() return 1 end
UnitAffectingCombat = function() return nil end
UnitXP = function() return 10 end
UnitXPMax = function() return 100 end
GetSpellTexture = function() return nil end
GetMinimapZoneText = function() return "Elwynn Forest" end
GetPlayerMapPosition = function() return 0.5, 0.5 end
UnitIsDead = function() return nil end
UnitCanAttack = function() return nil end
UnitBuff = function() return nil end
UnitDebuff = function() return nil end
GetRaidTargetIndex = function() return nil end
GetNumPartyMembers = function() return 0 end
GetScreenWidth = function() return 1920 end
GetScreenHeight = function() return 1080 end
MouseIsOver = function() return nil end
IsAddOnLoaded = function() return nil end
hooksecurefunc = nil

-- Inventory / bags: one equipped item, one bag stack
local invCalls = 0
GetInventoryItemTexture = function(_, slot)
    invCalls = invCalls + 1
    if slot == 16 then return "Interface\\Icons\\INV_Sword_04" end
    return nil
end
GetInventoryItemLink = function() return "|cff0070dd|Hitem:1:0:0:0|h[Sword]|h|r" end
GetInventoryItemQuality = function() return 3 end
local bagItems = { [1] = { "Interface\\Icons\\INV_Potion_51", 5 } }
GetContainerNumSlots = function(bag) return (bag == 0) and 16 or 0 end
GetContainerItemInfo = function(bag, slot)
    local it = (bag == 0) and bagItems[slot]
    if it then return it[1], it[2] end
    return nil
end
GetContainerItemLink = function() return "|cffffffff|Hitem:2:0:0:0|h[Potion]|h|r" end

-- Spellbook: two spells, one with a long cooldown
local spellCooldowns = { { name = "Fireball", start = 0, duration = 0 }, { name = "Blink", start = 0, duration = 0 } }
local cdScans = 0
GetSpellName = function(i)
    if i == 1 then cdScans = cdScans + 1 end
    local s = spellCooldowns[i]
    return s and s.name
end
GetSpellCooldown = function(i)
    local s = spellCooldowns[i]
    return s.start, s.duration, 1
end

-- Load the TOC ---------------------------------------------------------------
local toc = io.open(dir .. "/BlackwellUI.toc"):read("a")
local files = {}
for line in string.gmatch(toc, "[^\r\n]+") do
    if not string.find(line, "^#") and string.find(line, "%.lua%s*$") then
        table.insert(files, (string.gsub(string.gsub(line, "%s+$", ""), "\\", "/")))
    end
end

local pass, fail = 0, 0
local function check(name, cond)
    if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end
end

local loadErrors = {}
for _, f in ipairs(files) do
    local ok, err = pcall(dofile, dir .. "/" .. f)
    if not ok then table.insert(loadErrors, f .. ": " .. tostring(err)) end
end
for _, e in ipairs(loadErrors) do print("  load error " .. e) end
check("load: every TOC file loads", #loadErrors == 0)

local B = BlackwellUI
B.GetOptimalScale = function() return 1.0 end
B:InitDB()
B.db.modules.nameplates = true

-- Fire the boot sequence
local function fireBoot(ev, a1)
    event, arg1 = ev, a1
    BlackwellUIBoot.scripts.OnEvent()
end
fireBoot("VARIABLES_LOADED")
fireBoot("PLAYER_ENTERING_WORLD")
check("boot: modules built", B.built == true)

local function ModuleCreated(key)
    local m = B.modules[key]
    return m and m.created
end
for _, key in ipairs({ "equipment", "meter", "unitframes", "combattext", "nameplates" }) do
    check("boot: " .. key .. " created", ModuleCreated(key))
end
for i, m in ipairs(handled) do print("  reported: " .. tostring(m)) end
check("boot: no module errors", #handled == 0)

-- Live run state
AZS_GetPhase = function() return "playing" end
AZS_GetRunTime = function() return 120 end
local meterData = { { name = "Fireball", dmg = 1000 }, { name = "Arcane Missiles", dmg = 400 } }
AZS_GetMeter = function() return meterData, 1400, 12 end

-- 1. Tick coalescing: events only flag, the boot ticker runs the tick
local ticks = 0
local origTick = B.Tick
B.Tick = function(self) ticks = ticks + 1; return origTick(self) end
local uf = B.modules.unitframes
local watcher = uf.ufWatcher
event, arg1 = "UNIT_AURA", "party1"
watcher.scripts.OnEvent()
check("aura: party unit does not flag a tick", not B.tickDirty)
event, arg1 = "UNIT_AURA", "target"
watcher.scripts.OnEvent()
event, arg1 = "UNIT_AURA", "player"
watcher.scripts.OnEvent()
check("aura: target/player events run no tick directly", ticks == 0)
check("aura: target/player flag a tick", B.tickDirty == true)
arg1 = 0.06
BlackwellUIBoot.scripts.OnUpdate()
check("ticker: flagged tick runs on the next frame", ticks == 1 and not B.tickDirty)
arg1 = 0.02
BlackwellUIBoot.scripts.OnUpdate()
check("ticker: no tick without flag before 0.1 s", ticks == 1)
arg1 = 0.09
BlackwellUIBoot.scripts.OnUpdate()
check("ticker: regular 10 Hz tick", ticks == 2)

-- 2. State: no new tables per tick
AZS_UNITS = { { kind = "elite", name = "A", hp = 1, hpm = 2 }, { kind = "mob" }, { kind = "elite", name = "B" } }
local s1 = B:GetState()
local elites1, e1 = s1.elites, s1.elites[1]
local zone1 = s1.zone
local s2 = B:GetState()
check("state: elites table reused", s2.elites == elites1 and s2.elites[1] == e1)
check("state: two elites", table.getn(s2.elites) == 2 and s2.elites[2].name == "B")
AZS_UNITS = { { kind = "elite", name = "C" } }
local s3 = B:GetState()
check("state: shrinking elites clears trailing entries", table.getn(s3.elites) == 1 and s3.elites[2] == nil and s3.elites[1].name == "C")
check("state: missing zone uses a shared fallback", s3.zone == zone1 and next(s3.zone) == nil)
local fakeMod = { key = "x", frame = NewMock() }
check("look: one-frame list cached", B:GetLookFrames(fakeMod) == B:GetLookFrames(fakeMod))
fakeMod.frame = NewMock()
check("look: cache follows a new frame", B:GetLookFrames(fakeMod)[1] == fakeMod.frame)

-- 3. Equipment: scan only on events / fallback, render only on change
local eq = B.modules.equipment
B:Tick()
local scans = eq.scans or 0
invCalls = 0
B:Tick(); B:Tick(); B:Tick()
check("equipment: no rescan without event", invCalls == 0 and (eq.scans or 0) == scans)
check("equipment: cached items drawn", eq.frame.slots[1].itemKind == "inv" and eq.frame.slots[2].itemKind == "bag")
check("equipment: stack count from cache", eq.frame.slots[2].countFs.text == "5")
event, arg1 = "UNIT_INVENTORY_CHANGED", "target"
eq.watcher.scripts.OnEvent()
B:Tick()
check("equipment: other unit's inventory ignored", invCalls == 0)
bagItems[2] = { "Interface\\Icons\\INV_Misc_Bag_08", 1 }
event, arg1 = "BAG_UPDATE", 0
eq.watcher.scripts.OnEvent()
B:Tick()
check("equipment: BAG_UPDATE rescans", invCalls > 0 and eq.frame.slots[3].itemKind == "bag")
invCalls = 0
now = now + 2.5
B:Tick()
check("equipment: slow fallback rescan", invCalls > 0)

-- 4. Meter: pooled rows, redraw only on change
local meter = B.modules.meter
B.db.meterMode = "damage"
meter:Invalidate()
B:Tick()
local draws = meter.draws or 0
local row1 = meter.frame.rows[1].data
check("meter: rows sorted by amount", row1 and row1.name == "Fireball" and meter.frame.rows[2].data.name == "Arcane Missiles")
B:Tick(); B:Tick()
check("meter: unchanged data is not redrawn", (meter.draws or 0) == draws)
meterData[2].dmg = 2000
B:Tick()
check("meter: changed data redraws", (meter.draws or 0) == draws + 1)
check("meter: row tables reused", meter.frame.rows[1].data == row1 or meter.frame.rows[2].data == row1)
check("meter: new order", meter.frame.rows[1].data.name == "Arcane Missiles")
meterData[3] = nil
table.remove(meterData, 2)
B:Tick()
check("meter: shrinking list hides rows", meter.frame.rows[2].data == nil and meter.frame.maxEntries == 1)
-- merged procs reuse their proc entries
B.db.mergeItemProcs = true
meterData[2] = { name = "Ring of Fire: Fireball", dmg = 300 }
meterData[3] = { name = "Staff of Fire: Fireball", dmg = 200 }
B:Tick()
local d1 = meter.frame.rows[1].data
check("meter: procs merged into the spell", d1.name == "Fireball" and d1.procDmg == 500 and table.getn(d1.procs) == 2)
meterData[3] = nil
B:Tick()
check("meter: proc list shrinks in place", table.getn(meter.frame.rows[1].data.procs) == 1)
B.db.mergeItemProcs = false

-- 5. Cooldown scan: event flags, OnUpdate scans once; no scans while idle
local ct = B.modules.combattext
B.db.sctAlerts = true
local driver = ct.driver
cdScans = 0
arg1 = 0.05
for _ = 1, 40 do driver.scripts.OnUpdate() end
check("cooldowns: idle frames do not scan", cdScans == 0)
event = "SPELL_UPDATE_COOLDOWN"
driver.scripts.OnEvent(); driver.scripts.OnEvent(); driver.scripts.OnEvent()
check("cooldowns: events only flag", cdScans == 0)
arg1 = 0.11
driver.scripts.OnUpdate()
check("cooldowns: burst costs one scan", cdScans == 1)
spellCooldowns[2].start, spellCooldowns[2].duration = now, 10
event = "SPELL_UPDATE_COOLDOWN"
driver.scripts.OnEvent()
driver.scripts.OnUpdate()
check("cooldowns: running cooldown tracked", cdScans == 2)
-- The driver clamps frame time to 0.1 s: 11 frames are just over 1 s.
arg1 = 0.1
for _ = 1, 11 do driver.scripts.OnUpdate() end
check("cooldowns: fallback scan once a second while one runs", cdScans == 3)
B.db.sctAlerts = false
cdScans = 0
event = "SPELL_UPDATE_COOLDOWN"
driver.scripts.OnEvent()
arg1 = 2
driver.scripts.OnUpdate()
check("cooldowns: no scan while alerts are off", cdScans == 0)

-- 6. Nameplate scanner: one OnUpdate, throttled
local np = B.modules.nameplates
check("nameplates: scanner exists", np.scanner and np.scanner.scripts.OnUpdate ~= nil)
local childCalls = 0
WorldFrame.GetChildren = function() childCalls = childCalls + 1 return end
WorldFrame.GetNumChildren = function() return 0 end
NAMEPLATES_ON = 1
B.db.modules.nameplates = true
arg1 = 0.016
for _ = 1, 12 do np.scanner.scripts.OnUpdate() end
check("nameplates: child list collected once for an unchanged scene", childCalls == 1)

-- 7. Slash aliases: only when free
check("slash: /msbt not yet registered before login", SlashCmdList.BLACKWELLUI_MSBT == nil)
SLASH_MIKSBT1 = "/msbt"
SlashCmdList.MIKSBT = function() end
for _, f in ipairs(allFrames) do
    if f.events.PLAYER_LOGIN and f.scripts.OnEvent then
        this, event = f, "PLAYER_LOGIN"
        f.scripts.OnEvent()
    end
end
check("slash: /msbt left to its owner", SlashCmdList.BLACKWELLUI_MSBT == nil)
check("slash: free /splates registered", SlashCmdList.BLACKWELLUI_SPLATES ~= nil and SLASH_BLACKWELLUI_SPLATES1 == "/splates")

-- 8. Resets ask first
popups = {}
SlashCmdList.BLACKWELLUI("reset")
check("reset: /bw reset asks", popups[1] == "BLACKWELLUI_RESET_LAYOUT")
B.db.mod = { meter = { rows = 5 } }
B:ConfirmResetModuleSettings()
check("reset: module settings ask first", popups[2] == "BLACKWELLUI_RESET_SETTINGS" and B.db.mod.meter.rows == 5)
StaticPopupDialogs.BLACKWELLUI_RESET_SETTINGS.OnAccept()
check("reset: accept clears module settings", next(B.db.mod) == nil)

for _, m in ipairs(handled) do print("  reported: " .. tostring(m)) end
check("run: no module errors reported", #handled == 0)

print(string.format("PASS %d  FAIL %d", pass, fail))
if fail > 0 then os.exit(1) end
