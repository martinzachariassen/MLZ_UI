# Changelog

## 0.9.0

Ready for the WoW Forever launch. Found a problem? Install BugGrabber and BugSack, then
[open an issue](https://github.com/martinzachariassen/MLZ_UI/issues/new/choose) with the error text.

- The layout fits wide screens. On an ultrawide monitor chat, group frames, minimap, bags, micro menu and
  the meter sit at the edges of a 16:9 area in the middle instead of the far screen edges. On a 16:9
  screen nothing changes. A saved pet position is kept as it is.
- The pet bar (hunter, warlock) is always shown, right above bar 3. The stance bar uses the same spot.
  The cast bar moved up to make room.
- Bars 4-5 on the right sit a little higher, so they stay clear of the threat meter on shorter screens.
- Layout & scale shows "Screen fit": whether the layout was made for this screen, or needs to be applied
  again after you changed monitor or resolution.
- Other addons: window placement for Details! (meter and TinyThreat at the bottom right), RestedXP (guide,
  target and quest item windows), the TomTom arrow and Bagnon bags and bank. Undo moves them back.

- Combat text settings work on WoW Forever. The client renamed those CVars (`_v2`), so the rows showed as
  not available.
- Healers see friendly nameplates again on Forever, which uses `nameplateShowFriendlyPlayers`.
- Details!: the bar font row now uses Expressway at size 11. Details replaced the old font file on every
  refresh, so the row did nothing.
- Prat: the chat background row works (it pointed at the wrong module), and chat fades after 20 seconds,
  the same as MLZ's chat fade, instead of 45.
- The flat chat input box and Roboto chat font say "Prat styles..." when Prat already does it. The minimap
  size says "Leatrix Plus sets the minimap size" when Leatrix scales the minimap, so the two don't fight.
- AtlasLoot: removed the world map button row. The Forever version has no world map button.
- RXP Guides: the drowning warning row is off by default, because the tips row already turns it off.

- MLZ nameplates look sharper: thicker bars in Roboto, a cast bar with the spell icon, time left and who
  the spell is aimed at, a red "Interrupted" when a cast is kicked, and a light edge on the mob under
  your mouse.
- MLZ nameplates have a new, modern look. The name sits on the left above the bar, the level and an elite
  mark on the right. Missing health shows in a dark shade of the bar color, and health you just lost shows
  as a light chip that slides away in 0.4 seconds. Your target gets small arrows on both sides and a white
  edge instead of the blue strip.
- Elite and rare marks: a gold diamond for elite, a silver one for rare, silver with a gold edge for rare
  elite and a red skull for world bosses.
- Interrupt ready: the cast bar is blue when your interrupt is ready before the cast ends, slate when it is
  on cooldown and grey when the cast can't be interrupted. Warrior, rogue, priest, shaman and mage use
  their own spell, a warlock's Spell Lock is read from the felhunter.
- Refresh timing: your debuff timers turn amber at 3 seconds left and red at 1, so a DoT never drops off.
  Casters and hunters see their debuffs on every mob in DPS and Solo mode, so several mobs stay dotted.
- Pet holds it: a paw next to the level while a mob attacks your pet. When it turns to you, the paw goes
  and the bar turns red.
- The cast bar has a thin spark at the edge of the fill. Bigger debuff icons.
- Threat colors on the nameplates are now on by default, also for healers and solo. As DPS, healer or
  solo the bar turns amber at 80% of what pulls aggro and red once the mob is on you. Your threat % shows
  inside the bar, and in a group a warning sound plays once per mob near 90%. If you turned threat colors
  off before, they stay off.
- Other addons: Details! TinyThreat as a threat meter in Details window 2, in the MLZ look and hidden when
  you are not in a group. The window is opened for you, and undo closes it again.
- Ready-made setups on Profiles & backup: Minimal, Balanced and Informative set faded frames, nameplate
  options and reminders in one click (or `/mlz preset minimal`). Keybinds and scale stay as they are.
  A backup is taken first, so undo puts it back. "In use" shows which setup your choices match, and
  clicking the one already in use takes no new backup.
- MLZ nameplates: an amber strip on the right when a mob can be finished with Execute (warrior) or Hammer
  of Wrath (paladin). Only once you know the spell.
- MLZ nameplates: crowd control from anyone (Polymorph, Sap, Blind, Fear and more) shows next to the bar
  with the time left, so nobody breaks it by accident.
- Export and import now include which details MLZ nameplates show.
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
  with its version. "Turn them on" switches them back on for this character (after a reload).
- Settings for other addons can be limited to the addon versions that have them ("not in your version").
- Export now covers faded frames, helpers, reminders, and the role and situation profiles of this
  character. Strings start with `MLZ!2!`; `MLZ!1!` strings still import, and undo puts everything back.
- Lint (luacheck and a Lua 5.1 syntax check) runs on every push to main and every pull request.
- Tagged versions are packaged and published to GitHub Releases, and to CurseForge and Wago when they are set up.
- MIT license.
- A contributing guide, a code of conduct, a security policy, and issue and pull request templates.
- The control center search also finds text in cards ("How it works", chat commands).

- Every setting in the control center has a tooltip with the details. Rows that can't be used say why in
  amber: fade rows for frames this client doesn't have, action button colors without buttons, and the
  interrupt announce for a class without an interrupt.
- Druids: Feral Charge counts as an interrupt, so a bear tank gets the "Interrupt ready" cast bar.
- Key hints: hunter button 7 is "Slow (Concussive Shot)" and paladin button 7 is "Stun (Hammer of
  Justice)". Neither is an interrupt.
