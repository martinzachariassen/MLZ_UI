# Architecture

How MLZ UI is put together. For conventions and style, see [`CLAUDE.md`](../CLAUDE.md).

## Project layout

```
MLZ_UI/
├── MLZ_UI.toc            Load order, interface version, SavedVariables (MLZUIDB)
├── Bindings.xml          Key Bindings entry (pull timer), loaded by the game
├── Core.lua              Namespace, events, combat queue, state, roles, commands, migrations
├── Probe.lua             /mlz probe: dumps client facts to SavedVariables
├── Data/                 WHAT to set (plain tables, no logic)
│   ├── CVars.lua
│   ├── Bindings.lua
│   ├── Classes.lua       The 9 WoW Forever classes: talent trees, archetypes, stance and pet bars
│   ├── Layout.lua
│   ├── Fade.lua
│   ├── Nameplates.lua
│   ├── Addons.lua
│   ├── Reminders.lua     Self buffs, reagents, food and group buffs per class
│   ├── Tips.lua          Tips for the overview card
│   ├── Cooking.lua       Which dishes each cooking ingredient makes
│   └── Search.lua        Aliases, stopwords and examples for the control center search
├── Modules/              HOW to set it (one feature per file)
│   ├── Backup.lua        Backup stack, apply order, undo (loads first)
│   ├── Role.lua          "Your character" wizard step: confirm or change your role
│   ├── Scale.lua  Settings.lua  Bindings.lua  Layout.lua  Healer.lua
│   ├── Fade.lua  ActionButtons.lua  Tweaks.lua  Plates.lua  Nameplates.lua  Addons.lua
│   ├── Health.lua        Addon state and versions, switch addons on, /mlz health
│   ├── Vendor.lua  Automate.lua  Group.lua  ManaTick.lua  Interrupt.lua
│   ├── Profile.lua       Export/import, role profiles, situation profiles
│   └── Reminders.lua  XPRate.lua  Cooking.lua
├── UI/
│   ├── Widgets.lua       Theme tokens (W.T, W.C), fonts and every widget
│   ├── Installer.lua     Setup wizard
│   ├── Settings.lua      Control center (/mlz), including the overview tips
│   ├── MinimapButton.lua Minimap button, tooltip, quick menu
│   ├── Keys.lua          Keyboard map of your keybinds (/mlz keys)
│   └── Tour.lua          "Show me around" tour over the faded frames (/mlz tour)
├── Media/                Roboto Bold + license
├── docs/
│   ├── ARCHITECTURE.md
│   ├── mockups/          HTML sources for the README images + render.sh
│   └── screenshots/      Rendered PNGs used by the README
├── .github/workflows/    lint.yml (luacheck on main and pull requests), release.yml (packages a tag)
├── .luacheckrc           Lint config, including every WoW API global we use
├── .pkgmeta              Packager config: what the release zip leaves out
├── CHANGELOG.md
└── LICENSE
```

## Load order

`MLZ_UI.toc` loads files top to bottom:

1. `Core.lua` creates the shared namespace and helpers.
2. `Probe.lua`
3. `Data/*` fills `ns` with plain configuration tables.
4. `Modules/*`, with `Backup.lua` first, so other modules can rely on `ns.Backup`.
5. `UI/*`, with `Widgets.lua` first, since the wizard, control center and minimap button are built from it.

A new file only loads once it is listed in the `.toc`.

Every file starts with `local _, ns = ...`. `ns` is shared by all files of the addon. It is also exposed as the global `MLZUI` for debugging in `/dump`.

## Data vs modules

- **`Data/`** describes *what* we want: CVar values, key lists, frame positions, fade rules and settings for other addons. No API calls and no logic.
- **`Modules/`** knows *how* to read the current state, compare it with the data, apply it and put it back.

Changing a default should normally only touch `Data/`.

## Module contract

Modules that take part in the wizard register with Core:

