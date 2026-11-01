-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Options.lua
--  Control center (/bw): sidebar with pages, plain-language settings with a
--  one-line hint each; dependent settings are indented and disabled while
--  their module is off.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local optionsFrame = nil

local FRAME_W, FRAME_H = 640, 500
local NAV_W = 150
local HEADER_H = 28
local FOOTER_H = 44
local CONTENT_X = NAV_W + 20
local CONTENT_W = FRAME_W - CONTENT_X - 20

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

-------------------------------------------------------------------------------
--  Widgets
-------------------------------------------------------------------------------
local function CreateButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:EnableMouse(true)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    B:Solid(bg, 0.10, 0.10, 0.10, 0.95)
    bg:SetAllPoints(btn)
    btn.bg = bg
    B:Border(btn, 0.22, 0.22, 0.22, 1)

    local fs = B:Font(btn, 10, "CENTER")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    SetColor(fs, TEXT)
    fs:SetText(text)
    btn.label = fs

    btn:SetScript("OnEnter", function()
        local ar, ag, ab = B:GetAccent()
        B:SetBorderColor(this, ar, ag, ab, 0.9)
    end)
    btn:SetScript("OnLeave", function()
        B:SetBorderColor(this, 0.22, 0.22, 0.22, 1)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- A page lays its controls out top-down from a cursor.
local function NewPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_X, -(HEADER_H + 14))
    page:SetWidth(CONTENT_W)
    page:SetHeight(FRAME_H - HEADER_H - FOOTER_H - 20)
    page.y = 0
    page.controls = {}
    page:Hide()
    return page
end

local function AddSection(page, title)
    if page.y < 0 then page.y = page.y - 8 end
    local fs = B:Font(page, 9, "LEFT")
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    SetColor(fs, MUTED)
    fs:SetText(string.upper(title))
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
    fs:SetText(text)
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
    B:Solid(boxBg, 0.06, 0.06, 0.06, 1)
    boxBg:SetAllPoints(box)
    B:Border(box, 0.30, 0.30, 0.30, 1)
    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    check:SetTexture(B.WHITE)
    B:Accent(check, "tex", 1)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 1)
    labelFs:SetText(label)

    local hintFs
    if hint then
        hintFs = B:Font(row, 9, "LEFT")
        hintFs:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -3)
        hintFs:SetWidth(CONTENT_W - x - 24)
        hintFs:SetText(hint)
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

-- Label on the left, "<  value  >" on the right.
local function AddCycler(page, label, getText, onStep)
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    row:SetWidth(CONTENT_W)
    row:SetHeight(22)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    SetColor(labelFs, TEXT)
    labelFs:SetText(label)

    local nextBtn = CreateButton(row, 22, 20, ">", function() onStep(1) page:RefreshAll() end)
    nextBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local valueFs = B:Font(row, 10, "CENTER")
    valueFs:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    valueFs:SetWidth(130)
    SetColor(valueFs, TEXT)
    local prevBtn = CreateButton(row, 22, 20, "<", function() onStep(-1) page:RefreshAll() end)
    prevBtn:SetPoint("RIGHT", valueFs, "LEFT", -4, 0)

    function row:Refresh() valueFs:SetText(getText()) end
    table.insert(page.controls, row)
    page.y = page.y - 28
    return row
end

-- Label on the left, "-  value  +" on the right, optional extra button.
local function AddStepper(page, label, getText, onStep, extra)
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    row:SetWidth(CONTENT_W)
    row:SetHeight(22)

    local labelFs = B:Font(row, 11, "LEFT")
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    SetColor(labelFs, TEXT)
    labelFs:SetText(label)

    local anchor = row
    local anchorPoint = "RIGHT"
    local xoff = 0
    if extra then
        local eb = CreateButton(row, 54, 20, extra.text, function() extra.onClick() page:RefreshAll() end)
        eb:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.extraBtn = eb
        anchor, anchorPoint, xoff = eb, "LEFT", -8
    end
    local plusBtn = CreateButton(row, 22, 20, "+", function() onStep(1) page:RefreshAll() end)
    plusBtn:SetPoint("RIGHT", anchor, anchorPoint, xoff, 0)
    local valueFs = B:Font(row, 10, "CENTER")
    valueFs:SetPoint("RIGHT", plusBtn, "LEFT", -4, 0)
    valueFs:SetWidth(70)
    SetColor(valueFs, TEXT)
    local minusBtn = CreateButton(row, 22, 20, "-", function() onStep(-1) page:RefreshAll() end)
    minusBtn:SetPoint("RIGHT", valueFs, "LEFT", -4, 0)

    function row:Refresh()
        valueFs:SetText(getText())
        if extra and extra.getText then row.extraBtn.label:SetText(extra.getText()) end
    end
    table.insert(page.controls, row)
    page.y = page.y - 28
    return row
