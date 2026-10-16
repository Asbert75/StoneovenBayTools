local _, SBT = ...

SBT.Campsite = SBT.Campsite or {}

local Campsite = SBT.Campsite

local players = {}

Campsite.players = players

local function GetPlayerKey(unit)
    local guid = UnitGUID(unit)

    if guid then
        return guid
    end

    return UnitName(unit)
end

local function GetClass(unit)
    local _, class = UnitClass(unit)

    return class
end

local function GetLocalProfessions()
    local professions = {}

    if not GetProfessions then
        return professions
    end

    local prof1, prof2, archaeology, fishing, cooking, firstAid =
        GetProfessions()
    
    local professionIndexes = {
        prof1,
        prof2,
        fishing,
        cooking,
        firstAid,
    }

    for _, index in ipairs(professionIndexes) do

        if index then

            local name, _, skillLevel =
                GetProfessionInfo(index)

            if name then

                local id = Campsite:GetProfessionID(name)

                if id then
                    professions[id] = skillLevel or 0
                end
            end
        end
    end

    return professions
end

function Campsite:CreatePlayer(unit)
    if not UnitExists(unit) then
        return nil
    end

    local guid = UnitGUID(unit)

    if not guid then
        return nil
    end

    local name, realm = UnitName(unit)

    local player = {
        guid = guid,

        unit = unit,

        name = name,
        realm = realm,

        class = GetClass(unit),
        level = UnitLevel(unit),

        professions = {},
        professionSource = nil,

        isLocalPlayer = unit == "player",
    }

    if player.isLocalPlayer then
        player.professions = GetLocalProfessions()
        player.professionSource = "LOCAL"
    end

    return player
end

function Campsite:ScanParty()
    wipe(players)

    -- Player
    local player = self:CreatePlayer("player")

    if player then
        players[player.guid] = player
    end


    -- Party members
    for i = 1, MAX_PARTY_MEMBERS do

        local unit = "party" .. i

        if UnitExists(unit) then

            local member = self:CreatePlayer(unit)

            if member then
                players[member.guid] = member
            end
        end
    end

    return players
end

function Campsite:GetProfessionID(name)
    if not name then
        return nil
    end

    name = name:lower()

    local aliases = {
        ["alchemy"] = "ALCHEMY",
        ["blacksmithing"] = "BLACKSMITHING",
        ["cooking"] = "COOKING",
        ["enchanting"] = "ENCHANTING",
        ["engineering"] = "ENGINEERING",
        ["first aid"] = "FIRST_AID",
        ["fishing"] = "FISHING",
        ["herbalism"] = "HERBALISM",
        ["leatherworking"] = "LEATHERWORKING",
        ["mining"] = "MINING",
        ["skinning"] = "SKINNING",
        ["tailoring"] = "TAILORING",
    }

    return aliases[name]
end

function Campsite:GetBestObject(profession, skill)
    local objects = Campsite.professions[profession]

    if not objects then
        return nil
    end

    local best

    for _, object in ipairs(objects) do

        if skill >= object.skill then

            if not best or object.skill > best.skill then
                best = object
            end
        end
    end

    return best
end
function Campsite:GetPlayerCapabilities(player)
    local result = {
        buffs = {},
        utilities = {},
        objects = {},
    }

    for profession, skill in pairs(player.professions or {}) do
        local object = self:GetBestObject(
            profession,
            skill
        )

        if object then
            local objectData = {
                profession = profession,
                skill = skill,
                object = object.object,

                buffs = object.buffs or {},
                utilities = object.utilities or {},
            }

            table.insert(result.objects, objectData)

            ------------------------------------------------
            -- COMBAT BUFFS
            ------------------------------------------------
            for _, buffID in ipairs(object.buffs or {}) do

                table.insert(result.buffs, {
                    id = buffID,

                    profession = profession,

                    skill = skill,

                    object = object.object,

                    player = player,
                })
            end

            ------------------------------------------------
            -- UTILITY
            ------------------------------------------------
            for _, utilityID in ipairs(object.utilities or {}) do

                table.insert(result.utilities, {
                    id = utilityID,

                    profession = profession,

                    skill = skill,

                    object = object.object,

                    player = player,
                })
            end
        end
    end

    return result