```lua
local Tweaks = ns.RegisterModule({ key = "tweaks", title = "Tweaks" })

function Tweaks:Preview()        -- returns a list of items (one row each in the wizard)
function Tweaks:Backup(items)    -- returns a snapshot of the current values for those items
function Tweaks:Apply(items)     -- applies the ticked items; returns nil, or a short text when part of it failed
function Tweaks:Restore(snap)    -- puts a snapshot back
```

A preview item is a table with at least `id`, `label`, `old` and `new`. Optional fields include `group`, `groupNote`, `note`, `enabled`, `toggle`/`isOn`, `behaviour` (changes how the game plays, drawn in amber), `keepVisible`, and `unavailable = true` with the reason in `new` (e.g. "tracker not found"). `attention = true` on an unavailable row keeps it in the list, in amber (a key that will be lost). The wizard draws one row per item, as *now → will become*.

If `Apply` returns a text, the last wizard page shows the step as "PARTLY" with that text. A module can set `dependents = { "settings" }`: those steps are previewed again when a choice in this one changes (the role step does this).

Wizard steps and modules are not 1:1. `PAGES` in `UI/Installer.lua` lists the 8 steps, and a step can hold several modules with `keys = { "actionbuttons", "tweaks" }` (plus optional `groups` headings per module). Each module still has its own row toggles (`ns.db.toggles[key]`), backup and place in `APPLY_ORDER`. "Use this step" turns all of the step's modules on or off, and the review lists changes in step order. A new module joins an existing step by adding its key there.

Rules:
- `Preview` must not change anything.
- `Backup` must capture everything `Apply` is about to change.
- `Restore` must work on a snapshot from an older version of the addon, or skip it safely.
- `Restore` may `error()` when it can't put everything back (an addon is switched off, Platynator is missing). `Backup:Undo` then keeps that module's snapshot for a later retry, so strip the parts that were restored before you raise the error.
- Anything that touches protected frames or bindings goes through `ns.RunOutOfCombat`.

Feature-only modules (`Vendor`, `Automate`, `Group`, `ManaTick`, `Interrupt`, `Health`, `Healer`, `Plates`, `Reminders`, `XPRate`, `Cooking`) don't register. They hook events through `ns.On` and expose a small table on `ns` (e.g. `ns.Vendor`) for the control center. Their settings live in a lazily filled `ns.db.<key>` table (`DEFAULTS` plus `Cfg()`). Automations that act for you (Fewer clicks, Group) are off by default, and SHIFT skips an automation once. Passive helpers such as repair, sell greys, the durability reminder and the cooking tooltip start on.

`Profile` registers as a module (so an import can be undone) but is not in `APPLY_ORDER`: it only runs through `/mlz import`.

`Bindings.xml` sits next to the `.toc` and is loaded by the game, not listed in the `.toc`. Its names come from `BINDING_HEADER_MLZUI` and `BINDING_NAME_MLZUI_*` in `Modules/Group.lua`.

Export strings start with `MLZ!2!` (`MLZ!1!` still imports). `Validate` in `Modules/Profile.lua` lets only known keys with the right types through. A new exported key needs a line there, in `Profile:Backup` and in `Profile:Restore`.

## Settings for other addons

