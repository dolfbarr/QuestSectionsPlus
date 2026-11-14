std = "lua51"

max_line_length = 120
unused_args = false

read_globals = {
    -- Core WoW Lua globals
    "_G",
    "CreateFrame",
    "CreateFromMixins",
    "Mixin",
    "hooksecurefunc",
    "InCombatLockdown",
    "IsInInstance",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "IsAltKeyDown",
    "IsModifiedClick",
    "GetRealZoneText",
    "GetSubZoneText",
    "UnitLevel",
    "UnitClass",
    "GetQuestDifficultyColor",
    "GetDifficultyColor",
    "GetQuestLogSpecialItemInfo",
    "GetQuestLogSpecialItemCooldown",
    "SetQuestTitleLevelAndDifficultyColor",
    "CooldownFrame_Set",
    "GameTooltip",
    "GameTooltip_SetDefaultAnchor",
    "UIParent",
    "SOUNDKIT",
    "PlaySound",
    "DEFAULT_CHAT_FRAME",
    "LFG_TYPE_DUNGEON",
    "TRACKER_HEADER_QUESTS",
    "QuestDifficultyColors",
    -- WoW 16001 Namespaces & Mixins
    "Enum",
    "C_QuestLog",
    "C_Map",
    "C_SuperTrack",
    "C_PlayerInfo",
    "C_CreatureInfo",
    "C_CVar",
    "C_Timer",
    "QuestCache",
    "QuestUtil",
    "QuestUtilsOverrides",
    "ObjectiveTrackerFrame",
    "ObjectiveTrackerManager",
    "ObjectiveTrackerModuleMixin",
    "QuestObjectiveTrackerMixin",
    "AchievementObjectiveTracker",
    "ProfessionsRecipeTracker",
    "Settings",
    -- Optional Addon Bridges
    "ForeverQuestPins",
    "Questie",
    "QuestieLoader",
    "TomTom",
}

globals = {
    "QuestSectionsPlusDB",
    "QuestSectionsPlusCharDB",
    "QuestSectionsPlus",
    "SlashCmdList",
    "QuestObjectiveTracker",
    "SLASH_QUESTSECTIONSPLUS1",
    "SLASH_QUESTSECTIONSPLUS2",
}

files["tests/**/*.lua"] = {
    globals = {
        "_G",
    },
}
