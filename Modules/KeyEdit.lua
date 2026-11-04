-- MLZ UI: Change single keys
-- The logic behind "Change keys" on the key map (/mlz keys, UI/Keys.lua): which actions a key can get,
-- what a change will do (old -> new, which action loses its key) and the change itself, backed up so
-- /mlz undo puts every key of one editing session back.

local _, ns = ...

local KeyEdit = {}
ns.KeyEdit = KeyEdit

-- Bars in the order the player knows them. Bar 1-3 follow the wizard layers, 4-5 are the side bars.
local BARS = {
    { prefix = "ACTIONBUTTON", text = "Bar 1" },
    { prefix = "MULTIACTIONBAR1BUTTON", text = "Bar 2" },
    { prefix = "MULTIACTIONBAR2BUTTON", text = "Bar 3" },
    { prefix = "MULTIACTIONBAR3BUTTON", text = "Bar 4" },
    { prefix = "MULTIACTIONBAR4BUTTON", text = "Bar 5" },
}

-- Names for the other actions. Blizzard's own names are long ("Toggle Character Pane").
local COMMANDS = {
    { title = "Movement", list = {
        { "MOVEFORWARD", "Move forward" }, { "MOVEBACKWARD", "Move back" },
        { "STRAFELEFT", "Strafe left" }, { "STRAFERIGHT", "Strafe right" },
        { "TURNLEFT", "Turn left" }, { "TURNRIGHT", "Turn right" }, { "JUMP", "Jump" },
        { "TOGGLEAUTORUN", "Autorun" }, { "SITORSTAND", "Sit or stand" }, { "TOGGLERUN", "Walk or run" },
    } },
    { title = "Targeting", list = {
        { "TARGETNEARESTENEMY", "Next enemy" }, { "TARGETPREVIOUSENEMY", "Previous enemy" },
        { "TARGETNEARESTFRIEND", "Next friend" }, { "TARGETSELF", "Target me" },
        { "TARGETPARTYMEMBER1", "Target party member 1" }, { "TARGETPARTYMEMBER2", "Target party member 2" },
        { "TARGETPARTYMEMBER3", "Target party member 3" }, { "TARGETPARTYMEMBER4", "Target party member 4" },
        { "TARGETPET", "Target my pet" }, { "ASSISTTARGET", "Assist target" },
        { "INTERACTTARGET", "Interact with target" }, { "INTERACTMOUSEOVER", "Interact with mouseover" },
    } },
    { title = "Panels", list = {
        { "OPENALLBAGS", "Open all bags" }, { "TOGGLECHARACTER0", "Character" }, { "TOGGLESPELLBOOK", "Spellbook" },
        { "TOGGLETALENTS", "Talents" }, { "TOGGLEQUESTLOG", "Quest log" }, { "TOGGLEWORLDMAP", "World map" },
        { "TOGGLESOCIAL", "Friends" }, { "TOGGLEPETBOOK", "Pet spellbook" },
    } },
    { title = "Chat and other", list = {
        { "OPENCHAT", "Open chat" }, { "REPLY", "Reply to whisper" }, { "SCREENSHOT", "Screenshot" },
        { "MLZUI_PULL", "Pull timer (MLZ UI)" },
    } },
}

local NAMES = {}
for _, group in ipairs(COMMANDS) do
    for _, c in ipairs(group.list) do NAMES[c[1]] = c[2] end
end
for _, bar in ipairs(BARS) do NAMES[bar.prefix] = bar.text end

-- "Bar 2 button 3", "Pet bar button 4", "Strafe left", or Blizzard's name for anything else
function KeyEdit.Name(cmd)
    if not cmd or cmd == "" then return "nothing" end
    if NAMES[cmd] then return NAMES[cmd] end
    local prefix, n = cmd:match("^(.-BUTTON)(%d+)$")
    if prefix == "BONUSACTIONBUTTON" then return "Pet bar button " .. n end
    if prefix == "SHAPESHIFTBUTTON" then return "Stance bar button " .. n end
    if prefix and NAMES[prefix] then return NAMES[prefix] .. " button " .. n end
    return _G["BINDING_NAME_" .. cmd] or cmd
end

local function HasPet()
    local c = ns.data.classes and ns.data.classes[ns.PlayerClass() or ""]
    return (c and c.pet) or (HasPetUI and HasPetUI()) or false
end

