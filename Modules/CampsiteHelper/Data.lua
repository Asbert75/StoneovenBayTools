local _, SBT = ...

SBT.Campsite = SBT.Campsite or {}

SBT.Campsite.Buffs = {
    ALL_ATTRIBUTES = {
        name = "Blessing of Kings",
        profession = "Fishing",
        object = "Fish Bowl",
        bonus = "+8% All Attributes",
        classBuff = "Blessing of Kings",
        class = "Paladin",
    },

    CRITICAL_STRIKE = {
        name = "Moonkin Aura",
        profession = "Skinning",
        object = "Camp Chair",
        bonus = "+2% Critical Strike",
        classBuff = "Moonkin Aura",
        class = "Druid",
    },

    STAMINA = {
        name = "Power Word: Fortitude",
        profession = "First Aid",
        object = "First Aid Kit",
        classBuff = "Power Word: Fortitude",
        class = "Priest",
    },

    STRENGTH = {
        name = "Strength of Earth Totem",
        profession = "Blacksmithing",
        object = "Sharpening Wheel",
        classBuff = "Strength of Earth Totem",
        class = "Shaman",
    },

    INTELLECT = {
        name = "Arcane Intellect",
        profession = "Herbalism",
        object = "Incense Candle",
        classBuff = "Arcane Intellect",
        class = "Mage",
    },

    MELEE_ATTACK_POWER = {
        name = "Blessing of Might",
        profession = "Mining",
        object = "Lodestone",
        classBuff = "Blessing of Might",
        class = "Paladin",
    },

    MANA_REGEN = {
        name = "Blessing of Wisdom",
        profession = "Alchemy",
        object = "Mana Well",
        classBuff = "Blessing of Wisdom",
        class = "Paladin",
    },

    SPIRIT = {
        name = "Divine Spirit",
        profession = "Tailoring",
        object = "Faction Banner",
        classBuff = "Divine Spirit",
        class = "Priest",
    },

    ARMOR_STATS_RESIST = {
        name = "Mark of the Wild",
        profession = "Enchanting",
        object = "Enchanted Lute",
        classBuff = "Mark of the Wild",
        class = "Druid",
    },
}