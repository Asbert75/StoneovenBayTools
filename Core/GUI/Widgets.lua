local _, SBT = ...

SBT.Widgets = {}

function SBT.Widgets:CreateLabel(parent, text, fontTemplate)
    local label = parent:CreateFontString(nil, "ARTWORK", fontTemplate or "GameFontNormal")
    label:SetTextColor(unpack(SBT.Theme.text))
    if text then
        label:SetText(text)
    end
    return label
end

-- opts: { getValue = function() end, setValue = function(checked) end }
function SBT.Widgets:CreateCheckbox(parent, text, opts)
    opts = opts or {}

    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox.text:SetText(text or "")
    checkbox.text:SetTextColor(unpack(SBT.Theme.text))
    checkbox:SetScript("OnClick", function(self)
        if opts.setValue then
            opts.setValue(self:GetChecked() and true or false)
        end
    end)

    function checkbox:Refresh()
        if opts.getValue then
            checkbox:SetChecked(opts.getValue())
        end
    end

    checkbox:Refresh()
    return checkbox
end

-- opts: { min, max, step, getValue = function() end, setValue = function(value) end, formatValue = function(value) end }
function SBT.Widgets:CreateSlider(parent, text, opts)
    opts = opts or {}
    local min = opts.min or 0
    local max = opts.max or 100
    local step = opts.step or 1
    local formatValue = opts.formatValue or function(value) return tostring(value) end

    local label = SBT.Widgets:CreateLabel(parent, text)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider.Low:SetText(tostring(min))
    slider.High:SetText(tostring(max))
    slider.Text:SetText("")

    local valueLabel = SBT.Widgets:CreateLabel(parent)
    valueLabel:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        local stepped = step < 1 and value or math.floor(value + 0.5)
        if opts.setValue then
            opts.setValue(stepped)
        end
        valueLabel:SetText(formatValue(stepped))
    end)

    function slider:Refresh()
        if opts.getValue then
            local value = opts.getValue()
            slider:SetValue(value)
            valueLabel:SetText(formatValue(value))
        end
    end

    slider:Refresh()
    return slider, label, valueLabel
end

-- A themed child frame, useful as a tab page or a grouped section of controls.
function SBT.Widgets:CreatePanel(parent, opts)
    opts = opts or {}

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = SBT.Theme.panelBackgroundTexture,
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        tile = true,
        tileSize = 256,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel:SetBackdropColor(1, 1, 1, 1)
    panel:SetBackdropBorderColor(unpack(SBT.Theme.border))

    if opts.size then
        panel:SetSize(opts.size[1], opts.size[2])
    end

    return panel
end

-- tabs: { { text = "General", panel = frame, onSelect = function() end }, ... }. Only one panel is shown at a time.
function SBT.Widgets:CreateTabGroup(parent, tabs)
    local tabGroup = { buttons = {}, tabs = tabs }
    local previousButton

    local function selectTab(index)
        for tabIndex, tab in ipairs(tabs) do
            local isActive = tabIndex == index
            tab.panel:SetShown(isActive)
            local button = tabGroup.buttons[tabIndex]
            button.texture:SetTexture(isActive and SBT.Theme.tabActiveTexture or SBT.Theme.tabInactiveTexture)
            button.label:SetTextColor(unpack(isActive and SBT.Theme.text or SBT.Theme.textDisabled))
        end
        tabGroup.activeIndex = index

        if tabs[index].onSelect then
            tabs[index].onSelect()
        end
    end

    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(130, 32)

        local texture = button:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        button.texture = texture

        if previousButton then
            button:SetPoint("LEFT", previousButton, "RIGHT", -4, 0)
        else
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        end
        previousButton = button

        local buttonLabel = SBT.Widgets:CreateLabel(button, tab.text)
        buttonLabel:SetPoint("CENTER", 0, -6)
        button.label = buttonLabel

        button:SetScript("OnClick", function()
            selectTab(index)
        end)

        tabGroup.buttons[index] = button
    end

    function tabGroup:SelectTab(index)
        selectTab(index)
    end

    selectTab(1)
    return tabGroup
end

-- Wraps the Blizzard scroll frame template with a content frame sized to the visible width.
function SBT.Widgets:CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    return scrollFrame, content
end

-- opts: { getValue = function() return r, g, b, a end, setValue = function(r, g, b, a) end }
function SBT.Widgets:CreateColorSwatch(parent, opts)
    opts = opts or {}

    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(20, 20)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    swatch:SetBackdropBorderColor(unpack(SBT.Theme.border))

    local function applyColor(r, g, b, a)
        swatch:SetBackdropColor(r, g, b, a or 1)
    end

    local function currentColor()
        if opts.getValue then
            return opts.getValue()
        end
        return 1, 1, 1, 1
    end

    swatch:SetScript("OnClick", function()
        local r, g, b, a = currentColor()

        local function onColorChanged(newR, newG, newB, newA)
            applyColor(newR, newG, newB, newA)
            if opts.setValue then
                opts.setValue(newR, newG, newB, newA)
            end
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    onColorChanged(newR, newG, newB, 1 - OpacitySliderFrame:GetValue())
                end,
                opacityFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    onColorChanged(newR, newG, newB, 1 - OpacitySliderFrame:GetValue())
                end,
                cancelFunc = function(previous)
                    onColorChanged(previous.r, previous.g, previous.b, previous.opacity and (1 - previous.opacity) or a)
                end,
            })
        else
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = 1 - a
            ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = 1 - a }
            ColorPickerFrame.func = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                onColorChanged(newR, newG, newB, 1 - OpacitySliderFrame:GetValue())
            end
            ColorPickerFrame.opacityFunc = ColorPickerFrame.func
            ColorPickerFrame.cancelFunc = function(previous)
                onColorChanged(previous.r, previous.g, previous.b, previous.opacity and (1 - previous.opacity) or a)
            end
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)

    function swatch:Refresh()
        applyColor(currentColor())
    end

    swatch:Refresh()
    return swatch
end
