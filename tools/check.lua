-- MLZ UI: repo checks
-- Checks the project rules from CLAUDE.md that luacheck can't see: TOC, versions, migrations,
-- formatting, writing style, no libraries, no Blizzard templates, theme colors and protected frames.
-- Run from anywhere with any Lua 5.1+: lua tools/check.lua. Prints file:line: message, exits 1 on problems.

local root = (arg and arg[0] or ""):match("^(.*)[/\\]tools[/\\]") or "."

local problems = {}
local function Problem(file, line, msg)
    problems[#problems + 1] = ("%s:%s: %s"):format(file, line or 1, msg)
end

local function Read(path)
    local f = io.open(root .. "/" .. path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function Exists(path)
    local f = io.open(root .. "/" .. path, "rb")
    if f then f:close() end
    return f ~= nil
end

local function Lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = l end
    if out[#out] == "" then out[#out] = nil end
    return out
end

-- Tracked files, so untracked junk and .git don't count
local function TrackedFiles()
    local p = io.popen('git -C "' .. root .. '" ls-files --cached --others --exclude-standard')
    local files = {}
    if p then
        for l in p:lines() do files[#files + 1] = l end
        p:close()
    end
    if #files == 0 then
        io.stderr:write("check.lua: git ls-files returned nothing (run inside the repo)\n")
        os.exit(2)
    end
    return files
end

local FILES = TrackedFiles()

local function IsText(path)
    return path:match("%.lua$") or path:match("%.md$") or path:match("%.toc$") or path:match("%.xml$")
        or path:match("%.ya?ml$") or path:match("%.sh$") or path:match("%.html$") or path:match("%.css$")
        or path:match("^%.[%w]+$") or path:match("/%.[%w]+$") or path:match("pre%-commit$")
end

-- Addon code that ships in the zip (not tests or tools)
local function IsAddonLua(path)
    return path:match("%.lua$") and not path:match("^tests/") and not path:match("^tools/")
        and path ~= ".luacheckrc"
end

------------------------------------------------------------------------
-- 1. TOC <-> files
------------------------------------------------------------------------
local TOC_NAME = "MLZ_UI.toc"
local toc = Read(TOC_NAME) or ""
local tocFiles, tocLine, meta = {}, {}, {}
for i, l in ipairs(Lines(toc)) do
    local key, value = l:match("^## ([%w%-]+):%s*(.-)%s*$")
    if key then
        meta[key] = { value = value, line = i }
    elseif l ~= "" and not l:match("^#") then
        local path = l:gsub("\\", "/")
        tocFiles[#tocFiles + 1] = path
        tocLine[path] = i
    end
end

for _, path in ipairs(tocFiles) do
    if not Exists(path) then Problem(TOC_NAME, tocLine[path], path .. " is listed but does not exist") end
end
for _, path in ipairs(FILES) do
    local inAddon = path:match("^[^/]+%.lua$") or path:match("^Data/[^/]+%.lua$")
        or path:match("^Modules/[^/]+%.lua$") or path:match("^UI/[^/]+%.lua$")
    if inAddon and path ~= ".luacheckrc" and not tocLine[path] then
        Problem(path, 1, "not listed in " .. TOC_NAME)
    end
end

-- Load order: Core, Probe, then Data, Modules (Backup first), UI (Widgets first)
if tocFiles[1] ~= "Core.lua" then Problem(TOC_NAME, 1, "Core.lua must load first") end
if tocFiles[2] ~= "Probe.lua" then Problem(TOC_NAME, 1, "Probe.lua must load second") end
local SECTION = { Data = 1, Modules = 2, UI = 3 }
local lastSection, firstIn = 0, {}
for _, path in ipairs(tocFiles) do
    local dir = path:match("^(%w+)/")
    local s = dir and SECTION[dir]
    if s then
        if s < lastSection then Problem(TOC_NAME, tocLine[path], path .. " is out of order (Data, Modules, UI)") end
        lastSection = s
        firstIn[dir] = firstIn[dir] or path
    end
end
if firstIn.Modules and firstIn.Modules ~= "Modules/Backup.lua" then
    Problem(TOC_NAME, tocLine[firstIn.Modules], "Modules/Backup.lua must be the first module")
end
if firstIn.UI and firstIn.UI ~= "UI/Widgets.lua" then
    Problem(TOC_NAME, tocLine[firstIn.UI], "UI/Widgets.lua must be the first UI file")
end
if not Exists("Bindings.xml") then Problem("Bindings.xml", 1, "missing") end
for _, key in ipairs({ "OptionalDeps", "Dependencies", "RequiredDeps" }) do
    if meta[key] then Problem(TOC_NAME, meta[key].line, "## " .. key .. ": MLZ UI has no dependencies") end
end

------------------------------------------------------------------------
-- 2. Version in all three places, and a changelog section
------------------------------------------------------------------------
local core = Read("Core.lua") or ""
local readme = Read("README.md") or ""
local changelog = Read("CHANGELOG.md") or ""
local tocVersion = meta.Version and meta.Version.value
local coreVersion = core:match('ns%.version%s*=%s*"([^"]+)"')
local badgeVersion = readme:match("badge/version%-([%w%.%-]-)%-%x%x%x%x%x%x")
if not tocVersion then Problem(TOC_NAME, 1, "## Version is missing") end
if coreVersion ~= tocVersion then
    Problem("Core.lua", 1, ("ns.version is %s, the toc says %s"):format(tostring(coreVersion), tostring(tocVersion)))
end
if badgeVersion ~= tocVersion then
    Problem("README.md", 1, ("version badge is %s, the toc says %s"):format(tostring(badgeVersion), tostring(tocVersion)))
end
local escaped = (tocVersion or ""):gsub("%p", "%%%0")
if not (changelog:match("\n## Unreleased") or changelog:match("^## Unreleased")
        or changelog:match("\n## " .. escaped .. "%f[%s]")) then
    Problem("CHANGELOG.md", 1, "needs a '## Unreleased' or '## " .. tostring(tocVersion) .. "' section")
end

------------------------------------------------------------------------
-- 3. Every DB_VERSION has a migration step
------------------------------------------------------------------------
local dbVersion = tonumber(core:match("local DB_VERSION%s*=%s*(%d+)"))
if not dbVersion then
    Problem("Core.lua", 1, "local DB_VERSION = N not found")
elseif dbVersion > 1 and not core:match("%[" .. dbVersion .. "%]%s*=%s*function") then
    Problem("Core.lua", 1, ("DB_VERSION is %d but migrations[%d] is missing"):format(dbVersion, dbVersion))
end

------------------------------------------------------------------------
-- 4-9. Per-file checks
------------------------------------------------------------------------
-- Blizzard templates we replace with W.* widgets (GameTooltipTemplate for the scan tooltip is fine)
local TEMPLATES = {
    "UIPanelButtonTemplate", "UIPanelCloseButton", "BasicFrameTemplate", "BasicFrameTemplateWithInset",
    "ButtonFrameTemplate", "PortraitFrameTemplate", "InsetFrameTemplate", "InputBoxTemplate",
    "OptionsSliderTemplate", "UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate",
    "ChatConfigCheckButtonTemplate", "UIPanelScrollFrameTemplate", "UIDropDownMenuTemplate",
    "TooltipBorderedFrameTemplate", "DialogBoxFrame", "UIPanelDialogTemplate",
}

-- Protected Blizzard frames: only SetAlpha and safe hooks (hard rule 1)
local PROTECTED = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyMemberFrame%d*", "MainMenuBar",
    "MainActionBar", "MultiBar%w+", "ActionButton%d+", "StanceBar", "PetActionBar", "EditModeManagerFrame",
    "CompactRaidFrame%w*", "CompactPartyFrame", "ObjectiveTrackerFrame", "QuestWatchFrame",
}
local FORBIDDEN_CALLS = { "Hide", "SetPoint", "ClearAllPoints", "SetParent", "SetAllPoints" }

local function CheckLuaLine(path, i, l)
    local code = l:gsub("%-%-.*$", "") -- good enough: our strings rarely contain "--"
    if code:match("LibStub") or code:match("AceAddon") or code:match("AceGUI") then
        Problem(path, i, "no libraries (hard rule 2)")
    end
    for _, t in ipairs(TEMPLATES) do
        if code:match('"' .. t .. '"') then Problem(path, i, t .. ": use the W.* widgets instead") end
    end
    for _, name in ipairs(PROTECTED) do
        for _, call in ipairs(FORBIDDEN_CALLS) do
            if code:match("%f[%w_]" .. name .. "[%w_%.]*:" .. call .. "%(") then
                Problem(path, i, name .. ":" .. call .. "() taints a protected frame (hard rule 1, use SetAlpha)")
            end
        end
    end
    if path ~= "UI/Widgets.lua" then
        if code:match("|c%x%x%x%x%x%x%x%x") then
            Problem(path, i, "fixed color code: use W.C from UI/Widgets.lua")
        end
        local args = code:match("Set%a*Color%a*%(%s*([%d%.]+%s*,[^%)]*)%)")
        if args then
            local normalized = args:gsub("%s", "")
            if normalized ~= "1,1,1" and normalized ~= "1,1,1,1" then
                Problem(path, i, "fixed color values: use W.T from UI/Widgets.lua")
            end
        end
    end
end

for _, path in ipairs(FILES) do
    if IsText(path) then
        local text = Read(path)
        if text then
            if text:find("\r", 1, true) then Problem(path, 1, "CRLF line endings (use LF)") end
            if #text > 0 and text:sub(-1) ~= "\n" then Problem(path, #Lines(text), "no newline at end of file") end
            local isMd = path:match("%.md$")
            for i, l in ipairs(Lines(text)) do
                if path:match("%.lua$") and l:find("\t", 1, true) then Problem(path, i, "tab (use 4 spaces)") end
                if not isMd and l:match("[ \t]+$") then Problem(path, i, "trailing whitespace") end
                if l:find("\226\128\148", 1, true) then Problem(path, i, "em dash (use a period, comma or colon)") end
                if IsAddonLua(path) then CheckLuaLine(path, i, l) end
            end
        end
    end
end

for _, path in ipairs(FILES) do
    if path:match("^Libs/") then Problem(path, 1, "no libraries (hard rule 2)") break end
end

------------------------------------------------------------------------
if #problems > 0 then
    table.sort(problems)
    for _, p in ipairs(problems) do print(p) end
    print(("Repo check: %d problem(s)"):format(#problems))
    os.exit(1)
end
print(("Repo check: OK (%d files, version %s, DB_VERSION %s)"):format(#FILES, tostring(tocVersion), tostring(dbVersion)))