-- Groups of actions a key can get: { { title, list = { { cmd, text } } } }
function KeyEdit.Actions()
    local out = {}
    for _, bar in ipairs(BARS) do
        local list = {}
        for i = 1, 12 do list[i] = { bar.prefix .. i, bar.text .. " button " .. i } end
        out[#out + 1] = { title = bar.text, list = list }
    end
    if HasPet() then
        local list = {}
        for i = 1, 10 do list[i] = { "BONUSACTIONBUTTON" .. i, "Pet bar button " .. i } end
        out[#out + 1] = { title = "Pet bar", list = list }
    end
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    if forms > 0 then
        local list = {}
        for i = 1, forms do list[i] = { "SHAPESHIFTBUTTON" .. i, "Stance bar button " .. i } end
        out[#out + 1] = { title = "Stance bar", list = list }
    end
    for _, group in ipairs(COMMANDS) do out[#out + 1] = group end
    return out
end

local function Action(key)
    local a = GetBindingAction(key)
    return (a and a ~= "") and a or ""
end

local function KeysOf(cmd)
    local out = {}
    for _, k in ipairs({ GetBindingKey(cmd) }) do
        if k then out[#out + 1] = k end
    end
    return out
end

-- What giving `key` the action `cmd` does (cmd nil = clear the key). Returns
-- { old, freed = { keys cmd had before }, lost = action that is left without a key, same = nothing changes }.
-- An action moves: its old keys are freed, so the button shows the new key (Blizzard shows only the first).
function KeyEdit.Plan(key, cmd)
    local old = Action(key)
    local plan = { key = key, cmd = cmd, old = old, freed = {} }
    if cmd and old == cmd and #KeysOf(cmd) == 1 then plan.same = true return plan end
    if not cmd and old == "" then plan.same = true return plan end
    if cmd then
        for _, k in ipairs(KeysOf(cmd)) do
            if k ~= key then plan.freed[#plan.freed + 1] = k end
        end
    end
    if old ~= "" and old ~= cmd then
        local other = false
        for _, k in ipairs(KeysOf(old)) do
            if k ~= key then other = true end
        end
        if not other then plan.lost = old end
    end
    return plan
end

-- One line for the picker: "SHIFT-Q: Bar 2 button 1  >  Pet bar button 4."
function KeyEdit.Describe(plan)
    local C = ns.W and ns.W.C or {}
    if plan.same then return "Nothing changes." end
    local text = plan.key .. ": " .. KeyEdit.Name(plan.old) .. "  >  " .. (plan.cmd and KeyEdit.Name(plan.cmd) or "no key") .. "."
    if #plan.freed > 0 then
        text = text .. " " .. table.concat(plan.freed, ", ") .. (#plan.freed == 1 and " is" or " are") .. " freed."
    end
    if plan.lost then
        text = text .. "\n" .. (C.red or "") .. KeyEdit.Name(plan.lost) .. " loses its key." .. (C.r or "")
    end
    return text
end

------------------------------------------------------------------------
-- Backup: one entry per editing session, so /mlz undo puts all of it back at once
------------------------------------------------------------------------
local session

function KeyEdit.EndSession() session = nil end

-- Remembers the keys a change touches, before it happens. The first value of a key wins.
local function Remember(keys)
    local list = ns.db.backups
    local bindings = ns.modules.bindings
    if not (session and list and list[#list] == session) then
        local items = {}
        for _, k in ipairs(keys) do items[#items + 1] = { key = k, unbind = true } end
        session = ns.Backup:Create({ { mod = bindings, items = items } }, "keys")
        return session ~= nil
    end
    local snap = session.data.bindings
    for _, k in ipairs(keys) do
        if snap.keys[k] == nil then snap.keys[k] = Action(k) end
    end
    return true
end

local function Save()
    local set = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    pcall(SaveBindings, set)
end

-- Returns true, or nil and the reason (shown in the key map footer)
function KeyEdit.Apply(plan)
    if plan.same then return true end
    if InCombatLockdown() then return nil, "Keys can't change in combat. Try again after combat." end
    if not SetBinding then return nil, "This client can't change keys from an addon." end
    local touched = { plan.key }
    for _, k in ipairs(plan.freed) do touched[#touched + 1] = k end
    if not Remember(touched) then return nil, "Could not save a backup, so nothing was changed." end

    -- bind the new key first, so a key the game rejects leaves the action on its old keys
    local ok, result = pcall(SetBinding, plan.key, plan.cmd)
    if not ok or result == false then
        ns.Debug("KeyEdit: could not bind", plan.key, plan.cmd, ok and "" or result)
        return nil, "The game did not accept " .. plan.key .. " for " .. KeyEdit.Name(plan.cmd) .. "."
    end
    for _, k in ipairs(plan.freed) do pcall(SetBinding, k) end
    Save()
    -- remembered for export (Modules/Profile.lua): false = cleared on purpose. A key that only lost its action
    -- here is not locked: the wizard holds its default back while the action sits on the new key
    -- (Bindings:WithKeyEdits), and gives it back once the action moves on.
    ns.db.keyEdits = ns.db.keyEdits or {}
    for _, k in ipairs(plan.freed) do
        if ns.db.keyEdits[k] then ns.db.keyEdits[k] = nil end
    end
    ns.db.keyEdits[plan.key] = plan.cmd or false
    ns.FireState()
    return true
end
