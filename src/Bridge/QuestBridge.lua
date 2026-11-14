local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local QuestBridge = {}
ns.QuestBridge = QuestBridge

function QuestBridge.GetExternalQuestMeta(questID)
    local meta = {
        isInstance = false,
        tagID = nil,
        zoneNames = {},
        mapIDs = {},
    }
    if not questID or questID <= 0 then
        return meta
    end

    -- 1. ForeverQuestPins integration
    local fqp = _G and _G.ForeverQuestPins
    if type(fqp) == "table" then
        if type(fqp.QuestTagCorrections) == "table" and fqp.QuestTagCorrections[questID] then
            meta.tagID = fqp.QuestTagCorrections[questID]
        end
        if type(fqp.IsInstanceQuest) == "function" then
            local ok, isInst = pcall(fqp.IsInstanceQuest, questID)
            if ok and isInst then
                meta.isInstance = true
            end
        end
        if type(fqp.Quests) == "table" then
            local qData = fqp.Quests[questID]
            if type(qData) == "table" then
                if qData.isInstanceQuest then
                    meta.isInstance = true
                end
                if type(qData.mapID) == "number" then
                    meta.mapIDs[qData.mapID] = true
                    local zName = Compat.GetMapName(qData.mapID)
                    if zName and zName ~= "" then
                        meta.zoneNames[zName] = true
                    end
                end
                if type(qData.coords) == "table" then
                    for _, coord in ipairs(qData.coords) do
                        local mID = type(coord) == "table" and coord[3] or nil
                        if type(mID) == "number" then
                            meta.mapIDs[mID] = true
                            local zName = Compat.GetMapName(mID)
                            if zName and zName ~= "" then
                                meta.zoneNames[zName] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Optional Questie integration
    local qLoader = _G and _G.QuestieLoader
    if type(qLoader) == "table" and type(qLoader.ImportModule) == "function" then
        local okDB, questieDB = pcall(qLoader.ImportModule, qLoader, "QuestieDB")
        local okZone, zoneDB = pcall(qLoader.ImportModule, qLoader, "ZoneDB")
        if okDB and type(questieDB) == "table" and type(questieDB.GetQuest) == "function" then
            local okQ, qObj = pcall(questieDB.GetQuest, questID)
            if okQ and type(qObj) == "table" and type(qObj.zoneOrSort) == "number" and qObj.zoneOrSort > 0 then
                if okZone and type(zoneDB) == "table" and type(zoneDB.GetUiMapIdByAreaId) == "function" then
                    local okMap, uiMapId = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, qObj.zoneOrSort)
                    if okMap and type(uiMapId) == "number" then
                        meta.mapIDs[uiMapId] = true
                        local zName = Compat.GetMapName(uiMapId)
                        if zName and zName ~= "" then
                            meta.zoneNames[zName] = true
                        end
                    end
                end
            end
        end
    end

    return meta
end

function QuestBridge.TriggerWaypoint(questID, questTitle)
    if not questID or questID <= 0 then
        return false, "invalid_quest"
    end

    -- 1. ForeverQuestPins native waypoint router (handles Blizzard SuperTrack or TomTom)
    local fqp = _G and _G.ForeverQuestPins
    if type(fqp) == "table" and type(fqp.TrackQuest) == "function" then
        local ok, tracked = pcall(fqp.TrackQuest, questID)
        if ok and tracked then
            return true, "ForeverQuestPins"
        end
    end

    -- 2. Direct TomTom fallback via C_QuestLog.GetNextWaypoint
    local tomtom = _G and _G.TomTom
    if type(tomtom) == "table" and type(tomtom.AddWaypoint) == "function"
        and C_QuestLog and C_QuestLog.GetNextWaypoint then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if mapID and x and y then
            local resolvedTitle = questTitle
                or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID))
                or "Quest"
            pcall(tomtom.AddWaypoint, tomtom, mapID, x, y, {
                title = resolvedTitle,
                from = "QuestSectionsPlus",
                persistent = false,
                minimap = true,
                world = true,
                crazy = true,
            })
            return true, "TomTom"
        end
    end

    -- 3. Blizzard native SuperTracking fallback
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        local current = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
        if current == questID then
            C_SuperTrack.SetSuperTrackedQuestID(0)
        else
            C_SuperTrack.SetSuperTrackedQuestID(questID)
        end
        return true, "BlizzardSuperTrack"
    end

    return false, "unavailable"
end

function QuestBridge.GetDiagnostics()
    local fqp = _G and _G.ForeverQuestPins
    local questie = _G and _G.Questie
    local tomtom = _G and _G.TomTom
    local conflicts = {}

    if _G and (_G.QuestSections or _G.QuestSectionsDB) then
        conflicts[#conflicts + 1] = "QuestSections Forever is enabled and also modifies ObjectiveTrackerFrame."
    end
    if _G and (_G.KalielsTracker or _G["!KalielsTrackerFrame"]) then
        conflicts[#conflicts + 1] = "Kaliel's Tracker is enabled and conflicts with ObjectiveTrackerFrame modules."
    end
    if type(questie) == "table" and questie.db and questie.db.profile and questie.db.profile.trackerEnabled then
        conflicts[#conflicts + 1] = "Questie Tracker module is enabled; disable Tracker in /questie to avoid overlap."
    end

    return {
        hasForeverQuestPins = type(fqp) == "table",
        hasQuestie = type(questie) == "table",
        hasTomTom = type(tomtom) == "table",
        conflicts = conflicts,
    }
end

return QuestBridge
