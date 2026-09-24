local _, SBT = ...

local ICON_ID = "StoneovenBayTools"
local ICON_PATH = "Interface\\AddOns\\StoneovenBayTools\\Media\\Logos\\logo.png";

local function getLDB()
    if not LibStub then
        return nil
    end

    return LibStub:GetLibrary("LibDataBroker-1.1", true)
end

local function getDBIcon()
    if not LibStub then
        return nil
    end

    return LibStub("LibDBIcon-1.0", true)
end

local function getMinimapSettings()
    local profile = SBT:GetProfileDB()
    if not profile then
        return nil
    end

    if type(profile.MinimapButton) ~= "table" then
        profile.MinimapButton = {
            hide = false,
            minimapPos = 225,
        }
    end

    return profile.MinimapButton
end

function SBT:SetMinimapButtonHidden(hidden)
    local settings = getMinimapSettings()
    if not settings then
        return
    end

    settings.hide = hidden and true or false
    SBT:ApplyMinimapButtonVisibility()
end

function SBT:IsMinimapButtonHidden()
    local settings = getMinimapSettings()
    return settings and settings.hide == true or false
end

function SBT:ApplyMinimapButtonVisibility()
    local dbIcon = getDBIcon()
    local settings = getMinimapSettings()
    if not dbIcon then
        return
    end

    if settings and settings.hide then
        dbIcon:Hide(ICON_ID)
        return
    end

    dbIcon:Show(ICON_ID)
end

function SBT:UpdateMinimapButtonPosition()
    SBT:ApplyMinimapButtonVisibility()
end

function SBT:InitializeMinimapButton()
    local ldb = getLDB()
    local dbIcon = getDBIcon()
    local settings = getMinimapSettings()

    if not ldb or not dbIcon or not settings then
        return
    end

    if not SBT._minimapDataObject then
        SBT._minimapDataObject = ldb:NewDataObject(ICON_ID, {
            type = "data source",
            icon = ICON_PATH,
            text = "SBT",
            OnClick = function(_)
                SBT:ToggleMainFrame()
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("StoneovenBayTools")
                tooltip:AddLine("Click to open settings", 0.9, 0.9, 0.9)
                tooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
            end,
        })
    end

    if not dbIcon:IsRegistered(ICON_ID) then
        dbIcon:Register(ICON_ID, SBT._minimapDataObject, settings)
    elseif dbIcon.Refresh then
        dbIcon:Refresh(ICON_ID, settings)
    end

    SBT._minimapButton = dbIcon:GetMinimapButton(ICON_ID)
    SBT:ApplyMinimapButtonVisibility()
end
