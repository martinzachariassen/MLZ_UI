-- MLZ UI: Health check
-- Warns once after login if an addon MLZ UI configures is missing or not loaded.
-- /mlz health runs the same check on demand.

local _, ns = ...

-- Addons that are expected besides the ones listed in Data/Addons.lua
local EXTRA = {
    { addon = "Platynator", title = "Platynator" },
    { addon = "!BugGrabber", title = "BugGrabber" },
}

local function Problems()
    local list = {}
    local function Check(addon, title)
        if C_AddOns.IsAddOnLoaded(addon) then return end
        local exists = C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(addon)
        list[#list + 1] = title .. (exists and " (installed but not loaded, check the addon list)" or " (not installed)")
    end
    for _, entry in ipairs(ns.data.addons) do Check(entry.addon, entry.title) end
    for _, entry in ipairs(EXTRA) do Check(entry.addon, entry.title) end
    return list
end

local function Report(quiet)
    local list = Problems()
    if #list == 0 then
        if not quiet then ns.Print("Health: all supported addons are loaded.") end
        return
    end
    ns.Print("|cffff8800Health:|r " .. #list .. " addon(s) missing or not loaded:")
    for _, line in ipairs(list) do DEFAULT_CHAT_FRAME:AddMessage("  - " .. line) end
end

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(8, function() ns.Try(Report, true) end)
end)

ns.AddCommand("health", "checks that the supported addons are installed and loaded", function() Report(false) end)
