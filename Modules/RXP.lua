-- MLZ UI: Fixed column for RestedXP Guides
-- Puts the arrow, active steps, party steps, active targets and active items in one column on the right
-- side of the screen and locks them there (no dragging, not even with Alt). Position: Data/RXP.lua.
-- Turn off with /mlz rxp (then /reload), and the boxes are movable again.
--
-- RXP creates some of these boxes late (when a guide loads, or when the first target/item shows up), so
-- a light poll adopts them as soon as they exist. Boxes that RXP moves or resizes itself are put back
-- in the column on the next frame. Nothing is moved in combat; it catches up when combat ends.

local _, ns = ...

local RXP = ns.RegisterModule({ key = "rxp", title = "RXP column" })

local function Cfg() return ns.data.rxp end
local function Enabled() return not (ns.db and ns.db.rxpColumn == false) end

local column
local adopted = {}      -- [frame] = true
local dirty = true
local reflowing = false

-- Order in the column, top to bottom. Frames are looked up by their global name, since RXP creates them late.
local function Entries()
    local player = UnitName("player")
    return {
        { name = "RXPG_ARROW", arrow = true },
        { name = "RXPActiveStepsFrame" .. (player or ""), width = true },
        { name = "RXPActivePartyStepsFrame", width = true },
        { name = "RXPTargetFrame" },
        { name = "RXPItemFrame" },
    }
end

local function MarkDirty() dirty = true end

local function Adopt(f)
    if adopted[f] then return end
    adopted[f] = true
    f.savePosition = false                 -- RXP no longer saves or restores a position for this box
    if f.SetMovable then f:SetMovable(false) end
    if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
    -- If RXP tries to start a drag anyway (Alt+drag, or after it re-enables movement), stop it at once
    hooksecurefunc(f, "StartMoving", function(self)
        if Enabled() then self:StopMovingOrSizing(); MarkDirty() end
    end)
    -- If RXP moves the box itself, put it back
    hooksecurefunc(f, "SetPoint", function() if not reflowing then MarkDirty() end end)
    hooksecurefunc(f, "ClearAllPoints", function() if not reflowing then MarkDirty() end end)
    f:HookScript("OnShow", MarkDirty)
    f:HookScript("OnHide", MarkDirty)
    f:HookScript("OnSizeChanged", MarkDirty)
end

local function Reflow()
    if not Enabled() or InCombatLockdown() then return end   -- retried when combat ends
    local c = Cfg()
    if not column then
        column = CreateFrame("Frame", "MLZUI_RXPColumn", UIParent)
        column:SetSize(1, 1)
    end
    column:ClearAllPoints()
    column:SetPoint(c.point, UIParent, c.point, c.x, c.y)

    reflowing = true
    local yUsed = 0
    for _, e in ipairs(Entries()) do
        local f = _G[e.name]
        if f and f.SetPoint then
            Adopt(f)
            local s = f:GetScale() or 1
            if s <= 0 then s = 1 end
            if e.width then f:SetWidth(c.width / s) end
            f:ClearAllPoints()
            f:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -yUsed / s)
            -- Only boxes that are actually visible take up space (the arrow is hidden with alpha 0 sometimes)
            local visible = f:IsShown() and (f:GetAlpha() or 1) > 0
            if visible then
                local h = (f:GetHeight() or 0) + (e.arrow and c.arrowExtra / s or 0)
                yUsed = yUsed + h * s + c.gap
            end
        end
    end
    reflowing = false
    dirty = false
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    if not (RXPGuides or _G.RXPG_ARROW) then return end   -- RXP isn't loaded
    elapsed = elapsed + dt
    if elapsed >= 0.5 then       -- find boxes RXP created late
        elapsed = 0
        dirty = true
    end
    if dirty then
        local ok, err = pcall(Reflow)
        reflowing = false
        if not ok then dirty = false; ns.Debug("RXP column:", err) end
    end
end)

ns.On("PLAYER_REGEN_ENABLED", MarkDirty)
ns.On("UI_SCALE_CHANGED", MarkDirty)
ns.On("DISPLAY_SIZE_CHANGED", MarkDirty)

ns.AddCommand("rxp", "toggles the fixed RXP column on the right side on/off (needs /reload)", function()
    ns.db.rxpColumn = not Enabled()
    ns.Print("RXP column:", Enabled() and "on" or "off", "- type /reload to apply.")
end)

-- No wizard step: this works by itself once the module is loaded.
function RXP:Preview() return {} end
function RXP:Apply() end
