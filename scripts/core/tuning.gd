extends Node
## Global gameplay constants. Pixel units; one tile is 32 px.

const TILE := 32
const GRAVITY := 1900.0
const MAX_FALL := 920.0
const RUN_SPEED := 262.0
const WALK_SPEED := 150.0
const GROUND_ACCEL := 2600.0
const GROUND_DECEL := 3000.0
const AIR_ACCEL := 1900.0
const ICE_ACCEL := 420.0
const ICE_DECEL := 260.0
const JUMP_V := 650.0
const JUMP_CUT := 0.45             # velocity multiplier when jump released early
const COYOTE := 0.11
const JUMP_BUFFER := 0.13
const WALL_SLIDE := 120.0
const WALL_JUMP_V := Vector2(280.0, -600.0)
const DASH_SPEED := 560.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.55
const CLIMB_SPEED := 130.0
const PLAYER_SIZE := Vector2(20.0, 42.0)
const INVULN_TIME := 1.0
const HITSTOP_LIGHT := 0.035
const HITSTOP_HEAVY := 0.08

# Level-generator limits derived from the above (used by the reachability checker too).
# Max standing jump height ~ JUMP_V^2 / (2 g) = 111 px = 3.4 tiles; run-jump distance ~ 5.5 tiles.
const MAX_JUMP_UP_TILES := 3
const MAX_GAP_TILES := 4
