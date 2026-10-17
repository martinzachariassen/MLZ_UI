# CLAUDE.md

Guidance for working on MLZ UI. Read this before you change code, UI or copy. For how the code fits together, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Project

MLZ UI is a World of Warcraft Classic addon (`## Interface: 16001`, Lua 5.1). **WoW Forever is the main supported client**, and every class is supported: tank, healer, melee, ranged and caster DPS, and hybrids such as druid, paladin, shaman and priest get the UI that fits how they play. Class facts live in `Data/Classes.lua`. It turns the default Blizzard UI into a clean, minimal setup through one guided wizard and a control center (`/mlz`).

**Philosophy: configure, never replace.** We set up Edit Mode, CVars, keybinds and other addons the player already has. We do not build replacement unit frames or action bars. The one exception is nameplates (`Modules/Plates.lua`): our own frames on top of Blizzard's plate, with Platynator as an optional engine. Every change is previewed as *now → will become*, backed up first and undoable with `/mlz undo`.

The target player wants a calm, good-looking UI without learning a big suite like ElvUI. If a feature needs a manual to understand, it is not done yet.

## Architecture in one minute

- **Load order** (`MLZ_UI.toc`): `Core.lua` → `Probe.lua` → `Data/*` → `Modules/*` (`Backup.lua` first) → `UI/*` (`Widgets.lua` first).
- **Namespace:** every file starts with `local _, ns = ...`. `ns` is global as `MLZUI` for `/dump` only. Never read `MLZUI` from code.
- **`Data/` = what, `Modules/` = how.** Defaults and presets go in `Data/` as plain tables. Logic goes in `Modules/`.
- **Module contract:** `ns.RegisterModule({ key, title })`, then `:Preview()`, `:Backup(items)`, `:Apply(items)`, `:Restore(snap)`. `:Apply` returns nil, or a short text when part of it failed (the wizard then shows PARTLY). New wizard modules must be added to `Backup.APPLY_ORDER` in `Modules/Backup.lua`.
- **Reuse Core helpers** instead of writing your own: `ns.On`/`ns.TryOn`, `ns.RunOutOfCombat`, `ns.FireState`/`ns.OnState`, `ns.MarkReload` (last resort, apply live when you can), `ns.MarkEditModeStale`, `ns.Error`, `ns.Enabled`/`ns.SetEnabled`, `ns.Try`, `ns.IsAddOnLoaded`/`ns.IsAddOnInstalled`, `ns.Role`/`ns.LiveRole`, `ns.Archetype`/`ns.LiveArchetype`, `ns.CharDB`, `ns.AddCommand`, `ns.ShowCopy`, `ns.Debug`.

## Hard rules

These are not up for debate. Breaking one is a bug.

1. **No taint.** On protected frames (action bars, unit frames, Edit Mode systems) only use `SetAlpha` and hooks that don't call protected functions. Never `Hide()`, `SetPoint()` or reparent them from addon code. Nameplates follow the same rule: Blizzard's `nameplate.UnitFrame` is only set to alpha 0 (and back to 1), our frames are children of the nameplate, and forbidden plates are skipped. Anything that is blocked in combat (bindings, Edit Mode, CVars that need it) goes through `ns.RunOutOfCombat(fn, label)`.
2. **No libraries.** No Ace3, LibStub, LibDataBroker or embeds. Plain Lua and the WoW API only.
3. **Feature-detect every API.** Classic clients differ. Use fallbacks like `local Container = C_Container or {}` (see `Modules/Vendor.lua`), `ns.TryOn` for events that may not exist and `ns.Try` for calls that may fail. If something is missing, show the feature as unavailable with a reason. Don't error.
4. **Everything is undoable.** If the wizard changes it, `:Backup` captures it and `:Restore` puts it back. If a change can't be undone, it doesn't ship.
5. **List new files in `MLZ_UI.toc`.** In the right section, in the right order.
6. **SavedVariables changes need a migration.** Bump `DB_VERSION` in `Core.lua` and add `migrations[n]`. Never rename or drop saved keys without one.
7. **No chat spam.** At most one summary line per user action. Diagnostics go through `ns.Debug`. Feedback inside the control center goes to the footer with `S:Notify(text, kind)`.
8. **Respect other addons.** Only touch an addon's settings when it is loaded, through its own saved variables or import format, and skip settings its version doesn't have. Don't fight it (e.g. `Vendor` skips selling when Leatrix Plus already does).

## Code style

- 4 spaces, no tabs. Keep lines readable (about 120 characters).
- File header: `-- MLZ UI: <Area>` followed by 1–4 comment lines on what the file does and where the player finds it.
- Section banners with `----` lines for long files.
- `local` everything. The only globals are `MLZUIDB`, `MLZUI`, named font objects (`MLZUI_Font*`) and `MLZUIScanTooltip` (quest scan on clients without `C_TooltipInfo`). `GetMinimapShape` is defined only while the square minimap is on and no other addon has defined it (minimap button libraries read it).
- Upvalue hot globals at the top (`local GetTime = GetTime`) only where it matters (OnUpdate, frequent events).
- Comments in English, short, explaining *why*, not *what*.
- Module tables are PascalCase (`local Tweaks = ns.RegisterModule(...)`), locals are camelCase, constants are UPPER_CASE.
- Return early instead of nesting. Prefer small local functions over long ones.

## UI design language

