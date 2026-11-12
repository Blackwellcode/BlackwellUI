-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Options.lua
--  Copyright (c) 2026 Blackwell Code. All rights reserved. See LICENSE.
--  Control center (/bw): sidebar with General, Appearance and Tooltips, then
--  one page per module, generated from the module's own settings
--  (mod.options, see Core.lua RegisterModule). Pages scroll with the mouse
--  wheel; dependent settings are indented and greyed while switched off.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local L = B.L
local optionsFrame = nil

local FRAME_W, FRAME_H = 720, 560
local NAV_W = 176
local HEADER_H = 30
local FOOTER_H = 44
local CONTENT_X = NAV_W + 22
local CONTENT_W = FRAME_W - CONTENT_X - 30
local NAV_ROW = 22

local TEXT = { 0.92, 0.92, 0.92 }
local MUTED = { 0.55, 0.55, 0.55 }
local DIM = { 0.38, 0.38, 0.38 }

-- step = 1 forward, -1 backward
local function CycleValue(list, current, step)
    local n = table.getn(list)
    for i = 1, n do
        if list[i] == current then
            local idx = i + (step or 1)
            if idx > n then idx = 1 end
            if idx < 1 then idx = n end
            return list[idx]
        end
    end
    return list[1]
end

local function SetColor(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-------------------------------------------------------------------------------
--  Widgets (pills and round check boxes in the round style)
-------------------------------------------------------------------------------
local function CreateButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:EnableMouse(true)

    if B:IsRound() then
        -- Explicit width: anchored sizes are only known a frame later.
        local pill = B:RoundBar(btn, h)
        pill:SetPoint("LEFT", btn, "LEFT", 0, 0)
        pill:SetWidth(w)
        pill:SetTrackColor(1, 1, 1, 0.08)
        pill:SetFill(0)
        btn.pill = pill
    else
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        B:Solid(bg, 0.10, 0.10, 0.10, 0.95)
        bg:SetAllPoints(btn)
        btn.bg = bg
        B:Border(btn, 0.22, 0.22, 0.22, 1)
    end

    local fs = B:Font(btn, 10, "CENTER")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    SetColor(fs, TEXT)
    fs:SetText(L[text])
    btn.label = fs

    btn:SetScript("OnEnter", function()
        local ar, ag, ab = B:GetAccent()
        if this.pill then
            this.pill:SetTrackColor(ar, ag, ab, 0.30)
            this.pill:SetFill(0)
        else
            B:SetBorderColor(this, ar, ag, ab, 0.9)
        end
    end)
    btn:SetScript("OnLeave", function()
        if this.pill then
            this.pill:SetTrackColor(1, 1, 1, 0.08)
            this.pill:SetFill(0)
        else
            B:SetBorderColor(this, 0.22, 0.22, 0.22, 1)
        end
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- A page is a scroll frame; controls are laid out top-down on its content
-- from a cursor (content.y). NewPage returns the content frame.
local function NewPage(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_X, -(HEADER_H + 14))
    scroll:SetWidth(CONTENT_W)
    scroll:SetHeight(FRAME_H - HEADER_H - FOOTER_H - 24)

    local page = CreateFrame("Frame", nil, scroll)
    page:SetWidth(CONTENT_W)
    page:SetHeight(10)
    scroll:SetScrollChild(page)
    page.scroll = scroll
    page.y = 0
    page.controls = {}

    -- Thin scroll indicator on the right edge
    local track = scroll:CreateTexture(nil, "ARTWORK")
    track:SetTexture(B.WHITE)
    track:SetVertexColor(1, 1, 1)
    track:SetAlpha(0.06)
    track:SetWidth(3)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 14, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 14, 0)
    local thumb = scroll:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(B.WHITE)
    thumb:SetWidth(3)
    B:Accent(thumb, "tex", 0.7)
    scroll.track = track
    scroll.thumb = thumb

    function scroll:UpdateThumb()
        local viewH = self:GetHeight()
        local fullH = page:GetHeight()
        if fullH <= viewH + 1 then
            self.track:Hide()
            self.thumb:Hide()
            return
        end
        self.track:Show()
        self.thumb:Show()
        local thumbH = math.floor(viewH * viewH / fullH)
        if thumbH < 20 then thumbH = 20 end
        local maxOff = fullH - viewH
        local off = self:GetVerticalScroll() or 0
        local y = math.floor((viewH - thumbH) * off / maxOff)
        self.thumb:SetHeight(thumbH)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 14, -y)
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function()
        local maxOff = page:GetHeight() - this:GetHeight()
        if maxOff < 0 then maxOff = 0 end
        local off = Clamp((this:GetVerticalScroll() or 0) - arg1 * 36, 0, maxOff)
        this:SetVerticalScroll(off)
        this:UpdateThumb()
    end)

    -- Fixes the scroll height once every control is placed.
    function page:Finish()
        self:SetHeight(-self.y + 12)
        if self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end
        self.scroll:SetVerticalScroll(0)
        self.scroll:UpdateThumb()
    end

    scroll:Hide()
    return page
end

local function AddSection(page, title)
    if page.y < 0 then page.y = page.y - 10 end
    local fs = B:Font(page, 9, "LEFT")
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    SetColor(fs, MUTED)
    fs:SetText(string.upper(L[title]))
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 14)
    rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page.y - 14)
    B:Solid(rule, 1, 1, 1, 0.08)
    page.y = page.y - 22
end

local function AddNote(page, text)
    local fs = B:Font(page, 9, "LEFT")
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    fs:SetWidth(CONTENT_W)
    fs:SetHeight(26)
    fs:SetJustifyV("TOP")
    SetColor(fs, MUTED)
    fs:SetText(L[text])
    page.y = page.y - 30
end

