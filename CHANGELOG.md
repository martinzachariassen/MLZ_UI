# Changelog

## Unreleased

- Lint (luacheck and a Lua 5.1 syntax check) runs on every push and pull request.
- Tagged versions are packaged and published to GitHub Releases, and to CurseForge and Wago when they are set up.
- MIT license.

## 0.8.0

A full polish pass: calmer screens, better placement in game and fewer surprises.

**Setup wizard**
- 8 steps instead of 10. Scale and layout are one step, and so are action buttons and interface tweaks ("Bars & interface").
- Rows that are already right are hidden, toggle rows included. Click "N settings are already right" to see them.
- Blue values can be clicked to change them. Right-click goes back one choice.
- The review lists changes in step order. "Skip this step" is gone: turn the step off and press Next.
- If combat starts during setup, you continue where you left off afterwards.

**Control center**
- New sidebar: Overview, Your role, Layout & scale, Nameplates, Minimalism, Bars & interface, Helpers, Reminders,
  Other addons, Profiles & backup, About & help.
- Chat and minimap settings are on "Bars & interface". Reminders have their own page.
- Every row has a description and a tooltip. Margins follow one 14 px rhythm.
- The tour is called "Show me around" everywhere.

**In game**
- Narrower healer frames: 88 px in dungeons, 88x36 in raids, so a 40-player raid stays below the middle of the screen.
- Focus no longer sits on the stance bar. Boss frames follow the minimap. Debuffs sit under buffs.
- The reminder row sits above the group frames. Nameplate text is a little larger.

**Fixes**
- The quest tracker and minimap no longer cause taint.
- `/mlz undo` also restores action bars, spell queue, frame alpha and chat fade time.
- At most one chat line per action.

**Performance**
- Fading, range colors, nameplate updates and the mana tick do much less work when nothing changes.
