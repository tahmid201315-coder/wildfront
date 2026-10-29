# Features (what is implemented)

## World
- 7 regions x 7 rooms = 49 rooms: Whispering Meadows, Emberforge Caverns, Sunken Observatory, Thornwild Forest,
  Frostfall Citadel, Clockwork Abyss, Eclipse Realm. Each has a hub, side-scrolling runs, a vertical climb, a puzzle room,
  a pre-boss sanctuary (with a shortcut back) and a boss arena.
- Rooms are generated deterministically from templates (not hand-drawn) and every room is checked by a reachability
  verifier (see LIMITATIONS: this means rooms within a region resemble each other).
- Per-region theme colours, parallax backdrops, ambient particles, glow.
- Hazards: spikes, thorns, lava, water, crushers, lasers, saws, moving platforms, ice.
- Secrets: cracked walls, hidden rooms revealed by the Astral Lens, secret pits, chests, 14 journal pages, heart pieces.
- Puzzles: switch sequences, beam/prism puzzles, push-block + pressure plates (with a rewind stone), gates.
- Starshrine checkpoints, shortcuts.

## Kael
Variable jump, coyote time, jump buffer, wall jump, double jump (Skyleap), dash (Starlight Dash), ladders, swimming,
crouch, 3-hit light combo, heavy, air and dash attacks, magic bolt, dodge with i-frames, healing, Stasis Pulse
(freezes platforms, hazards and enemies), hurt/knockback, victory and defeat poses. Hit-stop, particles, damage numbers.

## Enemies and bosses
8 enemy types as state machines with telegraphs: slime, guard, crawler, archer, stalker, knight, drone, wraith.
7 bosses (data-driven attack scripts): Meadow Colossus, Furnace Behemoth, Astral Watcher, Thorn Queen, Frostbound King,
Clockwork Sovereign, Eclipse Architect. Each has an intro, health bar, telegraphed attacks, vulnerability windows
(armoured otherwise), 3-4 phases, a defeat sequence, a fragment, XP/shards/skill point and a reward altar (abilities or equipment).
Retrying a boss reloads the arena at full health.

## Progression
Star Shards, XP and levels, 8-skill tree, 8 equipment pieces with real stat effects and 3 upgrade levels, shop (Orrin),
upgrades (Tinka), 13 side quests from four NPCs, difficulty (Story / Adventurer / Veteran) that changes enemy health,
damage taken, aggro range and healing charges.

## Story
Intro, two mid-story reveals, finale and ending cutscenes (skippable), boss intro/defeat dialogue, journal pages, NPC dialogue.

## UI
Animated title, New Game with slot choice, overwrite and delete confirmations, Continue, 3 save slots, difficulty select,
HUD, boss bar, toasts, interaction prompts, quest tracker, world map, equipment, skill tree, quest log, journal,
pause, settings, game over with retry, victory, credits.

## Audio
Procedural music: 11 tracks (title, 7 regions, combat, boss, victory); 38 sound effects. Separate master/music/effects
sliders and mute. Combat music switches on when enemies engage.

## Accessibility and controls
Volume sliders, mute, screen-shake toggle, flash reduction, particle level, text size, high-contrast UI, sound captions
(subtitles for key sounds), difficulty, hints toggle, keyboard remapping, touch layout size/opacity/left-handed.

## Platforms
Keyboard, gamepad, touch. Android debug APK via GitHub Actions.

## Added after the first release
- **Auto-aim** magic bolts (toggle in Settings) that lock onto the nearest enemy, boss or switch in front of Kael.
- **Haptics** on hits, boss roars, heals and defeats (Android only; follows the vibration setting).
- **Battery saver**: 30 FPS cap and fewer particles.
- **Auto-pause** when the app loses focus or is backgrounded.
- **Tutorial prompts** on the first visit to the Meadows hub (touch wording), skipped if Hints is off.
- **15 achievements** with a screen on the title and pause menus; they persist across saves and New Game+.
- **Cosmetic scarf colours** (6), five of them unlocked by achievements; chosen on the Equipment screen.
- **Equipment set bonus**: filling all four slots gives +10% damage and +5% defence.
- **Elite enemies** (golden, 2.2x health, bigger, 4x shards): 12+ placed across the campaign as mini-bosses.
- **Echo guardians**: after the ending, guardians can be fought again at 1.6x health and faster, for shards and XP.
- **New Game+**: from a finished save, keep level/skills/gear/money; the world resets and enemies get 50% more health and 25% more damage per cycle.
- **Daily Trial**: a date-seeded boss fight with all abilities, best time stored locally; nothing is written to your saves.
- **Save sharing**: copy a slot as a text code to the clipboard and paste it into another slot (validated before anything is written).