end

function Campsite:GetClassCoverage(player)
    local coverage = {}

    for _, classBuff in ipairs(self.DB.classBuffs) do
        if classBuff.class == player.class then
            if not classBuff.minimumLevel or player.level >= classBuff.minimumLevel then

                for _, buffID in ipairs(classBuff.replaces) do
                    coverage[buffID] = {
                        source = "CLASS",
                        player = player,
                        spell = classBuff.spell,
                    }
                end
            end
        end
    end

    return coverage
end

function Campsite:BuildPartyCapabilities()
    self:ScanParty()

    local result = {
        players = {},
        classBuffs = {},
        campsiteBuffs = {},
        utilities = {},
    }

    for _, player in pairs(self.players) do
        local capabilities = self:GetPlayerCapabilities(player)

        player.capabilities = capabilities
        result.players[player.guid] = player

        ----------------------------------------------------
        -- CLASS BUFFS
        ----------------------------------------------------
        local classCoverage = self:GetClassCoverage(player)

        for buffID, data in pairs(classCoverage) do
            if not result.classBuffs[buffID] then
                result.classBuffs[buffID] = data
            end
        end

        ----------------------------------------------------
        -- CAMPSITE BUFFS
        ----------------------------------------------------
        for _, buff in ipairs(capabilities.buffs) do
            result.campsiteBuffs[buff.id] = result.campsiteBuffs[buff.id] or {}

            table.insert(
                result.campsiteBuffs[buff.id],
                buff
            )
        end

        ----------------------------------------------------
        -- UTILITIES
        ----------------------------------------------------
        for _, utility in ipairs(capabilities.utilities) do
            result.utilities[utility.id] = result.utilities[utility.id] or {}

            table.insert(
                result.utilities[utility.id],
                utility
            )
        end
    end

    return result
end

function Campsite:GetBuffStatus(buffID, party)
    --------------------------------------------------------
    -- CLASS BUFF EXISTS
    --------------------------------------------------------
    if party.classBuffs[buffID] then
        return {
            state = "CLASS",
            provider = party.classBuffs[buffID].player,
            spell = party.classBuffs[buffID].spell,
        }
    end

    --------------------------------------------------------
    -- CAMPSITE PROVIDER EXISTS
    --------------------------------------------------------
    if party.campsiteBuffs[buffID] then
        return {
            state = "CAMPSITE",
            providers = party.campsiteBuffs[buffID],
        }
    end

    --------------------------------------------------------
    -- NOTHING
    --------------------------------------------------------
    return {
        state = "MISSING",
    }
end

function Campsite:BuildReport()
    local party = self:BuildPartyCapabilities()

    local report = {
        buffs = {},
        utilities = {},
        players = party.players,
    }

    --------------------------------------------------------
    -- COMBAT BUFFS
    --------------------------------------------------------
    for _, buff in ipairs(self.DB.buffs) do
        local status = self:GetBuffStatus(
            buff.id,
            party
        )

        local entry = {
            id = buff.id,
            name = buff.name,
            profession = buff.profession,
            object = buff.object,
            state = status.state,
        }

        if status.state == "CLASS" then
            entry.player =  status.provider
            entry.spell =  status.spell
        elseif status.state == "CAMPSITE" then
            entry.providers =  status.providers
        end

        table.insert(report.buffs, entry)
    end

    --------------------------------------------------------
    -- UTILITIES
    --------------------------------------------------------
    for _, utility in ipairs(self.DB.utilities) do
        local providers = party.utilities[utility.id]

        local entry = {
            id = utility.id,
            name = utility.name,
            profession = utility.profession,
            description = utility.description,
            providers = providers or {},
        }

        table.insert(
            report.utilities,
            entry
        )
    end

    return report
end