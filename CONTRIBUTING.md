# Contributing to MLZ UI

Thanks for helping out. Bug reports, settings for more addons, and layout or keybind ideas are all welcome.

This is the short version. The full rules, design language and workflow are in [`CLAUDE.md`](CLAUDE.md), and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) explains how the code fits together.

## Reporting a bug

Open an issue with the **Bug report** template and include:

- The Lua error text from [BugGrabber + BugSack](https://www.curseforge.com/wow/addons/bugsack), if there is one.
- What you did and what you expected.
- Your class, role and client (MLZ UI is built for WoW Forever).
- The output of `/mlz probe` if the bug is about a missing API, CVar, Edit Mode or keybinds. It is written to
  `WTF/Account/<ACCOUNT>/SavedVariables/MLZ_UI.lua` after a `/reload` or logout.

## Development setup

1. Clone the repo and symlink it into your AddOns folder as `MLZ_UI`:
   ```sh
   git clone https://github.com/martinzachariassen/MLZ_UI.git
   ln -s "$PWD/MLZ_UI" "/Applications/World of Warcraft/_<flavor>_/Interface/AddOns/MLZ_UI"
   ```
   On Windows: `mklink /D "...\Interface\AddOns\MLZ_UI" "C:\path\to\MLZ_UI"`.
2. Install BugGrabber + BugSack and turn on `/mlz debug` for verbose output.
3. `/reload` after each change.
4. Install [luacheck](https://github.com/lunarmodules/luacheck) and Lua 5.1 or LuaJIT (macOS:
   `brew install luacheck luajit`), then run `./tools/check.sh` before you push. It must pass. The same checks
   run in CI on every pull request:
   - Lua 5.1 syntax and `luacheck .`
   - `tools/check.lua`: the TOC lists every file in the right order, the version matches in all three places,
     `DB_VERSION` has a migration, no tabs, em dashes, libraries, Blizzard templates, fixed colors or calls that
     taint protected frames
   - `tests/load.lua`: loads the addon on a fake client (`tests/wowstub.lua`), opens the wizard and every
     control center page, applies the wizard and checks that `/mlz undo` puts every CVar and keybind back
5. Optional: `git config core.hooksPath .githooks` runs the same checks before each commit
   (`git commit --no-verify` skips them once).

## Hard rules

Breaking one of these is a bug:

1. **No taint.** Protected frames (action bars, unit frames, Edit Mode) are only faded with `SetAlpha`. Never
   `Hide()`, `SetPoint()` or reparent them. Anything blocked in combat goes through `ns.RunOutOfCombat`.
   Allowed exceptions: `MinimapCluster:SetScale` (out of combat only) and `EnableMouse` on the quest tracker header.
2. **No libraries.** No Ace3, LibStub or embeds. Plain Lua 5.1 and the WoW API.
3. **Feature-detect every API.** Classic clients differ. Use `ns.Try`, `ns.TryOn` and fallbacks. If something is
   missing, show the feature as unavailable with a reason instead of erroring.
4. **Everything is undoable.** If the wizard changes it, `:Backup` captures it and `:Restore` puts it back.
5. **New files go in `MLZ_UI.toc`**, in the right section and order.
6. **SavedVariables changes need a migration.** Bump `DB_VERSION` in `Core.lua` and add a migration.
7. **No chat spam.** At most one line per user action. Diagnostics go through `ns.Debug`.
8. **Respect other addons.** Only touch an addon's settings when it is loaded, through its own saved variables.

New WoW API globals go in `read_globals` in `.luacheckrc`. If the addon calls one without a feature check at
load or in a preview, the load test needs it too: add it to `tests/wowstub.lua`.

## Adding settings for another addon

Start in [`Data/Addons.lua`](Data/Addons.lua). The comment at the top describes every field. In short: an addon
has its folder name, a `root` function that returns its saved variables, and `rows` with an `id`, `label`, `desc`,
the `path` to the key and the `value` MLZ UI suggests. `roles`, `archetypes` and `minVersion`/`maxVersion` limit
a row to the players and addon versions it fits. Copy an existing entry (for example Details! or Questie). Keys
that don't exist in the player's version are skipped. Set `tested` to the addon version you checked against.

## UI and writing style

- Use the widgets and colors in `UI/Widgets.lua` (`W.*`, `W.T`, `W.C`). No new hex colors, no Blizzard templates.
- Every setting row has a label, a one-line description, a tooltip, and applies right away.
- Plain English, short sentences, sentence case ("Setup wizard"). Show changes as *old → new*.
- No em dashes, no exclamation marks, no hype words. Numbers as digits, key names in caps (`SHIFT-Q`).

## Before you open a pull request

- `/reload` without Lua errors.
- Run the wizard step you changed, apply it, then `/mlz undo` and check everything is back.
- Test once in combat if you touched frames or keybinds.
- `./tools/check.sh` passes.
- Add a line under **Unreleased** in [`CHANGELOG.md`](CHANGELOG.md), written for players.

## Branches and pull requests

`main` is protected. Work on a branch and open a pull request. To merge:

- The `checks` job (the `Checks` workflow) must pass, and the branch must be up to date with `main`.
- All review threads must be resolved.
- Commits must be signed. History stays linear, so pull requests merge with squash or rebase only.
- Force pushes to `main` and deleting it are blocked.

Repo admins can bypass these rules (the maintainer works solo), but the normal path is a pull request.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), imperative, lowercase, no period:
`feat(nameplates): add solo mode`, `fix(fade): keep bags visible on hover`, `docs: ...`, `refactor: ...`.

## Code of conduct

Be kind. This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
