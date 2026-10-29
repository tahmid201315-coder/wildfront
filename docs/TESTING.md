# Testing: what was actually run

All suites are headless Godot scenes in `tests/` (listed in `tests/suite.txt`) and run in CI before the APK is exported.
Results from the last local run (Godot 4.3-stable, Linux, headless):

| Suite | Checks | Result | What it covers |
|---|---|---|---|
| test_core | 3 | 3 passed | basic movement physics |
| test_world | 98 | 98 passed | all 49 rooms build and pass the reachability/soft-lock verifier |
| test_boss | 122 | 122 passed | every attack script of all 7 bosses runs to completion, armour vs vulnerability, every phase, defeat sequence, flags, fragment, gate opening, reward altar, boss stays defeated |
| test_audio | 62 | 62 passed | all 38 SFX recipes and 11 music tracks render, bus volumes, mute |
| test_flow | 28 | 28 passed | real Main scene: title, new game, cutscene skip/advance, pause, every sub-screen, settings, key remap, death, game over, retry, save, continue, corrupt save, touch buttons, finale -> ending -> victory -> credits |
| test_play | 104 | 104 passed | jump limits vs real physics, variable jump, coyote, buffer, double/wall jump, ladders, moving platforms, combat (combo, heavy, i-frames, dodge, heal, magic), all 8 enemy kinds, items, equipment effects, skills, upgrades, chests, difficulty scaling, quests, shop, save round-trip and sanitising, checkpoints, room transitions, every room exit, scripted solution of every puzzle room |
| test_fight | 63 | 63 passed | a bot beats each boss 3 times (different seeds) using real attacks |
| test_extras | 52 | 52 passed | auto-aim, battery saver, achievements, scarves, set bonus, elites, Echo bosses, New Game+, save export/import (including garbage and future-version codes), daily seed rotation, trial isolation, auto-pause |

Total: 532 checks, 0 failures. The tests also found and I fixed real bugs: push blocks were never ticked (block puzzles
were unsolvable), `change_room` overwrote the respawn shrine, a chest could be looted twice, flying bosses made armour too
punishing (armour reduced to 0.6 damage).

## What was NOT done (honest)
- **No human manual playthrough.** The author is an AI working in a cloud container with no display, controller or phone.
  "Manual" verification consisted of rendering screenshots (title, cutscene, gameplay, pause, settings, equipment, skills,
  map, characters, region themes) and reading them, plus the bots above. Nobody has played the campaign start to finish.
- The fight bot is invulnerable; it shows bosses can be damaged and defeated, not how hard they are for a person.
  Flying bosses (Astral Watcher, Eclipse Architect) took the bot 80-130 s of simulated time; others 30-50 s.
- The APK is built in CI and the build succeeds; it has not been installed or run on a real Android device, so touch
  feel and frame rate on a modest phone are unverified.
- No automated test drives a full 49-room physical run; room reachability is proven by the verifier's conservative model,
  whose jump limits were spot-checked against the real physics (gaps up to 5 tiles crossable without abilities, 6 with dash).
- Audio quality and visual polish are subjective and were not judged by a person.
