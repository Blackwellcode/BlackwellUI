-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Pins.lua
--  Cyberpunk Minimap Radar & Pins Engine:
--  - Real-time field radar for Caches (AZS_CHESTS) and Guardian Lairs (AZS_GetLairs)
--  - Square minimap edge clamping with distance and directional calculation
--  - Cyberpunk neon pin styling with breathing aura for flagged target lair
--  - Hover tooltip with status, guardian state, and exact yard telemetry
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Minimap Radar Pins"

local ART_PATH = "Interface\\AddOns\\BlackwellUI\\media\\pins\\"
local PIN_SIZE = 14
local EDGE_SIZE = 10

local MINIMAP_YARDS = { [0] = 466.67, [1] = 400.00, [2] = 333.33, [3] = 266.67, [4] = 200.00, [5] = 133.33 }
local INSIDE_YARDS  = { [0] = 300.00, [1] = 240.00, [2] = 180.00, [3] = 120.00, [4] = 80.00,  [5] = 50.00 }

local spans = {}
local pins = {}
local flaggedPin = nil
local breathTime = 0
local elapsedTimer = 0

local function Playing()
    if B.unlocked or (B.db and B.db.demo) then
        return true
    end
    local s = B:GetState()
    if not s or not s.active then
        return false
    end
    local phase = s.phase
    return phase == "playing" or phase == "choosing" or phase == "paused"
end

local function Share(value)
    local n = tonumber(value)
    if not n or n < 0 then
        return nil
    end
    if n > 1.5 then
        return n / 100
    end
    return n
end

local function GetPlaces()
    local list = {}
    local chests = AZS_CHESTS or (type(AZS_GetChests) == "function" and AZS_GetChests()) or {}
    local nChests = (type(chests) == "table") and table.getn(chests) or 0
    for i = 1, nChests do
        table.insert(list, chests[i])
    end
    local lairs = (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or (type(AZS_LAIRS) == "table" and AZS_LAIRS) or {}
    local nLairs = (type(lairs) == "table") and table.getn(lairs) or 0
    for i = 1, nLairs do
        table.insert(list, lairs[i])
    end
    return list
end

local NEAREST = 0.004

local function CalculateSpan()
    local zone = (AZS_ZONE and AZS_ZONE.zname) or "?"
    local known = spans[zone] or { baseAcross = 0, baseDown = 0 }
    local places = GetPlaces()
    local nPlaces = table.getn(places)

    for a = 1, nPlaces do
        for b = a + 1, nPlaces do
            local p, q = places[a], places[b]
            local pmx, qmx = Share(p.mx), Share(q.mx)
            local pmy, qmy = Share(p.my), Share(q.my)
            local px, qx = tonumber(p.x), tonumber(q.x)
            local py, qy = tonumber(p.y), tonumber(q.y)

            if pmx and qmx and pmy and qmy and px and qx and py and qy then
                local dmx = math.abs(pmx - qmx)
                local dmy = math.abs(pmy - qmy)
                if dmx > known.baseAcross and dmx > NEAREST then
                    known.baseAcross = dmx
                    known.foundAcross = math.abs(py - qy) / dmx
                end
                if dmy > known.baseDown and dmy > NEAREST then
                    known.baseDown = dmy
                    known.foundDown = math.abs(px - qx) / dmy
                end
            end
        end
    end

    known.across = known.foundAcross or (known.foundDown and known.foundDown * 3 / 2)
    known.down = known.foundDown or (known.foundAcross and known.foundAcross * 2 / 3)
    spans[zone] = known
    if known.across and known.down then
        return known
    end
    return nil
end

local function GetHeroMapPlace()
    if not GetPlayerMapPosition then return nil end
    local x, y = GetPlayerMapPosition("player")
    if (not x or (x == 0 and y == 0)) and SetMapToCurrentZone then
        SetMapToCurrentZone()
        x, y = GetPlayerMapPosition("player")
    end
    if not x or (x == 0 and y == 0) then return nil end
    return x, y
end

local function GetHeroWorld()
    local run = AZS_RUN
    if not run then return nil end
    local px, py = tonumber(run.px), tonumber(run.py)
    if not (px and py) then return nil end
    local facing = tonumber(run.pf)
    if facing then facing = -facing end
    return px, py, facing
end

local function WorldWay(px, py, x, y)
    return py - y, px - x
end

local function Indoors()
    if not GetCVar then return false end
    local zoom = Minimap:GetZoom() or 0
    local outside = tonumber(GetCVar("minimapZoom"))
    local inside = tonumber(GetCVar("minimapInsideZoom"))
    if outside and inside and outside ~= inside then
        return zoom == inside
    end
    return not GetHeroMapPlace()
end

local function GetMinimapYards()
    local zoom = Minimap:GetZoom() or 0
    local yards = Indoors() and INSIDE_YARDS or MINIMAP_YARDS
    return yards[zoom] or yards[0]
end

local function WayTo(place, px, py, heroX, heroY, span)
    local x, y = tonumber(place.x), tonumber(place.y)
    if px and x and y then
        return WorldWay(px, py, x, y)
    end
    local mx, my = Share(place.mx), Share(place.my)
    if heroX and span and mx and my then
        return (mx - heroX) * span.across, (my - heroY) * span.down
    end
    return nil, nil
end

local function CreateOrGetPin(index)
    local pin = pins[index]
    if pin then return pin end

    pin = CreateFrame("Frame", nil, Minimap)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel(25)
    pin:SetWidth(PIN_SIZE)
    pin:SetHeight(PIN_SIZE)

    -- Background glow for flagged lair
    local glow = pin:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ART_PATH .. "PaceGlow.tga")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    glow:Hide()
    pin.glow = glow

    -- Main pin art
    local art = pin:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints(pin)
    art:SetTexture(ART_PATH .. "PinCache.tga")
    pin.art = art

    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        local title = this.title or "Target"
        GameTooltip:AddLine(title, 0.0, 0.90, 1.0)
        if this.note and this.note ~= "" then
            GameTooltip:AddLine(this.note, 0.85, 0.85, 0.85)
        end
        if this.flagged then
            GameTooltip:AddLine("Primary Objective", 1.0, 0.82, 0.10)
        end
        if this.yards then
            local dist = math.floor(this.yards + 0.5)
            GameTooltip:AddLine(string.format("%d yards away", dist), 0.60, 0.60, 0.60)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pins[index] = pin
    return pin
