local _, ns = ...
ns = ns or {}

local Classifier = {}
ns.Classifier = Classifier

local SECTION_RANK = {
    READY = 1,
    ACTIVE_DUNGEON = 2,
    DUNGEON = 3,
    RAID = 3,
    CLASS = 4,
    PROFESSION = 4,
    CURRENT_ZONE = 5,
    ZONE = 6,
}

-- ASCII-only uppercase folding preserves multi-byte UTF-8 continuation and lead bytes (>= 0x80).
function Classifier.AsciiLower(str)
    if type(str) ~= "string" or str == "" then
        return ""
    end
    return (string.gsub(str, "[A-Z]", function(ch)
        return string.char(string.byte(ch) + 32)
    end))
end

function Classifier.EscapeLuaPattern(str)
    if type(str) ~= "string" or str == "" then
        return ""
    end
    return (string.gsub(str, "([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"))
end

function Classifier.Trim(str)
    if type(str) ~= "string" then
        return ""
    end
    return (string.match(str, "^%s*(.-)%s*$")) or ""
end

function Classifier.StripDungeonSuffix(title, localizedDungeonWord)
    if type(title) ~= "string" or title == "" then
        return ""
    end
    local cleaned = string.gsub(title, "%s*%(Dungeon%)%s*$", "")
    if type(localizedDungeonWord) == "string" and localizedDungeonWord ~= "" and localizedDungeonWord ~= "Dungeon" then
        local pat = "%s*%(" .. Classifier.EscapeLuaPattern(localizedDungeonWord) .. "%)%s*$"
        cleaned = string.gsub(cleaned, pat, "")
    end
    return cleaned
end

function Classifier.MatchesSearch(quest, rawQuery)
    local trimmed = Classifier.Trim(rawQuery)
    if trimmed == "" then
        return true
    end
    local needle = Classifier.AsciiLower(trimmed)

    if string.find(Classifier.AsciiLower(quest.title), needle, 1, true) then
        return true
    end
    if string.find(Classifier.AsciiLower(quest.headerTitle), needle, 1, true) then
        return true
    end
    if quest.waypointZoneName and string.find(Classifier.AsciiLower(quest.waypointZoneName), needle, 1, true) then
        return true
    end
    local levelToken = "[" .. tostring(quest.level or "") .. "]"
    if string.find(levelToken, needle, 1, true) then
        return true
    end
    if type(quest.objectiveTexts) == "table" then
        for _, objText in ipairs(quest.objectiveTexts) do
            if string.find(Classifier.AsciiLower(objText), needle, 1, true) then
                return true
            end
        end
    end
    return false
end

function Classifier.QuestMatchesZone(quest, context)
    if not context then
        return true
    end
    if quest.isOnCurrentMap then
        return true
    end

    local candidates = {}
    if context.zoneName and context.zoneName ~= "" then
        candidates[Classifier.AsciiLower(context.zoneName)] = true
    end
    if context.subZoneName and context.subZoneName ~= "" then
        candidates[Classifier.AsciiLower(context.subZoneName)] = true
    end
    if context.mapZoneName and context.mapZoneName ~= "" then
        candidates[Classifier.AsciiLower(context.mapZoneName)] = true
    end

    if next(candidates) == nil then
        return false
    end

    if quest.headerTitle and candidates[Classifier.AsciiLower(quest.headerTitle)] then
        return true
    end
    if quest.waypointZoneName and quest.waypointZoneName ~= ""
        and candidates[Classifier.AsciiLower(quest.waypointZoneName)] then
        return true
    end
    if context.uiMapID and quest.waypointMapID == context.uiMapID then
        return true
    end
    if type(quest.bridgeZones) == "table" then
        for zName in pairs(quest.bridgeZones) do
            if candidates[Classifier.AsciiLower(zName)] then
                return true
            end
        end
    end
    return false
end

function Classifier.MatchesFilter(quest, context, charState)
    local mode = (charState and charState.filterMode) or "ALL"
    local hideGray = charState and charState.hideGray or false
    local searchQuery = (charState and charState.searchQuery) or ""

    if hideGray and quest.isTrivial then
        return false
    end

    if not Classifier.MatchesSearch(quest, searchQuery) then
        return false
    end

    if mode == "ALL" then
        return true
    elseif mode == "READY" then
        return quest.isComplete == true
    elseif mode == "DUNGEON" then
        if context and context.inInstance and context.instanceName ~= "" then
            return (quest.isDungeon or quest.isRaid)
                and (
                    Classifier.AsciiLower(quest.headerTitle) == Classifier.AsciiLower(context.instanceName)
                    or quest.isOnCurrentMap
                )
        end
        return (quest.isDungeon or quest.isRaid) == true
    elseif mode == "ZONE" then
        if context and context.inInstance then
            return (quest.isDungeon or quest.isRaid) and Classifier.QuestMatchesZone(quest, context)
                or Classifier.QuestMatchesZone(quest, context)
        end
        return Classifier.QuestMatchesZone(quest, context)
    end

    return true
