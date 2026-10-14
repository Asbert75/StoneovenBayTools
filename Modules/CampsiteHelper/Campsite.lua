local _, SBT = ...

SBT.Campsite = SBT.Campsite or {}

local SBT_CAMPSITE_PREFIX = "SBTCAMPSITE"

local function GetProfessionData()
    local professions = {}

    local function AddProfession(name, rank)
        if name and rank then
            professions[name] = rank
        end
    end

    -- Primary professions
    local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()

    local professionIndexes = {
        prof1,
        prof2,
        fishing,
        cooking,
        firstAid,
    }

    for _, index in ipairs(professionIndexes) do
        if index then
            local name, _, rank = GetProfessionInfo(index)
            AddProfession(name, rank)
        end
    end

    return professions
end

local function SerializeProfessions(professions)
    local entries = {}

    for profession, rank in pairs(professions) do
        table.insert(entries, profession .. ":" .. rank)
    end

    return table.concat(entries, ",")
end

local function DeserializeProfessions(payload)
    local professions = {}

    for professionData in string.gmatch(payload, "[^,]+") do
        local profession, rank = strsplit(":", professionData)

        professions[profession] = tonumber(rank)
    end

    return professions
end

function SBT.Campsite:UpdateGroupRoster()
   if not IsInGroup() then
      SBT.Campsite.Party = {}
      return
   end

   local units = {
      {
         unitIdentifier = "player",
         name = UnitName("player"),
         class = UnitClass("player")
      }
   }

   for i = 1, GetNumGroupMembers() do
      local unit = "party" .. i
      if UnitExists(unit) then
         local unit = {
            unitIdentifier = "party" .. i,
            name = UnitName(unit),
            class = UnitClass(unit)
         }

         table.insert(units, unit)
      end
   end
   SBT.Campsite.Party = units

   C_ChatInfo.SendAddonMessage(SBT_CAMPSITE_PREFIX, "REQUEST_PROFS", "PARTY")
end

function SBT.Campsite:SendPlayerProfessionInformation()
   local professions = GetProfessionData()
   local payload = "PROFS|" .. SerializeProfessions(professions)

   C_ChatInfo.SendAddonMessage(SBT_CAMPSITE_PREFIX, payload, "PARTY")
end

function SBT.Campsite:UpdateGroupMemberProfession(sender, payload)
   local data = DeserializeProfessions(payload)
   if not data then return end

   for _, unit in ipairs(SBT.Campsite.Party) do
      if unit.name == sender then
         unit.professions = data
         break
      end
   end
end

function SBT.Campsite:DumpData()
   SBT.Campsite.Party = {
      { unitIdentifier = "player", name = "Zy Fire", class = UnitClass("player"), professions = GetProfessionData() },
      { unitIdentifier = "party1", name = "Willem Dafoe", class = "Hunter", professions = GetProfessionData() }
   }

   for _, unit in ipairs(SBT.Campsite.Party or {}) do
      print(string.format("%s, Class: %s", unit.name, unit.class))
      if unit.professions then
         for profession, rank in pairs(unit.professions) do
            print(string.format("  %s (%d/300)", profession, rank))
         end
      end
   end
end

function SBT.Campsite:Initialize()
   local frame = CreateFrame("Frame")
   frame:RegisterEvent("GROUP_ROSTER_UPDATE")
   frame:RegisterEvent("CHAT_MSG_ADDON")
   
   frame:SetScript("OnEvent", function(self, event, ...)
      if event == "GROUP_ROSTER_UPDATE" then
         SBT.Campsite:UpdateGroupRoster()
      end
   
      if event == "CHAT_MSG_ADDON" then
         local prefix, message, channel, sender = ...
   
         if prefix == SBT_CAMPSITE_PREFIX and sender ~= UnitName("player") then
            local messageType, payload = strsplit("|", message, 2)

            if messageType == "PROFS" then
               SBT.Campsite:UpdateGroupMemberProfession(sender, payload)
            elseif messageType == "REQUEST_PROFS" then
               SBT.Campsite:SendPlayerProfessionInformation()
            end
         end
      end
   end)

   if C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(SBT_CAMPSITE_PREFIX)
   end

   -- local mainWindow = CreateFrame("Frame", "CampsiteMainWindow", UIParent, "BackdropTemplate")
   -- mainWindow:SetSize(300, 200)
   -- mainWindow:SetPoint("CENTER")
   -- mainWindow:SetFrameStrata("HIGH")
   -- mainWindow:SetMovable(true)
   -- mainWindow:SetResizable(true)
   -- mainWindow:SetResizeBounds(500, 420, 1400, 900)
   -- mainWindow:EnableMouse(true)
   -- mainWindow:RegisterForDrag("LeftButton")

   -- mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
   -- mainWindow:SetScript("OnDragStop", function(self)
   --     self:StopMovingOrSizing()
   -- end)

   -- mainWindow:SetBackdrop({
   --      bgFile = SBT.Theme.dialogBackground,
   --      edgeFile = SBT.Theme.dialogBorder,
   --      tile = true,
   --      tileSize = 32,
   --      edgeSize = 32,
   --      insets = { left = 5, right = 6, top = 6, bottom = 5 },
   --  })
end