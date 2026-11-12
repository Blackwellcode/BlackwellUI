-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Chat.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Chat panel in the active style, mousewheel scrolling, styled EditBox,
--  hides scroll buttons, optional timestamps and tab pills.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local mod = {}
mod.label = "Chat panel"
mod.alwaysActive = true
-- ChatFrame1 is reparented into the panel; turning it off takes a /reload.
mod.reloadOnToggle = true

local CHAT_WIDTH = 380
local CHAT_HEIGHT = 140
local TAB_PILL_HEIGHT = 18

mod.options = {
    { type = "section", label = "Layout" },
    { type = "range", key = "width", label = "Width", min = 240, max = 800, step = 10, default = CHAT_WIDTH, format = "%d px" },
    { type = "range", key = "height", label = "Height", min = 80, max = 400, step = 10, default = CHAT_HEIGHT, format = "%d px" },
    { type = "toggle", key = "showBackground", label = "Show background", default = true },
    { type = "choice", key = "editBoxPosition", label = "Input box", default = "top",
      values = { { value = "top", label = "Above the panel" }, { value = "bottom", label = "Below the panel" } } },
    { type = "section", label = "Text" },
    { type = "range", db = "chatFontSize", label = "Font size", min = 8, max = 20, step = 1, default = 12, format = "%d px" },
    { type = "toggle", key = "timestamps", label = "Show timestamps", default = false },
    { type = "choice", key = "timestampFormat", label = "Timestamp format", default = "hm", depends = "timestamps",
      values = { { value = "hm", label = "12:34" }, { value = "hms", label = "12:34:56" } } },
    { type = "toggle", key = "fade", label = "Fade old messages", default = true },
    { type = "range", key = "fadeTime", label = "Visible for", min = 10, max = 300, step = 10, default = 120, format = "%d s", depends = "fade" },
    { type = "range", key = "scrollLines", label = "Lines per wheel step", min = 1, max = 5, step = 1, default = 1, format = "%d" },
    { type = "toggle", db = "filterChatSpam", label = "Filter level-up spam", default = true },
    { type = "section", label = "Tabs" },
    { type = "choice", key = "tabStyle", label = "Tab style", default = "text",
      values = { { value = "text", label = "Text only" }, { value = "pill", label = "Pill" } } },
    { type = "range", key = "tabFontSize", label = "Tab font size", min = 7, max = 14, step = 1, default = 9, format = "%d px" },
    { type = "toggle", key = "accentActiveTab", label = "Accent the active tab", default = true },
}

local function Opt(key, default)
    return B:ModOpt("chat", key, default)
end

-- Shows or hides a backdrop made by B:Panel / B:Backdrop in either style.
local function SetBackdropShown(f, show)
    local parts = {}
    if f.buiRound then table.insert(parts, f.buiRound) end
    if f.buiBg then table.insert(parts, f.buiBg) end
    if f.buiEdges then
        for i = 1, table.getn(f.buiEdges) do table.insert(parts, f.buiEdges[i]) end
    end
    for i = 1, table.getn(parts) do
        if show then parts[i]:Show() else parts[i]:Hide() end
    end
end

function mod:HideBlizzardButtons()
    local btnList = {
        ChatFrame1UpButton,
        ChatFrame1DownButton,
        ChatFrame1BottomButton,
        ChatFrameMenuButton,
    }
    for i = 1, table.getn(btnList) do
        local btn = btnList[i]
        if btn then
            btn:Hide()
            btn:SetAlpha(0)
            btn:SetScript("OnShow", function() this:Hide() end)
        end
    end
end

function mod:SkinEditBox(panel)
    if not ChatFrameEditBox then return end

    -- Hide Blizzard chrome
    local toHide = {
        ChatFrameEditBoxLeft,
        ChatFrameEditBoxRight,
        ChatFrameEditBoxMid,
    }
    for i = 1, table.getn(toHide) do
        local tex = toHide[i]
        if tex then
            tex:SetTexture("")
            tex:Hide()
        end
    end
    if ChatFrameEditBoxHeader then
        ChatFrameEditBoxHeader:Hide()
    end

    self:PositionEditBox()
    ChatFrameEditBox:SetHeight(22)
    ChatFrameEditBox:SetFont(B:GetFontPath(), 10)

    if not ChatFrameEditBox.buiBackdrop then
        B:Backdrop(ChatFrameEditBox, 0.85)
        ChatFrameEditBox.buiBackdrop = true
    end
