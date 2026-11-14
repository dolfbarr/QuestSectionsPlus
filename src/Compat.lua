local _, ns = ...
ns = ns or {}

local Compat = {}
ns.Compat = Compat

Compat.QUEST_TAG = {
    GROUP = (Enum and Enum.QuestTag and Enum.QuestTag.Group) or 1,
    PVP = (Enum and Enum.QuestTag and Enum.QuestTag.PvP) or 41,
    RAID = (Enum and Enum.QuestTag and Enum.QuestTag.Raid) or 62,
    DUNGEON = (Enum and Enum.QuestTag and Enum.QuestTag.Dungeon) or 81,
    LEGENDARY = (Enum and Enum.QuestTag and Enum.QuestTag.Legendary) or 83,
    HEROIC = (Enum and Enum.QuestTag and Enum.QuestTag.Heroic) or 85,
    RAID10 = (Enum and Enum.QuestTag and Enum.QuestTag.Raid10) or 88,
    RAID25 = (Enum and Enum.QuestTag and Enum.QuestTag.Raid25) or 89,
    SCENARIO = (Enum and Enum.QuestTag and Enum.QuestTag.Scenario) or 98,
}

Compat.DUNGEON_TAGS = {
    [Compat.QUEST_TAG.DUNGEON] = true,
    [Compat.QUEST_TAG.HEROIC] = true,
    [Compat.QUEST_TAG.SCENARIO] = true,
}

Compat.RAID_TAGS = {
    [Compat.QUEST_TAG.RAID] = true,
    [Compat.QUEST_TAG.RAID10] = true,
    [Compat.QUEST_TAG.RAID25] = true,
}

Compat.KNOWN_PROFESSIONS = {
    ["Alchemy"] = true,
    ["Blacksmithing"] = true,
    ["Cooking"] = true,
    ["Enchanting"] = true,
    ["Engineering"] = true,
    ["First Aid"] = true,
    ["Fishing"] = true,
    ["Herbalism"] = true,
    ["Inscription"] = true,
    ["Jewelcrafting"] = true,
    ["Leatherworking"] = true,
    ["Mining"] = true,
    ["Skinning"] = true,
    ["Tailoring"] = true,
}

function Compat.InCombat()
    if InCombatLockdown then
        return InCombatLockdown() and true or false
    end
    return false
end

function Compat.GetPlayerContext()
    local inInstance, instanceType = false, "none"
    if IsInInstance then
        local isInst, instType = IsInInstance()
        inInstance = isInst and true or false
        instanceType = instType or "none"
    end

    local zoneName = (GetRealZoneText and GetRealZoneText()) or ""
    local subZoneName = (GetSubZoneText and GetSubZoneText()) or ""
    local uiMapID = nil
    local mapZoneName = ""

    if C_Map and C_Map.GetBestMapForUnit then
        uiMapID = C_Map.GetBestMapForUnit("player")
        if uiMapID and C_Map.GetMapInfo then
            local mapInfo = C_Map.GetMapInfo(uiMapID)
            if mapInfo and mapInfo.name then
                mapZoneName = mapInfo.name
            end
        end
    end

    local effectiveZone = zoneName ~= "" and zoneName or mapZoneName
    local isDungeonInstance = inInstance and (
        instanceType == "party" or instanceType == "raid" or instanceType == "scenario"
    )

    return {
        inInstance = isDungeonInstance,
        instanceType = instanceType,
        instanceName = isDungeonInstance and effectiveZone or "",
        zoneName = effectiveZone,
        subZoneName = subZoneName,
        mapZoneName = mapZoneName,
        uiMapID = uiMapID,
        playerLevel = (UnitLevel and UnitLevel("player")) or 60,
    }
end

function Compat.GetMapName(uiMapID)
    if not uiMapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local info = C_Map.GetMapInfo(uiMapID)
    return info and info.name or nil
end

function Compat.IsQuestTrivial(questID, difficultyLevel)
    if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer and questID then
        local rel = C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
        local trivialEnum = Enum and Enum.RelativeContentDifficulty and Enum.RelativeContentDifficulty.Trivial
        if trivialEnum ~= nil and rel ~= nil then
            return rel == trivialEnum
        end
    end

    if GetQuestDifficultyColor and difficultyLevel and difficultyLevel > 0 then
        local color = GetQuestDifficultyColor(difficultyLevel)
        if color then
            local trivialRef = QuestDifficultyColors and QuestDifficultyColors["trivial"]
            if trivialRef and color == trivialRef then
                return true
            end
            if color.r and color.g and color.b then
                return color.r <= 0.55 and color.g <= 0.55 and color.b <= 0.55
            end
        end
    end

    return false
end

function Compat.BuildClassNameSet()
    local classes = {
        ["Druid"] = true,
        ["Hunter"] = true,
        ["Mage"] = true,
        ["Paladin"] = true,
        ["Priest"] = true,
        ["Rogue"] = true,
        ["Shaman"] = true,
        ["Warlock"] = true,
        ["Warrior"] = true,
    }
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        for classID = 1, 13 do
            local info = C_CreatureInfo.GetClassInfo(classID)
            if info and info.className and info.className ~= "" then
                classes[info.className] = true
            end
        end
    end
    if UnitClass then
        local localizedClass = UnitClass("player")
        if localizedClass and localizedClass ~= "" then
            classes[localizedClass] = true
        end
    end
    return classes
end

function Compat.Print(msg)
    local prefix = "|cffffd100QuestSectionsPlus:|r "
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    end
end

return Compat
