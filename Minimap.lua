-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Minimap.lua
--  Authentic Minimap:
--  - Clean 140 x 140 square minimap with 1px black border
--  - Bottom zone banner strip (locationMode="inside", locationPosition="bottom")
--  - Coordinates overlay
--  - Mousewheel zoom in/out
--  - Complete suppression of circular Blizzard frames, textures and buttons
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Minimap"
mod.alwaysActive = true

local MAP_SIZE = 140
local FOOTER_HEIGHT = 18

function mod:HideBlizzardArt()
    local hideList = {
        MinimapBorder,
        MinimapBorderTop,
        MinimapZoneTextButton,
        MinimapZoomIn,
        MinimapZoomOut,
        GameTimeFrame,
        MiniMapTrackingFrame,
        MiniMapMeetingStoneFrame,
        MiniMapWorldMapButton,
    }
    for i = 1, table.getn(hideList) do
        local f = hideList[i]
        if f then
            f:Hide()
            f:SetAlpha(0)
        end
    end

    if MinimapNorthTag then
        MinimapNorthTag:SetAlpha(0)
    end
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_MinimapModule", UIParent)
    EUI_MinimapModule = root -- Compatibility alias
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardArt()

    ---------------------------------------------------------------------------
    --  Minimap Container (142 x 142)
    ---------------------------------------------------------------------------
    local cont = CreateFrame("Frame", "BUI_Minimap", root)
    EUI_Minimap = cont -- Compatibility alias
    cont:SetWidth(MAP_SIZE + 2)
    cont:SetHeight(MAP_SIZE + 2)
    B:Backdrop(cont, 0.90)

    ---------------------------------------------------------------------------
    --  Minimap Frame (Square Mask)
    ---------------------------------------------------------------------------
    if Minimap then
        Minimap:SetParent(cont)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPLEFT", cont, "TOPLEFT", 1, -1)
        Minimap:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -1, 1)
        Minimap:SetWidth(MAP_SIZE)
        Minimap:SetHeight(MAP_SIZE)

        -- Mask to 1.12 square if supported
        if type(Minimap.SetMaskTexture) == "function" then
            Minimap:SetMaskTexture(B.WHITE)
        end

        -- Mousewheel zoom
        if type(Minimap.EnableMouseWheel) == "function" then
            Minimap:EnableMouseWheel(true)
            Minimap:SetScript("OnMouseWheel", function()
                if arg1 and arg1 > 0 then
                    if type(Minimap_ZoomIn) == "function" then Minimap_ZoomIn() end
                else
                    if type(Minimap_ZoomOut) == "function" then Minimap_ZoomOut() end
                end
            end)
        end
    end

    ---------------------------------------------------------------------------
    --  Bottom Zone Banner Strip
    ---------------------------------------------------------------------------
    local footer = CreateFrame("Button", nil, cont)
    footer:SetPoint("BOTTOMLEFT", cont, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", cont, "BOTTOMRIGHT", -1, 1)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:EnableMouse(true)

    local footerBg = footer:CreateTexture(nil, "BACKGROUND")
    footerBg:SetAllPoints(footer)
    B:Solid(footerBg, 0.05, 0.05, 0.05, 0.85)

    local footerLine = footer:CreateTexture(nil, "BORDER")
    footerLine:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footerLine:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footerLine:SetHeight(1)
    B:Solid(footerLine, 0, 0, 0, 1)

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
    --  Coordinates Badge (Top-Left of Minimap)
    ---------------------------------------------------------------------------
    local coordBadge = CreateFrame("Frame", nil, cont)
    coordBadge:SetPoint("TOPLEFT", cont, "TOPLEFT", 3, -3)
    coordBadge:SetWidth(50)
    coordBadge:SetHeight(14)

    local coordFs = B:Font(coordBadge, 9, "LEFT")
    coordFs:SetPoint("LEFT", coordBadge, "LEFT", 0, 0)
    coordFs:SetWidth(50)
    coordFs:SetHeight(14)
    B:Accent(coordFs, "text")
    self.coordFs = coordFs

    -- Clean mail indicator
    if MiniMapMailFrame then
        MiniMapMailFrame:ClearAllPoints()
        MiniMapMailFrame:SetPoint("TOPRIGHT", cont, "TOPRIGHT", -4, -4)
        MiniMapMailFrame:SetFrameStrata("HIGH")
    end

    B:RegisterMover(cont, "minimap", "Minimap", "TOPRIGHT", "TOPRIGHT", -12, -12)
    self.container = cont
end

function mod:Update(state)
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
    if self.coordFs then
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then
            self.coordFs:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
        else
            self.coordFs:SetText("")
        end
    end
end

B:RegisterModule("minimap", mod)