end

function mod:PositionEditBox()
    local panel = self.panel
    if not ChatFrameEditBox or not panel then return end
    ChatFrameEditBox:ClearAllPoints()
    if Opt("editBoxPosition", "top") == "bottom" then
        ChatFrameEditBox:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -4)
        ChatFrameEditBox:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -4)
    else
        ChatFrameEditBox:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 4)
        ChatFrameEditBox:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 4)
    end
end

-- Blizzard's tab template carries a HIGHLIGHT-layer texture, which this
-- engine draws all the time: blank it and show our own hover tint instead.
local function StripTabHighlight(tab, i)
    if type(tab.GetHighlightTexture) == "function" then
        local h = tab:GetHighlightTexture()
        if h then
            h:SetTexture(nil)
            h:Hide()
        end
    end
    local named = getglobal("ChatFrame" .. i .. "TabHighlight")
    if named and type(named.SetTexture) == "function" then
        named:SetTexture(nil)
        named:Hide()
    end
end

-- Pill drawn with the tab's own textures (behind its text): two disc halves
-- and a stretched middle, anchored to both tab edges so it needs no layout.
local function MakePill(owner, height)
    local shape = B:ShapeTexture()
    local p = { parts = {} }
    local left = owner:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(shape)
    left:SetTexCoord(0, 0.5, 0, 1)
    left:SetWidth(height / 2)
    left:SetHeight(height)
    left:SetPoint("LEFT", owner, "LEFT", 2, 0)
    local right = owner:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(shape)
    right:SetTexCoord(0.5, 1, 0, 1)
    right:SetWidth(height / 2)
    right:SetHeight(height)
    right:SetPoint("RIGHT", owner, "RIGHT", -2, 0)
    local mid = owner:CreateTexture(nil, "BACKGROUND")
    mid:SetTexture(B.WHITE)
    mid:SetHeight(height)
    mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
    mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
    p.parts[1] = left
    p.parts[2] = mid
    p.parts[3] = right
    function p:SetColor(r, g, b, a)
        for i = 1, 3 do
            self.parts[i]:SetVertexColor(r, g, b)
            self.parts[i]:SetAlpha(a or 1)
        end
    end
    function p:Show()
        for i = 1, 3 do self.parts[i]:Show() end
    end
    function p:Hide()
        for i = 1, 3 do self.parts[i]:Hide() end
    end
    return p
end

function mod:SkinTabs()
    self.tabs = self.tabs or {}
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local tab = getglobal("ChatFrame" .. i .. "Tab")
        if tab then
            local left = getglobal("ChatFrame" .. i .. "TabLeft")
            local mid = getglobal("ChatFrame" .. i .. "TabMiddle")
            local right = getglobal("ChatFrame" .. i .. "TabRight")
            if left then left:Hide() end
            if mid then mid:Hide() end
            if right then right:Hide() end

            local tabText = getglobal("ChatFrame" .. i .. "TabText")
            if tabText then
                tabText:SetFont(B:GetFontPath(), 9, "OUTLINE")
                tabText:SetTextColor(0.8, 0.8, 0.8)
            end

            if not tab.buiSkinned then
                tab.buiSkinned = true
                StripTabHighlight(tab, i)

                local pill = MakePill(tab, TAB_PILL_HEIGHT)
                pill:SetColor(0, 0, 0, 0.55)
                pill:Hide()
                tab.buiPill = pill

                local hover = MakePill(tab, TAB_PILL_HEIGHT)
                hover:SetColor(1, 1, 1, 0.08)
                hover:Hide()
                tab.buiHover = hover

                local origEnter = tab:GetScript("OnEnter")
                local origLeave = tab:GetScript("OnLeave")
                tab:SetScript("OnEnter", function()
                    if this.buiHover then this.buiHover:Show() end
                    if origEnter then origEnter() end
                end)
                tab:SetScript("OnLeave", function()
                    if this.buiHover then this.buiHover:Hide() end
                    if origLeave then origLeave() end
                end)

                table.insert(self.tabs, { tab = tab, text = tabText, frame = getglobal("ChatFrame" .. i) })
            end
        end
    end
