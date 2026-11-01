-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Minimap.lua
--  Copyright (c) 2026 Pierre (Blackwellcode). All rights reserved. See LICENSE.
--  Authentic Minimap:
--  - Clean square minimap (140 x 140 by default): rounded frame in the round
--    style, 1px black border in the sharp style
--  - Bottom zone banner (pill in the round style, strip in the sharp style)
--  - Coordinates overlay, optional clock, optional hiding of addon buttons
--  - Mousewheel zoom in/out
--  - Complete suppression of circular Blizzard frames, textures and buttons
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Minimap"
mod.toggleLabel = "Square minimap with coordinates"
mod.alwaysActive = true
-- Minimap is reparented and BuffFrame/ToggleMinimap are stubbed; off takes a /reload.
mod.reloadOnToggle = true

local function Noop() end

local MAP_SIZE = 140
local FOOTER_HEIGHT = 18

local COORD_FORMATS = {
    ["0"] = "%.0f, %.0f",
    ["1"] = "%.1f, %.1f",
    ["2"] = "%.2f, %.2f",
}

mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "size", label = "Size", min = 100, max = 260, step = 10, default = MAP_SIZE, format = "%d px" },
    { type = "toggle", key = "showZone", label = "Show zone text", default = true },
    { type = "range", key = "zoneFontSize", label = "Zone font size", min = 8, max = 14, step = 1, default = 10, format = "%d px", depends = "showZone" },
    { type = "toggle", key = "mouseWheelZoom", label = "Zoom with the mousewheel", default = true },
    { type = "section", label = "Coordinates" },
    { type = "toggle", key = "showCoords", label = "Show coordinates", default = true },
    { type = "choice", key = "coordPrecision", label = "Decimals", default = "1", depends = "showCoords",
      values = { { value = "0", label = "None" }, { value = "1", label = "One" }, { value = "2", label = "Two" } } },
    { type = "choice", key = "coordPosition", label = "Position", default = "topleft", depends = "showCoords",
      values = {
          { value = "topleft", label = "Top left" }, { value = "topright", label = "Top right" },
          { value = "bottomleft", label = "Bottom left" }, { value = "bottomright", label = "Bottom right" },
      } },
    { type = "section", label = "Clock" },
    { type = "toggle", key = "showClock", label = "Show clock", default = false },
    { type = "choice", key = "clockSource", label = "Time", default = "local", depends = "showClock",
      values = { { value = "local", label = "Local time" }, { value = "server", label = "Server time" } } },
    { type = "toggle", key = "clock24", label = "24-hour clock", default = true, depends = "showClock" },
    { type = "section", label = "Buttons" },
    { type = "toggle", key = "showMail", label = "Show mail icon", default = true },
    { type = "toggle", key = "hideButtons", label = "Hide addon buttons",
      hint = "Hides buttons other addons put on the minimap.", default = false },
}

local function Opt(key, default)
    return B:ModOpt("minimap", key, default)
end

-- Pill behind a text: two disc halves and a stretched middle on the owner's
-- BACKGROUND layer, anchored to both owner edges (square in the sharp style).
local function MakePill(owner, height)
    local shape = B:ShapeTexture()
    local left = owner:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(shape)
    left:SetTexCoord(0, 0.5, 0, 1)
    left:SetWidth(height / 2)
    left:SetHeight(height)
    left:SetPoint("LEFT", owner, "LEFT", 0, 0)
    local right = owner:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(shape)
    right:SetTexCoord(0.5, 1, 0, 1)
    right:SetWidth(height / 2)
    right:SetHeight(height)
    right:SetPoint("RIGHT", owner, "RIGHT", 0, 0)
    local mid = owner:CreateTexture(nil, "BACKGROUND")
    mid:SetTexture(B.WHITE)
    mid:SetHeight(height)
    mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
    mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
    local p = { parts = { left, mid, right } }
    function p:SetColor(r, g, b, a)
        for i = 1, 3 do
            self.parts[i]:SetVertexColor(r, g, b)
            self.parts[i]:SetAlpha(a or 1)
        end
    end
    return p
end