The look: **dark, flat, quiet, precise.** Think a modern desktop app, not a fantasy parchment frame. The interface should disappear until you need it.

**Use the system, don't invent.**
- Colors only from `W.T` (frames) and `W.C` (text codes) in `UI/Widgets.lua`. No new hex values in feature code.
- Widgets only from `W.*`: `Line`, `Muted`, `Window`, `Card`, `Button` (`normal`, `primary`, `danger`, `subtle`), `Check`, `Toggle`, `Segmented`, `Stepper`, `Slider`, `Badge`, `ScrollArea`, `Tooltip`. No Blizzard templates (`UIPanelButtonTemplate`, `BasicFrameTemplate`, and so on).
- Control center pages are built only with the page builder in `UI/Settings.lua` (`Title`, `Card`, `Row`, `Toggle`, `Choice`, `Step`, `Slider`, `Value`, `Status`, `Buttons`, `Text`).

**Visual rules.**
- 1px borders (`W.T.border`), no rounded corners, no gradients, no drop shadows inside the window.
- Selection and state are shown with a **3px accent strip** or a filled segment, never with glow.
- Spacing on a 14px rhythm (`PAD`). Cards are separated by space, not lines.
- Fonts: **Roboto Bold** (`MLZUI_FontTitle` 20, `Head` 14, `Button` 12, `SmallBold` 11) for headings, labels in caps and buttons only. Body text and descriptions use the game font.
- Semantic color only: **accent blue** = selected, interactive, current; **green** = on, OK, will change; **amber** = needs attention or a reload; **red** = conflict, error, destructive; **muted** = secondary text; **off** = disabled.

**Behavior rules.**
- Every setting row has a **label**, a one-line **muted description**, a **tooltip** with the details, and a control that **applies right away**. No "Save" buttons.
- When a feature can't be used, keep the row and say **why** in amber ("Platynator is not loaded"). No dead controls without an explanation.
- Status is visible at a glance: badges (`on`, `off`, `warn`, `bad`, `info`, `na`) and the footer reload state.
- The wizard always shows *now → will become*, groups rows, and hides rows that are already right behind "N settings are already right".
- Nothing opens in combat that can't work in combat. Say so in the footer instead.

## Writing style

Applies to UI text, chat output, tooltips, docs and commit messages.

- Plain English, short sentences. Write for a player, not a developer.
- Sentence case for titles and buttons ("Setup wizard", not "Setup Wizard").
- Say what the player sees and what will happen: "Bars 2-3 fade out of combat", not "Enables combat-state alpha handling".
- Show changes as *old → new*.
- No em dashes. Use a period, comma, colon or parentheses.
- No hype or filler ("awesome", "seamless", "simply"). No exclamation marks.
- Numbers as digits ("5 backups"). Key names in caps (`SHIFT-Q`, `ALT-C`).
- Errors say what happened and what to do: "Edit Mode can't open in combat. Try again after combat."

## Workflow

- **Dev setup:** symlink the repo into `Interface/AddOns/MLZ_UI`, then `/reload` after each change.
- **Debugging:** `/mlz debug` for verbose output, BugGrabber + BugSack for Lua errors, `/mlz probe` to dump client facts (APIs, CVars, Edit Mode, bindings) into `SavedVariables/MLZ_UI.lua`. Verify against the probe instead of guessing what the client has.
- **Before you finish a change:** `/reload` without errors, run the affected wizard step, apply, then `/mlz undo` and check that everything is back. Test once in combat for anything that touches frames or bindings.
- **Release checklist:** bump the version in all three places (`## Version` in `MLZ_UI.toc`, `ns.version` in `Core.lua`, the badge in `README.md`), update the README if commands, pages or supported addons changed, and re-render screenshots if the UI changed.
- **Commits:** Conventional Commits, matching the history: `feat(nameplates): ...`, `fix(fade): ...`, `refactor: ...`, `docs: ...`. Imperative, lowercase, no period.
- Don't commit or push unless asked.

## Screenshots

The README images in `docs/screenshots/` are currently **mockups**: HTML in `docs/mockups/` built from the real dimensions, colors, fonts and copy, rendered at 2x with headless Chrome.

```sh
./docs/mockups/render.sh          # set CHROME=/path/to/chrome if needed
```

`docs/mockups/theme.css` mirrors `W.T`. If you change the theme in `UI/Widgets.lua`, update `theme.css` and re-render.

**Shot list.** Replace each mockup 1:1 with an in-game capture under the same file name. Crop to the window plus a small margin and save as PNG, about 2200px wide.

| File | What to show | Client state |
|---|---|---|
| `control-center.png` | `/mlz`, Overview page with all status lines | Setup done, no reload pending (so no banner), healer role, hover one line |
| `nameplates.png` | `/mlz` → Nameplates, Engine, Mode and Options cards | MLZ engine (the default), Auto mode, healer role in a group |
| `wizard.png` | `/mlz install`, step 4 Keybinds | Moving ESDF → WASD so red conflicts and Alt moves show |
| `addons.png` | `/mlz install`, step 7 Other addons | Healer role, DBM, Questie, and Details! loaded, so role rows show |
| `minimap-menu.png` | Minimap button tooltip and right-click menu | Two separate captures composed side by side (they can't be open at once) |

Use a clean, well-lit spot (e.g. a capital city at day), 1440p or higher, UI scale set by MLZ UI, and no other addon windows open.
