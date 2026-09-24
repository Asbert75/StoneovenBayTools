local _, SBT = ...

SBT.Theme = {
    frameBg = { 0.05, 0.06, 0.07, 0.97 },
    panelBg = { 0.09, 0.10, 0.11, 0.95 },
    border = { 0.20, 0.22, 0.24, 1 },
    textDisabled = { 0.50, 0.50, 0.50, 1 },
    text = { 0.88, 0.90, 0.83, 1 },
    accent = { 0.22, 0.70, 0.34, 1 },
    accentHover = { 0.29, 0.78, 0.40, 1 },
    accentActive = { 0.16, 0.57, 0.27, 1 },
    buttonBg = { 0.15, 0.16, 0.17, 1 },
    sliderTrack = { 0.12, 0.13, 0.14, 1 },
    tabActiveBg = { 0.19, 0.20, 0.21, 1 },
    tabInactiveBg = { 0.11, 0.12, 0.13, 1 },
}

local MEDIA = "Interface\\AddOns\\StoneovenBayTools\\Media\\Textures\\"

-- Classic dialog chrome (standard Blizzard paths, present in every client build).
SBT.Theme.dialogBackground = "Interface\\DialogFrame\\UI-DialogBox-Background"
SBT.Theme.dialogBorder = "Interface\\DialogFrame\\UI-DialogBox-Border"
SBT.Theme.dialogHeader = "Interface\\DialogFrame\\UI-DialogBox-Header"

-- Bundled classic art used for panels/tabs so the GUI reads as native WoW chrome.
SBT.Theme.panelBackgroundTexture = MEDIA .. "UI-Background-Marble"
SBT.Theme.tabActiveTexture = MEDIA .. "UI-OptionsFrame-ActiveTab"
SBT.Theme.tabInactiveTexture = MEDIA .. "UI-OptionsFrame-InActiveTab"
