class_name KaelArt
extends Node2D
## Kael drawn procedurally as a posed skeleton (two-bone IK for arms and legs) with smoothed pose blending,
## flowing cape and scarf, a glowing sword and slash arcs. All animation is driven by Player state.

const SKIN := Color(0.96, 0.78, 0.62)
const TUNIC := Color(0.17, 0.46, 0.66)
const TUNIC_D := Color(0.1, 0.3, 0.46)
const TRIM := Color(0.97, 0.85, 0.4)
const PANTS := Color(0.2, 0.22, 0.34)
const BOOT := Color(0.38, 0.23, 0.15)
const SCARF := Color(0.92, 0.3, 0.22)
const HAIR := Color(0.36, 0.2, 0.12)
const STEEL := Color(0.88, 0.94, 1.0)
const GLOW := Color(0.45, 0.92, 1.0)
const OUT := Color(0.06, 0.05, 0.1)

var player: Player
var pose := {
	"lean": 0.0, "bob": 0.0, "crouch": 0.0, "head": 0.0,
	"fx": 6.0, "fy": 0.0, "bx": -6.0, "by": 0.0,                 # foot targets relative to hip (front/back)
	"hx": 10.0, "hy": -8.0, "ax": -6.0, "ay": 6.0,               # hand targets relative to shoulder (front/back)
	"sword": 0.6, "sword_vis": 1.0, "roll": 0.0,
}
var _cape: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _scarf: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _run_phase: float = 0.0
var _slash_t: float = 0.0
var _last_state: String = ""


func _process(delta: float) -> void:
	pass


