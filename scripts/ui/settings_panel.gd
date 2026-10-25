extends "res://scripts/ui/modal.gd"
## Settings. Every control changes real behaviour through Game.set_setting().

func _init(use_state: bool = true) -> void:
	super._init("Settings", Game.State.PAUSE, use_state)


func _build() -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(UI.label("Controls", 24, UI.COL_ACCENT))
	_slider(v, "Camera sensitivity", "cam_sens", 0.3, 2.5, 0.05)
	_check(v, "Invert camera Y", "cam_invert")
	_check(v, "Vibration", "vibration")
	_check(v, "Left-handed layout", "left_handed")
	_slider(v, "Button size", "btn_scale", 0.8, 1.4, 0.05)
	v.add_child(UI.label("Graphics", 24, UI.COL_ACCENT))
	_option(v, "Graphics quality", "quality", ["Low (best battery)", "Medium", "High"])
	_check(v, "Performance mode (30 FPS, lowest settings)", "perf_mode")
	_slider(v, "Render scale", "render_scale", 0.5, 1.0, 0.05)
	_option(v, "Frame rate target", "fps", ["30 FPS", "60 FPS"], [30, 60])
	_slider(v, "Interface scale", "ui_scale", 0.8, 1.3, 0.05)
	v.add_child(UI.label("Audio", 24, UI.COL_ACCENT))
	_slider(v, "Master volume", "vol_master", 0.0, 1.0, 0.05)
	_slider(v, "Music volume", "vol_music", 0.0, 1.0, 0.05)
	_slider(v, "Effects volume", "vol_sfx", 0.0, 1.0, 0.05)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(text, 22)
	l.custom_minimum_size.x = 300
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(360, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var val := UI.label("%.2f" % s.value, 20, UI.COL_DIM)
	val.custom_minimum_size.x = 70
	var heavy := key in ["render_scale", "ui_scale", "btn_scale"]
	s.value_changed.connect(func(v: float):
		val.text = "%.2f" % v
		if not heavy:
			Game.set_setting(key, v))
	# heavy settings (render scale / UI scale) apply on release so they do not thrash while dragging
	s.drag_ended.connect(func(_changed: bool):
		if heavy:
			Game.set_setting(key, s.value))
	row.add_child(s)
	row.add_child(val)
	parent.add_child(row)


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Game.settings[key])
	c.custom_minimum_size = Vector2(0, 52)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		Game.set_setting(key, on)
		Sfx.play("click"))
	parent.add_child(c)


func _option(parent: Control, text: String, key: String, labels: Array, values: Array = []) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(text, 22)
	l.custom_minimum_size.x = 300
	row.add_child(l)
	var group_row := HBoxContainer.new()
	var current: Variant = Game.settings[key]
	for i in labels.size():
		var val: Variant = values[i] if not values.is_empty() else i
		var b := UI.button(labels[i], func(): pass, Vector2(150, 50))
		b.disabled = (val == current)
		b.pressed.connect(func():
			Game.set_setting(key, val)
			_rebuild())
		group_row.add_child(b)
	row.add_child(group_row)
	parent.add_child(row)


func _rebuild() -> void:
	UI.clear(body)
	_build()
