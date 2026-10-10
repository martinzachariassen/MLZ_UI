-- MLZ UI: Keybinds
-- Bygger ønskede bindings fra Data/Bindings.lua, finner konflikter med dagens bindings
-- og flytter fortrengte handlinger (f.eks. Character-panel på C) til ALT-varianten.

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

-- Returnerer liste med { key, command, group, role } for valgt bevegelsesoppsett
function Bindings:Desired(movement)
    local D = ns.data.bindings
    movement = D.movement[movement] and movement or "ESDF"
    local list = {}
    for _, b in ipairs(D.movement[movement]) do
        list[#list + 1] = { key = b.key, command = b.command, group = "Bevegelse (" .. movement .. ")" }
    end
    local keys = D.baseKeys[movement]
    for _, layer in ipairs(D.layers) do
        for i, k in ipairs(keys) do
            list[#list + 1] = {
                key = layer.modifier .. k,
                command = layer.prefix .. i,
                group = layer.bar .. (layer.modifier ~= "" and (" (" .. layer.modifier:sub(1, -2) .. ")") or ""),
                role = layer.modifier == "" and D.roles[i] or nil,
            }
        end
    end
    for _, b in ipairs(D.mouse) do
        list[#list + 1] = { key = b.key, command = b.command, group = "Bar 4 (mus)" }
    end
    return list
end

function Bindings:Preview()
    local D = ns.data.bindings
    local movement = ns.db.movement or "ESDF"
    local desired = self:Desired(movement)

    local desiredKeys, desiredCommands = {}, {}
    for _, d in ipairs(desired) do
        desiredKeys[d.key] = true
        desiredCommands[d.command] = true
    end

    local items = {}

    -- Valg av bevegelse (ikke en binding i seg selv)
    local mchoices, midx = {}, 1
    local names = { "ESDF", "WASD" }
    for i, n in ipairs(names) do
        mchoices[i] = { value = n, text = n }
        if n == movement then midx = i end
    end
    items[#items + 1] = {
        id = MOVEMENT_ID, label = "Bevegelse", group = "Oppsett",
        old = "", new = movement, value = movement, choices = mchoices, choiceIndex = midx,
        enabled = true, rebuild = true,
        note = "ESDF gir flere taster rundt fingrene. Klikk verdien for å bytte (listen oppdateres).",
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

        -- Fortrengt handling? Flytt til ALT-varianten hvis mulig.
        if item.conflict and not desiredCommands[current] and not D.neverDisplace[current] then
            local hasOtherKey = false
            for _, k in ipairs({ GetBindingKey(current) }) do
                if k and not desiredKeys[k] then hasOtherKey = true end
            end
            if not hasOtherKey then
                local newKey = D.displaceModifier .. d.key
                if not desiredKeys[newKey] and not displacedTargets[newKey] and CurrentAction(newKey) == "" then
                    displacedTargets[newKey] = true
                    items[#items + 1] = {
                        id = newKey, key = newKey, command = current, group = "Flyttede handlinger",
                        label = newKey, old = "", new = Pretty(current) .. "  |cff888888(var " .. d.key .. ")|r",
                        enabled = item.enabled, displaced = true,
                    }
                else
                    items[#items + 1] = {
                        id = "lost:" .. d.key, group = "Flyttede handlinger",
                        label = d.key, old = Pretty(current), new = "mister tast",
                        enabled = false, unavailable = true,
                        note = newKey .. " er opptatt. Sett en ny tast for denne i Blizzards keybind-meny om du trenger den.",
                    }
                end
            end
        end
    end

    -- Ekstra taster på action-knappene våre (f.eks. Blizzards standard 9/0/-/= på knapp 9-12).
    -- Blizzard viser bare den FØRSTE tasten på knappen, så de må bort for at riktig tast skal vises.
    for _, d in ipairs(desired) do
        if d.command:find("BUTTON%d+$") then
            for _, k in ipairs({ GetBindingKey(d.command) }) do
                if k and k ~= d.key and not desiredKeys[k] then
                    items[#items + 1] = {
                        id = "unbind:" .. k, key = k, unbind = true, group = "Ekstra taster som fjernes",
                        label = k, old = Pretty(d.command), new = "ingen",
                        enabled = ns.Enabled("bindings", "unbind:" .. k, true),
                        note = "Knappen har allerede " .. d.key .. ". Med to taster viser Blizzard bare den første, så " ..
                               d.key .. " ville ikke synes på knappen.",
                    }
                end
            end
        end
    end
    return items
end

function Bindings:OnChoice(item)
    if item.id == MOVEMENT_ID then
        ns.db.movement = item.value
        return true -- bygg listen på nytt
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
    local snap = { set = GetCurrentBindingSet and GetCurrentBindingSet() or nil, keys = {} }
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
    -- Fjern ekstra taster først, så de nye bindingene står alene på knappene
    for _, item in ipairs(list) do
        if item.unbind then pcall(SetBinding, item.key) end
    end
    for _, item in ipairs(list) do
        if item.unbind then
            -- allerede gjort
        else
        local ok, result = pcall(SetBinding, item.key, item.command)
        if ok and result ~= false then
            n = n + 1
        else
            ns.Print("|cffff4444Kunne ikke binde|r", item.key, "->", item.command, ok and "" or result)
        end
        end
    end
    Save()
    ns.Debug("bindings satt:", n)
end

function Bindings:Restore(snap)
    -- Først løs alle tastene vi rørte, så legg tilbake de gamle handlingene
    for key in pairs(snap.keys) do SetBinding(key) end
    for key, action in pairs(snap.keys) do
        if action ~= "" then SetBinding(key, action) end
    end
    Save(snap.set)
end
