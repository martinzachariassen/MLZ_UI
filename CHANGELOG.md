# Changelog

## Unreleased

- Search in the control center: type in the box at the top of the sidebar (or `/mlz search minimap`) to
  find any setting. Typos, short forms (5sr, np) and other words (junk, kick) still find it. UP and DOWN
  pick a match, ENTER opens the page and points out the setting.
- Tick bar: mana or energy from Illumination, Relentless Strikes, potions, drinks or totems no longer moves
  the 2-second tick. A lower max mana (a buff that ran out) no longer starts the five-second rule.
- New "Fewer clicks" card on Helpers, all off by default: accept and turn in quests, accept summons and
  resurrections, confirm bind on pickup loot when solo, decline duels. Hold SHIFT to skip once.
  Options that Leatrix Plus already handles step aside.
- Reminders: a hunter pet that is not happy, and food and flask inside raids (own switch, off by default).
- Reminders: Thorns now also shows for a DPS druid who plays solo, not only for tanks.
- Reminders: food while leveling (own switch, off by default). Solo and below max level, an icon when you
  are not Well Fed, for the extra XP from kills.
- New "Group & raid" card on Helpers: a buff check on ready check lists who misses a buff you can cast
  (or every class buff when you lead), only in your own chat. `/mlz buffs` checks at any time.
- Pull timer: `/mlz pull [seconds]` or a key in Key Bindings > AddOns > MLZ UI. Uses the game's countdown
  when the client has it, otherwise Deadly Boss Mods.
- Situation profiles on Profiles & backup: save fading, the quest tracker and threat colors for solo,
  dungeon, raid and battleground. With switching on, the saved one loads when you get there, on top of
  your role profile.
- Other addons: the "Your addons" card shows each supported addon as loaded, switched off or missing,
  with its version. "Turn on switched-off" switches them back on for this character (after a reload).
- Settings for other addons can be limited to the addon versions that have them ("not in your version").
- Export now covers faded frames, helpers, reminders, and the role and situation profiles of this
  character. Strings start with `MLZ!2!`; `MLZ!1!` strings still import, and undo puts everything back.
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
