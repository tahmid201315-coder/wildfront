# Feature checklist

Status key: **Done** = implemented and exercised by an automated test or a headless screenshot run. **Done (unverified on device)** = implemented, but touch feel, audio output and frame rate have not been checked on a phone. **Not built** = missing.

| Area | Status | Notes |
|---|---|---|
| Island with 5 regions | Done | 512 m procedural island; region shading, fog and temperature per region |
| Movement, camera, touch controls | Done (unverified on device) | Walk, run, sprint, crouch, jump, swim, dodge, ledge step-up, spring-arm camera, left-handed layout |
| Survival: health, stamina, hunger, temperature | Done | Unit tests cover the drain and damage rules |
| Gathering with tool tiers | Done | Playthrough gathers by hand through the real gather action; tier gating covered in unit tests |
| Inventory and equipment | Done | Weapon, tool, armor slots; durability; pack-full handling, quest items are never lost |
| Recipe crafting, stations, unlocks | Done | Workbench, campfire, cooking, processor stations; recipes unlock from logs, the generator and bosses |
| Base building | Done | Snapping, preview, validation, doors, storage, bedroll, turret, dismantle, persistence (7 build tests) |
| Combat | Done | Light combo, heavy, thrust, ranged, dodge, i-frames, damage numbers |
| 4 enemy AI types | Done | Forest Stalker, Rockback Brute, Crystal Wraith, Ruin Sentinel (18 combat tests) |
| 3 bosses | Done | Grove Guardian, Furnace Colossus, Core Architect: phases, telegraphed attacks, adds, shield phase (18 boss tests). Balance is untested by a human |
| 12 main quests + 8 side quests | Done | All 12 main quests completed by the scripted playthrough |
| XP, levels, skill tree | Done | 15 skills in three branches |
| Map, fog, waypoints, compass | Done | Fog from exploration, found sites, tracked objective, tap-to-set waypoint |
| Wildlife | Done | Crab, deer, goat, newt with flee/wander behaviour |
| Day/night and weather | Done | Clear, overcast, rain with thunder and chill; ash fall in the Ashen Expanse |
| Loot containers, one-time state | Done | Saved in `Game.opened` |
| Research logs and dialogue | Done | Terminals, journals, log reader, journal tab |
| Death and respawn | Done | Half of each stack is left in a Death Cache; respawn at campfire or bedroll |
| Ending | Done | Triggers when the final quest completes |
| Procedural audio, music and SFX volume | Done (unverified on device) | Music and ambience switch by region, time, combat, boss and weather |
| Save system | Done | New/continue, atomic write, backup, corrupt-save handling, versioning, reset confirmation |
| Menus and settings | Done | Quality presets, volumes, sensitivity, UI scale, left-handed, vibration |
| Quality presets | Done (unverified on device) | Low/Medium/High; 30 FPS baseline is a target, not a measured result |
| GitHub Actions APK build | Done | See TESTING.md for the most recent real run |
| Optional rover | **Not built** | Documented in KNOWN_LIMITATIONS.md |
