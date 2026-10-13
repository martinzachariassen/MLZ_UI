# Architecture

How MLZ UI is put together. For conventions and style, see [`CLAUDE.md`](../CLAUDE.md).

## Project layout

```
MLZ_UI/
├── MLZ_UI.toc            Load order, interface version, SavedVariables (MLZUIDB)
├── Core.lua              Namespace, events, combat queue, state, roles, commands, migrations
├── Probe.lua             /mlz probe: dumps client facts to SavedVariables
├── Data/                 WHAT to set (plain tables, no logic)
│   ├── CVars.lua
│   ├── Bindings.lua
│   ├── Layout.lua
│   ├── Fade.lua
│   ├── Nameplates.lua
│   └── Addons.lua
├── Modules/              HOW to set it (one feature per file)
│   ├── Backup.lua        Backup stack, apply order, undo (loads first)
│   ├── Scale.lua  Settings.lua  Bindings.lua  Layout.lua  Healer.lua
│   ├── Fade.lua  ActionButtons.lua  Tweaks.lua  Plates.lua  Nameplates.lua  Addons.lua
│   └── Health.lua  Vendor.lua  ManaTick.lua  Interrupt.lua  Profile.lua
├── UI/
│   ├── Widgets.lua       Theme tokens (W.T, W.C), fonts and every widget
│   ├── Installer.lua     Setup wizard
│   ├── Settings.lua      Control center (/mlz)
│   └── MinimapButton.lua Minimap button, tooltip, quick menu
├── Media/                Roboto Bold + license
└── docs/
    ├── ARCHITECTURE.md
    ├── mockups/          HTML sources for the README images + render.sh
    └── screenshots/      Rendered PNGs used by the README
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
function Tweaks:Apply(items)     -- applies the ticked items
function Tweaks:Restore(snap)    -- puts a snapshot back
```

A preview item is a table with at least `id`, `label`, `old` and `new`. Optional fields include `group`, `note`, `enabled`, `toggle`/`isOn`, and `unavailable = true` with the reason in `new` (e.g. "tracker not found"). The wizard draws one row per item, as *now → will become*.

Rules:
- `Preview` must not change anything.
- `Backup` must capture everything `Apply` is about to change.
- `Restore` must work on a snapshot from an older version of the addon, or skip it safely.
- Anything that touches protected frames or bindings goes through `ns.RunOutOfCombat`.

Feature-only modules (`Vendor`, `ManaTick`, `Interrupt`, `Health`, `Plates`) don't register. They hook events through `ns.On` and expose a small table on `ns` (e.g. `ns.Vendor`) for the control center.

## Apply and undo flow

```
Wizard "Apply"
  └─ Backup:Create(selections)      every module snapshots what it will change
       └─ pushed onto MLZUIDB.backups (max 5, #1 is always kept: your pre-MLZ state)
  └─ modules apply in Backup.APPLY_ORDER
       scale → settings → layout → bindings → fade → actionbuttons → tweaks → addons → nameplates
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
| `ns.Role()` · `ns.LiveRole()` · `ns.SetRoleForce` · `ns.OnRoleChanged(fn)` | Role detection and overrides. |
| `ns.CharDB()` | Per-character table inside `MLZUIDB.chars`. |
| `ns.AddCommand(name, help, fn)` | Add a `/mlz <name>` subcommand. It shows up in `/mlz help`. |
| `ns.ShowCopy(title, text, onAccept)` | Copy/paste dialog (export, import, probe). |
| `ns.Print(...)` · `ns.Debug(...)` | Chat output. `Debug` only prints with `/mlz debug` on. |
| `ns.CopyTable(t)` | Deep copy for snapshots. |

## Nameplates

`Modules/Nameplates.lua` is the brain: it picks the mode from your role and owns the wizard step. The engine (`MLZUIDB.nameplates.engine`) decides who draws:

- `mlz`: `Modules/Plates.lua` draws its own frames as children of each nameplate. Blizzard's `UnitFrame` only gets alpha 0, forbidden plates are skipped, and everything is event driven with one `OnUpdate` for cast bars and debuff timers. Nothing is registered while another engine is picked.
- `platynator`: the profile import path described at the top of `Modules/Nameplates.lua`.
- `off`: Blizzard's plates, untouched.

The only game setting MLZ nameplates change is `nameplateShowFriends` (plus friendly click-through) in Healer mode. The old value is kept in `nameplates.friendsBase` and put back when you leave Healer mode or switch engines.

## SavedVariables

Everything lives in `MLZUIDB` (account wide), with per-character data in `MLZUIDB.chars[<name-realm>]`.

The schema is versioned with `DB_VERSION` in `Core.lua`. When you change the shape of saved data:

1. Bump `DB_VERSION`.
2. Add `migrations[<new version>] = function(db) ... end`, which upgrades from the previous version.
3. Keep it safe to run on partial or old data. Fresh installs start at the current version and skip migrations.

## UI layer

All UI is built from `UI/Widgets.lua` (`W.Window`, `W.Card`, `W.Button`, `W.Toggle`, `W.Segmented`, `W.Stepper`, `W.Slider`, `W.Badge`, `W.ScrollArea`, `W.Tooltip`) and the theme tokens `W.T` / `W.C`. The control center pages in `UI/Settings.lua` use a small page builder (`Title`, `Card`, `Row`, `Toggle`, `Choice`, `Step`, `Slider`, `Value`, `Status`, `Buttons`, `Text`), so every page looks and behaves the same.

Design rules are in [`CLAUDE.md`](../CLAUDE.md#ui-design-language).