end

function mod:ApplyTabs()
    if not self.tabs then return end
    local pill = Opt("tabStyle", "text") == "pill"
    local size = Opt("tabFontSize", 9)
    for i = 1, table.getn(self.tabs) do
        local t = self.tabs[i]
        if t.text then
            t.text:SetFont(B:GetFontPath(), size, "OUTLINE")
        end
        if t.tab.buiPill then
            if pill then
                t.tab.buiPill:Show()
            else
                t.tab.buiPill:Hide()
            end
        end
    end
end

function mod:UpdateTabs()
    if not self.tabs then return end
    local accent = Opt("accentActiveTab", true)
    local pill = Opt("tabStyle", "text") == "pill"
    local ar, ag, ab = B:GetAccent()
    for i = 1, table.getn(self.tabs) do
        local t = self.tabs[i]
        local active = accent and t.frame and SELECTED_CHAT_FRAME == t.frame
        if t.text then
            if active then
                t.text:SetTextColor(ar, ag, ab)
            else
                t.text:SetTextColor(0.8, 0.8, 0.8)
            end
        end
        if pill and t.tab.buiPill then
            if active then
                t.tab.buiPill:SetColor(ar, ag, ab, 0.22)
            else
                t.tab.buiPill:SetColor(0, 0, 0, 0.55)
            end
        end
    end
end

function mod:PositionChat()
    if not ChatFrame1 or not self.panel then return end

    SIMPLE_CHAT = "0"

    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetParent(self.panel)
    ChatFrame1:SetPoint("BOTTOMLEFT", self.panel, "BOTTOMLEFT", 6, 6)
    ChatFrame1:SetWidth(self.panel:GetWidth() - 12)
    ChatFrame1:SetHeight(self.panel:GetHeight() - 12)
    ChatFrame1:SetUserPlaced(1)
    ChatFrame1:SetClampedToScreen(false)

    local fontSize = (B.db and B.db.chatFontSize) or 12
    if type(ChatFrame1.SetFont) == "function" then
        ChatFrame1:SetFont(B:GetFontPath(), fontSize)
    end
end

-------------------------------------------------------------------------------
--  Timestamps: AddMessage is wrapped once per chat frame; the setting is
--  read on every message, so switching it needs no reload.
-------------------------------------------------------------------------------
local function Timestamp()
    local fmt = Opt("timestampFormat", "hm")
    if type(date) == "function" then
        if fmt == "hms" then
            return date("%H:%M:%S")
        end
        return date("%H:%M")
    end
    if type(GetGameTime) == "function" then
        local h, m = GetGameTime()
        return string.format("%02d:%02d", math.floor(h or 0), math.floor(m or 0))
    end
    return nil
end

function mod:HookTimestamps()
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local cf = getglobal("ChatFrame" .. i)
        if cf and type(cf.AddMessage) == "function" and not cf.buiOrigAddMessage then
            cf.buiOrigAddMessage = cf.AddMessage
            cf.AddMessage = function(self, msg, r, g, b, id, hold)
                if type(msg) == "string" and Opt("timestamps", false) then
                    local stamp = Timestamp()
                    if stamp then
                        msg = "|cff8a8f99" .. stamp .. "|r " .. msg
                    end
                end
                return self.buiOrigAddMessage(self, msg, r, g, b, id, hold)
            end
        end
    end
end

