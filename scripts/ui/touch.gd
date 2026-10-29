class_name TouchControls
extends CanvasLayer
## On-screen controls: virtual joystick plus action buttons. Size, opacity and handedness come from settings.
## Presses are injected as InputEventAction so every system (player, HUD dialogue, menus) sees them like keyboard input.

const BUTTONS := {
	"jump": {"o": Vector2(-120, -120), "r": 58.0, "t": "JUMP"},
	"light": {"o": Vector2(-255, -85), "r": 46.0, "t": "ATK"},
	"heavy": {"o": Vector2(-225, -205), "r": 42.0, "t": "HVY"},
	"dodge": {"o": Vector2(-95, -250), "r": 40.0, "t": "DODGE"},
	"magic": {"o": Vector2(-345, -180), "r": 36.0, "t": "MAGIC"},
	"ability": {"o": Vector2(-350, -295), "r": 34.0, "t": "SKILL"},
	"interact": {"o": Vector2(-445, -70), "r": 40.0, "t": "USE"},
	"heal": {"o": Vector2(-455, -170), "r": 32.0, "t": "HEAL"},
}
const PAUSE_POS := Vector2(44, 150)

var enabled := false
var forced := false
var ctrl: Control
var stick_finger := -99
var stick_center := Vector2.ZERO
var stick_vec := Vector2.ZERO
var fingers: Dictionary = {}          # finger id -> action
var held: Dictionary = {}             # action -> true
var _layout: Dictionary = {}
var _vp := Vector2(1280, 720)


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(_draw_controls)
	add_child(ctrl)
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	Game.state_changed.connect(func(_s: int) -> void: release_all())


func set_forced(v: bool) -> void:
	forced = v


func active() -> bool:
	return (enabled or forced) and Game.state == Game.State.PLAY


func compute_layout() -> void:
	_vp = ctrl.get_viewport_rect().size if ctrl.is_inside_tree() else _vp
	var s: float = float(Game.settings.get("ctrl_scale", 1.0))
	var lh: bool = Game.settings.get("left_handed", false)
	_layout.clear()
	for n in BUTTONS:
		var o: Vector2 = BUTTONS[n]["o"]
		var x := _vp.x + o.x * s if not lh else -o.x * s
		var y := _vp.y + o.y * s
		_layout[n] = {"c": Vector2(x, y), "r": float(BUTTONS[n]["r"]) * s}
	var sc := PAUSE_POS
	_layout["pause"] = {"c": Vector2(sc.x if not lh else _vp.x - sc.x, sc.y), "r": 28.0 * s}
	var jx := 170.0 * s
	stick_base = Vector2(jx if not lh else _vp.x - jx, _vp.y - 150.0 * s)
	stick_r = 95.0 * s


var stick_base := Vector2(170, 570)
var stick_r := 95.0


func _input(e: InputEvent) -> void:
	if not active():
		return
	compute_layout()
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)


func _down(id: int, pos: Vector2) -> void:
	for n in _layout:
		var d: Dictionary = _layout[n]
		if pos.distance_to(d["c"]) <= d["r"] * 1.15:
			fingers[id] = n
			_press(n)
			return
	var half := _vp.x * 0.5
	var on_stick_side := (pos.x < half) if not Game.settings.get("left_handed", false) else (pos.x > half)
	if on_stick_side and stick_finger == -99:
		stick_finger = id
		stick_center = pos if pos.distance_to(stick_base) > stick_r * 1.6 else stick_base
		stick_vec = Vector2.ZERO
		_drag(id, pos)


func _drag(id: int, pos: Vector2) -> void:
	if id != stick_finger:
		return
	var v := (pos - stick_center) / stick_r
	if v.length() > 1.0:
		v = v.normalized()
	stick_vec = v
	_apply_stick()


func _up(id: int) -> void:
	if id == stick_finger:
		stick_finger = -99
		stick_vec = Vector2.ZERO
		_apply_stick()
	if fingers.has(id):
		_release(fingers[id])
		fingers.erase(id)


func _apply_stick() -> void:
	var dead := 0.28
	_axis("left", maxf(-stick_vec.x, 0.0) if -stick_vec.x > dead else 0.0)
	_axis("right", stick_vec.x if stick_vec.x > dead else 0.0)
	_axis("up", -stick_vec.y if -stick_vec.y > 0.55 else 0.0)
	_axis("down", stick_vec.y if stick_vec.y > 0.55 else 0.0)


func _axis(a: String, strength: float) -> void:
	var on := strength > 0.0
	if on:
		_send(a, true, strength)
		held[a] = true
	elif held.has(a):
		_send(a, false, 0.0)
		held.erase(a)


func _press(n: String) -> void:
	if Game.settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	if n == "pause":
		_send("pause", true, 1.0)
		_send("pause", false, 0.0)
		return
	_send(n, true, 1.0)
	held[n] = true


func _release(n: String) -> void:
	if n == "pause":
		return
	_send(n, false, 0.0)
	held.erase(n)


func _send(a: String, pressed: bool, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)


func release_all() -> void:
	for a in held.keys():
		_send(a, false, 0.0)
	held.clear()
	fingers.clear()
	stick_finger = -99
	stick_vec = Vector2.ZERO


func _process(_dt: float) -> void:
	ctrl.visible = active()
	if ctrl.visible:
		ctrl.queue_redraw()


func _draw_controls() -> void:
	compute_layout()
	var op: float = float(Game.settings.get("ctrl_opacity", 0.75))
	var f := ThemeDB.fallback_font
	# joystick
	var base := stick_base
	var thumb := base + stick_vec * stick_r * 0.7 if stick_finger == -99 else stick_center + stick_vec * stick_r
	var bc := stick_base if stick_finger == -99 else stick_center
	ctrl.draw_circle(bc, stick_r, Color(0.1, 0.15, 0.3, 0.35 * op))
	ctrl.draw_arc(bc, stick_r, 0, TAU, 40, Color(0.7, 0.85, 1.0, 0.7 * op), 3.0)
	ctrl.draw_circle(thumb, stick_r * 0.42, Color(0.7, 0.85, 1.0, 0.55 * op))
	for n in _layout:
		var d: Dictionary = _layout[n]
		var down := held.has(n)
		var col := Color(0.12, 0.2, 0.4, 0.5 * op)
		if down:
			col = Color(0.9, 0.8, 0.4, 0.75 * op)
		ctrl.draw_circle(d["c"], d["r"], col)
		ctrl.draw_arc(d["c"], d["r"], 0, TAU, 32, Color(0.75, 0.88, 1.0, 0.8 * op), 3.0)
		var label: String = "II" if n == "pause" else str(BUTTONS[n]["t"])
		var fs := int(maxf(d["r"] * 0.38, 11.0))
		ctrl.draw_string(f, d["c"] + Vector2(-d["r"], fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, d["r"] * 2.0, fs, Color(1, 1, 1, 0.95 * op + 0.05))
