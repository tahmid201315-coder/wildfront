extends Control
## Draws the logo immediately (never a black screen), validates data, generates procedural audio
## on a background thread, loads settings, then emits `finished`. Shows errors instead of hanging.

signal finished

const UI = preload("res://scripts/ui/ui_kit.gd")

var _t: float = 0.0
var _status: String = "Starting"
var _progress: float = 0.0
var _error: String = ""
var _retry: Button


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_retry = UI.button("Retry", _start, Vector2(220, 60), true)
	_retry.visible = false
	add_child(_retry)
	_start()


func _start() -> void:
	_error = ""
	_retry.visible = false
	_run()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_retry.position = Vector2(size.x * 0.5 - 110, size.y - 120)


func _fail(msg: String) -> void:
	_error = msg
	_status = "Something went wrong"
	_retry.visible = true
	push_error("Boot failed: " + msg)


func _run() -> void:
	_status = "Checking game data"
	_progress = 0.1
	await get_tree().process_frame
	var errs: Array = Data.validate()
	if not errs.is_empty():
		_fail("Game data is inconsistent:\n" + "\n".join(errs.slice(0, 8)))
		return
	_status = "Synthesising sound"
	_progress = 0.3
	await get_tree().process_frame
	await Sfx.generate_async()
	if not Sfx.ready_to_play:
		push_warning("Audio generation failed; continuing silently.")
	_progress = 0.85
	_status = "Loading settings"
	await get_tree().process_frame
	Game.load_settings()
	_progress = 1.0
	_status = "Welcome, explorer"
	await get_tree().create_timer(0.3).timeout
	finished.emit()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.07, 0.08))
	var sc := clampf(s.y / 720.0, 0.6, 1.4)
	UI.draw_logo(self, Vector2(s.x * 0.5, s.y * 0.36), sc, _t)
	var font := ThemeDB.fallback_font
	var bw := 420.0 * sc
	var bx := (s.x - bw) * 0.5
	var by := s.y * 0.78
	draw_rect(Rect2(bx, by, bw, 14), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bx, by, bw * _progress, 14), UI.COL_ACCENT)
	draw_rect(Rect2(bx, by, bw, 14), Color(1, 1, 1, 0.5), false, 2.0)
	var tw := font.get_string_size(_status, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
	draw_string(font, Vector2((s.x - tw) * 0.5, by + 42), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.9, 0.9))
	if _error != "":
		draw_multiline_string(font, Vector2(s.x * 0.15, by + 80), _error, HORIZONTAL_ALIGNMENT_LEFT, s.x * 0.7, 18, 8, Color(1, 0.5, 0.45))