function mod:Create()
    local root = CreateFrame("Frame", "BUI_ChatModule", UIParent)
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardButtons()

    ---------------------------------------------------------------------------
    --  Chat Panel (default 380 x 140, sized by the options)
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "BUI_ChatPanel", root)
    panel:SetWidth(Opt("width", CHAT_WIDTH))
    panel:SetHeight(Opt("height", CHAT_HEIGHT))
    B:Panel(panel)
    self.panel = panel
    -- Scale / opacity / visibility act on the panel, not the full-screen root.
    self.lookFrames = { panel }

    if ChatFrame1 then
        self:PositionChat()

        -- Mousewheel scroll
        ChatFrame1:EnableMouseWheel(true)
        ChatFrame1:SetScript("OnMouseWheel", function()
            local lines = math.floor(Opt("scrollLines", 1))
            if lines < 1 then lines = 1 end
            if arg1 > 0 then
                if IsShiftKeyDown() then
                    this:ScrollToTop()
                else
                    for n = 1, lines do this:ScrollUp() end
                end
            else
                if IsShiftKeyDown() then
                    this:ScrollToBottom()
                else
                    for n = 1, lines do this:ScrollDown() end
                end
            end
        end)
    end

    -- Hook FCF_RestorePositionAndDimensions so Blizzard cannot collapse ChatFrame1
    if type(FCF_RestorePositionAndDimensions) == "function" and not mod.hookedFCF then
        mod.hookedFCF = true
        local orig_FCF_Restore = FCF_RestorePositionAndDimensions
        FCF_RestorePositionAndDimensions = function(chatFrame)
            if orig_FCF_Restore then orig_FCF_Restore(chatFrame) end
            if chatFrame == ChatFrame1 and mod.panel then
                mod:PositionChat()
            end
        end
    end

    self:SkinEditBox(panel)
    self:SkinTabs()
    self:HookTimestamps()

    B:RegisterMover(panel, "chat", L["Chat Frame"], "BOTTOMLEFT", "BOTTOMLEFT", 12, 24)
end

function mod:ApplyOptions()
    local panel = self.panel
    if not panel then return end
    panel:SetWidth(Opt("width", CHAT_WIDTH))
    panel:SetHeight(Opt("height", CHAT_HEIGHT))
    SetBackdropShown(panel, Opt("showBackground", true))
    self:PositionChat()
    self:PositionEditBox()

    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local cf = getglobal("ChatFrame" .. i)
        if cf then
            if type(cf.SetFading) == "function" then
                cf:SetFading(Opt("fade", true) and 1 or nil)
            end
            if type(cf.SetTimeVisible) == "function" then
                cf:SetTimeVisible(Opt("fadeTime", 120))
            end
        end
    end

    self:ApplyTabs()
    self:UpdateTabs()
end

-------------------------------------------------------------------------------
--  Chat Spam Filter (Suppresses repetitive Azeroth Survivors level spam)
-------------------------------------------------------------------------------
local lastLevelUp = 0

local function FilterChatMessage(ev, frame, msg)
    if not (B.db and B.db.filterChatSpam ~= false) then
        return false
    end

    if ev == "PLAYER_LEVEL_UP" then
        lastLevelUp = GetTime()
        return true
    end

    if ev == "CHAT_MSG_SYSTEM" and msg then
        -- Suppress stat increases directly following level up "+3% damage..."
        if (GetTime() - lastLevelUp < 1.5) and string.find(msg, "%+%d") then
            return true
        end
    end

    if ev == "CHAT_MSG_RAID_BOSS_EMOTE" and B.db and B.db.hideBanners then
        return true
    end

    return false
end

if ChatFrame_OnEvent and not mod.hookedChatEvent then
    mod.hookedChatEvent = true
    local orig_ChatFrame_OnEvent = ChatFrame_OnEvent
    ChatFrame_OnEvent = function(ev)
        if FilterChatMessage(ev, this, arg1) then
            return
        end
        if orig_ChatFrame_OnEvent then
            orig_ChatFrame_OnEvent(ev)
        end
    end
end

function mod:Update(state)
    self:UpdateTabs()
end

B:RegisterModule("chat", mod)
