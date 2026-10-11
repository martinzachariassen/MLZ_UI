-- MLZ UI: Health check
-- After login: warns once if an addon MLZ UI configures is installed but not loaded
-- (usually switched off in the addon list by mistake). Addons you don't have are not mentioned.
-- /mlz health lists everything, including supported addons that aren't installed.

local _, ns = ...

-- Addons that are expected besides the ones listed in Data/Addons.lua
local EXTRA = {
    { addon = "Platynator", title = "Platynator" },
    { addon = "!BugGrabber", title = "BugGrabber" },
}

local function Installed(addon)
    if C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist(addon) end
    local name = C_AddOns.GetAddOnInfo(addon)
    return name ~= nil
end

-- onlyInstalled = skip addons that aren't installed at all (the login check)
local function Problems(onlyInstalled)
    local list = {}
    local function Check(addon, title)
        if C_AddOns.IsAddOnLoaded(addon) then return end
        local exists = Installed(addon)
        if onlyInstalled and not exists then return end
        list[#list + 1] = title .. (exists and " (installed but not loaded, check the addon list)" or " (not installed)")
    end
    for _, entry in ipairs(ns.data.addons) do Check(entry.addon, entry.title) end
    for _, entry in ipairs(EXTRA) do Check(entry.addon, entry.title) end
    return list
end

local function Report(quiet)
    local list = Problems(quiet)
    if #list == 0 then
        if not quiet then ns.Print("Health: all supported addons are loaded.") end
        return
    end
    ns.Print("|cffff8800Health:|r " .. #list .. (quiet and " addon(s) installed but not loaded:" or " addon(s) missing or not loaded:"))
    for _, line in ipairs(list) do DEFAULT_CHAT_FRAME:AddMessage("  - " .. line) end
end

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(8, function() ns.Try(Report, true) end)
end)

ns.AddCommand("health", "checks that the supported addons are installed and loaded", function() Report(false) end)
