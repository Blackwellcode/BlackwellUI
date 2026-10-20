-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Chat.lua
--  Clean 1px chat frame, mousewheel scrolling, styled EditBox, hides scroll buttons.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local mod = {}
mod.label = "Chat"
mod.alwaysActive = true

local CHAT_WIDTH = 380
local CHAT_HEIGHT = 140

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

    ChatFrameEditBox:ClearAllPoints()
    ChatFrameEditBox:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 4)
    ChatFrameEditBox:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 4)
    ChatFrameEditBox:SetHeight(22)
    ChatFrameEditBox:SetFont(B:GetFontPath(), 10)

    if not ChatFrameEditBox.buiBackdrop then
        B:Backdrop(ChatFrameEditBox, 0.85)
        ChatFrameEditBox.buiBackdrop = true
        ChatFrameEditBox.euiBackdrop = true
    end
end

function mod:SkinTabs()
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

function mod:Create()
    local root = CreateFrame("Frame", "BUI_ChatModule", UIParent)
    EUI_ChatModule = root -- Compatibility alias
    root:SetAllPoints(UIParent)
    self.frame = root

    self:HideBlizzardButtons()

    ---------------------------------------------------------------------------
    --  Chat Panel (380 x 140)
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "BUI_ChatPanel", root)
    EUI_ChatPanel = panel -- Compatibility alias
    panel:SetWidth(CHAT_WIDTH)
    panel:SetHeight(CHAT_HEIGHT)
    B:Backdrop(panel, 0.65)
    self.panel = panel

    if ChatFrame1 then
        self:PositionChat()

        -- Mousewheel scroll
        ChatFrame1:EnableMouseWheel(true)
        ChatFrame1:SetScript("OnMouseWheel", function()
            if arg1 > 0 then
                if IsShiftKeyDown() then
                    this:ScrollToTop()
                else
                    this:ScrollUp()
                end
            else
                if IsShiftKeyDown() then
                    this:ScrollToBottom()
                else
                    this:ScrollDown()
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

    B:RegisterMover(panel, "chat", "Chat Frame", "BOTTOMLEFT", "BOTTOMLEFT", 12, 24)
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
end

B:RegisterModule("chat", mod)
