local _, ns = ...
ns = ns or {}

local Store = {}
ns.Store = Store

Store.SCHEMA_VERSION = 1
Store.CVAR_BACKUP_NAME = "qspSettingsBackup"

local VALID_FILTERS = {
    ALL = true,
    ZONE = true,
    DUNGEON = true,
    READY = true,
}

local VALID_SORT_MODES = {
    level_asc = true,
    title_asc = true,
}

local ACCOUNT_DEFAULTS = {
    schemaVersion = Store.SCHEMA_VERSION,
    enabled = true,
    smartAutoFold = true,
    hoistReadyForTurnIn = true,
    splitDungeonsByInstance = true,
    stripDungeonTag = true,
    sortMode = "level_asc",
    showCountBadges = true,
    showFilterBar = true,
}

local CHAR_DEFAULTS = {
    schemaVersion = Store.SCHEMA_VERSION,
    filterMode = "ALL",
    hideGray = false,
    searchQuery = "",
    searchExpanded = false,
    questsMasterCollapsed = false,
    lastZoneKey = "",
    manualCollapsed = {},
    dismissedNotices = {},
}

local function ShallowCopyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
        elseif type(target[k]) ~= type(v) then
            target[k] = v
        end
    end
    target.schemaVersion = Store.SCHEMA_VERSION
    return target
end

local function SerializeBackup(account, char)
    local parts = {
        account.enabled and "1" or "0",
        account.smartAutoFold and "1" or "0",
        account.hoistReadyForTurnIn and "1" or "0",
        account.splitDungeonsByInstance and "1" or "0",
        account.stripDungeonTag and "1" or "0",
        account.showCountBadges and "1" or "0",
        account.showFilterBar and "1" or "0",
        char.hideGray and "1" or "0",
        char.filterMode or "ALL",
        char.questsMasterCollapsed and "1" or "0",
    }
    return table.concat(parts, ":")
end

local function ApplyBackupIfFresh(account, char, raw)
    if type(raw) ~= "string" or raw == "" then
        return
    end
    local fields = {}
    for token in string.gmatch(raw, "([^:]+)") do
        fields[#fields + 1] = token
    end
    if #fields < 9 then
        return
    end
    account.enabled = fields[1] == "1"
    account.smartAutoFold = fields[2] == "1"
    account.hoistReadyForTurnIn = fields[3] == "1"
    account.splitDungeonsByInstance = fields[4] == "1"
    account.stripDungeonTag = fields[5] == "1"
    account.showCountBadges = fields[6] == "1"
    account.showFilterBar = fields[7] == "1"
    char.hideGray = fields[8] == "1"
    if VALID_FILTERS[fields[9]] then
        char.filterMode = fields[9]
    end
    if fields[10] ~= nil then
        char.questsMasterCollapsed = fields[10] == "1"
    end
end

function Store:Init(customAccountDB, customCharDB)
    local hadSavedAccount = type(customAccountDB or QuestSectionsPlusDB) == "table"
    local hadSavedChar = type(customCharDB or QuestSectionsPlusCharDB) == "table"

    self.account = ShallowCopyDefaults(customAccountDB or QuestSectionsPlusDB, ACCOUNT_DEFAULTS)
    self.char = ShallowCopyDefaults(customCharDB or QuestSectionsPlusCharDB, CHAR_DEFAULTS)

    if not VALID_FILTERS[self.char.filterMode] then
        self.char.filterMode = "ALL"
    end
    if not VALID_SORT_MODES[self.account.sortMode] then
        self.account.sortMode = "level_asc"
    end

    if C_CVar and C_CVar.RegisterCVar then
        pcall(C_CVar.RegisterCVar, Store.CVAR_BACKUP_NAME, "")
        if not hadSavedAccount and not hadSavedChar and C_CVar.GetCVar then
            local ok, raw = pcall(C_CVar.GetCVar, Store.CVAR_BACKUP_NAME)
            if ok and raw and raw ~= "" then
                ApplyBackupIfFresh(self.account, self.char, raw)
            end
        end
    end

    if customAccountDB == nil then
        QuestSectionsPlusDB = self.account
    end
    if customCharDB == nil then
        QuestSectionsPlusCharDB = self.char
    end

    self:SyncBackupCVar()
    return self
end

function Store:SyncBackupCVar()
    if C_CVar and C_CVar.SetCVar and self.account and self.char then
        pcall(C_CVar.SetCVar, Store.CVAR_BACKUP_NAME, SerializeBackup(self.account, self.char))
    end
end

function Store:GetAccount()
    if not self.account then
        self:Init()
    end
    return self.account
end

function Store:GetChar()
    if not self.char then
        self:Init()
    end
    return self.char
end

function Store:SetAccountOption(key, value)
    local acc = self:GetAccount()
    if ACCOUNT_DEFAULTS[key] == nil then
        return false
    end
    if key == "sortMode" and not VALID_SORT_MODES[value] then
        return false
    end
    acc[key] = value
    self:SyncBackupCVar()
    return true
end

function Store:SetFilterMode(mode)
    local upper = type(mode) == "string" and string.upper(mode) or ""
    if not VALID_FILTERS[upper] then
        return false
    end
    local ch = self:GetChar()
    ch.filterMode = upper
    self:SyncBackupCVar()
    return true
end

function Store:SetHideGray(flag)
    local ch = self:GetChar()
    ch.hideGray = flag and true or false
    self:SyncBackupCVar()
end

function Store:SetSearchQuery(query)
    local ch = self:GetChar()
    ch.searchQuery = type(query) == "string" and query or ""
end

function Store:SetSearchExpanded(expanded)
    local ch = self:GetChar()
    ch.searchExpanded = expanded and true or false
end

function Store:SetQuestsMasterCollapsed(collapsed)
    local ch = self:GetChar()
    ch.questsMasterCollapsed = collapsed and true or false
    self:SyncBackupCVar()
end

function Store:IsQuestsMasterCollapsed()
    local ch = self:GetChar()
    return ch.questsMasterCollapsed == true
end

function Store:SetManualCollapsed(sectionKey, isCollapsed)
    if type(sectionKey) ~= "string" or sectionKey == "" then
        return
    end
    local ch = self:GetChar()
    ch.manualCollapsed[sectionKey] = isCollapsed and true or false
end

function Store:ResetAll()
    self.account = ShallowCopyDefaults({}, ACCOUNT_DEFAULTS)
    self.char = ShallowCopyDefaults({}, CHAR_DEFAULTS)
    QuestSectionsPlusDB = self.account
    QuestSectionsPlusCharDB = self.char
    self:SyncBackupCVar()
end

return Store
