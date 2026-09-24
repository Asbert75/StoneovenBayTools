local _, SBT = ...

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local out = {}
    for key, value in pairs(source) do
        out[key] = CopyTable(value)
    end
    return out
end

local ClassColors = {
    DRUID = { 1.00, 0.49, 0.04, 1 },
    HUNTER = { 0.67, 0.83, 0.45, 1 },
    MAGE = { 0.25, 0.78, 0.92, 1 },
    MONK = { 0.00, 1.00, 0.60, 1 },
    PALADIN = { 0.96, 0.55, 0.73, 1 },
    PRIEST = { 1.00, 1.00, 1.00, 1 },
    ROGUE = { 1.00, 0.96, 0.41, 1 },
    SHAMAN = { 0.00, 0.44, 0.87, 1 },
    WARLOCK = { 0.53, 0.53, 0.93, 1 },
    WARRIOR = { 0.78, 0.61, 0.43, 1 },
}

local PowerTypeColors = {
    MANA = { 0.00, 0.44, 0.87, 1 },
    RAGE = { 0.90, 0.20, 0.23, 1 },
    FOCUS = { 1.00, 0.50, 0.25, 1 },
    ENERGY = { 1.00, 0.86, 0.10, 1 },
    COMBO_POINTS = { 1.00, 0.25, 0.10, 1 }
}

local SharedDefaults = {
    MinimapButton = {
        hide = false,
        minimapPos = 225,
    },
    enableAutoResponse = true,
    responseCooldown = 10,
}

local Defaults = {
    -- Profile data for all user-facing settings.
    profile = CopyTable(SharedDefaults),

    -- Account-wide metadata for profile automation.
    global = {
        ProfileBindings = {
            EnableSpecProfiles = false,
            SpecProfiles = {},
        },
    },
}

function SBT:GetDefaultDB()
    return Defaults
end