function mod:HideBlizzardArt()
    local hideList = {
        MinimapBorder,
        MinimapBorderTop,
        MinimapZoneTextButton,
        MinimapToggleButton,
        MinimapZoomIn,
        MinimapZoomOut,
        GameTimeFrame,
        MiniMapTrackingFrame,
        MiniMapMeetingStoneFrame,
        MiniMapBattlefieldFrame,
        MiniMapWorldMapButton,
    }
    for i = 1, table.getn(hideList) do
        local f = hideList[i]
        if f then
            f:Hide()
            f:SetAlpha(0)
            if f.ClearAllPoints then
                f:ClearAllPoints()
                f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
            end
            if f.UnregisterAllEvents then
                pcall(f.UnregisterAllEvents, f)
            end
            if f.EnableMouse then
                f:EnableMouse(false)
            end
            f.Show = function() end
            if f.GetObjectType and f:GetObjectType() == "Texture" then
                f:SetTexture(nil)
            end
        end
    end

    if MinimapBorderTop and MinimapBorderTop.SetAlpha then
        MinimapBorderTop:SetAlpha(0)
    end

    if MinimapNorthTag then
        MinimapNorthTag:SetAlpha(0)
    end

    ToggleMinimap = Noop
end

local function SuppressBuffFrame()
    if BuffFrame then
        BuffFrame:Hide()
        BuffFrame:SetAlpha(0)
        BuffFrame:ClearAllPoints()
        BuffFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
        BuffFrame:UnregisterAllEvents()
        BuffFrame.Show = Noop
    end
    if type(BuffFrame_Update) == "function" then
        BuffFrame_Update = Noop
    end
    for i = 0, 23 do
        local btn = getglobal("BuffButton" .. i)
        if btn then
            btn:Hide()
            btn:SetAlpha(0)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
            btn.Show = Noop
        end
    end
    for i = 1, 2 do
        local te = getglobal("TempEnchant" .. i)
        if te then
            te:Hide()
            te:SetAlpha(0)
            te:ClearAllPoints()
            te:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 5000, 5000)
            te.Show = Noop
        end
    end
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_MinimapModule", UIParent)
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardArt()
    SuppressBuffFrame()

    ---------------------------------------------------------------------------
    --  Minimap Container (map size + frame inset on each side)
    ---------------------------------------------------------------------------
    -- Round style: the rounded panel shows as a frame around the square map.
    local round = B:IsRound()
    local inset = round and 4 or 1
    self.inset = inset
    local cont = CreateFrame("Frame", "BUI_Minimap", root)
    cont:SetWidth(MAP_SIZE + 2 * inset)
    cont:SetHeight(MAP_SIZE + 2 * inset)
    B:Panel(cont)
    -- Scale / opacity / visibility act on the map, not the full-screen root.
    self.lookFrames = { cont }

    ---------------------------------------------------------------------------
    --  Minimap Frame (Square Mask)
    ---------------------------------------------------------------------------
    if Minimap then
        Minimap:SetParent(cont)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPLEFT", cont, "TOPLEFT", inset, -inset)
        Minimap:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -inset, inset)
        Minimap:SetWidth(MAP_SIZE)
        Minimap:SetHeight(MAP_SIZE)
        Minimap:SetFrameLevel(cont:GetFrameLevel() + 1)
        Minimap:Show()

        -- Mask to 1.12 square if supported
        local smt = rawget(Minimap, "SetMaskTexture")
        if type(smt) == "function" then
            pcall(smt, Minimap, B.WHITE)
        end

        -- Explicitly restore Rotating Player Arrow
        local sam = rawget(Minimap, "SetArrowModel")
        if type(sam) == "function" then
            pcall(sam, Minimap, "Interface\\Minimap\\Rotating-MinimapArrow.mdx")
        end

        -- Elevate any child Model frames (such as player position arrow) above the backdrop
        local children = { Minimap:GetChildren() }
        for i = 1, table.getn(children) do
            local child = children[i]
            if child and child:IsObjectType("Model") then
                child:SetFrameLevel(Minimap:GetFrameLevel() + 3)
                child:Show()
            end
        end

        -- Mousewheel zoom
        if type(Minimap.EnableMouseWheel) == "function" then
            Minimap:EnableMouseWheel(true)
            Minimap:SetScript("OnMouseWheel", function()
                if not Opt("mouseWheelZoom", true) then return end
                if arg1 and arg1 > 0 then
                    if type(Minimap_ZoomIn) == "function" then Minimap_ZoomIn() end
                else
                    if type(Minimap_ZoomOut) == "function" then Minimap_ZoomOut() end
                end
            end)
        end
    end

    ---------------------------------------------------------------------------
    --  Bottom Zone Banner
    ---------------------------------------------------------------------------
    local footer = CreateFrame("Button", nil, cont)
    footer:EnableMouse(true)
    if round then
        -- Round style: a dark pill floating above the map's bottom edge.
        footer:SetPoint("BOTTOMLEFT", cont, "BOTTOMLEFT", inset + 4, inset + 4)
        footer:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -inset - 4, inset + 4)
        footer:SetHeight(FOOTER_HEIGHT - 2)
        local pill = MakePill(footer, FOOTER_HEIGHT - 2)
        pill:SetColor(0, 0, 0, 0.62)
    else
        footer:SetPoint("BOTTOMLEFT", cont, "BOTTOMLEFT", 1, 1)
        footer:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -1, 1)
        footer:SetHeight(FOOTER_HEIGHT)

        local footerBg = footer:CreateTexture(nil, "BACKGROUND")
        footerBg:SetAllPoints(footer)
        B:Solid(footerBg, 0.05, 0.05, 0.05, 0.85)

        local footerLine = footer:CreateTexture(nil, "BORDER")
        footerLine:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
        footerLine:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
        footerLine:SetHeight(1)
        B:Solid(footerLine, 0, 0, 0, 1)
    end
    self.footer = footer

    local zoneFs = B:Font(footer, 10, "CENTER")
    zoneFs:SetPoint("LEFT", footer, "LEFT", 4, 0)
    zoneFs:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
    zoneFs:SetHeight(14)
    zoneFs:SetTextColor(1, 1, 1)
    self.zoneFs = zoneFs

    footer:SetScript("OnClick", function()
        if ToggleWorldMap then
            ToggleWorldMap()
        end
    end)

    ---------------------------------------------------------------------------
    --  Coordinates Badge (corner set in the options, top left by default)
    ---------------------------------------------------------------------------
    local coordBadge = CreateFrame("Frame", nil, cont)
    coordBadge:SetPoint("TOPLEFT", cont, "TOPLEFT", inset + 2, -(inset + 2))
    coordBadge:SetWidth(50)
    coordBadge:SetHeight(14)
    coordBadge:SetFrameLevel(cont:GetFrameLevel() + 6)

    local coordFs = B:Font(coordBadge, 9, round and "CENTER" or "LEFT")
    coordFs:SetHeight(14)
    B:Accent(coordFs, "text")
    if round then
        coordFs:SetPoint("CENTER", coordBadge, "CENTER", 0, 0)
        local cPill = MakePill(coordBadge, 14)
        cPill:SetColor(0, 0, 0, 0.55)
    else
        coordFs:SetPoint("LEFT", coordBadge, "LEFT", 0, 0)
    end
    self.coordFs = coordFs
    self.coordBadge = coordBadge

    ---------------------------------------------------------------------------
    --  Clock Badge (top centre)
    ---------------------------------------------------------------------------
    local clockBadge = CreateFrame("Frame", nil, cont)
    clockBadge:SetPoint("TOP", cont, "TOP", 0, -(inset + 2))
    clockBadge:SetWidth(44)
    clockBadge:SetHeight(14)
    clockBadge:SetFrameLevel(cont:GetFrameLevel() + 6)
    local clockFs = B:Font(clockBadge, 9, "CENTER")
    clockFs:SetPoint("CENTER", clockBadge, "CENTER", 0, 0)
    clockFs:SetTextColor(0.92, 0.92, 0.92)
    if round then
        local kPill = MakePill(clockBadge, 14)
        kPill:SetColor(0, 0, 0, 0.55)
    end
    clockBadge:Hide()
    self.clockBadge = clockBadge
    self.clockFs = clockFs

    -- Clean mail indicator
    if MiniMapMailFrame then
        MiniMapMailFrame:ClearAllPoints()
        MiniMapMailFrame:SetPoint("TOPRIGHT", cont, "TOPRIGHT", -(inset + 3), -(inset + 3))
        MiniMapMailFrame:SetFrameStrata("HIGH")
    end

    B:RegisterMover(cont, "minimap", L["Minimap"], "TOPRIGHT", "TOPRIGHT", -12, -12)
    self.container = cont