-- opts: indent (bool), depends (function -> bool: parent setting is on)
local function AddToggle(page, label, hint, getFn, setFn, opts)
    opts = opts or {}
    local x = (opts.indent and 20) or 0
    local h = (hint and 32) or 22
    local row = CreateFrame("Button", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
    row:SetWidth(CONTENT_W - x)
    row:SetHeight(h - 4)
    row:EnableMouse(true)

    local box = CreateFrame("Frame", nil, row)
    box:SetWidth(12)
    box:SetHeight(12)
    box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints(box)
    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    if B:IsRound() then
        -- Round check box: a dark disc with an accent dot.
        boxBg:SetTexture(B.ROUND)
        boxBg:SetVertexColor(1, 1, 1)
        boxBg:SetAlpha(0.12)
        check:SetTexture(B.ROUND)
    else
        B:Solid(boxBg, 0.06, 0.06, 0.06, 1)
        B:Border(box, 0.30, 0.30, 0.30, 1)
        check:SetTexture(B.WHITE)
        check:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
        check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    end
    B:Accent(check, "tex", 1)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 1)
    labelFs:SetText(L[label])

    local hintFs
    if hint then
        hintFs = B:Font(row, 9, "LEFT")
        hintFs:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -3)
        hintFs:SetWidth(CONTENT_W - x - 24)
        hintFs:SetText(L[hint])
    end

    function row:Refresh()
        local enabled = (not opts.depends) or opts.depends()
        local on = getFn() and true or false
        if on then check:Show() else check:Hide() end
        if not enabled then
            SetColor(labelFs, DIM)
            if hintFs then SetColor(hintFs, DIM) end
            check:SetAlpha(0.35)
        else
            SetColor(labelFs, (on and TEXT) or { 0.72, 0.72, 0.72 })
            if hintFs then SetColor(hintFs, MUTED) end
            check:SetAlpha(1)
        end
        self.enabled = enabled
    end

    row:SetScript("OnClick", function()
        if not this.enabled then return end
        setFn(not getFn())
        if page.RefreshAll then page:RefreshAll() end
    end)

    table.insert(page.controls, row)
    page.y = page.y - h
    return row
end

-- Label on the left, "<  value  >" (cycler) or "-  value  +" (stepper) on
-- the right. opts: indent, depends, extra = { text/getText, onClick }.
local function AddStepRow(page, label, getText, onStep, opts, minus, plus)
    opts = opts or {}
    local x = (opts.indent and 20) or 0
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
    row:SetWidth(CONTENT_W - x)
    row:SetHeight(22)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    labelFs:SetText(L[label])

    local anchor, anchorPoint, xoff = row, "RIGHT", 0
    if opts.extra then
        local eb = CreateButton(row, 58, 20, opts.extra.text or "", function()
            if row.enabled == false then return end
            opts.extra.onClick()
            page:RefreshAll()
        end)
        eb:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.extraBtn = eb
        anchor, anchorPoint, xoff = eb, "LEFT", -8
    end
    local nextBtn = CreateButton(row, 22, 20, plus, function()
        if row.enabled == false then return end
        onStep(1)
        page:RefreshAll()
    end)
    nextBtn:SetPoint("RIGHT", anchor, anchorPoint, xoff, 0)
    local valueFs = B:Font(row, 10, "CENTER")
    valueFs:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    valueFs:SetWidth(opts.valueWidth or 130)
    local prevBtn = CreateButton(row, 22, 20, minus, function()
        if row.enabled == false then return end
        onStep(-1)
        page:RefreshAll()
    end)
    prevBtn:SetPoint("RIGHT", valueFs, "LEFT", -4, 0)

    function row:Refresh()
        local enabled = (not opts.depends) or opts.depends()
        self.enabled = enabled
        valueFs:SetText(getText())
        SetColor(labelFs, (enabled and TEXT) or DIM)
        SetColor(valueFs, (enabled and TEXT) or DIM)
        if opts.extra and opts.extra.getText then
            self.extraBtn.label:SetText(opts.extra.getText())
        end
    end
    table.insert(page.controls, row)
    page.y = page.y - 28
    return row
end

local function AddCycler(page, label, getText, onStep, opts)
    return AddStepRow(page, label, getText, onStep, opts, "<", ">")
end

local function AddStepper(page, label, getText, onStep, opts)
    opts = opts or {}
    opts.valueWidth = opts.valueWidth or 70
    return AddStepRow(page, label, getText, onStep, opts, "-", "+")
end

local function AddActionButton(page, text, w, onClick)
    local btn = CreateButton(page, w or 180, 22, text, onClick)
    btn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    page.y = page.y - 30
    return btn
end

-- Colour row: label, swatch, and a reset button. get() -> r, g, b.
local function AddColorRow(page, label, get, set, reset, opts)
    opts = opts or {}
    local x = (opts.indent and 20) or 0
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
    row:SetWidth(CONTENT_W - x)
    row:SetHeight(22)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    labelFs:SetText(L[label])

    local resetBtn = CreateButton(row, 58, 20, "Reset", function()
        if row.enabled == false then return end
        reset()
        page:RefreshAll()
    end)
    resetBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local swatch = CreateFrame("Button", nil, row)
    swatch:SetWidth(36)
    swatch:SetHeight(16)
    swatch:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
    swatch:EnableMouse(true)
    local sw = swatch:CreateTexture(nil, "ARTWORK")
    sw:SetAllPoints(swatch)
    if B:IsRound() then
        local pill = B:RoundBar(swatch, 16)
        pill:SetPoint("LEFT", swatch, "LEFT", 0, 0)
        pill:SetWidth(36)
        pill:SetFill(0)
        swatch.pill = pill
        sw:Hide()
    else
        sw:SetTexture(B.WHITE)
        B:Border(swatch, 0.30, 0.30, 0.30, 1)
    end
    swatch.tex = sw

    swatch:SetScript("OnClick", function()
        if row.enabled == false or not ColorPickerFrame then return end
        local r, g, b = get()
        local pr, pg, pb = r, g, b
        ColorPickerFrame.hasOpacity = nil
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.func = nil
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(r, g, b)
        end
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            set(nr, ng, nb)
            page:RefreshAll()
        end
        ColorPickerFrame.cancelFunc = function()
            set(pr, pg, pb)
            page:RefreshAll()
        end
        ColorPickerFrame:Show()
    end)

    function row:Refresh()
        local enabled = (not opts.depends) or opts.depends()
        self.enabled = enabled
        local r, g, b = get()
        if swatch.pill then
            swatch.pill:SetTrackColor(r, g, b, (enabled and 1) or 0.35)
            swatch.pill:SetFill(0)
        else
            swatch.tex:SetVertexColor(r, g, b)
            swatch.tex:SetAlpha((enabled and 1) or 0.35)
        end
        SetColor(labelFs, (enabled and TEXT) or DIM)
    end
    table.insert(page.controls, row)
    page.y = page.y - 28
    return row
end

