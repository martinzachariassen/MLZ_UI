-- MLZ UI: Your character (wizard step)
-- Shows the class and role MLZ UI detected and lets the player confirm or change it. Applying saves the choice
-- as "My role" (the same setting as /mlz > Your role). Undo gives the old choice back.

local _, ns = ...

local Role = ns.RegisterModule({ key = "role", title = "Your character" })

-- The choice made in the wizard but not applied yet: "auto" | "TANK" | "HEALER" | "DAMAGER" | nil
function Role:BeginWizard()
    self.pending = nil
end

-- Steps whose preview depends on the role picked here (the wizard builds them again after a change)
Role.dependents = { "settings" }

-- The role the rest of the wizard should plan for: your pending choice, else what is saved
function ns.WizardRole()
    local pending = Role.pending
    -- A choice that will not be applied (step skipped or row unticked) must not shape the other steps
    local wizard = ns.Installer
    if pending and wizard and wizard.stepOn then
        local item = wizard.items and wizard.items.role and wizard.items.role[1]
        if wizard.stepOn.role == false or (item and not item.enabled) then pending = nil end
    end
    if pending == "auto" then return (ns.Role(true)) end
    if pending then return pending end
    return (ns.Role())
end

local function Choices()
    local role, source = ns.Role(true)
    local arch = ns.Archetype(true)
    local auto = ("Auto: %s (%s)"):format(ns.ArchetypeText(arch), ns.SOURCE_TEXT[source] or tostring(source))
    return {
        { value = "auto", text = auto },
        { value = "TANK", text = ns.ROLE_TEXT.TANK },
        { value = "HEALER", text = ns.ROLE_TEXT.HEALER },
        { value = "DAMAGER", text = ns.ROLE_TEXT.DAMAGER },
    }, role
end

function Role:Preview()
    local choices = Choices()
    local saved = ns.GetRoleForce() or "auto"
    local chosen = self.pending or saved
    local idx = 1
    for i, c in ipairs(choices) do
        if c.value == chosen then idx = i end
    end
    local savedIdx = 1
    for i, c in ipairs(choices) do
        if c.value == saved then savedIdx = i end
    end
    return {
        {
            id = "role", label = (UnitClass("player") or "Your") .. " role", group = "Your character",
            old = choices[savedIdx].text, new = choices[idx].text, value = chosen,
            choices = choices, choiceIndex = idx,
            enabled = ns.Enabled("role", "role", true),
            alreadySet = chosen == saved,
            keepVisible = true,
            note = "Tank, healer and DPS get different nameplates, role layouts and a few game settings. "
                .. "Auto reads your talents, form and group role. Pick a role if the detected one is wrong. "
                .. "Click the value to change it (right-click goes back). You can change this later in /mlz.",
        },
    }
end

function Role:OnChoice(item)
    self.pending = item.value
    item.alreadySet = item.value == (ns.GetRoleForce() or "auto")
end

function Role:Backup()
    return { forced = ns.GetRoleForce() or false }
end

function Role:Apply(items)
    local item = items[1]
    if not item then return end
    ns.SetRoleForce(item.value ~= "auto" and item.value or nil)
    self.pending = nil
end

function Role:Restore(snap)
    ns.SetRoleForce(snap.forced or nil)
end