end

-- Buttons other addons parent to the minimap. Ours (BUI_*) and the mail icon
-- stay; only buttons that were visible are hidden, and exactly those return.
function mod:HideAddonButtons()
    if not Minimap then return end
    self.hiddenButtons = self.hiddenButtons or {}
    local children = { Minimap:GetChildren() }
    for i = 1, table.getn(children) do
        local c = children[i]
        if c and c ~= MiniMapMailFrame and c:IsObjectType("Button") and c:IsShown() then
            local name = c:GetName()
            if not (name and string.find(name, "^BUI_")) then
                c:Hide()
                self.hiddenButtons[c] = true
            end
        end
    end
end

function mod:RestoreButtons()
    if not self.hiddenButtons then return end
    for c in pairs(self.hiddenButtons) do
        c:Show()
        self.hiddenButtons[c] = nil
    end
end

function mod:ApplyOptions()
    local cont = self.container
    if not cont then return end
    local inset = self.inset or 1
    local size = Opt("size", MAP_SIZE)
    cont:SetWidth(size + 2 * inset)
    cont:SetHeight(size + 2 * inset)
    if Minimap then
        Minimap:SetWidth(size)
        Minimap:SetHeight(size)
    end

    local showZone = Opt("showZone", true)
    if self.footer then
        if showZone then self.footer:Show() else self.footer:Hide() end
    end
    if self.zoneFs then
        self.zoneFs.buiSize = Opt("zoneFontSize", 10)
        B:ApplyFont(self.zoneFs)
    end

    local badge = self.coordBadge
    if badge then
        local pos = Opt("coordPosition", "topleft")
        local pad = inset + 2
        local bottomLift = pad
        if showZone then
            bottomLift = pad + FOOTER_HEIGHT + 2
        end
        badge:ClearAllPoints()
        if pos == "topright" then
            badge:SetPoint("TOPRIGHT", cont, "TOPRIGHT", -pad, -pad)
        elseif pos == "bottomleft" then
            badge:SetPoint("BOTTOMLEFT", cont, "BOTTOMLEFT", pad, bottomLift)
        elseif pos == "bottomright" then
            badge:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -pad, bottomLift)
        else
            badge:SetPoint("TOPLEFT", cont, "TOPLEFT", pad, -pad)
        end
        if Opt("showCoords", true) then badge:Show() else badge:Hide() end
    end

    if self.clockBadge then
        if Opt("showClock", false) then self.clockBadge:Show() else self.clockBadge:Hide() end
    end

    if MiniMapMailFrame then
        if Opt("showMail", true) then
            if type(HasNewMail) == "function" and HasNewMail() then MiniMapMailFrame:Show() end
        else
            MiniMapMailFrame:Hide()
        end
    end

    if Opt("hideButtons", false) then
        self:HideAddonButtons()
    else
        self:RestoreButtons()
    end