end

function Classifier.AssignBucket(quest, accountOpts)
    local hoistReady = accountOpts == nil or accountOpts.hoistReadyForTurnIn ~= false
    local splitDungeons = accountOpts == nil or accountOpts.splitDungeonsByInstance ~= false
    local stripDungeon = accountOpts == nil or accountOpts.stripDungeonTag ~= false

    local header = (quest.headerTitle and quest.headerTitle ~= "") and quest.headerTitle or "Quests"

    if hoistReady and quest.isComplete then
        return {
            key = "READY",
            kind = "READY",
            title = "Ready for Turn-In",
            rawZone = "",
            stripDungeonTag = false,
        }
    end

    if quest.isRaid then
        if splitDungeons and header ~= "Quests" then
            return {
                key = "RAID:" .. header,
                kind = "RAID",
                title = "Raid: " .. header,
                rawZone = header,
                stripDungeonTag = false,
            }
        end
        return {
            key = "RAIDS",
            kind = "RAID",
            title = "Raids",
            rawZone = "",
            stripDungeonTag = false,
        }
    end

    if quest.isDungeon then
        if splitDungeons and header ~= "Quests" then
            return {
                key = "DUNGEON:" .. header,
                kind = "DUNGEON",
                title = "Dungeon: " .. header,
                rawZone = header,
                stripDungeonTag = stripDungeon,
            }
        end
        return {
            key = "DUNGEONS",
            kind = "DUNGEON",
            title = "Dungeons",
            rawZone = "",
            stripDungeonTag = stripDungeon,
        }
    end

    if quest.isClass then
        return {
            key = "CLASS:" .. header,
            kind = "CLASS",
            title = "Class: " .. header,
            rawZone = header,
            stripDungeonTag = false,
        }
    end

    if quest.isProfession then
        return {
            key = "PROFESSION",
            kind = "PROFESSION",
            title = "Professions",
            rawZone = header,
            stripDungeonTag = false,
        }
    end

    return {
        key = "ZONE:" .. header,
        kind = "ZONE",
        title = header,
        rawZone = header,
        stripDungeonTag = false,
    }
end

function Classifier.SortQuests(quests, sortMode)
    local mode = sortMode or "level_asc"
    table.sort(quests, function(a, b)
        if mode == "title_asc" then
            local ta = Classifier.AsciiLower(a.title)
            local tb = Classifier.AsciiLower(b.title)
            if ta ~= tb then
                return ta < tb
            end
        else
            local la = a.level or 0
            local lb = b.level or 0
            if la ~= lb then
                return la < lb
            end
            local ta = Classifier.AsciiLower(a.title)
            local tb = Classifier.AsciiLower(b.title)
            if ta ~= tb then
                return ta < tb
            end
        end
        return (a.questID or 0) < (b.questID or 0)
    end)
end

local function SectionMatchesContext(section, context)
    if not context then
        return false
    end
    local rawLower = Classifier.AsciiLower(section.rawZone or "")
    if rawLower == "" then
        return false
    end
    if context.inInstance and context.instanceName and context.instanceName ~= "" then
        return (section.kind == "DUNGEON" or section.kind == "RAID")
            and rawLower == Classifier.AsciiLower(context.instanceName)
    end
    if section.kind == "ZONE" then
        if context.zoneName ~= "" and rawLower == Classifier.AsciiLower(context.zoneName) then
            return true
        end
        if context.mapZoneName and context.mapZoneName ~= ""
            and rawLower == Classifier.AsciiLower(context.mapZoneName) then
            return true
        end
    end
    return false
end

local function GetSectionSortRank(section, context)
    if section.kind == "READY" then
        return SECTION_RANK.READY
    end
    if section.kind == "DUNGEON" or section.kind == "RAID" then
        if SectionMatchesContext(section, context) then
            return SECTION_RANK.ACTIVE_DUNGEON
        end
        return SECTION_RANK.DUNGEON
    end
    if section.kind == "CLASS" or section.kind == "PROFESSION" then
        return SECTION_RANK.CLASS
    end
    if SectionMatchesContext(section, context) then
        return SECTION_RANK.CURRENT_ZONE
    end
    return SECTION_RANK.ZONE
end

function Classifier.ComputeZoneTransitionKey(context)
    if not context then
        return ""
    end
    if context.inInstance and context.instanceName and context.instanceName ~= "" then
        return "INST:" .. Classifier.AsciiLower(context.instanceName)
    end
    local z = (context.zoneName and context.zoneName ~= "" and context.zoneName)
        or (context.mapZoneName or "")
    if z == "" then
        return ""
    end
    return "ZONE:" .. Classifier.AsciiLower(z)
end