func _target_pose() -> Dictionary:
	var p := player
	var t := {}
	var speed := absf(p.vel.x)
	var st := p.state
	var f := float(p.facing)
	t["lean"] = 0.0
	t["bob"] = 0.0
	t["crouch"] = 0.0
	t["head"] = 0.0
	t["roll"] = 0.0
	t["sword_vis"] = 1.0
	# defaults: relaxed
	t["fx"] = 3.0; t["fy"] = 0.0; t["bx"] = -3.0; t["by"] = 0.0
	t["hx"] = 8.0; t["hy"] = 6.0; t["ax"] = -4.0; t["ay"] = 9.0
	t["sword"] = 1.15
	if st == "normal" or st == "interact":
		if not p.on_floor and not p.in_water and p.wall_dir == 0:
			if p.vel.y < -40.0:      # rising
				t["fx"] = 7.0; t["fy"] = -6.0; t["bx"] = -4.0; t["by"] = -2.0
				t["hx"] = 9.0; t["hy"] = -9.0; t["ax"] = -3.0; t["ay"] = -10.0
				t["sword"] = -0.7
				t["lean"] = 0.05
			else:                    # falling
				t["fx"] = 6.0; t["fy"] = 3.0; t["bx"] = -7.0; t["by"] = 1.0
				t["hx"] = 10.0; t["hy"] = -3.0; t["ax"] = -8.0; t["ay"] = -4.0
				t["sword"] = 0.2
				t["lean"] = -0.04
		elif p.wall_dir != 0:
			t["fx"] = 4.0; t["fy"] = -4.0; t["bx"] = 3.0; t["by"] = 2.0
			t["hx"] = 8.0; t["hy"] = -12.0; t["ax"] = 7.0; t["ay"] = -9.0
			t["sword"] = -0.4
		elif p.in_water:
			var s := sin(p._anim_t * 6.0)
			t["fx"] = 5.0 + s * 4.0; t["fy"] = -3.0; t["bx"] = -5.0 - s * 4.0; t["by"] = -2.0
			t["hx"] = 8.0; t["hy"] = -4.0 + s * 3.0; t["ax"] = -4.0; t["ay"] = -2.0 - s * 3.0
			t["lean"] = 0.25
		elif speed > 20.0:
			var ph := _run_phase
			var run := clampf(speed / Tune.RUN_SPEED, 0.0, 1.2)
			var stride := 6.0 + 7.0 * run
			var lift := 3.0 + 6.0 * run
			t["fx"] = sin(ph) * stride; t["fy"] = -maxf(0.0, cos(ph)) * lift
			t["bx"] = -sin(ph) * stride; t["by"] = -maxf(0.0, -cos(ph)) * lift
			t["hx"] = 4.0 - sin(ph) * (4.0 + 4.0 * run) + 6.0 * run; t["hy"] = 6.0 - 10.0 * run
			t["ax"] = -2.0 + sin(ph) * (4.0 + 4.0 * run) - 4.0 * run; t["ay"] = 8.0 - 8.0 * run
			t["lean"] = 0.12 + 0.18 * run
			t["bob"] = -absf(sin(ph)) * (1.5 + 1.5 * run)
			t["sword"] = 1.0 - 0.7 * run
		else:
			t["bob"] = sin(p._anim_t * 2.4) * 0.8
			t["hy"] = 6.0 + sin(p._anim_t * 2.4) * 0.8
			t["sword"] = 1.1 + sin(p._anim_t * 2.4) * 0.05
		if p.crouching:
			t["crouch"] = 1.0
			t["lean"] = 0.2
		if p.land_t > 0.0 and p.on_floor:
			t["crouch"] = maxf(t["crouch"], clampf(p.land_t / 0.14, 0.0, 1.0) * 0.8)
		if st == "interact":
			t["hx"] = 15.0; t["hy"] = 0.0; t["sword"] = 1.5; t["lean"] = 0.15
	elif st == "climb":
		var ph2 := p.position.y * 0.09
		t["fx"] = 3.0; t["fy"] = sin(ph2) * 6.0 - 2.0; t["bx"] = 2.0; t["by"] = -sin(ph2) * 6.0 - 2.0
		t["hx"] = 7.0; t["hy"] = -10.0 + sin(ph2) * 7.0; t["ax"] = 5.0; t["ay"] = -10.0 - sin(ph2) * 7.0
		t["sword_vis"] = 0.0
	elif st == "dash":
		t["lean"] = 0.65
		t["fx"] = 12.0; t["fy"] = -3.0; t["bx"] = -13.0; t["by"] = -4.0
		t["hx"] = -3.0; t["hy"] = 3.0; t["ax"] = -9.0; t["ay"] = 4.0
		t["sword"] = 0.1
	elif st == "dodge":
		t["roll"] = clampf(p.state_t / 0.24, 0.0, 1.0)
		t["crouch"] = 1.0
		t["fx"] = 4.0; t["bx"] = -2.0; t["fy"] = -6.0; t["by"] = -6.0
		t["hx"] = 4.0; t["hy"] = 6.0; t["ax"] = 2.0; t["ay"] = 6.0
		t["sword_vis"] = 0.6
	elif st == "hurt":
		t["lean"] = -0.35
		t["fx"] = 6.0; t["fy"] = -2.0; t["bx"] = -7.0; t["by"] = 0.0
		t["hx"] = -2.0; t["hy"] = -12.0; t["ax"] = -9.0; t["ay"] = -8.0
		t["head"] = -0.3
		t["sword"] = -1.2
	elif st == "heal":
		t["crouch"] = 0.5
		t["hx"] = 6.0; t["hy"] = 0.0; t["ax"] = 4.0; t["ay"] = 2.0
		t["sword"] = 1.45
		t["lean"] = 0.1
		t["head"] = -0.15
	elif st == "magic":
		t["lean"] = 0.12
		t["fx"] = 7.0; t["bx"] = -7.0
		t["hx"] = 17.0; t["hy"] = -1.0 - minf(p.state_t * 8.0, 3.0); t["ax"] = -6.0; t["ay"] = -2.0
		t["sword"] = 1.5
	elif st == "victory":
		t["bob"] = -absf(sin(p.state_t * 4.0)) * 3.0
		t["hx"] = 5.0; t["hy"] = -17.0; t["ax"] = -4.0; t["ay"] = -15.0
		t["sword"] = -1.3
		t["lean"] = -0.08
	elif st == "dead":
		t["lean"] = 0.0
		t["fx"] = 6.0; t["bx"] = -6.0
		t["hx"] = 6.0; t["hy"] = 8.0; t["ax"] = -6.0; t["ay"] = 8.0
		t["sword"] = 1.4
		t["roll"] = -0.25
	elif st == "attack":
		_attack_pose(t)
	return t


