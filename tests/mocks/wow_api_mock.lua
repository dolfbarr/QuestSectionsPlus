local Mock = {}

function Mock.Install()
    local state = {
        inCombat = false,
        inInstance = false,
        instanceType = "none",
        realZone = "The Veiled Sea",
        subZone = "",
        uiMapID = 1447,
        playerLevel = 34,
        playerClass = "Paladin",
        superTrackedQuestID = 0,
        cvarStore = {},
        removedWatches = {},
        chatMessages = {},
        entries = {},
        watchedQuestIDs = {},
        questTags = {},
        questComplete = {},
        questWaypoints = {},
        questOnMap = {},
        questObjectives = {},
        questTrivial = {},
        mapNames = {
            [1415] = "Eastern Kingdoms",
            [1431] = "Duskwood",
            [1434] = "Stranglethorn Vale",
            [1437] = "Wetlands",
            [1445] = "Dustwallow Marsh",
            [1447] = "The Veiled Sea",
            [1453] = "Stormwind City",
            [1455] = "Ironforge",
            [2001] = "City of Dalaran",
            [2002] = "Gnomeregan",
        },
    }

    _G.Enum = {
        QuestTag = {
            Group = 1,
            PvP = 41,
            Raid = 62,
            Dungeon = 81,
            Legendary = 83,
            Heroic = 85,
            Raid10 = 88,
            Raid25 = 89,
            Scenario = 98,
        },
        QuestClassification = {
            Normal = 0,
            Campaign = 1,
        },
        RelativeContentDifficulty = {
            Trivial = 0,
            Easy = 1,
            Fair = 2,
            Difficult = 3,
            Impossible = 4,
        },
    }

    _G.LFG_TYPE_DUNGEON = "Dungeon"
    _G.TRACKER_HEADER_QUESTS = "Quests"
    _G.QuestSectionsPlusDB = nil
    _G.QuestSectionsPlusCharDB = nil
    _G.ForeverQuestPins = nil
    _G.Questie = nil
    _G.QuestieLoader = nil
    _G.TomTom = nil

    _G.CreateFromMixins = function(...)
        local out = {}
        for i = 1, select("#", ...) do
            local src = select(i, ...)
            if type(src) == "table" then
                for k, v in pairs(src) do
                    out[k] = v
                end
            end
        end
        return out
    end

    _G.Mixin = function(obj, ...)
        for i = 1, select("#", ...) do
            local src = select(i, ...)
            if type(src) == "table" then
                for k, v in pairs(src) do
                    obj[k] = v
                end
            end
        end
        return obj
    end

    _G.InCombatLockdown = function()
        return state.inCombat
    end

    _G.IsInInstance = function()
        return state.inInstance, state.instanceType
    end

    _G.GetRealZoneText = function()
        return state.realZone
    end

    _G.GetSubZoneText = function()
        return state.subZone
    end

    _G.UnitLevel = function()
        return state.playerLevel
    end

    _G.UnitClass = function()
        return state.playerClass, string.upper(state.playerClass)
    end

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, msg)
            state.chatMessages[#state.chatMessages + 1] = msg
        end,
    }

    _G.C_Map = {
        GetBestMapForUnit = function()
            return state.uiMapID
        end,
        GetMapInfo = function(mapID)
            local name = state.mapNames[mapID]
            if name then
                return { mapID = mapID, name = name }
            end
            return nil
        end,
    }

    _G.C_PlayerInfo = {
        GetContentDifficultyQuestForPlayer = function(questID)
            if state.questTrivial[questID] then
                return _G.Enum.RelativeContentDifficulty.Trivial
            end
            return _G.Enum.RelativeContentDifficulty.Fair
        end,
    }

    _G.C_CreatureInfo = {
        GetClassInfo = function(classID)
            local classes = {
                [1] = "Warrior",
                [2] = "Paladin",
                [3] = "Hunter",
                [4] = "Rogue",
                [5] = "Priest",
                [7] = "Shaman",
                [8] = "Mage",
                [9] = "Warlock",
                [11] = "Druid",
            }
            if classes[classID] then
                return { className = classes[classID] }
            end
            return nil
        end,
    }

    _G.C_CVar = {
        RegisterCVar = function(name, defaultVal)
            if state.cvarStore[name] == nil then
                state.cvarStore[name] = defaultVal or ""
            end
        end,
        GetCVar = function(name)
            return state.cvarStore[name] or ""
        end,
        SetCVar = function(name, val)
            state.cvarStore[name] = tostring(val)
        end,
    }

    _G.C_SuperTrack = {
        GetSuperTrackedQuestID = function()
            return state.superTrackedQuestID
        end,
        SetSuperTrackedQuestID = function(questID)
            state.superTrackedQuestID = questID or 0
        end,
    }

    _G.C_QuestLog = {
        GetNumQuestLogEntries = function()
            return #state.entries, #state.watchedQuestIDs
        end,
        GetInfo = function(index)
            return state.entries[index]
        end,
        GetNumQuestWatches = function()
            return #state.watchedQuestIDs
        end,
        GetQuestIDForQuestWatchIndex = function(watchIdx)
            return state.watchedQuestIDs[watchIdx]
        end,
        GetLogIndexForQuestID = function(questID)
            for idx, entry in ipairs(state.entries) do
                if not entry.isHeader and entry.questID == questID then
                    return idx
                end
            end
            return nil
        end,
        GetHeaderIndexForQuest = function(questID)
            local lastHeaderIdx = nil
            for idx, entry in ipairs(state.entries) do
                if entry.isHeader then
                    lastHeaderIdx = idx
                elseif entry.questID == questID then
                    return lastHeaderIdx
                end
            end
            return nil
        end,
        GetTitleForQuestID = function(questID)
            for _, entry in ipairs(state.entries) do
                if not entry.isHeader and entry.questID == questID then
                    return entry.title
                end
            end
            return nil
        end,
        GetQuestTagInfo = function(questID)
            return state.questTags[questID]
        end,
        IsComplete = function(questID)
            return state.questComplete[questID] == true
        end,
        ReadyForTurnIn = function(questID)
            return state.questComplete[questID] == true
        end,
        IsFailed = function()
            return false
        end,
        IsEliteQuest = function(questID)
            local tag = state.questTags[questID]
            return tag and tag.isElite == true or false
        end,
        IsOnMap = function(questID)
            return state.questOnMap[questID] == true, state.questOnMap[questID] == true
        end,
        GetNextWaypoint = function(questID)
            local wp = state.questWaypoints[questID]
            if wp then
                return wp.mapID, wp.x or 0.5, wp.y or 0.5
            end
            return nil
        end,
        GetQuestObjectives = function(questID)
            return state.questObjectives[questID] or {}
        end,
        RemoveQuestWatch = function(questID)
            state.removedWatches[#state.removedWatches + 1] = questID
            return true
        end,
    }

    -- Populate screenshot fixture quests when requested
    function state:LoadScreenshotFixtures()
        self.entries = {}
        self.watchedQuestIDs = {}

        local function addHeader(title)
            self.entries[#self.entries + 1] = {
                title = title,
                questLogIndex = #self.entries + 1,
                questID = 0,
                level = 0,
                difficultyLevel = 0,
                suggestedGroup = 0,
                isHeader = true,
                isCollapsed = false,
                isTask = false,
                isBounty = false,
                isHidden = false,
                questClassification = 0,
            }
        end

        local function addQuest(spec)
            local idx = #self.entries + 1
            self.entries[idx] = {
                title = spec.title,
                questLogIndex = idx,
                questID = spec.id,
                level = spec.level,
                difficultyLevel = spec.level,
                suggestedGroup = spec.group or 0,
                isHeader = false,
                isCollapsed = false,
                isTask = false,
                isBounty = false,
                isHidden = false,
                isOnMap = spec.onMap or false,
                questClassification = 0,
            }
            self.watchedQuestIDs[#self.watchedQuestIDs + 1] = spec.id
            if spec.complete then
                self.questComplete[spec.id] = true
            end
            if spec.trivial then
                self.questTrivial[spec.id] = true
            end
            if spec.tagID or spec.isElite or spec.tradeskillLineID then
                self.questTags[spec.id] = {
                    tagID = spec.tagID or 0,
                    tagName = spec.tagName or "",
                    isElite = spec.isElite or false,
                    tradeskillLineID = spec.tradeskillLineID,
                }
            end
            if spec.waypointMapID then
                self.questWaypoints[spec.id] = { mapID = spec.waypointMapID, x = 0.5, y = 0.5 }
            end
            if spec.objectives then
                local objs = {}
                for _, text in ipairs(spec.objectives) do
                    objs[#objs + 1] = { text = text, finished = false }
                end
                self.questObjectives[spec.id] = objs
            end
        end

        addHeader("Wetlands")
        addQuest({
            id = 1001, level = 34, title = "Word to Ironforge",
            complete = true, waypointMapID = 1455,
            objectives = { "Deliver Howin's Missive to King Magni Bronzebeard in Ironforge." },
        })
        addQuest({
            id = 1011, level = 35, title = "James Hyal",
            complete = true, waypointMapID = 1445,
            objectives = { "Speak with Clerk Lendry in Theramore." },
        })

        addHeader("Excavation Site: Wetlands")
        addQuest({
            id = 1002, level = 31, title = "Prehistoric Prism",
            complete = true, tagID = 81, tagName = "Dungeon", waypointMapID = 1455,
            objectives = { "Bring the Titan Relic to High Explorer Magellas in Ironforge's Hall of Explorers." },
        })

        addHeader("Duskwood")
        addQuest({
            id = 1003, level = 25, title = "Look to the Stars",
            trivial = true,
            objectives = { "0/1 Bronze Tube" },
        })

        addHeader("Stranglethorn Vale")
        addQuest({
            id = 1004, level = 37, title = "Favor for Krazek",
            objectives = { "0/4 Lesser Bloodstone Ore" },
        })
        addQuest({
            id = 1005, level = 36, title = "Hostile Takeover",
            objectives = { "0/8 Tumbled Crystal" },
        })
        addQuest({
            id = 1006, level = 40, title = "Colonel Kurzen",
            tagID = 1, tagName = "Elite", isElite = true,
            objectives = { "0/6 Kurzen Elite slain", "0/4 Kurzen Subchief slain", "0/1 Kurzen's Head" },
        })
        addQuest({
            id = 1007, level = 34, title = "Raptor Mastery",
            objectives = { "0/10 Stranglethorn Raptor slain" },
        })
        addQuest({
            id = 1009, level = 32, title = "Investigate the Camp",
            complete = true,
        })
        addQuest({
            id = 1010, level = 41, title = "Scaring Shaky",
            objectives = { "0/5 Mistvale Giblets" },
        })
        addQuest({
            id = 1012, level = 38, title = "Kurzen's Mystery",
            objectives = { "0/1 The First Troll Legend", "0/1 The Second Troll Legend" },
        })
        addQuest({
            id = 1013, level = 37, title = "The Stone of the Tides",
            objectives = { "Locate the haunted island" },
        })

        addHeader("City of Dalaran")
        addQuest({
            id = 1008, level = 33, title = "Power Overwhelming",
            tagID = 81, tagName = "Dungeon",
            objectives = { "0/1 Arcanic Enigma slain" },
        })
        addQuest({
            id = 1014, level = 33, title = "A Green Sample",
            tagID = 81, tagName = "Dungeon",
            objectives = { "0/1 Fel Infused Blossom" },
        })

        addHeader("Gnomeregan")
        addQuest({
            id = 1015, level = 30, title = "Gyrodrillmatic Excavationators",
            tagID = 81, tagName = "Dungeon",
            objectives = { "0/24 Robo-mechanical Guts" },
        })

        addHeader("Paladin")
        addQuest({
            id = 1016, level = 30, title = "The Tome of Divinity",
            objectives = { "Speak with Duthorian Rall." },
        })

        addHeader("Cooking")
        addQuest({
            id = 1017, level = 35, title = "Soothing Turtle Bisque",
            tradeskillLineID = 185,
            objectives = { "0/10 Turtle Meat" },
        })
    end

    return state
end

return Mock