function Classifier.ApplyCollapsedStates(sections, context, accountOpts, charState)
    local smartAutoFold = accountOpts == nil or accountOpts.smartAutoFold ~= false
    charState = charState or {}
    if type(charState.manualCollapsed) ~= "table" then
        charState.manualCollapsed = {}
    end

    local currentZoneKey = Classifier.ComputeZoneTransitionKey(context)
    if smartAutoFold and currentZoneKey ~= "" and charState.lastZoneKey ~= currentZoneKey then
        charState.manualCollapsed = {}
        charState.lastZoneKey = currentZoneKey
    end

    local filterMode = charState.filterMode or "ALL"
    local hasSearch = Classifier.Trim(charState.searchQuery or "") ~= ""

    for _, section in ipairs(sections) do
        local manual = charState.manualCollapsed[section.key]
        if hasSearch then
            -- Always expand matching sections while actively searching
            section.isCollapsed = false
        elseif manual ~= nil then
            section.isCollapsed = manual and true or false
        elseif filterMode ~= "ALL" then
            -- Filtered views (Zone / Dungeon / Ready) already narrowed sections; keep expanded
            section.isCollapsed = false
        elseif smartAutoFold then
            if section.kind == "READY" then
                section.isCollapsed = false
            elseif SectionMatchesContext(section, context) then
                section.isCollapsed = false
            else
                -- Also expand a Zone section if any quest inside it has an active waypoint/turn-in in current zone
                local hasLocalObjective = false
                for _, q in ipairs(section.quests) do
                    if Classifier.QuestMatchesZone(q, context) then
                        hasLocalObjective = true
                        break
                    end
                end
                section.isCollapsed = not hasLocalObjective
            end
        else
            section.isCollapsed = false
        end
    end
end

function Classifier.FormatSectionHeader(section, showCountBadges)
    if showCountBadges == false then
        return section.title
    end
    return string.format("%s (%d)", section.title, #section.quests)
end

function Classifier.BuildEmptyFallbackMessage(totalWatched, context, charState)
    if totalWatched <= 0 then
        return nil
    end
    local search = Classifier.Trim(charState and charState.searchQuery or "")
    if search ~= "" then
        return string.format("No quests match \"%s\" — Show All (%d)", search, totalWatched)
    end
    local mode = (charState and charState.filterMode) or "ALL"
    if mode == "ZONE" then
        local zName = (context and context.zoneName ~= "" and context.zoneName) or "this zone"
        return string.format("No quests in %s — Show All (%d)", zName, totalWatched)
    elseif mode == "DUNGEON" then
        return string.format("No active dungeon quests — Show All (%d)", totalWatched)
    elseif mode == "READY" then
        return string.format("No quests ready for turn-in — Show All (%d)", totalWatched)
    elseif charState and charState.hideGray then
        return string.format("Only trivial (gray) quests tracked — Show All (%d)", totalWatched)
    end
    return nil
end

function Classifier.BuildViewModel(quests, context, accountOpts, charState)
    quests = quests or {}
    accountOpts = accountOpts or {}
    charState = charState or {}

    local totalWatched = #quests
    local bucketMap = {}
    local sections = {}
    local totalAfterFilter = 0

    for _, quest in ipairs(quests) do
        if Classifier.MatchesFilter(quest, context, charState) then
            totalAfterFilter = totalAfterFilter + 1
            local bucket = Classifier.AssignBucket(quest, accountOpts)
            local existing = bucketMap[bucket.key]
            if not existing then
                existing = {
                    key = bucket.key,
                    kind = bucket.kind,
                    title = bucket.title,
                    rawZone = bucket.rawZone,
                    stripDungeonTag = bucket.stripDungeonTag,
                    quests = {},
                    questIDs = {},
                    isCollapsed = false,
                }
                bucketMap[bucket.key] = existing
                sections[#sections + 1] = existing
            end
            existing.quests[#existing.quests + 1] = quest
        end
    end

    for _, section in ipairs(sections) do
        Classifier.SortQuests(section.quests, accountOpts.sortMode)
        for i, q in ipairs(section.quests) do
            section.questIDs[i] = q.questID
        end
        section.headerText = Classifier.FormatSectionHeader(section, accountOpts.showCountBadges)
    end

    table.sort(sections, function(a, b)
        local ra = GetSectionSortRank(a, context)
        local rb = GetSectionSortRank(b, context)
        if ra ~= rb then
            return ra < rb
        end
        return Classifier.AsciiLower(a.title) < Classifier.AsciiLower(b.title)
    end)

    Classifier.ApplyCollapsedStates(sections, context, accountOpts, charState)

    local emptyFallbackText = nil
    if totalWatched > 0 and totalAfterFilter == 0 then
        emptyFallbackText = Classifier.BuildEmptyFallbackMessage(totalWatched, context, charState)
    end

    local mode = charState.filterMode or "ALL"
    local hideNonQuestModules = (mode == "DUNGEON" or mode == "READY")

    return {
        sections = sections,
        totalWatched = totalWatched,
        totalAfterFilter = totalAfterFilter,
        showEmptyFallback = emptyFallbackText ~= nil,
        emptyFallbackText = emptyFallbackText,
        hideNonQuestModules = hideNonQuestModules,
    }
end

return Classifier
