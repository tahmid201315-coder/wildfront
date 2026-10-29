# Limitations and things not done
- Not play-tested by a human, not run on a device (see TESTING.md). Expect balance problems and bugs.
- Rooms are generated from templates; regions feel similar in structure. Bosses are data-driven scripts; the 7 bosses
  share one attack vocabulary (waves, lobs, volleys, rings, columns, dashes, beams, summons).
- Art is procedural vector drawing, not hand-made sprites; animations are skeletal poses, not frame-by-frame.
- Music is simple procedural looping; it is not composed. Rendering 11 tracks takes about 1 s each on desktop in a
  background thread at start-up; slower phones may start a track silent for a moment if it is not ready.
- No object pooling for projectiles/enemies (particles use a capped list). The 60 FPS target on modest Android is untested.
- Remapping covers keyboard only (not controller or touch). Text is English only.
- Hidden-wall reveal depends on equipping the Astral Lens. Secret rooms are limited to cracked walls and secret pits.
- Only one NPC conversation style (no branching dialogue). Quests are count-based (kill, chests, journals, shards, bosses, shrines).
- Flying bosses are hit by jumping and air attacks or magic; there is no special platform assist.
- Debug-signed APK only; no release signing or store listing.
