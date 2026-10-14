-- MLZ UI: Keybinds
-- Builds the desired bindings from Data/Bindings.lua, finds conflicts with current bindings
-- and moves displaced actions (e.g. Character panel on C) to the ALT variant.

local _, ns = ...

local Bindings = ns.RegisterModule({ key = "bindings", title = "Keybinds" })

local MOVEMENT_ID = "__movement"

local function Pretty(command)
    if not command or command == "" then return "" end
    return _G["BINDING_NAME_" .. command] or command
end

local function CurrentAction(key)
    local action = GetBindingAction(key)
    if action == nil then return "" end
    return action
end

-- Returns a list of { key, command, group, role } for the chosen movement setup
function Bindings:Desired(movement)
    local D = ns.data.bindings
    movement = D.movement[movement] and movement or "ESDF"
    local list = {}
    for _, b in ipairs(D.movement[movement]) do
        list[#list + 1] = { key = b.key, command = b.command, group = "Movement (" .. movement .. ")" }
    end
    local keys = D.baseKeys[movement]
    local class = ns.PlayerClass()
    local c = ns.data.classes and ns.data.classes[class]
    local hasStances = c and c.stance
    local hints = D.classRoles and D.classRoles[class] or {}
    local stance = (hasStances and D.stance and D.stance[movement]) or {}
    local stanceKeys = {}
    for _, b in ipairs(stance) do stanceKeys[b.key] = true end
    local relocate = D.stanceRelocate and D.stanceRelocate[movement] or {}
    for _, layer in ipairs(D.layers) do
        for i, k in ipairs(keys) do
          local full = layer.modifier .. k
          if stanceKeys[full] then full = relocate[full] end -- stance keys win; the bar button gets a replacement key
          if full then
            list[#list + 1] = {
                key = full,
                command = layer.prefix .. i,
                group = layer.bar .. (layer.modifier ~= "" and (" (" .. layer.modifier:sub(1, -2) .. ")") or ""),
                role = layer.modifier == "" and (hints[i] or D.roles[i]) or nil,
            }
          end
        end
    end
    for i, b in ipairs(stance) do
        list[#list + 1] = { key = b.key, command = b.command, group = "Stances / forms", role = "Stance " .. i }
    end
    if c and c.pet and D.pet and D.pet[movement] then
        for _, b in ipairs(D.pet[movement]) do
            list[#list + 1] = { key = b.key, command = b.command, group = "Pet", role = b.role }
        end
    end
    for _, b in ipairs(D.mouse) do
        list[#list + 1] = { key = b.key, command = b.command, group = "Bar 4 (mouseover)" }
    end
    return list
end

-- What the movement keys are bound to right now (for the "Current" column)
local function CurrentMovement()
    for _, k in ipairs({ GetBindingKey("MOVEFORWARD") }) do
        if k == "E" then return "ESDF" end
        if k == "W" then return "WASD" end
    end
    return "custom"
end

-- The movement choice is only saved on Apply. Until then it lives here, so closing the
-- wizard without applying leaves the saved setup alone.
function Bindings:BeginWizard()
    self.pendingMovement = nil
end

function Bindings:Preview()
    local D = ns.data.bindings
    local movement = self.pendingMovement or ns.db.movement or "ESDF"
    local desired = self:Desired(movement)

    local desiredKeys, desiredCommands = {}, {}
    for _, d in ipairs(desired) do
        desiredKeys[d.key] = true
        desiredCommands[d.command] = true
    end

    local items = {}

    -- Movement choice (not a binding in itself)
    local mchoices, midx = {}, 1
    local names = { "ESDF", "WASD" }
    for i, n in ipairs(names) do
        mchoices[i] = { value = n, text = n }
        if n == movement then midx = i end
    end
    items[#items + 1] = {
        id = MOVEMENT_ID, label = "Movement", group = "Setup",
        old = CurrentMovement(), new = movement, value = movement, choices = mchoices, choiceIndex = midx,
        enabled = true, fixed = true,
        note = "ESDF gives more keys around your fingers. Click the value to switch (the list updates).",
    }

    local displacedTargets = {}
    for _, d in ipairs(desired) do
        local current = CurrentAction(d.key)
        local item = {
            id = d.key, key = d.key, command = d.command, group = d.group,
            label = d.key .. (d.role and ("  |cff888888" .. d.role .. "|r") or ""),
            old = Pretty(current), new = Pretty(d.command),
            enabled = ns.Enabled("bindings", d.key, true),
            alreadySet = current == d.command,
            conflict = current ~= "" and current ~= d.command,
        }
        items[#items + 1] = item

        -- Displaced action? Move it to the ALT variant if possible.
        local isBarCommand = false
        for _, layer in ipairs(D.layers) do
            if current:find("^" .. layer.prefix .. "%d+$") then isBarCommand = true end
        end
        if item.conflict and not desiredCommands[current] and not D.neverDisplace[current] and not isBarCommand then
            local hasOtherKey = false
            for _, k in ipairs({ GetBindingKey(current) }) do
                if k and not desiredKeys[k] then hasOtherKey = true end
            end
            if not hasOtherKey then
                local newKey = D.displaceModifier .. d.key
                if not desiredKeys[newKey] and not displacedTargets[newKey] and CurrentAction(newKey) == "" then
                    displacedTargets[newKey] = true
                    items[#items + 1] = {
                        id = newKey, key = newKey, command = current, group = "Moved actions",
                        label = newKey, old = "", new = Pretty(current) .. "  |cff888888(was " .. d.key .. ")|r",
                        enabled = ns.Enabled("bindings", newKey, true), displaced = true, requires = d.key,
                        note = "Only moved if " .. d.key .. " is changed above.",
                    }
                else
                    items[#items + 1] = {
                        id = "lost:" .. d.key, group = "Moved actions",
                        label = d.key, old = Pretty(current), new = "loses key",
                        enabled = false, unavailable = true, requires = d.key,
                        note = newKey .. " is taken. Set a new key for this in Blizzard's keybinding menu if you need it.",
                    }
                end
            end
        end
    end

    -- Extra keys on our action buttons (e.g. Blizzard's default 9/0/-/= on buttons 9-12).
    -- Blizzard only shows the FIRST key on the button, so they must be removed for the right key to show.
    for _, d in ipairs(desired) do
        if d.command:find("BUTTON%d+$") then
            for _, k in ipairs({ GetBindingKey(d.command) }) do
                if k and k ~= d.key and not desiredKeys[k] then
                    items[#items + 1] = {
                        id = "unbind:" .. k, key = k, unbind = true, group = "Extra keys to remove",
                        label = k, old = Pretty(d.command), new = "none",
                        enabled = ns.Enabled("bindings", "unbind:" .. k, true), requires = d.key,
                        note = "The button already has " .. d.key .. ". With two keys Blizzard only shows the first, so " ..
                               d.key .. " would not be visible on the button.",
                    }
                end
            end
        end
    end
    -- Action bar paging (wheel/shift scrolling bar 1 through its pages): remove every remaining key
    local pageCommands = { "NEXTACTIONPAGE", "PREVIOUSACTIONPAGE" }
    for i = 1, 6 do pageCommands[#pageCommands + 1] = "ACTIONPAGE" .. i end
    for _, cmd in ipairs(pageCommands) do
        for _, k in ipairs({ GetBindingKey(cmd) }) do
            if k and not desiredKeys[k] then
                items[#items + 1] = {
                    id = "unbind:" .. k, key = k, unbind = true, group = "Extra keys to remove",
                    label = k, old = Pretty(cmd), new = "none",
                    enabled = ns.Enabled("bindings", "unbind:" .. k, true),
                    note = "Stops bar 1 from scrolling to another page (mouse wheel / shift).",
                }
            end
        end
    end
    return items
end

function Bindings:OnChoice(item)
    if item.id == MOVEMENT_ID then
        self.pendingMovement = item.value
        return true -- rebuild the list
    end
end

local function BindingItems(items)
    local out = {}
    for _, item in ipairs(items) do
        if item.key and (item.command or item.unbind) and not item.unavailable then out[#out + 1] = item end
    end
    return out
end

function Bindings:Backup(items)
    local snap = { set = GetCurrentBindingSet and GetCurrentBindingSet() or nil, keys = {}, movement = ns.db.movement }
    for _, item in ipairs(BindingItems(items)) do
        snap.keys[item.key] = CurrentAction(item.key)
    end
    return snap
end

local function Save(set)
    set = set or (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    SaveBindings(set)
end

function Bindings:Apply(items)
    local n = 0
    local list = BindingItems(items)
    -- Remove extra keys first, so the new bindings are alone on the buttons
    for _, item in ipairs(list) do
        if item.unbind then pcall(SetBinding, item.key) end
    end
    for _, item in ipairs(list) do
        if not item.unbind then
            local ok, result = pcall(SetBinding, item.key, item.command)
            if ok and result ~= false then
                n = n + 1
            else
                ns.Print("|cffff4444Could not bind|r", item.key, "->", item.command, ok and "" or result)
            end
        end
    end
    Save()
    for _, item in ipairs(items) do
        if item.id == MOVEMENT_ID then ns.db.movement = item.value end
    end
    self.pendingMovement = nil
    ns.Debug("bindings set:", n)
end

function Bindings:Restore(snap)
    -- First unbind all keys we touched, then restore the old actions. One bad key must not
    -- stop the rest, and the result is always saved.
    for key in pairs(snap.keys or {}) do pcall(SetBinding, key) end
    for key, action in pairs(snap.keys or {}) do
        if action ~= "" then pcall(SetBinding, key, action) end
    end
    pcall(Save, snap.set)
    if snap.movement then ns.db.movement = snap.movement end
end
