-- MLZ UI: Cooking tooltips
-- Meat, fish, eggs and spices show which dishes they go into, as lines in the item tooltip:
-- "Cooking: Roasted Boar Meat (1)". The dish is colored by your Cooking skill, like the
-- recipe list: orange, yellow, green, grey, or red when your skill is too low. Data: Data/Cooking.lua.
-- Settings: /mlz > Helpers. Only adds lines to the tooltip, so there is nothing to back up.

local _, ns = ...

local C = {}
ns.Cooking = C

local DEFAULTS = { tooltip = true }
local MAX_LINES = 3
local COOKING_SPELL = 2550 -- the Cooking profession spell, used for its localized name

local function Cfg()
    ns.db.cooking = ns.db.cooking or {}
    local c = ns.db.cooking
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    return c
end

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

------------------------------------------------------------------------
-- The player's Cooking skill, read from the skill list and cached until it changes
------------------------------------------------------------------------
local skillRank, skillDirty = nil, true

-- The skill list only shows lines under expanded headers. When a header is collapsed, keep the
-- last rank we saw instead of calling it "not learned" (expanding it ourselves would fire
-- SKILL_LINES_CHANGED again and fight the player's choice).
local function ReadSkill()
    skillDirty = false
    if not (GetNumSkillLines and GetSkillLineInfo) then skillRank = nil return end
    local want = _G.PROFESSIONS_COOKING or SpellName(COOKING_SPELL) or "Cooking"
    local collapsed = false
    for i = 1, GetNumSkillLines() or 0 do
        local name, isHeader, isExpanded, rank = GetSkillLineInfo(i)
        if name == want and not isHeader then
            skillRank = rank
            return
        end
        if isHeader and not isExpanded then collapsed = true end
    end
    if not collapsed then skillRank = 0 end -- not learned
end

local function Skill()
    if skillDirty then ReadSkill() end
    return skillRank
end

local function MarkDirty() skillDirty = true end
ns.TryOn("SKILL_LINES_CHANGED", MarkDirty)
ns.TryOn("PLAYER_ENTERING_WORLD", MarkDirty)

-- Same difficulty colors as the recipe list. The game's own table when it has one, W.C otherwise.
local DIFFICULTY = { optimal = "amber", medium = "gold", easy = "green", trivial = "grey", impossible = "red" }

local function ColorCode(kind)
    local game = _G.TradeSkillTypeColor and _G.TradeSkillTypeColor[kind]
    if game and game.r then
        return ("|cff%02x%02x%02x"):format(game.r * 255, game.g * 255, game.b * 255)
    end
    return ns.W.C[DIFFICULTY[kind]] or ns.W.C.white
end

local function Difficulty(recipe, rank)
    if not rank or rank == 0 then return nil end -- no skill info or not learned: neutral color
    if rank < recipe.skill then return "impossible" end
    if rank < recipe.yellow then return "optimal" end
    if rank < math.floor((recipe.yellow + recipe.grey) / 2) then return "medium" end
    if rank < recipe.grey then return "easy" end
    return "trivial"
end

------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------
local function ItemID(tooltip, data)
    if data and type(data.id) == "number" then return data.id end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    if GetItemInfoInstant then return (GetItemInfoInstant(link)) end
    return tonumber(link:match("item:(%d+)"))
end

local function OnTooltipItem(tooltip, data)
    if not (ns.db and Cfg().tooltip) then return end
    if tooltip ~= _G.GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
    local id = ItemID(tooltip, data)
    local recipes = id and ns.data.cooking and ns.data.cooking[id]
    if not recipes then return end

    local W = ns.W
    local rank = Skill()
    for i = 1, math.min(#recipes, MAX_LINES) do
        local r = recipes[i]
        local kind = Difficulty(r, rank)
        local color = kind and ColorCode(kind) or W.C.white
        local name = SpellName(r.spell) or ("#" .. r.spell)
        tooltip:AddLine(W.C.grey .. "Cooking:|r " .. color .. name .. "|r " .. W.C.grey .. "(" .. r.skill .. ")|r")
    end
    if #recipes > MAX_LINES then
        local more = #recipes - MAX_LINES
        tooltip:AddLine(W.C.grey .. ("+%d more recipe%s"):format(more, more == 1 and "" or "s") .. "|r")
    end
    tooltip:Show() -- resize to fit the new lines
end

local function Available()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Item then
        return true
    end
    return (_G.GameTooltip and _G.GameTooltip:HasScript("OnTooltipSetItem")) and true or false
end

local hooked = false
local function Hook()
    if hooked or not (ns.db and Cfg().tooltip) then return end -- hook only once it is wanted
    hooked = true
    local function Safe(tooltip, data)
        local ok, err = pcall(OnTooltipItem, tooltip, data)
        if not ok then ns.Error("cooking tooltip", err) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe)
    elseif _G.GameTooltip and _G.GameTooltip:HasScript("OnTooltipSetItem") then
        _G.GameTooltip:HookScript("OnTooltipSetItem", Safe)
        if _G.ItemRefTooltip and _G.ItemRefTooltip:HasScript("OnTooltipSetItem") then
            _G.ItemRefTooltip:HookScript("OnTooltipSetItem", Safe)
        end
    else
        hooked = false
    end
end

ns.On("PLAYER_LOGIN", Hook)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
function C.Get() return Cfg().tooltip and true or false end
function C.Set(on)
    Cfg().tooltip = on and true or false
    if on then Hook() end
    ns.FireState()
end
function C.Unavailable()
    if not Available() then return "Tooltip hooks not available" end
end
