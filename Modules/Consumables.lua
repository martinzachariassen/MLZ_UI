-- MLZ UI: Auto bar for consumables
-- A small bar above the chat that fills itself with the best you have in your bags: food, drink,
-- buff food, potions, healthstone, mana gem, bandages and elixirs. No hotkeys, just click.
-- Categories and order: Data/Consumables.lua. Position: ns.data.utilBarPos in Data/Layout.lua.
--
-- The buttons are Blizzard's secure "item" buttons (as used by RXPGuides/AutoBar), so they work in combat.
-- Which item a button uses can only be changed out of combat; in combat only count and cooldown are updated.

local _, ns = ...

local CB = ns.RegisterModule({ key = "consumables", title = "Consumables" })

local CIS = C_Item or {}
local CC = C_Container or {}
local GetInfo = CIS.GetItemInfo or GetItemInfo
local GetInfoInstant = CIS.GetItemInfoInstant or GetItemInfoInstant
local GetCount = CIS.GetItemCount or GetItemCount
local GetSpell = CIS.GetItemSpell or GetItemSpell
local GetIcon = CIS.GetItemIconByID or GetItemIcon
local NumSlots = CC.GetContainerNumSlots or GetContainerNumSlots
local SlotItemID = CC.GetContainerItemID or GetContainerItemID
local GetCooldown = CC.GetItemCooldown or GetItemCooldown

local function Cfg() return ns.db and ns.db.consumables end