func _attack_pose(t: Dictionary) -> void:
	var p := player
	var a: Dictionary = Player.ATTACKS[p.atk_kind]
	var ts: float = p.atk_t
	var s: float = a["start"]
	var ac: float = a["active"]
	var rec: float = a["rec"]
	var u := 0.0     # progress through swing 0..1
	var phase := "wind"
	if ts < s:
		phase = "wind"
		u = ts / s
	elif ts < s + ac:
		phase = "swing"
		u = (ts - s) / ac
	else:
		phase = "rec"
		u = clampf((ts - s - ac) / rec, 0.0, 1.0)
	t["fx"] = 8.0; t["bx"] = -8.0; t["fy"] = 0.0; t["by"] = 0.0
	t["ax"] = -7.0; t["ay"] = 3.0
	var k: String = p.atk_kind
	var w0 := -2.3
	var w1 := 1.0
	var lean0 := -0.1
	var lean1 := 0.3
	var reach0 := 9.0
	var reach1 := 15.0
	match k:
		"l1":
			w0 = -2.2; w1 = 0.9
		"l2":
			w0 = 1.6; w1 = -1.5; lean0 = 0.2; lean1 = 0.05
		"l3":
			w0 = -2.9; w1 = 1.5; lean0 = -0.25; lean1 = 0.4; reach1 = 17.0
			t["fx"] = 11.0; t["bx"] = -11.0
		"heavy":
			w0 = -3.0; w1 = 1.7; lean0 = -0.45; lean1 = 0.5; reach0 = 6.0; reach1 = 17.0
			t["crouch"] = 0.25 if phase == "wind" else 0.0
		"air":
			w0 = -1.2; w1 = 2.4; lean0 = 0.0; lean1 = 0.2
			t["fx"] = 7.0; t["fy"] = -5.0; t["bx"] = -5.0; t["by"] = -3.0
		"dash":
			w0 = 0.1; w1 = 0.0; lean0 = 0.6; lean1 = 0.75; reach0 = 10.0; reach1 = 19.0
			t["fx"] = 13.0; t["bx"] = -13.0
	var sw := w0
	var lean := lean0
	var reach := reach0
	match phase:
		"wind":
			var e := u * u
			sw = lerpf(w0 * 0.55 + 0.4, w0, e)
			lean = lerpf(0.0, lean0, e)
			reach = lerpf(10.0, reach0, e)
		"swing":
			var e2 := 1.0 - pow(1.0 - u, 3.0)
			sw = lerpf(w0, w1, e2)
			lean = lerpf(lean0, lean1, e2)
			reach = lerpf(reach0, reach1, e2)
		"rec":
			sw = lerpf(w1, 1.1, u)
			lean = lerpf(lean1, 0.1, u)
			reach = lerpf(reach1, 8.0, u)
	t["sword"] = sw
	t["lean"] = lean
	# hand rides on the sword grip direction (arm extends along a slightly offset angle)
	t["hx"] = cos(sw - 0.2) * reach
	t["hy"] = sin(sw - 0.2) * reach - 2.0
	t["ax"] = cos(sw - 0.2) * (reach * 0.6) - 4.0
	t["ay"] = sin(sw - 0.2) * (reach * 0.6) + 1.0