-------------------------------------------------------------------------------
--  Setting helpers
-------------------------------------------------------------------------------
local function ModuleToggle(key)
    return function() return B:IsEnabled(key) end,
        function(val)
            B.db.modules[key] = val
            B:OnModulesChanged()
        end
end

local function ModuleOn(key)
    return function() return B:IsEnabled(key) end
end

local function DbToggle(key, default, after)
    return function()
            local v = B.db[key]
            if v == nil then return default end
            return v
        end,
        function(val)
            B.db[key] = val
            if after then after(val) end
        end
end

-- Numbers as the option's format asks: "pct" = 0.85 -> 85%.
local function FormatValue(v, format)
    if format == "pct" then
        return string.format("%d%%", math.floor(v * 100 + 0.5))
    end
    if format then
        if string.find(format, "%%d") then
            return string.format(format, math.floor(v + 0.5))
        end
        return string.format(format, v)
    end
    return tostring(v)
end

-- Popup texts are filled in when shown, so they follow the active language.
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["BLACKWELLUI_RESET_LAYOUT"] = {
    text = "",
    button1 = "",
    button2 = "",
    OnAccept = function() B:ResetPositions() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}
StaticPopupDialogs["BLACKWELLUI_RESET_SETTINGS"] = {
    text = "",
    button1 = "",
    button2 = "",
    OnAccept = function()
        B.db.mod = {}
        B:PromptSettingReload()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}