end

local function AddActionButton(page, text, w, onClick)
    local btn = CreateButton(page, w or 180, 22, text, onClick)
    btn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
    page.y = page.y - 30
    return btn
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

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["BLACKWELLUI_RESET_LAYOUT"] = {
    text = "BlackwellUI: move every frame back to its default position?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function() B:ResetPositions() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

-------------------------------------------------------------------------------
--  Pages
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

    AddSection(page, "Layout")
    get, set = DbToggle("demo", false, function() B:Tick() end)
    AddToggle(page, "Preview mode",
        "Fills every panel with sample data, handy while arranging the layout.", get, set)
    get, set = DbToggle("showGrid", true, function()
        if B.SetAlignmentGridShown then B:SetAlignmentGridShown(B.unlocked) end
    end)
    AddToggle(page, "Alignment grid in edit mode",
        "32 px grid with centre lines while frames are unlocked.", get, set)

    AddSection(page, "Troubleshooting")
    AddActionButton(page, "Open script error log", 200, function()
        if type(BenillaScriptLog_Toggle) == "function" then
            BenillaScriptLog_Toggle()
        else
            B:Print("No script log available in this client.")
        end
    end)
    AddNote(page, "Before uninstalling, untick Combat text (Combat page) and Replace the stock run HUD here, so the game gets its own settings back.")
end

local function BuildAppearance(page, refreshOwner)
    AddSection(page, "Colour")
    AddCycler(page, "Theme",
        function() return tostring(B.db.theme) end,
        function(step)
            B.db.theme = CycleValue(B.THEME_ORDER, B.db.theme, step)
            B:RefreshTheme()
            refreshOwner()
        end)
    AddActionButton(page, "Pick custom colour", 180, function()
        if not ColorPickerFrame then return end
        local cur = B.db.customAccent or { r = 0, g = 0.9, b = 1 }
        local prev = { r = cur.r, g = cur.g, b = cur.b, theme = B.db.theme }
        ColorPickerFrame.hasOpacity = nil
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.func = nil
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(cur.r, cur.g, cur.b)
        end
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            B.db.customAccent = { r = r, g = g, b = b }
            B.db.theme = "Custom"
            B:RefreshTheme()
            refreshOwner()
        end
        ColorPickerFrame.cancelFunc = function()
            B.db.customAccent = { r = prev.r, g = prev.g, b = prev.b }
            B.db.theme = prev.theme
            B:RefreshTheme()
            refreshOwner()
        end
        ColorPickerFrame:Show()
    end)

    AddSection(page, "Style")
    AddCycler(page, "Bar texture",
        function() return tostring(B.db.barTexture) end,
        function(step)
            B.db.barTexture = CycleValue(B.BAR_TEXTURE_ORDER, B.db.barTexture, step)
            B:RefreshTheme()
        end)
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
    AddStepper(page, "Background opacity",
        function() return string.format("%d%%", math.floor((B.db.backdropAlpha or 0.85) * 100 + 0.5)) end,
        function(step)
            local v = Clamp((B.db.backdropAlpha or 0.85) + step * 0.05, 0.30, 1.0)
            B.db.backdropAlpha = math.floor(v * 100 + 0.5) / 100
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
            getText = function() return (B.db.autoScale and "Auto") or "Fixed" end,
            onClick = function()
                B.db.autoScale = not B.db.autoScale
                if B.db.autoScale then
                    B.db.scale = B:GetOptimalScale()
                    B:ApplyScale()
                end
            end,
        })
end