end

local function PlacePin(pin, east, south, yardsAcross, baseSize)
    local half = Minimap:GetWidth() / 2
    local ya = (yardsAcross and yardsAcross > 0) and yardsAcross or 300
    local perYard = (2 * half) / ya
    pin.yards = math.sqrt(east * east + south * south)

    local px = east * perYard
    local py = -south * perYard
    local size = baseSize or PIN_SIZE
    local edgeSize = math.floor(size * EDGE_SIZE / PIN_SIZE + 0.5)

    -- Square minimap Chebyshev boundary
    local reach = math.max(math.abs(px), math.abs(py))
    local limit = half - (edgeSize / 2) - 1

    if reach > limit then
        if B.db and B.db.pinEdge == "hide" then
            pin:Hide()
            return
        end
        if reach > 0 then
            px = px * limit / reach
            py = py * limit / reach
        end
        size = edgeSize
        pin:SetAlpha(0.75)
    else
        pin:SetAlpha(1.0)
    end

    pin:SetWidth(size)
    pin:SetHeight(size)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", px, py)
    pin:Show()
end

function mod:UpdateRadar()
    local shown = 0
    flaggedPin = nil

    if not Playing() or not B:IsEnabled("pins") then
        local nPins = table.getn(pins)
        for i = 1, nPins do
            pins[i]:Hide()
        end
        return
    end

    local px, py = GetHeroWorld()
    local heroX, heroY, span
    if not px then
        heroX, heroY = GetHeroMapPlace()
        span = heroX and CalculateSpan()
    end

    local isDemo = B.unlocked or (B.db and B.db.demo)

    if px or span or isDemo then
        local yardsAcross = GetMinimapYards()

        -- 1. Field Caches (Chests)
        local chests = (B.db and B.db.pinCaches ~= false) and (AZS_CHESTS or (type(AZS_GetChests) == "function" and AZS_GetChests()) or {}) or {}
        if isDemo and (type(chests) ~= "table" or table.getn(chests) == 0) then
            chests = {
                { id = 1, x = 60, y = -50, mx = 0.52, my = 0.48 },
                { id = 2, x = -80, y = 90, mx = 0.46, my = 0.55 },
            }
        end
        local nChests = (type(chests) == "table") and table.getn(chests) or 0
        for i = 1, nChests do
            local chest = chests[i]
            local east, south
            if isDemo and not px and not span then
                east, south = tonumber(chest.x) or 0, tonumber(chest.y) or 0
            else
                east, south = WayTo(chest, px, py, heroX, heroY, span)
            end
            if east and south then
                shown = shown + 1
                local pin = CreateOrGetPin(shown)
                pin.art:SetTexture(ART_PATH .. "PinCache.tga")
                pin.art:SetVertexColor(1.0, 0.82, 0.15) -- Cyber Amber / Gold
                pin.glow:Hide()
                pin.title = "Cache of Wealth"
                pin.note = "Break open for gold, stats & card upgrades."
                pin.flagged = nil
                PlacePin(pin, east, south, yardsAcross, PIN_SIZE)
            end
        end

        -- 2. Guardian Lairs & Bosses (Shrines)
        local lairs = (B.db and B.db.pinLairs ~= false) and ((type(AZS_GetLairs) == "function" and AZS_GetLairs()) or (type(AZS_LAIRS) == "table" and AZS_LAIRS) or {}) or {}
        if isDemo and (type(lairs) ~= "table" or table.getn(lairs) == 0) then
            lairs = {
                { name = "Garr (Guardian)", id = 101, x = -110, y = -90, mx = 0.44, my = 0.45, state = "awake", flag = 1 },
                { name = "Baron Geddon", id = 102, x = 120, y = 130, mx = 0.56, my = 0.56, state = "empty", left = 45 },
            }
        end
        local nLairs = (type(lairs) == "table") and table.getn(lairs) or 0
        for i = 1, nLairs do
            local lair = lairs[i]
            local east, south
            if isDemo and not px and not span then
                east, south = tonumber(lair.x) or 0, tonumber(lair.y) or 0
            else
                east, south = WayTo(lair, px, py, heroX, heroY, span)
            end

            local sState = lair.state
            local isActive = (sState == "awake") or (sState == "asleep") or (lair.active == true) or (tonumber(lair.awake) and tonumber(lair.awake) > 0)
            local isAsleep = (sState == "asleep")

            if east and south and (isActive or (B.db and B.db.pinEmpty ~= "hide")) then
                shown = shown + 1
                local pin = CreateOrGetPin(shown)
                pin.art:SetTexture(ART_PATH .. "PinLair.tga")

                local markName = lair.name or ("Guardian Lair " .. tostring(lair.index or i))
                pin.title = markName

                if isActive then
                    if isAsleep then
                        pin.art:SetVertexColor(0.20, 0.70, 1.0) -- Soft Ice Cyan
                        pin.note = "Dormant Guardian: " .. markName .. " (Approach to awaken)"
                    else
                        pin.art:SetVertexColor(1.0, 0.25, 0.25) -- Neon Crimson / Red (Active Boss!)
                        pin.note = "BOSS / GUARDIAN ACTIVE: " .. markName
                    end
                else
                    pin.art:SetVertexColor(0.40, 0.40, 0.45) -- Dimmed Slate
                    local respawnLeft = tonumber(lair.left) or tonumber(lair.respawn) or 0
                    if respawnLeft > 0 then
                        pin.note = string.format("Empty lair (Respawns in %s)", B:Clock(respawnLeft))
                    else
                        pin.note = "Empty lair"
                    end
                end

                pin.flagged = (tonumber(lair.flag) == 1)

                if pin.flagged then
                    flaggedPin = pin
                    pin.glow:SetVertexColor(1.0, 0.82, 0.10)
                    pin.glow:Show()
                else
                    pin.glow:Hide()
                end

                PlacePin(pin, east, south, yardsAcross, PIN_SIZE + 2)
            end
        end
    end

    local totalPins = table.getn(pins)
    for i = shown + 1, totalPins do
        pins[i]:Hide()
    end
end

function mod:Create()
    local watcher = CreateFrame("Frame", "BUI_RadarWatcher", Minimap)
    watcher:SetScript("OnUpdate", function()
        local dt = arg1 or 0.05
        elapsedTimer = elapsedTimer + dt
        if elapsedTimer >= 0.10 then
            elapsedTimer = 0
            mod:UpdateRadar()
        end

        -- Flagged pin pulse animation
        breathTime = breathTime + dt
        if flaggedPin and flaggedPin:IsShown() then
            local pSize = flaggedPin:GetWidth() * (2.2 + 0.35 * math.sin(breathTime * 4))
            flaggedPin.glow:SetWidth(pSize)
            flaggedPin.glow:SetHeight(pSize)
            flaggedPin.glow:SetAlpha(0.60 + 0.30 * math.sin(breathTime * 4))
            flaggedPin.glow:Show()
        end
    end)
    self.watcher = watcher
    self.frame = watcher
end

B:RegisterModule("pins", mod)
