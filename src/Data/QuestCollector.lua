local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local QuestBridge = ns.QuestBridge

local QuestCollector = {}
ns.QuestCollector = QuestCollector

local cachedClassSet = nil

local function GetClassSet()
    if not cachedClassSet then
        cachedClassSet = Compat.BuildClassNameSet()
    end
    return cachedClassSet
end

local function BuildHeaderScanTable()
    local byQuestID = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return byQuestID
    end
    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    local currentHeader = ""
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                currentHeader = info.title or ""
            elseif info.questID and info.questID > 0 then
                byQuestID[info.questID] = {
                    info = info,
                    headerTitle = currentHeader,
                }
            end
        end
    end
    return byQuestID
end

local function ResolveQuestInfoAndHeader(questID, scanTable)
    local scanned = scanTable[questID]
    local info = scanned and scanned.info or nil
    local headerTitle = scanned and scanned.headerTitle or ""

    if not info and C_QuestLog.GetLogIndexForQuestID then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex and C_QuestLog.GetInfo then
            info = C_QuestLog.GetInfo(logIndex)
        end
    end

    if headerTitle == "" and C_QuestLog.GetHeaderIndexForQuest then
        local headerIndex = C_QuestLog.GetHeaderIndexForQuest(questID)
        if headerIndex and C_QuestLog.GetInfo then
            local headerInfo = C_QuestLog.GetInfo(headerIndex)
            if headerInfo and headerInfo.title then
                headerTitle = headerInfo.title
            end
        end
    end

    return info, headerTitle
end

local function ShouldDisplayWatchedQuest(questID, info)
    if not info then
        return false
    end
    if info.isHeader or info.isHidden or info.isTask then
        return false
    end
    if info.isBounty then
        local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
        if not complete then
            return false
        end
    end
    local campaignEnum = Enum and Enum.QuestClassification and Enum.QuestClassification.Campaign
    if campaignEnum ~= nil and info.questClassification == campaignEnum then
        return false
    end
    if C_QuestLog.IsQuestDisabledForSession and C_QuestLog.IsQuestDisabledForSession(questID) then
        return false
    end
    return true
end

function QuestCollector.CollectWatchedQuests(context)
    local results = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then
        return results
    end

    local classNames = GetClassSet()
    local scanTable = BuildHeaderScanTable()
    local numWatches = C_QuestLog.GetNumQuestWatches() or 0

    for watchIndex = 1, numWatches do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
        if questID and questID > 0 then
            local info, headerTitle = ResolveQuestInfoAndHeader(questID, scanTable)
            if ShouldDisplayWatchedQuest(questID, info) then
                local tagInfo = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID) or nil
                local bridgeMeta = QuestBridge.GetExternalQuestMeta(questID)
                local effectiveTagID = (tagInfo and tagInfo.tagID) or bridgeMeta.tagID

                local isRaid = (effectiveTagID and Compat.RAID_TAGS[effectiveTagID]) or false
                local isDungeon = (not isRaid) and (
                    (effectiveTagID and Compat.DUNGEON_TAGS[effectiveTagID])
                    or bridgeMeta.isInstance
                ) or false

                local isProfession = (tagInfo and tagInfo.tradeskillLineID ~= nil)
                    or Compat.KNOWN_PROFESSIONS[headerTitle]
                    or false
                local isClass = (not isProfession) and (classNames[headerTitle] == true) or false

                local isComplete = false
                if C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
                    isComplete = true
                elseif C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then
                    isComplete = true
                end

                local isOnCurrentMap = info.isOnMap and true or false
                if not isOnCurrentMap and C_QuestLog.IsOnMap then
                    local onMap, hasLocalPOI = C_QuestLog.IsOnMap(questID)
                    isOnCurrentMap = (onMap or hasLocalPOI) and true or false
                end

                local waypointMapID = nil
                local waypointZoneName = ""
                if C_QuestLog.GetNextWaypoint then
                    local wpMap = C_QuestLog.GetNextWaypoint(questID)
                    if type(wpMap) == "number" then
                        waypointMapID = wpMap
                        waypointZoneName = Compat.GetMapName(wpMap) or ""
                    end
                end

                local objectiveTexts = {}
                if C_QuestLog.GetQuestObjectives then
                    local objs = C_QuestLog.GetQuestObjectives(questID)
                    if type(objs) == "table" then
                        for _, obj in ipairs(objs) do
                            if type(obj) == "table" and type(obj.text) == "string" and obj.text ~= "" then
                                objectiveTexts[#objectiveTexts + 1] = obj.text
                            end
                        end
                    end
                end

                local level = (info.difficultyLevel and info.difficultyLevel > 0)
                    and info.difficultyLevel or info.level or 1
                local isTrivial = Compat.IsQuestTrivial(questID, level)

                if context and context.uiMapID and bridgeMeta.mapIDs[context.uiMapID] then
                    isOnCurrentMap = true
                end

                results[#results + 1] = {
                    questID = questID,
                    watchIndex = watchIndex,
                    questLogIndex = info.questLogIndex,
                    title = info.title or "",
                    headerTitle = headerTitle ~= "" and headerTitle or "Quests",
                    level = info.level or level,
                    difficultyLevel = level,
                    isComplete = isComplete,
                    isDungeon = isDungeon,
                    isRaid = isRaid,
                    isClass = isClass,
                    isProfession = isProfession,
                    isElite = (C_QuestLog.IsEliteQuest and C_QuestLog.IsEliteQuest(questID))
                        or (tagInfo and tagInfo.isElite) or false,
                    isTrivial = isTrivial,
                    isOnCurrentMap = isOnCurrentMap,
                    waypointMapID = waypointMapID,
                    waypointZoneName = waypointZoneName,
                    bridgeZones = bridgeMeta.zoneNames,
                    bridgeMapIDs = bridgeMeta.mapIDs,
                    objectiveTexts = objectiveTexts,
                }
            end
        end
    end

    return results
end

return QuestCollector