local function BuildHud(page)
    AddSection(page, "Player")
    local get, set = ModuleToggle("unitframes")
    AddToggle(page, "Unit frames",
        "Hero, target, target of target and the elites & bosses list.", get, set)
    get, set = DbToggle("colorHealthByClass", true, function() B:RefreshTheme() end)
    AddToggle(page, "Class-coloured health", nil, get, set, { indent = true, depends = ModuleOn("unitframes") })
    get, set = ModuleToggle("castbar")
    AddToggle(page, "Cast bar", nil, get, set)
    get, set = ModuleToggle("build")
    AddToggle(page, "Spell tiles",
        "Your spells with cooldowns, ranks and upgrade tooltips.", get, set)
    get, set = DbToggle("showBuffBars", true, function() B:Tick() end)
    AddToggle(page, "Buff bars above the tiles", nil, get, set, { indent = true, depends = ModuleOn("build") })

    AddSection(page, "Panels")
    get, set = ModuleToggle("stats")
    AddToggle(page, "Multipliers",
        "Damage, cooldown, crit, area and the other run multipliers.", get, set)
    get, set = DbToggle("statsGrowUp", false, function()
        local m = B.modules["stats"]
        if m and type(m.ApplyGrowth) == "function" then m:ApplyGrowth() end
    end)
    AddToggle(page, "Grow upwards (bottom edge stays in place)", nil, get, set, { indent = true, depends = ModuleOn("stats") })
    get, set = ModuleToggle("equipment")
    AddToggle(page, "Equipment", nil, get, set)
    get, set = ModuleToggle("databar")
    AddToggle(page, "Data bar",
        "Level, XP, kills per minute, gold, lives, damage and FPS along the bottom.", get, set)
    get, set = ModuleToggle("actionbars")
    AddToggle(page, "Hide action bars and bags",
        "Spells cast themselves in Azeroth Survivors. Needs /reload to bring them back.", get, set)
end

local function BuildCombat(page)
    AddSection(page, "Damage meter")
    local get, set = ModuleToggle("meter")
    AddToggle(page, "Damage meter",
        "Damage, healing, boss, taken and party tabs with per-spell breakdown.", get, set)
    get, set = DbToggle("mergeItemProcs", false, function() B:Tick() end)
    AddToggle(page, "Merge item procs into their spell", nil, get, set, { indent = true, depends = ModuleOn("meter") })

    AddSection(page, "Combat text")
    get, set = ModuleToggle("combattext")
    AddToggle(page, "Combat text",
        "Replaces Blizzard's floating numbers. Turning it off restores them at once.", get, set)
    get, set = DbToggle("sctAlerts", false)
    AddToggle(page, "Ability alerts",
        "Ready, Overpower and Execute prompts. They do not check your class.", get, set, { indent = true, depends = ModuleOn("combattext") })

    AddSection(page, "Nameplates")
    get, set = ModuleToggle("nameplates")
    AddToggle(page, "Nameplates",
        "Coloured by reaction and unit kind. Show or hide them with V.", get, set)
end

local function BuildMap(page)
    AddSection(page, "Minimap")
    local get, set = ModuleToggle("minimap")
    AddToggle(page, "Square minimap with coordinates", nil, get, set)
    get, set = ModuleToggle("pins")
    AddToggle(page, "Radar pins",
        "Pins stay on the minimap edge when the target is out of range.", get, set)
    get, set = DbToggle("pinCaches", true)
    AddToggle(page, "Caches", nil, get, set, { indent = true, depends = ModuleOn("pins") })
    get, set = DbToggle("pinLairs", true)
    AddToggle(page, "Guardian lairs", nil, get, set, { indent = true, depends = ModuleOn("pins") })

    AddSection(page, "Run")
    get, set = ModuleToggle("timer")
    AddToggle(page, "Run clock",
        "Time, next boss, boss schedule and the 4 Guardians before 8:00 goal.", get, set)
    get, set = ModuleToggle("rares")
    AddToggle(page, "Rare spawn timers", nil, get, set)
    get, set = ModuleToggle("loot")
    AddToggle(page, "Loot log", nil, get, set)

    AddSection(page, "Chat and character")
    get, set = ModuleToggle("chat")
    AddToggle(page, "Chat panel", nil, get, set)
    get, set = DbToggle("filterChatSpam", true)
    AddToggle(page, "Filter level-up spam", nil, get, set, { indent = true, depends = ModuleOn("chat") })
    get, set = ModuleToggle("character")
    AddToggle(page, "Character window restyle", nil, get, set)
end

