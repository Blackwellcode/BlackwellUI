-------------------------------------------------------------------------------
--  BlackwellUI for Azeroth Survivors  -  Options.lua
--  Control center: Cyberpunk styling, ColorPicker, font scaling, module toggles.
--  Lua 5.0 / WoW 1.12.1: no '#', no '%', no string methods.
-------------------------------------------------------------------------------

local B = BlackwellUI
local E = BlackwellUI
local optionsFrame = nil

local function CycleValue(list, current)
    local n = table.getn(list)
    for i = 1, n do
        if list[i] == current then
            local nextIdx = i + 1
            if nextIdx > n then nextIdx = 1 end
            return list[nextIdx]
        end
    end
    return list[1]
end

local function CreateCheckbox(parent, x, y, label, getFn, setFn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(240)
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:EnableMouse(true)

    local box = CreateFrame("Frame", nil, btn)
    box:SetWidth(14)
    box:SetHeight(14)
    box:SetPoint("LEFT", btn, "LEFT", 0, 0)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    B:Solid(boxBg, 0.08, 0.08, 0.08, 0.95)
    boxBg:SetAllPoints(box)
    B:Border(box, 0.35, 0.35, 0.35, 1)

    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    check:SetTexture(B.WHITE)
    B:Accent(check, "tex", 0.95)
    btn.check = check

    local textFs = B:Font(btn, 10, "LEFT")
    textFs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    textFs:SetTextColor(0.9, 0.9, 0.9)
    textFs:SetText(label)
    btn.textFs = textFs

    function btn:Refresh()
        local val = getFn()
        if val then
            self.check:Show()
            self.textFs:SetTextColor(1, 1, 1)
        else
            self.check:Hide()
            self.textFs:SetTextColor(0.6, 0.6, 0.6)
        end
    end

    btn:SetScript("OnClick", function()
        local cur = getFn()
        setFn(not cur)
        this:Refresh()
    end)

    btn:Refresh()
    return btn
end

local function CreateSimpleButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:EnableMouse(true)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    B:Solid(bg, 0.12, 0.11, 0.10, 0.95)
    bg:SetAllPoints(btn)
    btn.bg = bg
    B:Border(btn, 0.25, 0.25, 0.25, 1)

    local fs = B:Font(btn, 10, "CENTER")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetTextColor(0.92, 0.92, 0.92)
    fs:SetText(text)
    btn.label = fs

    btn:SetScript("OnEnter", function()
        local ar, ag, ab = B:GetAccent()
        B:SetBorderColor(this, ar, ag, ab, 0.85)
        this.label:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function()
        B:SetBorderColor(this, 0.25, 0.25, 0.25, 1)
        this.label:SetTextColor(0.92, 0.92, 0.92)
    end)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function BuildOptionsFrame()
    if optionsFrame then return optionsFrame end

    local f = CreateFrame("Frame", "BlackwellUIOptionsFrame", UIParent)
    BlackwallUIOptionsFrame = f -- Compatibility alias
    EllesmereUIOptionsFrame = f -- Compatibility alias
    f:SetWidth(540)
    f:SetHeight(550)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    B:Backdrop(f, 0.96)
    table.insert(UISpecialFrames, "BlackwellUIOptionsFrame")

    -- Header
    local hdr = B:Header(f, "BLACKWELL UI  -  AZEROTH SURVIVORS", 24)
    hdr.value:SetText("v" .. B.version)

    local closeBtn = CreateSimpleButton(hdr, 20, 18, "X", function()
        f:Hide()
    end)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    hdr.value:ClearAllPoints()
    hdr.value:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    -- Appearance Section (Top)
    local secApp = B:Font(f, 10, "LEFT")
    secApp:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    secApp:SetTextColor(0.65, 0.65, 0.65)
    secApp:SetText("COLORS & TYPOGRAPHY")

    -- Row 1: Themes, ColorPicker Swatch, Bars, Font, Scale
    local themeBtn = CreateSimpleButton(f, 130, 22, "Theme", nil)
    themeBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -48)

    local swatchBtn = CreateFrame("Button", nil, f)
    swatchBtn:SetWidth(42)
    swatchBtn:SetHeight(22)
    swatchBtn:SetPoint("LEFT", themeBtn, "RIGHT", 6, 0)
    swatchBtn:EnableMouse(true)
    local swatchBg = swatchBtn:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetAllPoints(swatchBtn)
    swatchBtn.bg = swatchBg
    B:Border(swatchBtn, 0.25, 0.25, 0.25, 1)
    local swatchFs = B:Font(swatchBtn, 9, "CENTER")
    swatchFs:SetPoint("CENTER", swatchBtn, "CENTER", 0, 0)
    swatchFs:SetText("RGB")
    swatchBtn.fs = swatchFs
    f.swatchBtn = swatchBtn

    local barBtn = CreateSimpleButton(f, 110, 22, "Bars", nil)
    barBtn:SetPoint("LEFT", swatchBtn, "RIGHT", 6, 0)

    local fontBtn = CreateSimpleButton(f, 120, 22, "Font", nil)
    fontBtn:SetPoint("LEFT", barBtn, "RIGHT", 6, 0)

    -- Scale controls
    local scaleLbl = B:Font(f, 10, "LEFT")
    scaleLbl:SetPoint("LEFT", fontBtn, "RIGHT", 8, 0)
    scaleLbl:SetTextColor(0.8, 0.8, 0.8)

    local scaleDown = CreateSimpleButton(f, 18, 22, "-", function()
        local cur = B.db.scale or 1.0
        cur = cur - 0.05
        if cur < 0.5 then cur = 0.5 end
        B.db.scale = math.floor(cur * 100 + 0.5) / 100
        B:ApplyScale()
        scaleLbl:SetText(string.format("x%.2f", B.db.scale))
    end)
    scaleDown:SetPoint("LEFT", scaleLbl, "RIGHT", 4, 0)

    local scaleUp = CreateSimpleButton(f, 18, 22, "+", function()
        local cur = B.db.scale or 1.0
        cur = cur + 0.05
        if cur > 2.0 then cur = 2.0 end
        B.db.scale = math.floor(cur * 100 + 0.5) / 100
        B:ApplyScale()
        scaleLbl:SetText(string.format("x%.2f", B.db.scale))
    end)
    scaleUp:SetPoint("LEFT", scaleDown, "RIGHT", 3, 0)

    -- Row 2: Backdrop Opacity, HUD Font Size, Chat Font Size
    local bgAlphaLbl = B:Font(f, 10, "LEFT")
    bgAlphaLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -78)
    bgAlphaLbl:SetTextColor(0.8, 0.8, 0.8)

    local bgDown = CreateSimpleButton(f, 18, 20, "-", function()
        local cur = B.db.backdropAlpha or 0.85
        cur = cur - 0.05
        if cur < 0.30 then cur = 0.30 end
        B.db.backdropAlpha = math.floor(cur * 100 + 0.5) / 100
        B:RefreshTheme()
        bgAlphaLbl:SetText(string.format("Backdrop: %d%%", math.floor(B.db.backdropAlpha * 100 + 0.5)))
    end)
    bgDown:SetPoint("LEFT", bgAlphaLbl, "RIGHT", 4, 0)

    local bgUp = CreateSimpleButton(f, 18, 20, "+", function()
        local cur = B.db.backdropAlpha or 0.85
        cur = cur + 0.05
        if cur > 1.0 then cur = 1.0 end
        B.db.backdropAlpha = math.floor(cur * 100 + 0.5) / 100
        B:RefreshTheme()
        bgAlphaLbl:SetText(string.format("Backdrop: %d%%", math.floor(B.db.backdropAlpha * 100 + 0.5)))
    end)
    bgUp:SetPoint("LEFT", bgDown, "RIGHT", 3, 0)

    -- HUD Font Scale Modifier (-2 to +4)
    local fontModLbl = B:Font(f, 10, "LEFT")
    fontModLbl:SetPoint("LEFT", bgUp, "RIGHT", 24, 0)
    fontModLbl:SetTextColor(0.8, 0.8, 0.8)

    local fontModDown = CreateSimpleButton(f, 18, 20, "-", function()
        local cur = B.db.fontScaleMod or 0
        cur = cur - 1
        if cur < -3 then cur = -3 end
        B.db.fontScaleMod = cur
        B:RefreshTheme()
        fontModLbl:SetText(string.format("HUD Font: %+d", B.db.fontScaleMod))
    end)
    fontModDown:SetPoint("LEFT", fontModLbl, "RIGHT", 4, 0)

    local fontModUp = CreateSimpleButton(f, 18, 20, "+", function()
        local cur = B.db.fontScaleMod or 0
        cur = cur + 1
        if cur > 5 then cur = 5 end
        B.db.fontScaleMod = cur
        B:RefreshTheme()
        fontModLbl:SetText(string.format("HUD Font: %+d", B.db.fontScaleMod))
    end)
    fontModUp:SetPoint("LEFT", fontModDown, "RIGHT", 3, 0)

    -- Chat Font Size (10 to 18pt)
    local chatFontLbl = B:Font(f, 10, "LEFT")
    chatFontLbl:SetPoint("LEFT", fontModUp, "RIGHT", 24, 0)
    chatFontLbl:SetTextColor(0.8, 0.8, 0.8)

    local chatFontDown = CreateSimpleButton(f, 18, 20, "-", function()
        local cur = B.db.chatFontSize or 12
        cur = cur - 1
        if cur < 9 then cur = 9 end
        B.db.chatFontSize = cur
        if ChatFrame1 and type(ChatFrame1.SetFont) == "function" then
            ChatFrame1:SetFont(B:GetFontPath(), B.db.chatFontSize)
        end
        chatFontLbl:SetText(string.format("Chat: %dpt", B.db.chatFontSize))
    end)
    chatFontDown:SetPoint("LEFT", chatFontLbl, "RIGHT", 4, 0)

    local chatFontUp = CreateSimpleButton(f, 18, 20, "+", function()
        local cur = B.db.chatFontSize or 12
        cur = cur + 1
        if cur > 20 then cur = 20 end
        B.db.chatFontSize = cur
        if ChatFrame1 and type(ChatFrame1.SetFont) == "function" then
            ChatFrame1:SetFont(B:GetFontPath(), B.db.chatFontSize)
        end
        chatFontLbl:SetText(string.format("Chat: %dpt", B.db.chatFontSize))
    end)
    chatFontUp:SetPoint("LEFT", chatFontDown, "RIGHT", 3, 0)

    local function UpdateVisualLabels()
        themeBtn.label:SetText("Theme: " .. tostring(B.db.theme))
        local ar, ag, ab = B:GetAccent()
        B:Solid(swatchBg, ar, ag, ab, 0.95)
        if (ar * 0.299 + ag * 0.587 + ab * 0.114) > 0.55 then
            swatchFs:SetTextColor(0, 0, 0)
        else
            swatchFs:SetTextColor(1, 1, 1)
        end
        barBtn.label:SetText("Bars: " .. tostring(B.db.barTexture))
        fontBtn.label:SetText("Font: " .. tostring(B.db.font))
        scaleLbl:SetText(string.format("x%.2f", B.db.scale or 1.0))
        bgAlphaLbl:SetText(string.format("Backdrop: %d%%", math.floor((B.db.backdropAlpha or 0.85) * 100 + 0.5)))
        fontModLbl:SetText(string.format("HUD Font: %+d", B.db.fontScaleMod or 0))
        chatFontLbl:SetText(string.format("Chat: %dpt", B.db.chatFontSize or 12))
    end

    themeBtn:SetScript("OnClick", function()
        B.db.theme = CycleValue(B.THEME_ORDER, B.db.theme)
        B:RefreshTheme()
        UpdateVisualLabels()
    end)

    -- Native ColorPickerFrame integration
    swatchBtn:SetScript("OnClick", function()
        if not ColorPickerFrame then return end
        local cur = B.db.customAccent or { r = 0, g = 0.9, b = 1 }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            B.db.customAccent = { r = r, g = g, b = b }
            B.db.theme = "Custom"
            B:RefreshTheme()
            UpdateVisualLabels()
        end
        ColorPickerFrame.cancelFunc = function()
            -- do nothing on cancel
        end
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(cur.r, cur.g, cur.b)
        end
        ColorPickerFrame:Show()
    end)

    barBtn:SetScript("OnClick", function()
        B.db.barTexture = CycleValue(B.BAR_TEXTURE_ORDER, B.db.barTexture)
        B:RefreshTheme()
        UpdateVisualLabels()
    end)

    fontBtn:SetScript("OnClick", function()
        B.db.font = CycleValue(B.FONT_ORDER, B.db.font)
        B:RefreshTheme()
        UpdateVisualLabels()
    end)

    -- Left Column: Modules
    local secMod = B:Font(f, 10, "LEFT")
    secMod:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -108)
    secMod:SetTextColor(0.65, 0.65, 0.65)
    secMod:SetText("MODULES")

    local checkList = {}

    local modDefs = {
        { key = "actionbars", label = "Action Bars & Buttons" },
        { key = "minimap",    label = "Square Minimap & Coords" },
        { key = "pins",       label = "Minimap Radar Pins" },
        { key = "unitframes", label = "Hero, Target & Encounters" },
        { key = "chat",       label = "Chat Window & EditBox" },
        { key = "castbar",    label = "Player Cast Bar" },
        { key = "build",      label = "Build Spells & Cooldowns" },
        { key = "meter",      label = "Combat Damage & Boss Meter" },
        { key = "timer",      label = "Run Clock, Goal & Schedule" },
        { key = "databar",    label = "Bottom Telemetry Data Bar" },
        { key = "stats",      label = "Left Multipliers & Stats" },
        { key = "nameplates", label = "Cyberpunk Nameplates" },
        { key = "character",  label = "Character Matrix ('C' Key)" },
        { key = "loot",       label = "Loot Drop Telemetry Log" },
    }

    for i = 1, table.getn(modDefs) do
        local def = modDefs[i]
        local cb = CreateCheckbox(f, 16, -126 - (i - 1) * 21, def.label,
            function() return B:IsEnabled(def.key) end,
            function(val)
                B.db.modules[def.key] = val
                B:OnModulesChanged()
            end
        )
        table.insert(checkList, cb)
    end

    -- Right Column: Stock Game HUD control & Color Options
    local secHud = B:Font(f, 10, "LEFT")
    secHud:SetPoint("TOPLEFT", f, "TOPLEFT", 280, -108)
    secHud:SetTextColor(0.65, 0.65, 0.65)
    secHud:SetText("STOCK GAME HUD & RADAR OPTIONS")

    local cbReplace = CreateCheckbox(f, 280, -126, "Replace Stock Run HUD",
        function() return B.db.replaceHud end,
        function(val)
            B.db.replaceHud = val
            B:SyncHud()
        end
    )
    table.insert(checkList, cbReplace)

    local cbBanners = CreateCheckbox(f, 280, -148, "Hide Stock Boss Banners",
        function() return B.db.hideBanners end,
        function(val)
            B.db.hideBanners = val
            B:SyncHud()
        end
    )
    table.insert(checkList, cbBanners)

    local cbLoot = CreateCheckbox(f, 280, -170, "Hide Stock Loot Prompts",
        function() return B.db.hideLoot end,
        function(val)
            B.db.hideLoot = val
            B:SyncHud()
        end
    )
    table.insert(checkList, cbLoot)

    local cbDemo = CreateCheckbox(f, 280, -192, "Demo / Preview Mode",
        function() return B.db.demo end,
        function(val)
            B.db.demo = val
            B:Tick()
        end
    )
    table.insert(checkList, cbDemo)

    local cbClassHp = CreateCheckbox(f, 280, -214, "Class Colored Health Bars",
        function() return B.db.colorHealthByClass ~= false end,
        function(val)
            B.db.colorHealthByClass = val
            B:RefreshTheme()
        end
    )
    table.insert(checkList, cbClassHp)

    local cbChatSpam = CreateCheckbox(f, 280, -236, "Filter Chat Level-Up Spam",
        function() return B.db.filterChatSpam ~= false end,
        function(val)
            B.db.filterChatSpam = val
        end
    )
    table.insert(checkList, cbChatSpam)

    local cbPinCaches = CreateCheckbox(f, 280, -258, "Radar: Show Caches",
        function() return B.db.pinCaches ~= false end,
        function(val)
            B.db.pinCaches = val
        end
    )
    table.insert(checkList, cbPinCaches)

    local cbPinLairs = CreateCheckbox(f, 280, -280, "Radar: Show Guardian Lairs",
        function() return B.db.pinLairs ~= false end,
        function(val)
            B.db.pinLairs = val
        end
    )
    table.insert(checkList, cbPinLairs)

    -- Warning note about CVars
    local noteFs = B:Font(f, 9, "LEFT")
    noteFs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -425)
    noteFs:SetWidth(508)
    noteFs:SetHeight(28)
    noteFs:SetTextColor(0.55, 0.55, 0.55)
    noteFs:SetText("Note: Stock HUD toggles are persistent game CVars. To restore original interface before disabling BlackwellUI, uncheck 'Replace Stock Run HUD' or use the in-game options.")

    -- Action Buttons (Bottom)
    local unlockBtn = CreateSimpleButton(f, 160, 24, "Unlock / Move UI", function()
        B:SetUnlocked(not B.unlocked)
        if B.unlocked then
            this.label:SetText("Lock UI Positions")
        else
            this.label:SetText("Unlock / Move UI")
        end
    end)
    unlockBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 50)
    f.unlockBtn = unlockBtn

    local resetBtn = CreateSimpleButton(f, 160, 24, "Reset Positions", function()
        B:ResetPositions()
    end)
    resetBtn:SetPoint("LEFT", unlockBtn, "RIGHT", 14, 0)

    local hudToggleBtn = CreateSimpleButton(f, 160, 24, "Toggle Stock HUD", function()
        B.db.replaceHud = not B.db.replaceHud
        B:SyncHud()
        cbReplace:Refresh()
    end)
    hudToggleBtn:SetPoint("LEFT", resetBtn, "RIGHT", 14, 0)

    local errBtn = CreateSimpleButton(f, 246, 24, "Open Error Log (/err)", function()
        if type(BenillaScriptLog_Toggle) == "function" then
            BenillaScriptLog_Toggle()
        else
            B:Print("No script log frame found.")
        end
    end)
    errBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 18)

    local reloadBtn = CreateSimpleButton(f, 246, 24, "Reload UI (/reload)", function()
        ReloadUI()
    end)
    reloadBtn:SetPoint("LEFT", errBtn, "RIGHT", 16, 0)

    f:SetScript("OnShow", function()
        UpdateVisualLabels()
        for i = 1, table.getn(checkList) do
            checkList[i]:Refresh()
        end
        if B.unlocked then
            f.unlockBtn.label:SetText("Lock UI Positions")
        else
            f.unlockBtn.label:SetText("Unlock / Move UI")
        end
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
    elseif cmd == "help" then
        B:Print("Commands: /bw (options), /bw unlock, /bw lock, /bw reset, /bw demo, /bw hud, /bw pins, /bw loot")
    else
        B:ToggleOptions()
    end
end

SlashCmdList["BLACKWELLUI"] = HandleSlashCmd
SlashCmdList["BLACKWALLUI"] = HandleSlashCmd
SlashCmdList["ELLESMEREUI"] = HandleSlashCmd
