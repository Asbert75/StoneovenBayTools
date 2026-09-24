local _, SBT = ...
local StoneovenBayTools = LibStub("AceAddon-3.0"):NewAddon("StoneovenBayTools")

SBT.PREFIX = "|cffe6c56cStoneovenBayTools|r: "
SBT.EventHandlers = {}
SBT.Frame = CreateFrame("Frame")

function SBT.RegisterEvent(event, handler)
    SBT.EventHandlers[event] = SBT.EventHandlers[event] or {}
    SBT.EventHandlers[event][#SBT.EventHandlers[event] + 1] = handler
    SBT.Frame:RegisterEvent(event)
end

SBT.Frame:SetScript("OnEvent", function(_, event, ...)
    local handlers = SBT.EventHandlers[event]
    if not handlers then
        return
    end

    for _, handler in ipairs(handlers) do
        handler(...)
    end
end)

function SBT:GetAutoProfileSettings()
    if not SBT.db then
        return nil
    end

    if type(SBT.db.global) ~= "table" then
        SBT.db.global = {}
    end

    if type(SBT.db.global.ProfileBindings) ~= "table" then
        SBT.db.global.ProfileBindings = {}
    end

    local bindings = SBT.db.global.ProfileBindings
    if type(bindings.SpecProfiles) ~= "table" then
        bindings.SpecProfiles = {}
    end

    bindings.EnableSpecProfiles = bindings.EnableSpecProfiles == true
    return bindings
end

function SBT:OnProfileChanged()
    SBT.GetDatabase()
    if SBT.ApplyMinimapButtonVisibility then
        SBT:ApplyMinimapButtonVisibility()
    end
end

-- AceAddon only invokes lifecycle callbacks on the addon object it manages, not on the private namespace table.
function StoneovenBayTools:OnInitialize()
    SBT.db = LibStub("AceDB-3.0"):New("StoneovenBayToolsDB", SBT:GetDefaultDB())

    SBT.db.RegisterCallback(SBT, "OnProfileChanged", "OnProfileChanged")
    SBT.db.RegisterCallback(SBT, "OnProfileCopied", "OnProfileChanged")
    SBT.db.RegisterCallback(SBT, "OnProfileReset", "OnProfileChanged")

    SBT:GetAutoProfileSettings()
    if SBT.ApplyAutomaticProfile then
        SBT:ApplyAutomaticProfile()
    end
end

function StoneovenBayTools:OnEnable()
    SBT.GetDatabase()
    SBT.DefaultFont = SBT:GetSharedMedia("font")
    SBT:Init()
    SBT:InitializeMinimapButton()
    SBT:PrettyPrint("Addon loaded. Type |cff38b357/sbt|r for settings.")
end