local PAGES = {
    { key = "general",    label = "General",    build = BuildGeneral },
    { key = "appearance", label = "Appearance", build = BuildAppearance },
    { key = "hud",        label = "HUD",        build = BuildHud },
    { key = "combat",     label = "Combat",     build = BuildCombat },
    { key = "map",        label = "Map & Run",  build = BuildMap },
}

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local function BuildOptionsFrame()
    if optionsFrame then return optionsFrame end

    local f = CreateFrame("Frame", "BlackwellUIOptionsFrame", UIParent)
    BlackwallUIOptionsFrame = f -- Compatibility alias
    EllesmereUIOptionsFrame = f -- Compatibility alias
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
    -- Own opaque background: B:Backdrop follows the HUD opacity setting, and a
    -- see-through settings window is hard to read over the HUD.
    local frameBg = f:CreateTexture(nil, "BACKGROUND")
    B:Solid(frameBg, 0.045, 0.045, 0.05, 0.97)
    frameBg:SetAllPoints(f)
    B:Border(f, 0, 0, 0, 1)
    table.insert(UISpecialFrames, "BlackwellUIOptionsFrame")

    -- Title bar
    local title = B:Font(f, 13, "LEFT")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -9)
    SetColor(title, TEXT)
    title:SetText("BlackwellUI")
    local ver = B:Font(f, 9, "LEFT")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
    SetColor(ver, MUTED)
    ver:SetText("v" .. B.version)
    local closeBtn = CreateButton(f, 22, 20, "x", function() f:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -5)
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
    local navBg = nav:CreateTexture(nil, "BACKGROUND")
    B:Solid(navBg, 0, 0, 0, 0.30)
    navBg:SetAllPoints(nav)
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
            if nb.key == current then
                nb.bar:SetVertexColor(ar, ag, ab)
                nb.bar:Show()
                B:Solid(nb.bg, 1, 1, 1, 0.05)
                SetColor(nb.label, TEXT)
            else
                nb.bar:Hide()
                B:Solid(nb.bg, 1, 1, 1, 0)
                SetColor(nb.label, MUTED)
            end
        end
    end

    local function ShowPage(key)
        current = key
        for k, p in pairs(pages) do
            if k == key then
                p:RefreshAll()
                p:Show()
            else
                p:Hide()
            end
        end
        RefreshNav()
    end
    f.ShowPage = ShowPage

    for i = 1, table.getn(PAGES) do
        local def = PAGES[i]
        local nb = CreateFrame("Button", nil, nav)
        nb:SetWidth(NAV_W - 1)
        nb:SetHeight(28)
        nb:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -10 - (i - 1) * 30)
        nb:EnableMouse(true)
        nb.key = def.key
        local bg = nb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(nb)
        nb.bg = bg
        local bar = nb:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(B.WHITE)
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", nb, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", nb, "BOTTOMLEFT", 0, 0)
        nb.bar = bar
        local fs = B:Font(nb, 11, "LEFT")
        fs:SetPoint("LEFT", nb, "LEFT", 16, 0)
        fs:SetText(def.label)
        nb.label = fs
        nb:SetScript("OnClick", function() ShowPage(this.key) end)
        table.insert(navButtons, nb)

        local page = NewPage(f)
        function page:RefreshAll()
            for j = 1, table.getn(self.controls) do
                self.controls[j]:Refresh()
            end
        end
        def.build(page, RefreshNav)
        pages[def.key] = page
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
        if type(StaticPopup_Show) == "function" then
            StaticPopup_Show("BLACKWELLUI_RESET_LAYOUT")
        else
            B:ResetPositions()
        end
    end)
    resetBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    local editBtn = CreateButton(f, 120, 24, "Edit layout", function()
        B:SetUnlocked(not B.unlocked)
        this.label:SetText((B.unlocked and "Done editing") or "Edit layout")
    end)
    editBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
    f.editBtn = editBtn

    f:SetScript("OnShow", function()
        f.editBtn.label:SetText((B.unlocked and "Done editing") or "Edit layout")
        ShowPage(current or "general")
    end)

    f:Hide()
    optionsFrame = f
    return f
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
SLASH_BLACKWELLUI6 = "/eui"
SLASH_BLACKWELLUI7 = "/ellesmere"
SLASH_BLACKWELLUI8 = "/bw"