end

-- Local time needs date(); without it (or for "server") the game clock is used.
local function ClockText()
    local h, m
    if Opt("clockSource", "local") == "local" and type(date) == "function" then
        h = tonumber(date("%H"))
        m = tonumber(date("%M"))
    elseif type(GetGameTime) == "function" then
        h, m = GetGameTime()
    end
    if not h or not m then return "" end
    h = math.floor(h)
    m = math.floor(m)
    if Opt("clock24", true) then
        return string.format("%02d:%02d", h, m)
    end
    local suffix = (h >= 12) and "PM" or "AM"
    local h12 = math.mod(h, 12)
    if h12 == 0 then h12 = 12 end
    return string.format("%d:%02d %s", h12, m, suffix)
end

function mod:Update(state)
    SuppressBuffFrame()
    if MinimapToggleButton and MinimapToggleButton:IsShown() then
        MinimapToggleButton:Hide()
        MinimapToggleButton:SetAlpha(0)
    end
    -- Update Zone Name
    if self.zoneFs then
        local zText = GetMinimapZoneText()
        if not zText or zText == "" then
            local z = state and state.zone
            zText = z and z.zname or "Azeroth"
        end
        self.zoneFs:SetText(zText)
    end

    -- Update Coordinates
    if self.coordFs and Opt("showCoords", true) then
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then
            local fmt = COORD_FORMATS[Opt("coordPrecision", "1")] or COORD_FORMATS["1"]
            self.coordFs:SetText(string.format(fmt, x * 100, y * 100))
        else
            self.coordFs:SetText("")
        end
        local w = self.coordFs:GetStringWidth() or 0
        if w > 0 then
            self.coordBadge:SetWidth(w + 10)
        end
    end

    -- Clock
    if self.clockFs and Opt("showClock", false) then
        self.clockFs:SetText(ClockText())
        local w = self.clockFs:GetStringWidth() or 0
        if w > 0 then
            self.clockBadge:SetWidth(w + 12)
        end
    end

    if MiniMapMailFrame and not Opt("showMail", true) and MiniMapMailFrame:IsShown() then
        MiniMapMailFrame:Hide()
    end

    -- Addons may create or re-show their buttons later: rescan every 2 s.
    if Opt("hideButtons", false) then
        self.buttonScan = (self.buttonScan or 0) + 1
        if self.buttonScan >= 20 then
            self.buttonScan = 0
            self:HideAddonButtons()
        end
    end
end

B:RegisterModule("minimap", mod)
