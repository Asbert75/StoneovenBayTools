local _, SBT = ...

SBT.LSM = LibStub("LibSharedMedia-3.0", true)
SBT.AG = LibStub("AceGUI-3.0")

SBT.ADDON_NAME = C_AddOns.GetAddOnMetadata("StoneovenBayTools", "Title")

SBT.DefaultFont = "";

function SBT:PrettyPrint(msg)
    print("|cff8c1616" .. SBT.ADDON_NAME .. ":|r " .. msg)
end

function SBT:GetProfileDB()
    if not SBT.db then
        return nil
    end

    return SBT.db.profile
end

function SBT:GetDB(key, default)
    local profile = SBT:GetProfileDB()
    if not profile then
        return default
    end

    if key and type(key) == "string" then
        return profile[key] ~= nil and profile[key] or default
    end

    return profile
end

function SBT:SetDB(key, value)
    local profile = SBT:GetProfileDB()
    if not profile then
        return
    end

    if key and type(key) == "string" then
        profile[key] = value
    end
end

-- "/SBT" collides case-insensitively with the "/sbt" command in Settings.lua; toggle exposed as a subcommand instead.
function SBT:ToggleMainFrame()
    if not SBT.MainFrame then
        SBT:PrettyPrint("Settings UI is not ready yet.")
        return
    end

    if SBT.MainFrame:IsShown() then
        SBT.MainFrame:Hide()
    else
        SBT.MainFrame:Show()
    end
end

function SBT:PixelPerfect(value)
    if not value then return 0 end
    local _, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent:GetEffectiveScale()
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * math.floor((value / pixelSize) + 0.5333)
end

function SBT:Init()
end