------------------------------------------------------------------------
-- Item classification (result is cached per item ID)
------------------------------------------------------------------------
local scanTip
local function TooltipText(itemID)
    local parts = {}
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText then parts[#parts + 1] = line.leftText end
            end
            return table.concat(parts, "\n"):lower()
        end
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "MLZUI_ScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:SetHyperlink("item:" .. itemID)
    for i = 1, scanTip:NumLines() do
        local fs = _G["MLZUI_ScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then parts[#parts + 1] = t end
    end
    scanTip:Hide()
    return table.concat(parts, "\n"):lower()
end

local cache = {}   -- [itemID] = { cat = id|false, level, ilvl, conjured }
local pendingInfo = false

local function Classify(itemID)
    local c = cache[itemID]
    if c then return c end
    local name, _, _, ilvl, minLevel = GetInfo(itemID)
    if not name then pendingInfo = true return nil end -- not loaded yet; GET_ITEM_INFO_RECEIVED handles it
    local _, _, _, _, _, classID, subID = GetInfoInstant(itemID)
    local info = {
        name = name, classID = classID, subID = subID,
        spell = GetSpell and GetSpell(itemID) or nil,
        text = TooltipText(itemID),
    }
    local cat = false
    for _, def in ipairs(ns.data.consumables) do
        local hit = false
        if def.ids then
            for _, id in ipairs(def.ids) do if id == itemID then hit = true break end end
        elseif def.class then
            hit = classID == def.class and subID == def.sub and (not def.match or def.match(info))
            if not hit and def.altMatch then hit = def.altMatch(info) end
        elseif def.match then
            hit = def.match(info)
        end
        if hit then cat = def.id break end
    end
    c = { cat = cat, level = minLevel or 0, ilvl = ilvl or 0, conjured = name:find("Conjured") ~= nil }
    cache[itemID] = c
    return c
end

local function Better(a, b)
    if a.level ~= b.level then return a.level > b.level end
    if a.conjured ~= b.conjured then return a.conjured end
    if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
    return a.id < b.id
end

-- Returns a list of { id, cat, label } in order
local function Pick()
    local playerLevel = UnitLevel("player") or 60
    local found, seen = {}, {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local id = SlotItemID(bag, slot)
            if id and not seen[id] then
                seen[id] = true
                local c = Classify(id)
                if c and c.cat and c.level <= playerLevel then
                    found[c.cat] = found[c.cat] or {}
                    table.insert(found[c.cat], { id = id, level = c.level, ilvl = c.ilvl, conjured = c.conjured })
                end
            end
        end
    end
    local out = {}
    for _, def in ipairs(ns.data.consumables) do
        local list = found[def.id]
        if list then
            table.sort(list, Better)
            for i = 1, math.min(def.max or 1, #list) do
                out[#out + 1] = { id = list[i].id, cat = def.id, label = def.label }
            end
        end
    end
    return out
end

------------------------------------------------------------------------
-- The bar
------------------------------------------------------------------------
local bar
local buttons = {}

local function OnEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:AddLine("|cff33ccffMLZ UI:|r " .. (self.label or ""), 1, 1, 1)
    GameTooltip:Show()
end

local function CreateButton(i)
    local pos = ns.data.utilBarPos
    local b = CreateFrame("Button", "MLZUI_ConsumableButton" .. i, bar, "SecureActionButtonTemplate")
    b:SetSize(pos.size, pos.size)
    b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * (pos.size + pos.spacing), 0)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")

    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetColorTexture(0, 0, 0, 1)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[i] = b
    return b
end

-- Count and cooldown (safe in combat)
local function UpdateCounts()
    for _, b in ipairs(buttons) do
        if b.itemID and b:IsShown() then
            local n = GetCount(b.itemID) or 0
            b.count:SetText(n > 1 and n or "")
            b.icon:SetDesaturated(n == 0)
            if GetCooldown then
                local start, dur, enable = GetCooldown(b.itemID)
                if start and dur and dur > 1.5 and (enable == 1 or enable == true) then
                    b.cooldown:SetCooldown(start, dur)
                else
                    b.cooldown:Clear()
                end
            end
        end
    end
end

-- Changes which items the buttons use (out of combat only)
local dirty = false
local function Rebuild()
    local cfg = Cfg()
    if not bar then return end
    if InCombatLockdown() then dirty = true return end
    dirty = false
    if not (cfg and cfg.enabled) then bar:Hide() return end
    local list = Pick()
    for i, entry in ipairs(list) do
        local b = buttons[i] or CreateButton(i)
        b.itemID, b.label = entry.id, entry.label
        b:SetAttribute("item", "item:" .. entry.id)
        b.icon:SetTexture(GetIcon(entry.id))
        b:Show()
    end
    for i = #list + 1, #buttons do
        local b = buttons[i]
        b.itemID = nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
    bar:SetShown(#list > 0)
    UpdateCounts()
end

local function BuildBar()
    if bar then return end
    local pos = ns.data.utilBarPos
    bar = CreateFrame("Frame", "MLZUI_ConsumableBar", UIParent)
    bar:SetSize(pos.size, pos.size)
    bar:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    bar:SetFrameStrata("MEDIUM")
end

-- Batches many BAG_UPDATE events into a single update
local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0.3, function()
        queued = false
        Rebuild()
    end)
end

function CB:Refresh()
    if not Cfg() then return end
    BuildBar()
    Rebuild()
end

ns.On("PLAYER_ENTERING_WORLD", function() if Cfg() then CB:Refresh() end end)
ns.On("BAG_UPDATE_DELAYED", function() if Cfg() then Queue() end end)
ns.On("PLAYER_LEVEL_UP", function() if Cfg() then Queue() end end)
ns.On("GET_ITEM_INFO_RECEIVED", function()
    if pendingInfo and Cfg() then pendingInfo = false Queue() end
end)
ns.On("PLAYER_REGEN_ENABLED", function() if dirty then Rebuild() end end)
ns.On("BAG_UPDATE_COOLDOWN", function() if bar then UpdateCounts() end end)
ns.On("BAG_UPDATE", function() if bar then UpdateCounts() end end)

ns.AddCommand("consumables", "toggles the food/potions auto bar on/off", function()
    ns.db.consumables = ns.db.consumables or {}
    ns.db.consumables.enabled = not ns.db.consumables.enabled
    CB:Refresh()
    ns.Print("Consumables auto bar:", ns.db.consumables.enabled and "on" or "off",
        InCombatLockdown() and "(after combat)" or "")
end)

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function CB:Preview()
    local cur = Cfg()
    local names = {}
    for _, def in ipairs(ns.data.consumables) do names[#names + 1] = def.label end
    return { {
        id = "enabled", label = "Consumables auto bar (above chat)", group = "Bars without hotkeys",
        note = "Fills itself with the best you have of: " .. table.concat(names, ", ") ..
               ". Only categories you have something of are shown. /mlz consumables toggles it on/off.",
        old = (cur and cur.enabled) and "on" or "off", new = "on",
        enabled = ns.Enabled("consumables", "enabled", true),
        alreadySet = cur and cur.enabled or nil,
    } }
end

function CB:Backup()
    return { cfg = ns.CopyTable(ns.db.consumables) }
end

function CB:Apply(items)
    ns.db.consumables = ns.db.consumables or {}
    for _, item in ipairs(items) do ns.db.consumables[item.id] = true end
    self:Refresh()
end

function CB:Restore(snap)
    ns.db.consumables = snap.cfg or { enabled = false }
    self:Refresh()
    if not snap.cfg then ns.db.consumables = nil end
end