`Data/Addons.lua` has one entry per addon and `Modules/Addons.lua` reads, backs up, writes and restores the rows. Settings go straight into the addon's own saved variables, so a row only works for the version you have installed. Check key names against the addon's source before you add one. A row can carry `minVersion`/`maxVersion` (compared with the version in the addon's `.toc`) and an entry can carry `tested`, the newest version its rows were checked with.

- **Entry:** `addon` (folder name), optional `alt` (a port that installs under another folder name, e.g. `CliqueForever`), `title`, `root` (function returning the table that `path` starts from), `live = true` when the addon reads the value while it runs (no reload), and `manual = "text"` when the addon overwrites outside changes at logout (the rows are shown but never written).
- **Row:** `id`, `label`, `desc`, and either `path` + `value` or `set = { { path, value }, ... }` with `show` for the wizard text. `enabled = false` lists the row but leaves it unticked.
- **Role filter:** a row can carry `roles = { HEALER = true }` (TANK, HEALER, DAMAGER) and/or `archetypes = { CASTER = true }` (TANK, HEALER, MELEE, RANGED, CASTER). It then only shows for that role. The filter uses the role you picked in the wizard (`ns.Role`, `ns.Archetype`), not the live one, so a stance change never swaps another addon's settings. Two rows that exclude each other in the addon (Questie hide and minimize in combat) get one row per role.
- **Errors:** `Apply` counts keys it could not write and returns a short text, so the wizard shows the step as PARTLY.

Platynator does not go through this table. `Modules/Nameplates.lua` builds a changed copy of the current profile and imports it through Platynator's own API. `presets` in `Data/Nameplates.lua` set keys per mode, and `archetypePresets` add keys for DPS modes depending on your archetype.

## Apply and undo flow

```
Wizard "Apply"
  └─ Backup:Create(selections)      every module snapshots what it will change
       └─ pushed onto MLZUIDB.backups (max 5, #1 is always kept: your pre-MLZ state)
  └─ modules apply in Backup.APPLY_ORDER
       role → scale → settings → layout → bindings → fade → actionbuttons → tweaks → addons → nameplates
  └─ ns.MarkReload(reason) only if a /reload is really needed, ns.MarkEditModeStale() for layouts

/mlz undo
  └─ pops the newest backup
  └─ Restore runs in reverse apply order (modules not in the list go last)
  └─ waits for combat to end if needed
```

`/mlz import` also takes a backup first (`kind = "import"`), so an import can be undone the same way.

## Core helpers

Use these before writing your own.

| Helper | Use for |
|---|---|
| `ns.On(event, fn)` · `ns.TryOn(event, fn)` | Event bus. `TryOn` skips events the client doesn't have. |
| `ns.RunOutOfCombat(fn, label, quiet)` | Run now, or queue until combat ends. A newer job with the same label replaces the old one. |
| `ns.FireState()` · `ns.OnState(fn)` | Tell the UI that something changed, so open pages refresh. |
| `ns.MarkReload(reason)` | Flag that a `/reload` is truly needed (e.g. an addon that only reads its settings at load). The reason shows in the footer and overview. Prefer applying live. |
| `ns.MarkEditModeStale()` | MLZ UI changed Edit Mode layouts. Frames already moved, but Edit Mode keeps an old copy until a reload, so a guard warns if the player opens Edit Mode before reloading. |
| `ns.Error(where, err)` | Report an error once per session. Repeats only go to `ns.Debug`. |
| `ns.Enabled(mod, id, default)` · `ns.SetEnabled` | Remember which wizard rows are ticked. |
| `ns.Try(fn, ...)` | `pcall` wrapper for APIs that may not exist or may fail. |
| `ns.IsAddOnLoaded(name)` · `ns.IsAddOnInstalled(name)` | Addon checks that work across client APIs. |
| `ns.Role()` · `ns.LiveRole()` · `ns.SetRoleForce` · `ns.GetRoleForce` · `ns.OnRoleChanged(fn)` | Role detection (tank, healer, DPS) and overrides. `ns.Role(true)` ignores your own choice (what the game detects). `LiveRole` is what you do right now (Bear Form, Defensive Stance, Righteous Fury) and never overrides a role you picked. `ns.WizardRole()` (in `Modules/Role.lua`) is the role the wizard plans for, including a choice not applied yet. |
| `ns.Archetype()` · `ns.LiveArchetype()` · `ns.ArchetypeText(a)` | Tank, healer, melee, ranged or caster, from `Data/Classes.lua`. Layouts use the stable one, reminders and nameplates the live one. |
| `ns.ClientInfo()` | Game client facts for the About page. WoW Forever (Interface 16001) is the supported client. |
| `ns.CharDB()` · `ns.CharKey()` | Per-character table inside `MLZUIDB.chars`, and its key (`Name - Realm`). |
| `ns.AddCommand(name, help, fn)` · `ns.RunCommand(name, arg)` | Add a `/mlz <name>` subcommand, or run one from code. Only the commands in `LISTED` (`Core.lua`) show in `/mlz help`. |
| `ns.ShowCopy(title, text, onAccept)` | Copy/paste dialog (export, import, probe). |
| `ns.Print(...)` · `ns.Debug(...)` | Chat output. `Debug` only prints with `/mlz debug` on. |
| `ns.Cmd(text)` · `ns.Paint(color, text)` · `ns.Color(name)` | Color a command or a word in chat output. |
| `ns.CopyTable(t)` | Deep copy for snapshots. |
| `ns.QueuedCount()` | How many jobs wait for combat to end (footer). |
| `ns.AddonVersion` · `ns.CompareVersions` · `ns.AddonStatus` · `ns.EnableAddon` · `ns.CanEnableAddons` | In `Modules/Health.lua`: another addon's version and state (loaded, switched off, missing), and switching it back on. Used by the addon overview and version-aware rows. |

## Nameplates

`Modules/Nameplates.lua` is the brain: it picks the mode from your role and owns the wizard step. The engine (`MLZUIDB.nameplates.engine`) decides who draws:

- `mlz`: `Modules/Plates.lua` draws its own frames as children of each nameplate. Blizzard's `UnitFrame` only gets alpha 0, forbidden plates are skipped, and everything is event driven with one `OnUpdate` for cast bars and debuff timers. Nothing is registered while another engine is picked.
- `platynator`: the profile import path described at the top of `Modules/Nameplates.lua`. The clean style and threat colors edit the enemy design in the profile copy. If that design is one of Platynator's built-in ones (name starts with `_`), `AdoptBuiltin` takes the copy Platynator keeps in `designs["_custom"]` under our own name (`ownDesign` in `Data/Nameplates.lua`) and points the enemy assignments at it. The wizard row "Import MLZ profile" only shows when `profileString` in `Data/Nameplates.lua` is set.
- `off`: Blizzard's plates, untouched.

The only game setting MLZ nameplates change is `nameplateShowFriends` (plus friendly click-through) in Healer mode. The old value is kept in `nameplates.friendsBase` and put back when you leave Healer mode or switch engines.

## SavedVariables

Everything lives in `MLZUIDB` (account wide), with per-character data in `MLZUIDB.chars[<name-realm>]`.

The schema is versioned with `DB_VERSION` in `Core.lua`. When you change the shape of saved data:

1. Bump `DB_VERSION`.
2. Add `migrations[<new version>] = function(db) ... end`, which upgrades from the previous version.
3. Keep it safe to run on partial or old data. Fresh installs start at the current version and skip migrations.

## UI layer

All UI is built from `UI/Widgets.lua` (`W.Window`, `W.Card`, `W.Button`, `W.Check`, `W.Toggle`, `W.Segmented`, `W.Stepper`, `W.Slider`, `W.SearchBox`, `W.Badge`, `W.ScrollArea`, `W.Tooltip`, plus the small parts `W.Text`, `W.Muted`, `W.Line`, `W.Fill`, `W.Border`) and the theme tokens `W.T` / `W.C`. The control center pages in `UI/Settings.lua` use a small page builder (`Title`, `Card`, `Row`, `Toggle`, `Choice`, `Step`, `Slider`, `Value`, `Status`, `Buttons`, `Text`), so every page looks and behaves the same. Pages register in `PAGES` and the sidebar order comes from `PAGE_ORDER`. The status lines on the overview (and in the minimap tooltip) come from `SECTIONS`. A page for a feature-only module (Reminders, Cooking, XP rate) checks that `ns.X` exists and shows an amber line when it doesn't.

**Search.** Every builder call adds an entry to the page's index through `Page:AddToIndex` (label, description, tooltip, card, and card paragraphs as a low-weight `body`), so new rows are found without extra work. `Search.EnsureAll` builds every page once (hidden) before a search. A page whose rows depend on a choice sets `p.IsStale`, and `S:BuildPage` throws a stale hidden page away so the search never sees old rows. `Data/Search.lua` adds aliases (words players type that are not in the text) and stopwords.

Design rules are in [`CLAUDE.md`](../CLAUDE.md#ui-design-language).
