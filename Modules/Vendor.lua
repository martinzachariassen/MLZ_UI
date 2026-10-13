-- MLZ UI: Auto-repair and sell grey items at merchants
-- When a merchant window opens: repair everything (guild bank money first when allowed, then your
-- own) and sell every grey (poor quality) item, then print one summary line.
-- Hold Shift while opening the merchant to skip it once. Settings: /mlz > Quality of life.
-- Selling is skipped when Leatrix Plus already sells junk, so the two never fight.

local _, ns = ...

local V = {}
ns.Vendor = V

local DEFAULTS = { repair = true, guild = true, sell = true }

local function Cfg()
    ns.db.vendor = ns.db.vendor or {}
    local c = ns.db.vendor
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    return c
end

-- Bag API: C_Container on newer clients, globals on older ones
local Container = C_Container or {}
local GetNumSlots = Container.GetContainerNumSlots or GetContainerNumSlots
local GetItemInfoC = Container.GetContainerItemInfo
local UseItem = Container.UseContainerItem or UseContainerItem
local NUM_BAGS = NUM_BAG_SLOTS or 4

-- Returns quality, stack count, item link, locked, hasNoValue for a bag slot
local function SlotInfo(bag, slot)
    if GetItemInfoC then
        local info = GetItemInfoC(bag, slot)
        if not info then return end
        return info.quality, info.stackCount, info.hyperlink, info.isLocked, info.hasNoValue
    elseif GetContainerItemInfo then
        local _, count, locked, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
        return quality, count, link, locked, noValue
    end
end

local function SellPrice(link, count)
    if not link then return 0 end
    local price = select(11, GetItemInfo(link))
    return (tonumber(price) or 0) * (count or 1)
end

local function LeatrixSells()
    if not ns.IsAddOnLoaded("Leatrix_Plus") then return false end
    local lc = _G.LeaPlusLC
    if type(lc) == "table" and lc.AutoSellJunk ~= nil then return lc.AutoSellJunk == "On" end
    local db = _G.LeaPlusDB
    return type(db) == "table" and db.AutoSellJunk == "On"
end

local function Money(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end

------------------------------------------------------------------------
-- Repair
------------------------------------------------------------------------
-- Returns the cost, and true if the guild paid
local function Repair(cfg)
    if not (cfg.repair and CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return 0 end
    local cost, can = GetRepairAllCost()
    if not can or not cost or cost <= 0 then return 0 end
    if cfg.guild and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or -1
        if limit == -1 or limit >= cost then
            RepairAllItems(true)
            return cost, true
        end
    end
    if GetMoney() >= cost then
        RepairAllItems()
        return cost, false
    end
    return -cost -- not enough money
end

------------------------------------------------------------------------
-- Selling: one item every 0.15 s, stops when the merchant closes
------------------------------------------------------------------------
local selling, soldCount, soldValue = nil, 0, 0
local merchantOpen = false

local function Junk()
    local list = {}
    if not (GetNumSlots and UseItem) then return list end
    for bag = 0, NUM_BAGS do
        for slot = 1, GetNumSlots(bag) or 0 do
            local quality, count, link, locked, noValue = SlotInfo(bag, slot)
            if quality == 0 and link and not locked and not noValue then
                local value = SellPrice(link, count)
                if value > 0 then list[#list + 1] = { bag = bag, slot = slot, value = value } end
            end
        end
    end
    return list
end

local function Report(repairCost, guildPaid)
    local parts = {}
    if repairCost and repairCost > 0 then
        parts[#parts + 1] = "Repaired for " .. Money(repairCost) .. (guildPaid and " (guild bank)" or "")
    elseif repairCost and repairCost < 0 then
        parts[#parts + 1] = "|cffff8800Not enough money to repair|r (" .. Money(-repairCost) .. ")"
    end
    if soldCount > 0 then
        parts[#parts + 1] = ("sold %d grey item%s for %s"):format(soldCount, soldCount == 1 and "" or "s", Money(soldValue))
    end
    if #parts > 0 then
        local text = table.concat(parts, ", ")
        ns.Print(text:sub(1, 1):upper() .. text:sub(2) .. ".")
    end
end

local function SellNext(queue, repairCost, guildPaid)
    if not merchantOpen then
        selling = nil
        Report(repairCost, guildPaid)
        return
    end
    local item = table.remove(queue, 1)
    if not item then
        selling = nil
        Report(repairCost, guildPaid)
        return
    end
    -- the slot may have changed since the list was made: check it again
    local quality, count, link, locked = SlotInfo(item.bag, item.slot)
    if quality == 0 and link and not locked then
        UseItem(item.bag, item.slot)
        soldCount = soldCount + 1
        soldValue = soldValue + SellPrice(link, count)
    end
    C_Timer.After(0.15, function() SellNext(queue, repairCost, guildPaid) end)
end

ns.On("MERCHANT_SHOW", function()
    merchantOpen = true
    if not ns.db then return end
    if IsShiftKeyDown() then return end
    local cfg = Cfg()
    if not (cfg.repair or cfg.sell) then return end
    local cost, guild = Repair(cfg)
    if cfg.sell and not selling and not LeatrixSells() then
        local queue = Junk()
        if #queue > 0 then
            selling = true
            soldCount, soldValue = 0, 0
            SellNext(queue, cost, guild)
            return
        end
    end
    soldCount, soldValue = 0, 0
    Report(cost, guild)
end)

ns.On("MERCHANT_CLOSED", function() merchantOpen = false end)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
function V.Get(key) return Cfg()[key] and true or false end
function V.Set(key, on)
    Cfg()[key] = on and true or false
    ns.FireState()
end
function V.LeatrixSells() return LeatrixSells() end