- Reagent reminders: Symbol of Kings is checked for every Greater Blessing, not only Might.

- Change single keys on the key map: `/mlz keys`, then "Change keys" (also on the Your role page). Click a
  key, pick what it does from a list with search, and see what loses its key before anything changes. One
  `/mlz undo` puts back every key you changed since you opened the map. Not in combat.
- Pet spell keys for hunters and warlocks: pet bar buttons 4-6 (Spell Lock, Seduction, Growl and so on)
  get V, SHIFT-V and CTRL-V with ESDF, or G, V and SHIFT-V with WASD.
- Keybinds step: a key you unticked stays unticked when you switch between ESDF and WASD. Unticking a moved
  action says that it has no key afterwards. Arrow key movement shows as "custom (arrows)".
- The mouse wheel keys are labeled "Bar 4 (mouse wheel)".

- Fine-tune in game, no file editing. Every value applies right away and shows its default in the tooltip:
  - Nameplates: how much enemies you don't target dim (per mode), the threat warning % and its sound, when
    debuff timers turn amber (2-6 s), how many debuffs show (4, 6 or 8) and debuffs on every mob per mode.
    The Platynator engine gets the same dimming.
  - Minimalism: how far "out of combat" frames dim, and per frame whether it hides out of combat, until
    mouseover or always.
  - Chat: how long until chat fades (or never), and hiding the chat tabs and background on their own.
  - Reminders: repair at 10-50% durability, and the ammo and Soul Shard counts that count as low.
  - Pull timer: 5, 8, 10 or 15 seconds for the key, the button and `/mlz pull`.
- Ready-made setups also set how far frames dim: Minimal 10%, Balanced 25%, Informative 40%.
- "Reset page" at the top of Nameplates, Minimalism, Bars & interface, Helpers and Reminders puts that page's
  MLZ choices back to the defaults. "Everything to defaults" on Profiles & backup does all of them. Keybinds,
  Edit Mode and game settings stay as they are. Both take a backup first, so `/mlz undo` brings them back.
- Export covers the whole setup: keys you changed on the key map, every fine-tune value, the nameplate engine
  and size, cooking tooltips, interrupt announce, the tick bar and muted reminders. Older export strings
  still import.
- The setup wizard keeps keys you changed on the key map instead of setting them back.

**Fixes**
- Reagent reminders: Prayer of Fortitude rank 1 checks Holy Candles and Gift of the Wild rank 1 checks Wild
  Berries. With rank 2 learned you are only reminded about Sacred Candles or Wild Thornroot.
- `/mlz undo` after the layout step puts the extra action bars back exactly as they were.
- Fewer clicks no longer accepts grey quests from quest givers without a gossip window.
- Pull timer in a raid without lead or assist says why instead of doing nothing.
- Cooking tooltips keep their colors when the Secondary Skills header is collapsed.
- An addon with nothing for MLZ UI to set no longer shows "All 0 settings match".
- Search no longer shows old nameplate rows after the engine was switched from the minimap menu.
- The "Looks only" tooltip lists every step it uses.
- `/mlz help` and the About page list the same commands.
- "Show action bars" in the wizard no longer shows as a change when your bars are already right.
- `/mlz undo` brings fading back right away, without a reload.
- Back in a single wizard step ("Apply addon settings...") stays in that step.
- Selling greys shows the right total when you reopen the merchant during a sale.
- `/mlz health` lists Deadly Boss Mods once.
- `/mlz heal off` keeps a tank a tank.
- Situation profiles no longer print a line on every zone change.
- Undo keeps the settings of an addon that is switched off, or of a missing Platynator, so you can undo
  them later.
- Interrupt announce no longer listens to the combat log while it is off.
- Right-clicking the minimap button in combat says the quick menu opens after combat.
- Key names show in caps (SHIFT, CTRL, ALT, TAB).
- Healer friendly names try the Forever CVar first, so the right setting is turned on.
- An import skips fine-tune values of the wrong type instead of breaking nameplates or reminders.
- Importing an older string keeps your keybind tick boxes.

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
