local _, SBT = ...
local LibStub = _G.LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local format = string.format
    
SBT.Media = {
	Textures = {},
	StatusBars = {},
	Fonts = {}
}

local MediaKey = {
	texture	= 'Textures',
	statusbar = 'StatusBars',
	font = 'Fonts'
}

local MediaPath = {
	texture	= [[Interface\AddOns\StoneovenBayTools\Media\Textures\]],
	statusbar	= [[Interface\AddOns\StoneovenBayTools\Media\Textures\]],
	font = [[Interface\AddOns\StoneovenBayTools\Media\Fonts\]]
}

do
	local t, d = '|T%s%s|t', ''
	function SBT:TextureString(texture, data)
		return format(t, texture, data or d)
	end
end

local function AddMedia(Type, File, Name)
	if not LSM then
		return
	end

	local path = MediaPath[Type]
	if path then
		local key = File:gsub('%.%w-$','')
		local file = path .. File

		local pathKey = MediaKey[Type]
		if pathKey then SBT.Media[pathKey][key] = file end

        LSM:Register(Type, Name, file)
	end
end

AddMedia('texture', 'Backpack.tga', 'Backpack Icon')
AddMedia('texture', 'BagQuestIcon.tga', 'Bag Quest Icon')
AddMedia("texture", "Black8x8.tga", "SBT Black8x8")
AddMedia("texture", "White8x8.tga", "SBT White8x8")
AddMedia("texture", "Highlight.tga", "SBT Highlight")
AddMedia("texture", "Invisible.tga", "Invisible")

AddMedia('statusbar', 'Gradient.tga', 'SBT Gradient')
AddMedia('statusbar', 'StatusBar.blp', 'SBT Status Bar')
AddMedia('statusbar', 'GreyWhiteGradient.tga', 'SBT GreyWhite')
AddMedia('statusbar', 'GreyWhiteGradientReversed.tga', 'SBT GreyWhite Reversed')
AddMedia('statusbar', 'RegularWhite.tga', 'You Are Beautiful!')

AddMedia("font", "Expressway.ttf", "Expressway")

local function GetDefaultMediaName(Type)
    if Type == "statusbar" then
        return "You Are Beautiful!"
    elseif Type == "font" then
        return "Prototype"
    elseif Type == "texture" then
        return "SBT White8x8"
    end

    return nil
end

local function GetDefaultMediaPath(Type)
    if Type == "statusbar" then
        return "Interface\\AddOns\\StoneovenBayTools\\Media\\Textures\\YouAreBeautiful.tga"
    elseif Type == "font" then
        return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	elseif Type == "texture" then
		return "Interface\\AddOns\\StoneovenBayTools\\Media\\Textures\\White8x8.tga"
	end

    return nil
end

function SBT:GetSharedMedia(Type, Name)
    local lsm = SBT.LSM
    if not lsm then
        local libStub = _G.LibStub
        if libStub then
            lsm = libStub("LibSharedMedia-3.0", true)
            SBT.LSM = lsm
        end
    end

    local mediaName = Name or GetDefaultMediaName(Type)
    if lsm and mediaName then
        local fetched = lsm:Fetch(Type, mediaName)
        if fetched then
            return fetched
        end

        if not Name then
            local defaultName = GetDefaultMediaName(Type)
            if defaultName and defaultName ~= mediaName then
                fetched = lsm:Fetch(Type, defaultName)
                if fetched then
                    return fetched
                end
            end
        end
    end

    return GetDefaultMediaPath(Type)
end