local function HandleSlashCmd(msg)
    local cmd = string.lower((string.gsub(msg or "", "^%s*(.-)%s*$", "%1")))
    if cmd == "unlock" or cmd == "move" then
        B:SetUnlocked(true)
        B:Print("UI Unlocked. Drag frames to position.")
    elseif cmd == "lock" then
        B:SetUnlocked(false)
        B:Print("UI Locked.")
    elseif cmd == "reset" then
        B:ResetPositions()
    elseif cmd == "demo" then
        B.db.demo = not B.db.demo
        B:Tick()
        B:Print("Demo Mode: " .. (B.db.demo and "ON" or "OFF"))
    elseif cmd == "hud" then
        B.db.replaceHud = not B.db.replaceHud
        B:SyncHud()
        B:Print("Stock HUD replacement: " .. (B.db.replaceHud and "ON" or "OFF"))
    elseif cmd == "pins" or cmd == "radar" then
        local cur = B:IsEnabled("pins")
        B.db.modules["pins"] = not cur
        B:OnModulesChanged()
        B:Print("Minimap Radar Pins: " .. (B:IsEnabled("pins") and "ON" or "OFF"))
    elseif cmd == "loot" then
        local cur = B:IsEnabled("loot")
        B.db.modules["loot"] = not cur
        B:OnModulesChanged()
        B:Print("Loot Drop Log: " .. (B:IsEnabled("loot") and "ON" or "OFF"))
    elseif cmd == "rares" or cmd == "rare" then
        local cur = B:IsEnabled("rares")
        B.db.modules["rares"] = not cur
        B:OnModulesChanged()
        B:Print("Rare Spawn Timers: " .. (B:IsEnabled("rares") and "ON" or "OFF"))
    elseif cmd == "equipment" or cmd == "items" or cmd == "gear" then
        local cur = B:IsEnabled("equipment")
        B.db.modules["equipment"] = not cur
        B:OnModulesChanged()
        B:Print("Equipment HUD: " .. (B:IsEnabled("equipment") and "ON" or "OFF"))
    elseif cmd == "nameplates" or cmd == "plates" or cmd == "splates" then
        local cur = B:IsEnabled("nameplates")
        B.db.modules["nameplates"] = not cur
        B:OnModulesChanged()
        B:Print("Cyberpunk Nameplates: " .. (B:IsEnabled("nameplates") and "ON" or "OFF"))
    elseif cmd == "combattext" or cmd == "sct" or cmd == "msbt" then
        local cur = B:IsEnabled("combattext")
        B.db.modules["combattext"] = not cur
        B:OnModulesChanged()
        if B.SyncCombatText then B:SyncCombatText() end
        B:Print("Scrolling Combat Text: " .. (B:IsEnabled("combattext") and "ON (Blizzard Numbers suppressed)" or "OFF (Blizzard Numbers restored)"))
    elseif cmd == "grid" or cmd == "raster" then
        B.db.showGrid = not (B.db.showGrid ~= false)
        if B.SetAlignmentGridShown then B:SetAlignmentGridShown(B.unlocked) end
        B:Print("Edit Mode Alignment Grid: " .. (B.db.showGrid and "ON" or "OFF"))
    elseif cmd == "buffs" or cmd == "alerts" then
        B.db.showBuffBars = not (B.db.showBuffBars ~= false)
        B:Tick()
        B:Print("Build Buff & Alert Bars: " .. (B.db.showBuffBars and "ON" or "OFF"))
    elseif cmd == "autoscale" or cmd == "auto" then
        B.db.autoScale = not B.db.autoScale
        if B.db.autoScale then
            B.db.scale = B:GetOptimalScale()
            B:ApplyScale()
        end
        B:Print("Auto Resolution Scaling: " .. (B.db.autoScale and ("ON (x" .. string.format("%.2f", B.db.scale) .. ")") or "OFF"))
    elseif string.find(cmd, "^scale%s*") then
        local _, _, val = string.find(cmd, "^scale%s*([%d%.]+)")
        local num = tonumber(val)
        if num and num >= 0.5 and num <= 2.0 then
            B.db.autoScale = false
            B.db.scale = math.floor(num * 100 + 0.5) / 100
            B:ApplyScale()
            B:Print("Scale set to: " .. string.format("x%.2f", B.db.scale))
        else
            B:Print("Usage: /bw scale 0.80  (or /bw autoscale)")
        end
    elseif cmd == "help" then
        B:Print("Commands: /bw (options), /bw unlock, /bw lock, /bw reset, /bw grid, /bw buffs, /bw autoscale, /bw scale <val>, /bw demo, /bw hud, /bw pins, /bw loot, /bw plates, /bw sct")
    else
        B:ToggleOptions()
    end
end

SlashCmdList["BLACKWELLUI"] = HandleSlashCmd
SlashCmdList["BLACKWALLUI"] = HandleSlashCmd
SlashCmdList["ELLESMEREUI"] = HandleSlashCmd

SLASH_MSBT1 = "/msbt"
SlashCmdList["MSBT"] = function(msg)
    HandleSlashCmd("sct " .. (msg or ""))
end

SLASH_SPLATES1 = "/splates"
SlashCmdList["SPLATES"] = function(msg)
    HandleSlashCmd("plates " .. (msg or ""))
end
