extends Control
## Multi-touch input layer: floating virtual joystick (left), camera drag + pinch zoom (right),
## and multi-touch-safe action buttons. Handles raw touch events so any number of fingers can be
## used simultaneously, and releases everything if the app is interrupted.

signal look_delta(delta: Vector2)
signal zoom_delta(amount: float)

var buttons: Array = []            # TouchButton instances registered by the HUD
var active: bool = true:
	set(v):
		if active != v:
			active = v
			if not v:
				release_all()
var move_vec: Vector2 = Vector2.ZERO    # joystick output, length 0..1 (x right, y down)
var left_handed: bool = false

var joy_finger: int = -1
var joy_center: Vector2 = Vector2.ZERO
var joy_pos: Vector2 = Vector2.ZERO
var joy_rest: Vector2 = Vector2(180, 540)
var look_fingers: Dictionary = {}   # index -> last position
var button_fingers: Dictionary = {}  # index -> TouchButton

const JOY_RADIUS := 95.0
const DEADZONE := 0.12


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_update_rest)
	_update_rest()


func _vs() -> Vector2:
	# Use the viewport size so input zones never depend on this Control's layout timing.
	var v := get_viewport_rect().size
	return v if v.x > 1.0 else size


func _update_rest() -> void:
	var m := 190.0
	joy_rest = Vector2(_vs().x - m if left_handed else m, _vs().y - m)
	queue_redraw()


func register(b: Control) -> void:
	buttons.append(b)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)


func _press(idx: int, pos: Vector2) -> void:
	# 1) action buttons win
	for b in buttons:
		if b.hit(pos) and not button_fingers.has(idx):
			button_fingers[idx] = b
			b.press(idx)
			return
	# 2) joystick zone: left 42% of the screen, lower 70%
	if joy_finger == -1 and _in_joy_zone(pos):
		joy_finger = idx
		joy_center = pos
		joy_pos = pos
		_update_joy()
		queue_redraw()
		return
	# 3) everything else on the right side drags the camera
	if not _in_joy_zone_x(pos) and look_fingers.size() < 2:
		look_fingers[idx] = pos


func _in_joy_zone_x(pos: Vector2) -> bool:
	var w := _vs().x
	return pos.x > w * 0.58 if left_handed else pos.x < w * 0.42


func _in_joy_zone(pos: Vector2) -> bool:
	return _in_joy_zone_x(pos) and pos.y > _vs().y * 0.3


func _release(idx: int) -> void:
	if button_fingers.has(idx):
		button_fingers[idx].release()
		button_fingers.erase(idx)
	if idx == joy_finger:
		joy_finger = -1
		move_vec = Vector2.ZERO
		queue_redraw()
	look_fingers.erase(idx)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == joy_finger:
		joy_pos = pos
		_update_joy()
		queue_redraw()
	elif look_fingers.has(idx):
		if look_fingers.size() == 2:
			var keys := look_fingers.keys()
			var other: int = keys[0] if keys[0] != idx else keys[1]
			var before: float = look_fingers[idx].distance_to(look_fingers[other])
			look_fingers[idx] = pos
			var after: float = pos.distance_to(look_fingers[other])
			zoom_delta.emit((before - after) * 0.02)
		else:
			look_fingers[idx] = pos
			look_delta.emit(rel)


func _update_joy() -> void:
	var off := joy_pos - joy_center
	if off.length() > JOY_RADIUS:
		# let the base follow the finger so long drags never get "stuck" at the edge
		joy_center = joy_pos - off.normalized() * JOY_RADIUS
		off = joy_pos - joy_center
	var v := off / JOY_RADIUS
	if v.length() < DEADZONE:
		move_vec = Vector2.ZERO
	else:
		move_vec = v.limit_length(1.0)


func release_all() -> void:
	for idx in button_fingers.keys():
		button_fingers[idx].release()
	button_fingers.clear()
	joy_finger = -1
	move_vec = Vector2.ZERO
	look_fingers.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


func _draw() -> void:
	if not active or not is_visible_in_tree():
		return
	var center := joy_center if joy_finger != -1 else joy_rest
	var knob := joy_pos if joy_finger != -1 else joy_rest
	if joy_finger != -1:
		knob = center + (joy_pos - center).limit_length(JOY_RADIUS)
	draw_circle(center, JOY_RADIUS, Color(0.05, 0.08, 0.1, 0.35))
	draw_arc(center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	draw_arc(center, JOY_RADIUS * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.15), 2.0, true)
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.55 if joy_finger != -1 else 0.3))
	draw_arc(knob, 38.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0, true)