StaticPopupDialogs["BLACKWELLUI_LANGUAGE_RELOAD"] = {
    text = "",
    button1 = "",
    button2 = "",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function ShowPopup(key, text, accept, cancel)
    local dialog = StaticPopupDialogs[key]
    dialog.text = text
    dialog.button1 = accept
    dialog.button2 = cancel
    if type(StaticPopup_Show) == "function" then
        StaticPopup_Show(key)
        return true
    end
    return false
end

-- Both reset paths (options button and /bw reset) ask first. Without the
-- popup system (never seen in benilla) the action runs directly, as before.
function B:ConfirmResetLayout()
    if not ShowPopup("BLACKWELLUI_RESET_LAYOUT", L["BlackwellUI: move every frame back to its default position?"], L["Reset"], L["Cancel"]) then
        self:ResetPositions()
    end
end

function B:ConfirmResetModuleSettings()
    if not ShowPopup("BLACKWELLUI_RESET_SETTINGS", L["Reset all module settings? Every module option returns to its default. This can't be undone."], L["Reset settings"], L["Keep settings"]) then
        self.db.mod = {}
        self:PromptSettingReload()
    end
end

-- The language is read when frames are built; switching it needs a reload.
function B:PromptLanguageReload()
    local target = ((self.db.language == "auto") and self:DetectGameLanguage()) or self.db.language
    local text = string.format(L["BlackwellUI language: %s. Reload the UI now to apply it?"], self:GetLanguageName(target))
    if not ShowPopup("BLACKWELLUI_LANGUAGE_RELOAD", text, L["Reload"], L["Later"]) then
        self:Print(L["Type /reload to apply the new language."])
    end
end

-- Settings that frames read only while they are built (style, radius, ...).
function B:PromptSettingReload()
    if not ShowPopup("BLACKWELLUI_LANGUAGE_RELOAD", L["This setting applies after a reload. Reload the UI now?"], L["Reload"], L["Later"]) then
        self:Print(L["Type /reload to apply the change."])
    end
end

-------------------------------------------------------------------------------
--  Fixed pages
-------------------------------------------------------------------------------
local function BuildGeneral(page)
    AddSection(page, "Stock game interface")
    local get, set = DbToggle("replaceHud", true, function() B:SyncHud() end)
    AddToggle(page, "Replace the stock run HUD",
        "Hides the game's own clock, meter and boss bars where BlackwellUI shows them.", get, set)
    get, set = DbToggle("hideBanners", false, function() B:SyncHud() end)
    AddToggle(page, "Hide boss banners",
        "Removes the large boss announcements and boss emotes in chat.", get, set)
    get, set = DbToggle("hideLoot", false, function() B:SyncHud() end)
    AddToggle(page, "Hide loot pop-ups",
        "Removes the game's loot prompts. The BlackwellUI loot log stays.", get, set)

    get, set = DbToggle("welcomeMessage", true)
    AddToggle(page, "Welcome message in chat", nil, get, set)

    AddSection(page, "Layout")
    get, set = DbToggle("demo", false, function() B:Tick() end)
    AddToggle(page, "Preview mode",
        "Fills every panel with sample data, handy while arranging the layout.", get, set)
    get, set = DbToggle("showGrid", true, function()
        if B.SetAlignmentGridShown then B:SetAlignmentGridShown(B.unlocked) end
    end)
    AddToggle(page, "Alignment grid in edit mode",
        "32 px grid with centre lines while frames are unlocked.", get, set)

    AddSection(page, "Language")
    AddCycler(page, "Interface language",
        function()
            if B.db.language == "auto" then
                return string.format(L["Auto (%s)"], B:GetLanguageName(B:DetectGameLanguage()))
            end
            return B:GetLanguageName(B.db.language)
        end,
        function(step)
            local list = { "auto" }
            for i = 1, table.getn(B.LANGUAGES) do
                table.insert(list, B.LANGUAGES[i].code)
            end
            B.db.language = CycleValue(list, B.db.language, step)
            B:PromptLanguageReload()
        end)

    AddSection(page, "Troubleshooting")
    AddActionButton(page, "Open script error log", 200, function()
        if type(BenillaScriptLog_Toggle) == "function" then
            BenillaScriptLog_Toggle()
        else
            B:Print("No script log available in this client.")
        end
    end)
    AddActionButton(page, "Reset all module settings", 200, function()
        B:ConfirmResetModuleSettings()
    end)
    AddNote(page, "Before uninstalling, switch off Combat text (its module page) and Replace the stock run HUD here, so the game gets its own settings back.")
end

local STYLE_ORDER = { "round", "sharp" }
local STYLE_LABEL = { round = "Round (modern)", sharp = "Sharp (classic)" }
local OUTLINE_ORDER = { "OUTLINE", "THICKOUTLINE", "NONE" }
local OUTLINE_LABEL = { OUTLINE = "Outline", THICKOUTLINE = "Thick outline", NONE = "Shadow only" }

local function BuildAppearance(page, refreshOwner)
    AddSection(page, "Style")
    AddCycler(page, "Interface style",
        function() return L[STYLE_LABEL[B.db.uiStyle] or STYLE_LABEL.round] end,
        function(step)
            B.db.uiStyle = CycleValue(STYLE_ORDER, B.db.uiStyle, step)
            B:PromptSettingReload()
        end)
    AddStepper(page, "Corner radius",
        function() return FormatValue(B.db.cornerRadius or 10, "%d px") end,
        function(step)
            B.db.cornerRadius = Clamp((B.db.cornerRadius or 10) + step * 2, 2, 16)
            B:PromptSettingReload()
        end,
        { depends = function() return B.db.uiStyle ~= "sharp" end })
    AddColorRow(page, "Panel colour",
        function() return B:GetPanelColor() end,
        function(r, g, b)
            B.db.panelColor = { r = r, g = g, b = b }
            B:RefreshTheme()
        end,
        function()
            B.db.panelColor = false
            B:RefreshTheme()
        end)
    AddStepper(page, "Background opacity",
        function() return FormatValue(B.db.backdropAlpha or 0.85, "pct") end,
        function(step)
            local v = Clamp((B.db.backdropAlpha or 0.85) + step * 0.05, 0.30, 1.0)
            B.db.backdropAlpha = math.floor(v * 100 + 0.5) / 100
            B:RefreshTheme()
        end)

    AddSection(page, "Colour")
    AddCycler(page, "Theme",
        function() return tostring(B.db.theme) end,
        function(step)
            B.db.theme = CycleValue(B.THEME_ORDER, B.db.theme, step)
            B:RefreshTheme()
            refreshOwner()
        end)
    AddColorRow(page, "Custom accent colour",
        function()
            local c = B.db.customAccent or { r = 0, g = 0.9, b = 1 }
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            B.db.customAccent = { r = r, g = g, b = b }
            B.db.theme = "Custom"
            B:RefreshTheme()
            refreshOwner()
        end,
        function()
            B.db.customAccent = { r = 0, g = 229 / 255, b = 1 }
            B:RefreshTheme()
            refreshOwner()
        end)

    AddSection(page, "Text")
    AddCycler(page, "Font",
        function() return tostring(B.db.font) end,
        function(step)
            B.db.font = CycleValue(B.FONT_ORDER, B.db.font, step)
            B:RefreshTheme()
        end)
    AddStepper(page, "Text size",
        function() return string.format("%+d", math.floor(B.db.fontScaleMod or 0)) end,
        function(step)
            B.db.fontScaleMod = Clamp((B.db.fontScaleMod or 0) + step, -3, 5)
            B:RefreshTheme()
        end)
    AddCycler(page, "Text outline",
        function() return L[OUTLINE_LABEL[B.db.fontOutline] or OUTLINE_LABEL.OUTLINE] end,
        function(step)
            B.db.fontOutline = CycleValue(OUTLINE_ORDER, B.db.fontOutline, step)
            B:RefreshTheme()
        end)

    AddSection(page, "Bars")
    AddCycler(page, "Bar texture",
        function() return tostring(B.db.barTexture) end,
        function(step)
            B.db.barTexture = CycleValue(B.BAR_TEXTURE_ORDER, B.db.barTexture, step)
            B:RefreshTheme()
        end)

    AddSection(page, "Size")
    AddStepper(page, "UI scale",
        function() return string.format("%.2f", B.db.scale or 1.0) end,
        function(step)
            B.db.autoScale = false
            local v = Clamp((B.db.scale or 1.0) + step * 0.05, 0.5, 2.0)
            B.db.scale = math.floor(v * 100 + 0.5) / 100
            B:ApplyScale()
        end,
        {
            extra = {
                getText = function() return (B.db.autoScale and L["Auto"]) or L["Fixed"] end,
                onClick = function()
                    B.db.autoScale = not B.db.autoScale
                    if B.db.autoScale then
                        B.db.scale = B:GetOptimalScale()
                        B:ApplyScale()
                    end
                end,
            },
        })
end

local ANCHOR_ORDER = { "hud", "cursor", "default" }
local ANCHOR_LABEL = { hud = "Next to the HUD", cursor = "At the mouse cursor", default = "Game default" }

local function BuildTooltips(page)
    AddSection(page, "Tooltips")
    AddCycler(page, "Position",
        function() return L[ANCHOR_LABEL[B.db.tooltipAnchor] or ANCHOR_LABEL.hud] end,
        function(step)
            B.db.tooltipAnchor = CycleValue(ANCHOR_ORDER, B.db.tooltipAnchor, step)
        end)
    AddStepper(page, "Tooltip scale",
        function() return string.format("%.2f", B.db.tooltipScale or 0.82) end,
        function(step)
            local v = Clamp((B.db.tooltipScale or 0.82) + step * 0.05, 0.5, 1.5)
            B.db.tooltipScale = math.floor(v * 100 + 0.5) / 100
            if GameTooltip and GameTooltip.SetScale then GameTooltip:SetScale(B.db.tooltipScale) end
            if ItemRefTooltip and ItemRefTooltip.SetScale then ItemRefTooltip:SetScale(B.db.tooltipScale) end
        end)
    local get, set = DbToggle("tooltipReactionColor", true)
    AddToggle(page, "Class and reaction colour",
        "Players in their class colour, NPCs red, yellow or green by reaction.", get, set)
    get, set = DbToggle("tooltipHideInCombat", false)
    AddToggle(page, "Hide unit tooltips in combat", nil, get, set)
end

-------------------------------------------------------------------------------
--  Module pages (generated from mod.options)
-------------------------------------------------------------------------------
local VIS_ORDER = { "always", "combat", "nocombat", "mouseover" }
local VIS_LABEL = { always = "Always", combat = "Only in combat", nocombat = "Only out of combat", mouseover = "Faded until mouse-over" }

local function OptionGet(mod, entry)
    if entry.db then
        local v = B.db[entry.db]
        if v == nil then return entry.default end
        return v
    end
    return B:ModOpt(mod.key, entry.key, entry.default)
end

local function OptionSet(mod, entry, value)
    if entry.db then
        B.db[entry.db] = value
    else
        B:SetModOpt(mod.key, entry.key, value)
    end
    if entry.reload then
        B:PromptSettingReload()
    else
        B:OnModuleOptionChanged(mod)
    end
end

local function AddModuleOption(page, mod, entry, moduleOn)
    local depends = moduleOn
    if entry.depends then
        local depKey = entry.depends
        depends = function()
            return moduleOn() and B:ModOpt(mod.key, depKey, true) and true or false
        end
    end
    local opts = { indent = entry.depends ~= nil, depends = depends }

    if entry.type == "section" then
        AddSection(page, entry.label)
    elseif entry.type == "note" then
        AddNote(page, entry.label)
    elseif entry.type == "toggle" then
        AddToggle(page, entry.label, entry.hint,
            function() return OptionGet(mod, entry) end,
            function(v) OptionSet(mod, entry, v) end, opts)
    elseif entry.type == "range" then
        AddStepper(page, entry.label,
            function() return FormatValue(OptionGet(mod, entry), entry.format) end,
            function(step)
                local v = OptionGet(mod, entry) + step * (entry.step or 1)
                v = Clamp(v, entry.min or v, entry.max or v)
                v = math.floor(v * 1000 + 0.5) / 1000
                OptionSet(mod, entry, v)
            end, opts)
    elseif entry.type == "choice" then
        local list, labels = {}, {}
        for i = 1, table.getn(entry.values or {}) do
            table.insert(list, entry.values[i].value)
            labels[entry.values[i].value] = entry.values[i].label
        end
        AddCycler(page, entry.label,
            function()
                local v = OptionGet(mod, entry)
                return L[labels[v] or tostring(v)]
            end,
            function(step) OptionSet(mod, entry, CycleValue(list, OptionGet(mod, entry), step)) end, opts)
    elseif entry.type == "color" then
        AddColorRow(page, entry.label,
            function()
                local c = OptionGet(mod, entry) or { r = 1, g = 1, b = 1 }
                return c.r, c.g, c.b
            end,
            function(r, g, b) OptionSet(mod, entry, { r = r, g = g, b = b }) end,
            function() OptionSet(mod, entry, entry.default) end, opts)
    end
end

local function BuildModulePage(page, mod)
    local key = mod.key
    local moduleOn = ModuleOn(key)

    AddSection(page, mod.label)
    local get, set = ModuleToggle(key)
    AddToggle(page, mod.toggleLabel or "Enabled", mod.hint, get, set)

    if not mod.noLook then
        AddSection(page, "Size and visibility")
        local function LookSet(optKey, value)
            B:SetModOpt(key, optKey, value)
            B:OnModuleOptionChanged(mod)
        end
        AddStepper(page, "Scale",
            function() return string.format("%.2f", B:ModOpt(key, "scale", 1)) end,
            function(step)
                local v = Clamp(B:ModOpt(key, "scale", 1) + step * 0.05, 0.5, 2.0)
                LookSet("scale", math.floor(v * 100 + 0.5) / 100)
            end, { depends = moduleOn })
        AddStepper(page, "Opacity",
            function() return FormatValue(B:ModOpt(key, "alpha", 1), "pct") end,
            function(step)
                local v = Clamp(B:ModOpt(key, "alpha", 1) + step * 0.05, 0.1, 1.0)
                LookSet("alpha", math.floor(v * 100 + 0.5) / 100)
            end, { depends = moduleOn })
        AddCycler(page, "Visibility",
            function() return L[VIS_LABEL[B:ModOpt(key, "visibility", "always")] or VIS_LABEL.always] end,
            function(step)
                LookSet("visibility", CycleValue(VIS_ORDER, B:ModOpt(key, "visibility", "always"), step))
            end, { depends = moduleOn })
        AddStepper(page, "Faded opacity",
            function() return FormatValue(B:ModOpt(key, "fadeAlpha", 0.15), "pct") end,
            function(step)
                local v = Clamp(B:ModOpt(key, "fadeAlpha", 0.15) + step * 0.05, 0, 0.8)
                LookSet("fadeAlpha", math.floor(v * 100 + 0.5) / 100)
            end, {
                indent = true,
                depends = function() return moduleOn() and B:ModOpt(key, "visibility", "always") == "mouseover" end,
            })
    end

    if type(mod.options) == "table" then
        for i = 1, table.getn(mod.options) do
            AddModuleOption(page, mod, mod.options[i], moduleOn)
        end
    end

    page.y = page.y - 8
    AddActionButton(page, "Reset module settings", 200, function()
        B:ResetModOpts(key)
        B:OnModuleOptionChanged(mod)
        page:RefreshAll()
    end)
end

local FIXED_PAGES = {
    { key = "general",    label = "General",    build = BuildGeneral },
    { key = "appearance", label = "Appearance", build = BuildAppearance },
    { key = "tooltips",   label = "Tooltips",   build = BuildTooltips },
}

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local function BuildOptionsFrame()
    if optionsFrame then return optionsFrame end

    local f = CreateFrame("Frame", "BlackwellUIOptionsFrame", UIParent)
    BlackwallUIOptionsFrame = f -- Compatibility alias
    f:SetWidth(FRAME_W)
    f:SetHeight(FRAME_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    -- Own opaque background: a see-through settings window is hard to read
    -- over the HUD, so it does not follow the HUD opacity setting.
    if B:IsRound() then
        B:RoundPanel(f, 16, 0.97)
    else
        local frameBg = f:CreateTexture(nil, "BACKGROUND")
        B:Solid(frameBg, 0.045, 0.045, 0.05, 0.97)
        frameBg:SetAllPoints(f)
        B:Border(f, 0, 0, 0, 1)
    end
    table.insert(UISpecialFrames, "BlackwellUIOptionsFrame")

    -- Title bar
    local title = B:Font(f, 13, "LEFT")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -10)
    SetColor(title, TEXT)
    title:SetText("BlackwellUI")
    local ver = B:Font(f, 9, "LEFT")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
    SetColor(ver, MUTED)
    ver:SetText("v" .. B.version)
    local closeBtn = CreateButton(f, 22, 20, "x", function() f:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -6)
    local titleRule = f:CreateTexture(nil, "ARTWORK")
    titleRule:SetHeight(1)
    titleRule:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HEADER_H)
    titleRule:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HEADER_H)
    B:Solid(titleRule, 1, 1, 1, 0.08)

    -- Sidebar
    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(HEADER_H + 1))
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 1)
    nav:SetWidth(NAV_W)
    local navRule = nav:CreateTexture(nil, "ARTWORK")
    navRule:SetWidth(1)
    navRule:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, 0)
    navRule:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, 0)
    B:Solid(navRule, 1, 1, 1, 0.08)

    local pages, navButtons = {}, {}
    local current = nil

    local function RefreshNav()
        local ar, ag, ab = B:GetAccent()
        for i = 1, table.getn(navButtons) do
            local nb = navButtons[i]
            local active = (nb.key == current)
            if nb.pill then
                nb.pill:SetTrackColor(ar, ag, ab, (active and 0.22) or 0)
                nb.pill:SetFill(0)
            else
                if active then
                    nb.bar:SetVertexColor(ar, ag, ab)
                    nb.bar:Show()
                    B:Solid(nb.bg, 1, 1, 1, 0.05)
                else
                    nb.bar:Hide()
                    B:Solid(nb.bg, 1, 1, 1, 0)
                end
            end
            if active then
                SetColor(nb.label, TEXT)
            elseif nb.isModule and not B:IsEnabled(nb.key) then
                SetColor(nb.label, DIM)
            else
                SetColor(nb.label, MUTED)
            end
        end
    end

    local function ShowPage(key)
        current = key
        for k, p in pairs(pages) do
            if k == key then
                p:RefreshAll()
                p.scroll:Show()
                p.scroll:UpdateThumb()
            else
                p.scroll:Hide()
            end
        end
        RefreshNav()
    end
    f.ShowPage = ShowPage

    local navY = -8
    local function AddNavLabel(text)
        local fs = B:Font(nav, 9, "LEFT")
        fs:SetPoint("TOPLEFT", nav, "TOPLEFT", 18, navY - 6)
        SetColor(fs, DIM)
        fs:SetText(string.upper(L[text]))
        navY = navY - 22
    end

    local function AddNavPage(key, label, build, isModule)
        local nb = CreateFrame("Button", nil, nav)
        nb:SetWidth(NAV_W - 16)
        nb:SetHeight(NAV_ROW - 2)
        nb:SetPoint("TOPLEFT", nav, "TOPLEFT", 8, navY)
        nb:EnableMouse(true)
        nb.key = key
        nb.isModule = isModule
        if B:IsRound() then
            local pill = B:RoundBar(nb, NAV_ROW - 2)
            pill:SetPoint("LEFT", nb, "LEFT", 0, 0)
            pill:SetWidth(NAV_W - 16)
            pill:SetTrackColor(1, 1, 1, 0)
            pill:SetFill(0)
            nb.pill = pill
        else
            local bg = nb:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(nb)
            nb.bg = bg
            local bar = nb:CreateTexture(nil, "ARTWORK")
            bar:SetTexture(B.WHITE)
            bar:SetWidth(2)
            bar:SetPoint("TOPLEFT", nb, "TOPLEFT", 0, 0)
            bar:SetPoint("BOTTOMLEFT", nb, "BOTTOMLEFT", 0, 0)
            nb.bar = bar
        end
        local fs = B:Font(nb, 10, "LEFT")
        fs:SetPoint("LEFT", nb, "LEFT", 10, 0)
        fs:SetPoint("RIGHT", nb, "RIGHT", -6, 0)
        fs:SetText(L[label])
        nb.label = fs
        nb:SetScript("OnClick", function() ShowPage(this.key) end)
        table.insert(navButtons, nb)
        navY = navY - NAV_ROW

        local page = NewPage(f)
        function page:RefreshAll()
            for j = 1, table.getn(self.controls) do
                self.controls[j]:Refresh()
            end
            RefreshNav()
        end
        build(page)
        page:Finish()
        pages[key] = page
    end

    for i = 1, table.getn(FIXED_PAGES) do
        local def = FIXED_PAGES[i]
        AddNavPage(def.key, def.label, function(page) def.build(page, RefreshNav) end, false)
    end
    navY = navY - 4
    AddNavLabel("Modules")
    for i = 1, table.getn(B.moduleOrder) do
        local mod = B.modules[B.moduleOrder[i]]
        if mod then
            AddNavPage(mod.key, mod.label or mod.key, function(page) BuildModulePage(page, mod) end, true)
        end
    end

    -- Footer
    local footRule = f:CreateTexture(nil, "ARTWORK")
    footRule:SetHeight(1)
    footRule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", NAV_W, FOOTER_H)
    footRule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOTER_H)
    B:Solid(footRule, 1, 1, 1, 0.08)

    local reloadBtn = CreateButton(f, 96, 24, "Reload UI", function() ReloadUI() end)
    reloadBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 10)
    local resetBtn = CreateButton(f, 110, 24, "Reset layout", function()
        B:ConfirmResetLayout()
    end)
    resetBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    local editBtn = CreateButton(f, 120, 24, "Edit layout", function()
        B:SetUnlocked(not B.unlocked)
        this.label:SetText(((B.unlocked and L["Done editing"]) or L["Edit layout"]))
    end)
    editBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
    f.editBtn = editBtn

    f:SetScript("OnShow", function()
        f.editBtn.label:SetText(((B.unlocked and L["Done editing"]) or L["Edit layout"]))
        ShowPage(current or "general")
    end)

    f:Hide()
    optionsFrame = f
    return f
