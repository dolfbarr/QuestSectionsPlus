local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local SecureItemOverlay = {}
ns.SecureItemOverlay = SecureItemOverlay

local overlayPool = {}

local function ExtractItemIdentifier(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end
    local bracketName = string.match(itemLink, "%[(.-)%]")
    if bracketName and bracketName ~= "" then
        return bracketName
    end
    local itemID = string.match(itemLink, "item:(%d+)")
    if itemID then
        return "item:" .. itemID
    end
    return nil
end

local function CreateOverlayButton(index)
    local btnName = "QuestSectionsPlusItemOverlay" .. tostring(index)
    local btn = CreateFrame("Button", btnName, UIParent, "SecureActionButtonTemplate")
    btn:SetSize(26, 26)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(25)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    btn:SetScript("OnEnter", function(self)
        if GameTooltip and self.questLogIndex then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetQuestLogSpecialItem then
                GameTooltip:SetQuestLogSpecialItem(self.questLogIndex)
            end
        end
    end)

    btn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    btn:Hide()
    return btn
end

function SecureItemOverlay.SyncActiveModules(sectionModules, isTrackerCollapsed)
    if Compat.InCombat() or not CreateFrame or not UIParent then
        return false
    end

    local usedCount = 0

    if not isTrackerCollapsed and type(sectionModules) == "table" then
        for _, module in ipairs(sectionModules) do
            if module and module:IsShown() and not module:IsCollapsed() and module.usedBlocks then
                for _, templateBlocks in pairs(module.usedBlocks) do
                    for _, block in pairs(templateBlocks) do
                        local itemBtn = block and block.ItemButton
                        if itemBtn and block:IsShown() and itemBtn:IsShown() then
                            local qLogIndex = itemBtn:GetAttribute("questLogIndex")
                                or (block.id and C_QuestLog and C_QuestLog.GetLogIndexForQuestID
                                    and C_QuestLog.GetLogIndexForQuestID(block.id))
                            if qLogIndex and GetQuestLogSpecialItemInfo then
                                local link = GetQuestLogSpecialItemInfo(qLogIndex)
                                local itemIdent = ExtractItemIdentifier(link)
                                if itemIdent then
                                    usedCount = usedCount + 1
                                    local overlay = overlayPool[usedCount]
                                    if not overlay then
                                        overlay = CreateOverlayButton(usedCount)
                                        overlayPool[usedCount] = overlay
                                    end
                                    overlay.questLogIndex = qLogIndex
                                    overlay:SetAttribute("type", "item")
                                    overlay:SetAttribute("item", itemIdent)
                                    overlay:ClearAllPoints()
                                    overlay:SetPoint("CENTER", itemBtn, "CENTER", 0, 0)
                                    overlay:Show()
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = usedCount + 1, #overlayPool do
        local unused = overlayPool[i]
        if unused and unused:IsShown() then
            unused:ClearAllPoints()
            unused:Hide()
        end
    end

    return true
end

function SecureItemOverlay.HideAll()
    if Compat.InCombat() then
        return false
    end
    for i = 1, #overlayPool do
        local btn = overlayPool[i]
        if btn then
            btn:ClearAllPoints()
            btn:Hide()
        end
    end
    return true
end

return SecureItemOverlay