func _ik(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := target - root
	var dist := clampf(d.length(), 0.001, l1 + l2 - 0.01)
	var base := d.angle()
	var cosA := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var a := acos(cosA)
	return root + Vector2.from_angle(base + a * bend) * l1


func _line(a: Vector2, b: Vector2, w: float, col: Color, outline: bool = true) -> void:
	if outline:
		draw_line(a, b, OUT, w + 2.4, true)
	draw_line(a, b, col, w, true)


func _draw() -> void:
	if player == null:
		return
	var p := player
	var dt := get_process_delta_time()
	# state change bookkeeping
	if p.state != _last_state:
		_last_state = p.state
	if p.on_floor and p.state == "normal":
		_run_phase += absf(p.vel.x) * dt * 0.052
	elif p.state != "normal":
		_run_phase += absf(p.vel.x) * dt * 0.03
	var target := _target_pose()
	var rate := 24.0 if p.state == "attack" else 15.0
	var k := 1.0 - exp(-rate * dt)
	for key in target:
		pose[key] = lerpf(float(pose[key]), float(target[key]), k)
	var f := float(p.facing)
	var flash := p.hurt_flash > 0.0 and int(p._anim_t * 40.0) % 2 == 0
	var blink := p.invuln_t > 0.0 and p.state != "hurt" and int(p._anim_t * 16.0) % 2 == 0 and p.invuln_t < 0.95
	var alpha := 0.45 if blink else 1.0
	# ---- body transform (facing flips x, roll rotates about the body centre)
	var cy := -18.0
	draw_set_transform(Vector2(0, cy), float(pose["roll"]) * TAU * f, Vector2(f, 1.0))
	var crouch: float = pose["crouch"]
	var bob: float = float(pose["bob"]) + crouch * 9.0
	var hip := Vector2(0, -19.0 + bob - cy)
	var lean: float = pose["lean"]
	var sh := hip + Vector2(sin(lean) * 15.0, -cos(lean) * 15.0)
	var neck := sh + Vector2(sin(lean) * 3.0, -cos(lean) * 3.0)
	var head_c := neck + Vector2(1.0 + sin(lean) * 4.0, -6.0)
	var foot_y := 0.0 - cy
	var col_mod := Color(1, 1, 1, alpha)
	if flash:
		col_mod = Color(3.0, 3.0, 3.0, alpha)
	# ---- feet via IK
	var gnd := Vector2(0, foot_y)
	var ffoot := Vector2(hip.x + float(pose["fx"]), minf(foot_y + float(pose["fy"]), foot_y) )
	var bfoot := Vector2(hip.x + float(pose["bx"]), minf(foot_y + float(pose["by"]), foot_y))
	if p.state == "normal" and not p.on_floor:
		ffoot.y = hip.y + 19.0 + float(pose["fy"])
		bfoot.y = hip.y + 19.0 + float(pose["by"])
	# crouch folds the hips down so feet stay on the ground
	var kf := _ik(hip, ffoot, 9.5, 9.5, 1.0)
	var kb := _ik(hip, bfoot, 9.5, 9.5, 1.0)
	var back_mod := Color(0.78, 0.78, 0.85, 1.0)
	# ---- cape (behind everything)
	_update_cape(p, dt, sh, f)
	_draw_cape(sh, col_mod)
	# ---- back arm
	var hand_b := sh + Vector2(float(pose["ax"]), float(pose["ay"]))
	var elb_b := _ik(sh, hand_b, 7.5, 7.5, -1.0)
	_line(sh, elb_b, 4.0, (TUNIC_D * back_mod) * col_mod)
	_line(elb_b, hand_b, 3.6, (SKIN * back_mod) * col_mod)
	# ---- back leg
	_line(hip, kb, 5.0, (PANTS * back_mod) * col_mod)
	_line(kb, bfoot, 4.6, (PANTS * back_mod) * col_mod)
	_draw_boot(bfoot, back_mod * col_mod)
	# ---- torso
	draw_line(hip, sh, OUT, 12.4, true)
	draw_line(hip, sh, TUNIC * col_mod, 10.0, true)
	draw_line(hip + (sh - hip) * 0.15, hip + (sh - hip) * 0.35, TRIM * col_mod, 10.2, true)     # belt
	draw_line(sh + Vector2(-3, 1), sh + Vector2(3, -1), TUNIC_D * col_mod, 4.0, true)          # shoulder
	# ---- front leg
	_line(hip, kf, 5.2, PANTS.lightened(0.08) * col_mod)
	_line(kf, ffoot, 4.8, PANTS.lightened(0.08) * col_mod)
	_draw_boot(ffoot, col_mod)
	# ---- head
	_draw_head(head_c, neck, f, col_mod)
	# ---- scarf
	_draw_scarf(neck, p, dt, col_mod)
	# ---- front arm + sword
	var hand_f := sh + Vector2(float(pose["hx"]), float(pose["hy"]))
	var elb_f := _ik(sh, hand_f, 7.5, 7.5, -1.0)
	_line(sh, elb_f, 4.3, TUNIC * col_mod)
	_line(elb_f, hand_f, 3.9, SKIN * col_mod)
	if float(pose["sword_vis"]) > 0.05:
		_draw_sword(hand_f, float(pose["sword"]), col_mod, p)
	if p.state == "attack":
		_draw_slash(sh, p)
	if p.state == "magic" or p.state == "heal":
		_draw_cast(hand_f, p)
	if p.state == "dash":
		draw_line(Vector2(-16, -18), Vector2(-46, -18), Color(GLOW.r, GLOW.g, GLOW.b, 0.5), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boot(foot: Vector2, mod: Color) -> void:
	draw_circle(foot + Vector2(2.0, -1.5), 3.6, OUT)
	draw_circle(foot + Vector2(2.0, -1.5), 2.8, BOOT * mod)
	draw_rect(Rect2(foot + Vector2(-2.5, -3.2), Vector2(6.5, 3.4)), BOOT * mod)


func _draw_head(c: Vector2, neck: Vector2, f: float, mod: Color) -> void:
	var tilt: float = pose["head"]
	draw_circle(c, 7.7, OUT)
	draw_circle(c, 6.4, SKIN * mod)
	# hair: spiky tuft
	var hair := PackedVector2Array([c + Vector2(-6.5, -1), c + Vector2(-7.5, -6), c + Vector2(-3.5, -4.5), c + Vector2(-3.0, -9.0),
		c + Vector2(0.5, -6.5), c + Vector2(3.5, -8.5), c + Vector2(4.2, -4.0), c + Vector2(6.5, -3.0), c + Vector2(6.2, 0.0), c + Vector2(0.0, -2.0)])
	draw_colored_polygon(hair, HAIR * mod)
	draw_polyline(hair, OUT, 1.2, true)
	# eye + brow
	draw_circle(c + Vector2(2.8, 0.4), 1.25, Color(0.1, 0.1, 0.2))
	draw_circle(c + Vector2(3.1, 0.0), 0.45, Color.WHITE)
	draw_line(c + Vector2(1.4, -1.8), c + Vector2(4.4, -1.4 + tilt), OUT, 1.0)


func _update_cape(p: Player, dt: float, sh: Vector2, f: float) -> void:
	var drag := Vector2(-p.vel.x * f * 0.012, -p.vel.y * 0.012)
	var rest := Vector2(-2.5, 4.5)
	var prev := sh + Vector2(-2.0, 0.0)
	for i in _cape.size():
		var want: Vector2 = prev + (rest + drag) * 0.9 + Vector2(0, sin(p._anim_t * 5.0 + i) * 0.8)
		_cape[i] = (_cape[i] as Vector2).lerp(want, clampf(dt * 14.0, 0.0, 1.0)) if _cape[i] != Vector2.ZERO else want
		prev = _cape[i]


func _draw_cape(sh: Vector2, mod: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(sh + Vector2(-1, -1))
	for c in _cape:
		pts.append(c + Vector2(0, -3))
	for i in range(_cape.size() - 1, -1, -1):
		pts.append((_cape[i] as Vector2) + Vector2(1.5, 6))
	pts.append(sh + Vector2(3, 3))
	draw_colored_polygon(pts, Color(0.75, 0.2, 0.25) * mod)
	draw_polyline(pts, OUT, 1.2, true)


func _draw_scarf(neck: Vector2, p: Player, dt: float, mod: Color) -> void:
	var drag := Vector2(-p.vel.x * float(p.facing) * 0.06, -p.vel.y * 0.04)
	var prev := neck + Vector2(-2, 1)
	var pts := PackedVector2Array([prev])
	for i in _scarf.size():
		var want: Vector2 = prev + Vector2(-5.0, 2.0) + drag * 0.5 + Vector2(0, sin(p._anim_t * 8.0 + i * 1.3) * 1.5)
		_scarf[i] = (_scarf[i] as Vector2).lerp(want, clampf(dt * 16.0, 0.0, 1.0)) if _scarf[i] != Vector2.ZERO else want
		pts.append(_scarf[i])
		prev = _scarf[i]
	draw_polyline(pts, OUT, 6.4, true)
	draw_polyline(pts, SCARF * mod, 4.0, true)
	draw_line(neck + Vector2(-3, 1), neck + Vector2(4, 1), SCARF * mod, 4.6, true)


func _draw_sword(hand: Vector2, ang: float, mod: Color, p: Player) -> void:
	var dir := Vector2.from_angle(ang)
	var perp := dir.rotated(PI * 0.5)
	var base := hand
	var guard := base + dir * 2.5
	var tip := base + dir * 27.0
	var vis := float(pose["sword_vis"])
	draw_line(base - dir * 3.0, base + dir * 2.0, OUT, 3.2, true)
	draw_line(base - dir * 3.0, base + dir * 2.0, BOOT * mod, 2.0, true)
	draw_line(guard - perp * 4.5, guard + perp * 4.5, OUT, 3.4, true)
	draw_line(guard - perp * 4.0, guard + perp * 4.0, TRIM * mod, 2.0, true)
	var blade := PackedVector2Array([guard + perp * 1.8, tip, guard - perp * 1.8])
	draw_line(guard, tip, OUT, 5.0, true)
	draw_line(guard, tip, STEEL * mod, 3.2, true)
	draw_line(guard + dir * 3.0, tip - dir * 3.0, GLOW * mod, 1.2, true)
	var pulse := 0.6 + 0.4 * sin(p._anim_t * 4.0)
	draw_circle(guard + dir * 1.0, 2.0 + pulse, Color(GLOW.r, GLOW.g, GLOW.b, 0.55 * vis))
	draw_circle(guard + dir * 1.0, 1.1, Color.WHITE)


func _draw_slash(sh: Vector2, p: Player) -> void:
	var a: Dictionary = Player.ATTACKS[p.atk_kind]
	var ts := p.atk_t
	var s: float = a["start"]
	var ac: float = a["active"]
	if ts < s * 0.6 or ts > s + ac + 0.1:
		return
	var u := clampf((ts - s) / (ac + 0.1), 0.0, 1.0)
	var k: String = p.atk_kind
	var r := float(a["reach"]) * 0.78
	var a0 := -2.3
	var a1 := 0.9
	match k:
		"l2": a0 = 1.6; a1 = -1.5
		"l3": a0 = -2.9; a1 = 1.5; r *= 1.1
		"heavy": a0 = -3.0; a1 = 1.7; r *= 1.15
		"air": a0 = -1.2; a1 = 2.4
		"dash": a0 = -0.25; a1 = 0.25
	var cur := lerpf(a0, a1, 1.0 - pow(1.0 - clampf(u * 1.4, 0.0, 1.0), 3.0))
	var steps := 14
	var col := Color(0.85, 0.97, 1.0)
	if k == "l3" or k == "heavy":
		col = Color(1.0, 0.95, 0.65)
	for i in steps:
		var t0 := float(i) / steps
		var ang0 := lerpf(a0, cur, t0)
		var ang1 := lerpf(a0, cur, float(i + 1) / steps)
		var alpha := t0 * (1.0 - u * 0.75)
		draw_line(sh + Vector2.from_angle(ang0) * r, sh + Vector2.from_angle(ang1) * r, Color(col.r, col.g, col.b, alpha * 0.9), 2.0 + 5.0 * t0, true)


func _draw_cast(hand: Vector2, p: Player) -> void:
	var col := GLOW if p.state == "magic" else Color(0.5, 1.0, 0.7)
	var t := p.state_t
	var r := 3.0 + 4.0 * minf(t / 0.2, 1.0) if p.state == "magic" else 4.0 + 3.0 * sin(t * 18.0)
	draw_circle(hand + Vector2(5, -1), r + 3.0, Color(col.r, col.g, col.b, 0.25))
	draw_circle(hand + Vector2(5, -1), r, Color(col.r, col.g, col.b, 0.8))
	draw_circle(hand + Vector2(5, -1), r * 0.45, Color.WHITE)
