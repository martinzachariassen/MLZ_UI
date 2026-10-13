<div align="center">

# MLZ UI

**A one-click setup wizard for a clean, minimal, pixel-perfect World of Warcraft UI.**

Scaling · Edit Mode layout · keybinds · CVars · fading · nameplates · addon settings, all previewed, all undoable.

![Version](https://img.shields.io/badge/version-0.5.0-33ccff)
![Interface](https://img.shields.io/badge/interface-16001-blue)
![Language](https://img.shields.io/badge/lua-5.1-000080?logo=lua)
![Status](https://img.shields.io/badge/status-early%20development-orange)

</div>

---

## What is this?

MLZ UI is a World of Warcraft addon that configures your whole interface for you, without replacing Blizzard's UI the way ElvUI does. It uses the **default UI, Edit Mode and your existing addons**, and sets them up the way the author plays.

Instead of silently changing things, it opens an **installation wizard** that shows every change as *old → new*. You tick what you want, press apply, and everything is backed up first. If you don't like the result, `/mlz undo` puts it back.

> **Status:** early development (v0.5.0). It works and is used daily, but expect rough edges and breaking changes. Feedback and issues are welcome.

## Features

| Area | What it does |
|---|---|
| **Pixel-perfect scale** | Calculates UI scale from your screen height (`scale = k * 768 / height`). Stores the *mode*, not the number, so it recalculates if your resolution changes. Handles scales below Blizzard's 0.64 CVar limit. |
| **Edit Mode layout** | Creates a dedicated Edit Mode layout (bars stacked at bottom center, player/target flanking, swing timers, cast bar, corners kept for glance-only info). Your other layouts are untouched. |
| **Keybinds** | ESDF or WASD movement, a reach-sorted set of base keys, and Shift/Ctrl variants for bars 2 and 3. With WASD, Shift+1/2/3 switch stance/form (stance bar buttons 1-3), and bar 2 buttons 1-3 move to Shift+G/V/T. Detects conflicts and moves displaced actions (e.g. Character panel) to an ALT variant. |
| **Settings (CVars)** | Auto loot, auto self-cast, cast on key down, camera distance, nameplate visibility, disable tutorials and more. Each one is optional. CVars that don't exist in your client are skipped. |
| **Minimalism / fading** | Hides bars 4-5, micro menu, bags, chat buttons and XP bar until mouseover. Dims bars 2-3 out of combat. Damage meter only shows in a group. Uses `SetAlpha` only, so it causes **no taint** and works in combat. |
| **Action button colors** | Red = out of range, blue = no mana/rage/energy, grey = unusable, like tullaRange. Short hotkey labels (`S1`, `C1`) and hidden macro names. |
| **Nameplates** | Imports your saved [Platynator](https://www.curseforge.com/wow/addons/platynator) profile and/or a clean minimal style, switched by role: Defensive Stance / Bear Form = tank, otherwise DPS in a group and SOLO when alone. Threat colors are tuned per mode. |
| **Other addons** | Applies recommended settings to Prat, Auctionator, AtlasLoot, What's Training?, Bagnon, RestedXP Guides, Deadly Boss Mods and Leatrix Plus/Maps (see below). |
| **Tweaks** | Minimap size slider, FPS counter, calmer combat text (small Roboto Bold numbers; the font needs a full game restart), hide the quest tracker or just its "All Objectives" line. |
| **Backup / undo** | A stack of up to 5 backups. Every wizard run is reversible. |
| **Export / import** | Share your choices as a string with `/mlz export` and `/mlz import`. |
| **Health check** | Warns after login if an addon it configures is installed but not loaded (e.g. switched off by mistake). `/mlz health` also lists supported addons you don't have. |

## Installation

1. Download or clone this repo.
2. Put the `MLZ_UI` folder in your AddOns directory:
   - **macOS:** `/Applications/World of Warcraft/_<flavor>_/Interface/AddOns/`
   - **Windows:** `C:\Program Files (x86)\World of Warcraft\_<flavor>_\Interface\AddOns\`
3. Restart the game, or type `/reload`.
4. On first login the wizard opens automatically. You can reopen it any time with `/mlz install`.

```sh
cd "/Applications/World of Warcraft/_<flavor>_/Interface/AddOns"
git clone git@github.com:martinzachariassen/MLZ_UI.git
```

Check `## Interface: 16001` in [`MLZ_UI.toc`](MLZ_UI.toc) matches your client. If it shows as "out of date", enable *Load out of date AddOns* or update the number.

## Usage

Type `/mlz` in game for the full list. The commands:

| Command | Description |
|---|---|
| `/mlz install` | Open the installation wizard |
| `/mlz undo` | Undo the last wizard run |
| `/mlz backups` | List saved backups |
| `/mlz scale [auto \| 0.64 \| pixel1 …]` | Recalculate and reapply the UI scale |
| `/mlz np tank \| dps \| solo \| threat \| auto \| off \| tidy \| save \| load \| export` | Control nameplate switching |
| `/mlz heal` / `on` / `off` / `auto` / `build` | Healer layouts: status, force healer on/off, follow the spec, rebuild the layouts |
| `/mlz np style` / `/mlz np style off` | Turn the clean nameplate style on/off |
| `/mlz fade` | Toggle all fading until next `/reload` |
| `/mlz buttons` | Toggle action button coloring |
| `/mlz fps` | Toggle the FPS counter |
| `/mlz map [size]` | Change minimap size |
| `/mlz quests` / `/mlz tracker` | Hide/show the quest tracker / its header line |
| `/mlz addons` | Show which supported addons are loaded and which settings differ |
| `/mlz health` | Check that supported addons are installed and loaded |
| `/mlz export` / `/mlz import` | Share or restore your choices |
| `/mlz debug` | Toggle debug output |
| `/mlz probe` | Collect client info into SavedVariables (for development) |

## Supported addons

MLZ UI **configures** these addons if they are installed and loaded. It does not install or update them yet (see the roadmap).

| Addon | What gets set |
|---|---|
| [Prat 3.0](https://www.curseforge.com/wow/addons/prat-3-0) | Timestamp format, hide minimize/voice/channel buttons, scroll speed, chat fade time |
| [Auctionator](https://www.curseforge.com/wow/addons/auctionator) | Hide splash screen, auto-select next item, remember last duration |
| [AtlasLoot Classic](https://www.curseforge.com/wow/addons/atlasloot-classic-edition) | Optionally hide the minimap button |
| [What's Training?](https://www.curseforge.com/wow/addons/whats-training) | Hide known weapon skills, show beside trainer window |
| [Bagnon](https://www.curseforge.com/wow/addons/bagnon) | Bag and bank columns, darker background, softer item glow, no auto-open for crafting/socketing |
| [RestedXP Guides](https://www.restedxp.com/) | Lock frames, optional guide window scale, optional fixed column on the right (MLZ UI's own setting) |
| [Deadly Boss Mods](https://www.curseforge.com/wow/addons/deadly-boss-mods) | Warnings at the top center, info/range frames and timer bars on the right, slimmer bars, no separate large bars |
| [Leatrix Plus](https://www.curseforge.com/wow/addons/leatrix-plus-classic) | Auto-sell grey items, auto-repair, faster loot, hide minimap icon; optional quest automation, role confirm, no bag auto-open |
| [Leatrix Maps](https://www.curseforge.com/wow/addons/leatrix-maps-classic) | Hide minimap icon |
| [Platynator](https://www.curseforge.com/wow/addons/platynator) | Profile import, clean style, tank/DPS/solo switched by role |
| BugGrabber | Only checked by the health check |

Settings are read from each addon's own SavedVariables, so they depend on the version you have installed. Rows whose key doesn't exist are shown as "not available" and skipped.

In the wizard, rows that are already on start ticked; untick one to turn it off. Rows that depend on another row (e.g. frame placements on the layout row, moved actions on their key) are greyed out when that row is unticked.

## What it uses and what it gives

**Uses**
- Blizzard's own APIs: `C_EditMode`, `C_AddOns`, CVars, secure item buttons, binding functions.
- The saved variables of the addons listed above.
- Its own SavedVariables, `MLZUIDB`, for your choices, backups and DB version. It has a migration system for future changes.
- No libraries and no external dependencies. Plain Lua, a few thousand lines.

**Gives**
- A complete, consistent UI setup in a few clicks, with a preview and full undo.
- No taint: it never hides or shows protected frames. Anything blocked in combat is queued and runs when combat ends.
- All the choices live in plain Lua tables under `Data/`, so you can change them without touching any logic.

## Project layout

```
MLZ_UI/
├── MLZ_UI.toc
├── Core.lua            namespace, SavedVariables, event bus, combat queue, slash commands
├── Probe.lua           client introspection for development
├── Data/               what to apply (CVars, bindings, layout, fade, nameplates, addons)
├── Modules/            how to apply it (one module per area, all with Preview/Apply/Backup/Restore)
└── UI/                 widgets and the installation wizard
```

Each module registers itself with `ns.RegisterModule` and implements:

- `:Preview()` returns the list of changes shown in the wizard
- `:Backup(items)` saves the old values
- `:Apply(items)` applies the selected changes
- `:Restore(snapshot)` is called by `/mlz undo`

Adding a feature is mostly adding a data file and a module.

## Customizing

Everything is meant to be edited. Open the file in `Data/`:

| File | Controls |
|---|---|
| `Data/CVars.lua` | Game settings the wizard offers |
| `Data/Bindings.lua` | Movement setups and base keys |
| `Data/Layout.lua` | Edit Mode frame positions |
| `Data/Fade.lua` | What fades, when, and how much |
| `Data/Nameplates.lua` | Tank/DPS/solo nameplate presets and threat colors |
| `Data/Addons.lua` | Settings applied to other addons |

## Roadmap

The next big step is turning MLZ UI from "configures your addons" into an **addon manager** that also gets them onto your machine.

- [ ] **Addon manager:** list the addons MLZ UI knows about, with installed / missing / outdated state
- [ ] **Install:** download and install supported addons from within the wizard
- [ ] **Update:** check for new versions and update the addons it manages
- [ ] **One-step setup:** a fresh install ends up with all addons installed *and* configured
- [ ] **Per-addon profiles:** more addons and more settings per addon
- [ ] **Version-aware settings:** adapt to changes in other addons' SavedVariables
- [ ] Screenshots and a short demo in this README
- [ ] Packaged releases (CurseForge / Wago / GitHub Releases)

**Note on how this will work:** the game's Lua sandbox can't download files or write to the AddOns folder, so installing and updating needs a small **companion app** outside the game. The in-game addon will keep doing the configuration and show status; the companion will do the download and install. The design is still open and nothing here is implemented yet.

## Contributing

Issues and pull requests are welcome, especially for:

- Settings for more addons (`Data/Addons.lua` is a good place to start)
- Bug reports with the output of `/mlz probe` and any Lua error text
- Layout and keybind ideas

To develop, symlink the folder into your AddOns directory, use `/reload` to test and turn on `/mlz debug`. Installing [BugGrabber + BugSack](https://www.curseforge.com/wow/addons/bugsack) helps a lot.

## License

No license has been added yet. Until one is, all rights are reserved by the author.

## Credits

Inspired by [ElvUI](https://github.com/tukui-org/ElvUI), [Bartender4](https://www.curseforge.com/wow/addons/bartender4), [Dominos](https://www.curseforge.com/wow/addons/dominos), [tullaRange](https://www.curseforge.com/wow/addons/tullarange) and [AutoBar](https://www.curseforge.com/wow/addons/autobar).

Made by [Martin](https://github.com/martinzachariassen).