end

-------------------------------------------------------------------------------
--  Self test (/bw selftest): every module option is set to each of its test
--  values (toggle on/off, range min/max, every choice, a colour), the module
--  re-applies and updates with preview data, and Lua errors or frames that
--  collapse to zero size are reported. All settings are restored afterwards.
-------------------------------------------------------------------------------
local function CopyTable(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = CopyTable(v) end
    return c
end

local function TestValues(entry)
    if entry.type == "toggle" then return { true, false } end
    if entry.type == "range" then return { entry.min, entry.max, entry.default } end
    if entry.type == "choice" then
        local list = {}
        for i = 1, table.getn(entry.values or {}) do table.insert(list, entry.values[i].value) end
        return list
    end
    if entry.type == "color" then return { { r = 1, g = 0, b = 0 }, entry.default } end
    return {}
end

function B:SelfTest()
    local savedMod = CopyTable(self.db.mod)
    local savedDb = {}
    local savedDemo = self.db.demo
    self.db.demo = true
    local okState, state = pcall(self.GetState, self)
    if not okState then
        self:Print("Self test: state failed: " .. tostring(state))
        self.db.demo = savedDemo
        return
    end
    local failures, tested, modsTested = {}, 0, 0

    local function Run(mod, what)
        tested = tested + 1
        local steps = {
            function() self:ApplyModuleLook(mod) end,
            function() if type(mod.ApplyOptions) == "function" then mod:ApplyOptions() end end,
            function() if type(mod.Update) == "function" and mod.frame then mod:Update(state) end end,
            function() self:ApplyModuleVisibility(mod) end,
        }
        for i = 1, table.getn(steps) do
            local ok, err = pcall(steps[i])
            if not ok then
                table.insert(failures, mod.key .. " / " .. what .. ": " .. tostring(err))
                return
            end
        end
        local frames = self:GetLookFrames(mod)
        for i = 1, table.getn(frames) do
            local fr = frames[i]
            if fr and fr:IsShown() and fr.GetWidth and (fr:GetWidth() <= 0 or fr:GetHeight() <= 0) then
                table.insert(failures, mod.key .. " / " .. what .. ": frame size 0")
                return
            end
        end
    end

    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod and mod.created then
            modsTested = modsTested + 1
            if not mod.noLook then
                local looks = {
                    { "scale", 0.5 }, { "scale", 2.0 }, { "alpha", 0.1 },
                    { "visibility", "combat" }, { "visibility", "nocombat" }, { "visibility", "mouseover" },
                }
                for j = 1, table.getn(looks) do
                    self:SetModOpt(mod.key, looks[j][1], looks[j][2])
                    Run(mod, looks[j][1] .. "=" .. tostring(looks[j][2]))
                end
                self:ResetModOpts(mod.key)
            end
            for j = 1, table.getn(mod.options or {}) do
                local entry = mod.options[j]
                if entry.key or entry.db then
                    if entry.db and savedDb[entry.db] == nil then
                        savedDb[entry.db] = { value = self.db[entry.db] }
                    end
                    local values = TestValues(entry)
                    for v = 1, table.getn(values) do
                        local value = values[v]
                        if entry.db then
                            self.db[entry.db] = value
                        else
                            self:SetModOpt(mod.key, entry.key, value)
                        end
                        local shown = value
                        if type(value) == "table" then shown = "colour" end
                        Run(mod, (entry.key or entry.db) .. "=" .. tostring(shown))
                    end
                end
            end
        end
    end

    -- Restore everything and re-apply the real settings.
    self.db.mod = savedMod
    for k, v in pairs(savedDb) do self.db[k] = v.value end
    self.db.demo = savedDemo
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod and mod.created then self:OnModuleOptionChanged(mod) end
    end

    self:Print(string.format("Self test: %d modules, %d settings checks, %d problems.", modsTested, tested, table.getn(failures)))
    for i = 1, table.getn(failures) do
        if i > 15 then
            self:Print(string.format("... and %d more.", table.getn(failures) - 15))
            break
        end
        self:Print(failures[i])
    end
    self.selfTestFailures = failures
end

-------------------------------------------------------------------------------
--  Layout check (/bw layoutcheck): screen rectangles of every visible HUD
--  element; prints each pair that overlaps by more than 1 px.
-------------------------------------------------------------------------------
function B:LayoutCheck()
    local rects = {}
    local screenW = (UIParent:GetWidth() or 0) * ((UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1)
    local function Add(name, f)
        if not f or not f.IsVisible or not f:IsVisible() then return end
        local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
        if not (l and r and t and b) then return end
        local s = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        l, r, t, b = l * s, r * s, t * s, b * s
        if r - l < 2 or t - b < 2 or (screenW > 0 and r - l > screenW * 0.9) then return end
        table.insert(rects, { name = name, l = l, r = r, t = t, b = b })
    end

    local uf = self.modules["unitframes"]
    if uf and uf.created then
        Add("hero", uf.hero)
        Add("target", uf.target)
        Add("targettarget", uf.tot)
        Add("pet", uf.pet)
        Add("elites", uf.enc)
        for i = 1, table.getn(uf.partyFrames or {}) do Add("party" .. i, uf.partyFrames[i]) end
        if uf.target and uf.target.debuffBars then
            for i = 1, table.getn(uf.target.debuffBars) do Add("debuff" .. i, uf.target.debuffBars[i]) end
        end
    end
    local build = self.modules["build"]
    if build and build.created and build.frame then
        local f = build.frame
        for i = 1, table.getn(f.tiles or {}) do Add("tile" .. i, f.tiles[i]) end
        for i = 1, table.getn(f.buffBars or {}) do Add("buff" .. i, f.buffBars[i]) end
        Add("levelup", f.lvlUpBtn)
    end
    local skip = { unitframes = true, build = true, combattext = true, nameplates = true, pins = true, actionbars = true, character = true }
    for i = 1, table.getn(self.moduleOrder) do
        local mod = self.modules[self.moduleOrder[i]]
        if mod and mod.created and not skip[mod.key] then
            local frames = self:GetLookFrames(mod)
            for j = 1, table.getn(frames) do Add(mod.key, frames[j]) end
            if mod.key == "databar" and mod.frame then Add("databar-xp", mod.frame.xpBar) end
        end
    end

    local hits = {}
    for i = 1, table.getn(rects) do
        for j = i + 1, table.getn(rects) do
            local a, c = rects[i], rects[j]
            local ox = math.min(a.r, c.r) - math.max(a.l, c.l)
            local oy = math.min(a.t, c.t) - math.max(a.b, c.b)
            if ox > 1 and oy > 1 then
                table.insert(hits, string.format("%s x %s (%.0f x %.0f px)", a.name, c.name, ox, oy))
            end
        end
    end
    self:Print(string.format("Layout check: %d elements, %d overlaps.", table.getn(rects), table.getn(hits)))
    for i = 1, table.getn(hits) do
        if i > 20 then
            self:Print(string.format("... and %d more.", table.getn(hits) - 20))
            break
        end
        self:Print(hits[i])
    end
    self.layoutHits = hits
end

function B:ToggleOptions()
    local f = BuildOptionsFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

-------------------------------------------------------------------------------
--  Slash Commands: /bui, /blackwell, /blackwellui (and legacy aliases)
-------------------------------------------------------------------------------
SLASH_BLACKWELLUI1 = "/bui"
SLASH_BLACKWELLUI2 = "/blackwell"
SLASH_BLACKWELLUI3 = "/blackwellui"
SLASH_BLACKWELLUI4 = "/blackwall"
SLASH_BLACKWELLUI5 = "/blackwallui"
SLASH_BLACKWELLUI6 = "/bw"

local function OnOff(value)
    return (value and L["ON"]) or L["OFF"]
end

local function ToggleModule(key, label)
    B.db.modules[key] = not B:IsEnabled(key)
    B:OnModulesChanged()
    B:Print(string.format(L["%s: %s"], L[label], OnOff(B:IsEnabled(key))))
end

-- /bw lang <code|auto>: interface language, applied after /reload.
local function SetLanguage(code)
    if code == "" then
        local active = B:GetLanguageName(B.LANG)
        local mode = ((B.db.language == "auto") and L["Auto"]) or B:GetLanguageName(B.db.language)
        B:Print(string.format(L["Language: %s (setting: %s)"], active, mode))
        local codes = {}
        for i = 1, table.getn(B.LANGUAGES) do
            table.insert(codes, B.LANGUAGES[i].code)
        end
        B:Print(L["Usage: /bw lang auto | "] .. table.concat(codes, " | "))
        return
    end
    if code ~= "auto" and not B:IsKnownLanguage(code) then
        B:Print(string.format(L["Unknown language: %s"], code))
        return
    end
    B.db.language = code
    B:PromptLanguageReload()
end

local function HandleSlashCmd(msg)
    local cmd = string.lower((string.gsub(msg or "", "^%s*(.-)%s*$", "%1")))
    if cmd == "unlock" or cmd == "move" then
        B:SetUnlocked(true)
        B:Print(L["UI unlocked. Drag frames to position them."])
    elseif cmd == "lock" then
        B:SetUnlocked(false)
        B:Print(L["UI locked."])
    elseif cmd == "reset" then
        B:ConfirmResetLayout()
    elseif cmd == "demo" then
        B.db.demo = not B.db.demo
        B:Tick()
        B:Print(string.format(L["%s: %s"], L["Preview mode"], OnOff(B.db.demo)))
    elseif cmd == "hud" then
        B.db.replaceHud = not B.db.replaceHud
        B:SyncHud()
        B:Print(string.format(L["%s: %s"], L["Replace the stock run HUD"], OnOff(B.db.replaceHud)))
    elseif cmd == "pins" or cmd == "radar" then
        ToggleModule("pins", "Radar pins")
    elseif cmd == "loot" then
        ToggleModule("loot", "Loot log")
    elseif cmd == "rares" or cmd == "rare" then
        ToggleModule("rares", "Rare spawn timers")
    elseif cmd == "equipment" or cmd == "items" or cmd == "gear" then
        ToggleModule("equipment", "Equipment")
    elseif cmd == "nameplates" or cmd == "plates" or cmd == "splates" then
        ToggleModule("nameplates", "Nameplates")
    elseif cmd == "combattext" or cmd == "sct" or cmd == "msbt" then
        ToggleModule("combattext", "Combat text")
        if B.SyncCombatText then B:SyncCombatText() end
    elseif cmd == "grid" or cmd == "raster" then
        B.db.showGrid = not (B.db.showGrid ~= false)
        if B.SetAlignmentGridShown then B:SetAlignmentGridShown(B.unlocked) end
        B:Print(string.format(L["%s: %s"], L["Alignment grid in edit mode"], OnOff(B.db.showGrid)))
    elseif cmd == "buffs" or cmd == "alerts" then
        B.db.showBuffBars = not (B.db.showBuffBars ~= false)
        B:Tick()
        B:Print(string.format(L["%s: %s"], L["Buff bars above the tiles"], OnOff(B.db.showBuffBars)))
    elseif cmd == "autoscale" or cmd == "auto" then
        B.db.autoScale = not B.db.autoScale
        if B.db.autoScale then
            B.db.scale = B:GetOptimalScale()
            B:ApplyScale()
        end
        B:Print(string.format(L["%s: %s"], L["Automatic UI scale"], OnOff(B.db.autoScale)))
    elseif string.find(cmd, "^scale%s*") then
        local _, _, val = string.find(cmd, "^scale%s*([%d%.]+)")
        local num = tonumber(val)
        if num and num >= 0.5 and num <= 2.0 then
            B.db.autoScale = false
            B.db.scale = math.floor(num * 100 + 0.5) / 100
            B:ApplyScale()
            B:Print(string.format(L["UI scale set to %.2f."], B.db.scale))
        else
            B:Print(L["Usage: /bw scale 0.80 (or /bw autoscale)"])
        end
    elseif cmd == "selftest" then
        B:SelfTest()
    elseif cmd == "layoutcheck" then
        B:LayoutCheck()
    elseif string.find(cmd, "^lang") then
        local _, _, code = string.find(cmd, "^lang%a*%s*(%S*)")
        SetLanguage(code or "")
    elseif cmd == "help" then
        B:Print(L["Commands: /bw (options), /bw unlock, /bw lock, /bw reset, /bw grid, /bw buffs, /bw autoscale, /bw scale <value>, /bw demo, /bw hud, /bw pins, /bw loot, /bw plates, /bw sct, /bw lang <code>"])
    else
        B:ToggleOptions()
    end
end

SlashCmdList["BLACKWELLUI"] = HandleSlashCmd
SlashCmdList["BLACKWALLUI"] = HandleSlashCmd

-- Convenience aliases /msbt and /splates belong to other addons
-- (MikScrollingBattleText, ShaguPlates). They are registered only after every
-- addon has loaded (PLAYER_LOGIN) and only if no other addon claims the same
-- command, so BlackwellUI never takes them over.
local function SlashTaken(command)
    command = string.lower(command)
    for key in pairs(SlashCmdList) do
        local i = 1
        while true do
            local text = getglobal("SLASH_" .. key .. i)
            if not text then break end
            if string.lower(text) == command then return true end
            i = i + 1
        end
    end
    return false
end

local function RegisterAlias(key, command, target)
    if SlashCmdList[key] or SlashTaken(command) then return false end
    _G["SLASH_" .. key .. "1"] = command
    SlashCmdList[key] = function()
        HandleSlashCmd(target)
    end
    return true
end
B.RegisterSlashAlias = RegisterAlias

local aliasWatcher = CreateFrame("Frame")
aliasWatcher:RegisterEvent("PLAYER_LOGIN")
aliasWatcher:SetScript("OnEvent", function()
    RegisterAlias("BLACKWELLUI_MSBT", "/msbt", "sct")
    RegisterAlias("BLACKWELLUI_SPLATES", "/splates", "plates")
    this:UnregisterEvent("PLAYER_LOGIN")
end)
