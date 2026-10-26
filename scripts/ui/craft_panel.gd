extends "res://scripts/ui/modal.gd"
## Crafting and building menu. Craft tab lists unlocked recipes; Build tab lists structures.

const Crafting = preload("res://scripts/systems/crafting.gd")

var _tab: String = "craft"
var _list: VBoxContainer
var _detail: VBoxContainer
var _sel: String = ""
var _tabs: HBoxContainer
var _craft_id: String = ""
var _craft_t: float = 0.0
var _craft_len: float = 0.0
var _bar: ProgressBar = null


func _init() -> void:
	super._init("Craft and Build", Game.State.INVENTORY, true)
	max_size = Vector2(1180, 660)


func _build() -> void:
	_tabs = HBoxContainer.new()
	body.add_child(_tabs)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var dp := PanelContainer.new()
	dp.custom_minimum_size.x = 400
	row.add_child(dp)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.add_child(_detail)


func open() -> void:
	_craft_id = ""
	super.open()


func close() -> void:
	_craft_id = ""
	super.close()


func refresh() -> void:
	UI.clear(_tabs)
	for t in [["craft", "Craft"], ["build", "Build"]]:
		var b := UI.button(t[1], func():
			_tab = t[0]
			_sel = ""
			refresh(), Vector2(160, 50), _tab == t[0])
		_tabs.add_child(b)
	UI.clear(_list)
	var ids: Array = []
	if _tab == "craft":
		for id in Data.recipes:
			if Crafting.is_unlocked(id):
				ids.append(id)
	else:
		for id in Data.structures:
			if Game.unlocked(String(Data.structures[id]["unlock"])):
				ids.append(id)
	var tier_order := {"starter": 0, "intermediate": 1, "advanced": 2}
	ids.sort_custom(func(a, b):
		var da: Dictionary = Data.recipes[a] if _tab == "craft" else Data.structures[a]
		var db: Dictionary = Data.recipes[b] if _tab == "craft" else Data.structures[b]
		var ta: int = tier_order.get(String(da["tier"]), 0)
		var tb: int = tier_order.get(String(db["tier"]), 0)
		if ta != tb:
			return ta < tb
		return a < b)
	if _sel == "" or not ids.has(_sel):
		_sel = ids[0] if not ids.is_empty() else ""
	for id in ids:
		_list.add_child(_row(id))
	_show_detail()


func _row(id: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(h)
	var ok := false
	var title := ""
	var sub := ""
	var icon_id := ""
	if _tab == "craft":
		var r: Dictionary = Data.recipes[id]
		icon_id = String(r["out"])
		title = "%s%s" % [Data.item_name(icon_id), "" if int(r["qty"]) == 1 else " x%d" % int(r["qty"])]
		var bl := Crafting.blocker(id)
		ok = bl == ""
		sub = Crafting.station_label(String(r["station"])) if bl == "" else bl
	else:
		var s: Dictionary = Data.structures[id]
		title = String(s["name"])
		var missing: Dictionary = Inv.missing(_cost(id))
		ok = missing.is_empty()
		sub = "Ready to build" if ok else "Missing materials"
	if icon_id != "":
		var ic := UI.ItemIcon.new(icon_id, 52)
		h.add_child(ic)
	else:
		h.add_child(UI.spacer(0))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var l1 := UI.label(title, 22, UI.COL_TEXT if ok else UI.COL_DIM)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l2 := UI.label(sub, 17, UI.COL_GOOD if ok else UI.COL_BAD)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	v.add_child(l2)
	h.add_child(v)
	if id == _sel:
		b.add_theme_stylebox_override("normal", UI.style(UI.COL_PANEL_LIGHT.lightened(0.08), 12, UI.COL_ACCENT, 2, 10))
	b.pressed.connect(func():
		_sel = id
		Sfx.play("click")
		refresh())
	return b


func _cost(id: String) -> Dictionary:
	var c: Dictionary = Data.structures[id]["cost"]
	if Game.has_skill("en1"):
		var out := {}
		for k in c:
			out[k] = maxi(1, int(ceil(float(c[k]) * 0.8)))
		return out
	return c


func _ing_lines(ing: Dictionary) -> void:
	for k in ing:
		var have: int = Inv.count(k)
		var need := int(ing[k])
		var row := HBoxContainer.new()
		row.add_child(UI.ItemIcon.new(k, 36))
		var l := UI.label("%s  %d / %d" % [Data.item_name(k), have, need], 19, UI.COL_GOOD if have >= need else UI.COL_BAD)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		_detail.add_child(row)


func _show_detail() -> void:
	UI.clear(_detail)
	_bar = null
	if _sel == "":
		_detail.add_child(UI.label("Nothing available yet. Explore to find blueprints.", 20, UI.COL_DIM, true))
		return
	if _tab == "craft":
		var r: Dictionary = Data.recipes[_sel]
		var out := String(r["out"])
		var head := HBoxContainer.new()
		head.add_child(UI.ItemIcon.new(out, 64))
		head.add_child(UI.label(Data.item_name(out), 26, UI.COL_ACCENT, true))
		_detail.add_child(head)
		_detail.add_child(UI.label(String(Data.items[out]["desc"]), 19, UI.COL_TEXT, true))
		_detail.add_child(UI.label("Requires: %s" % Crafting.station_label(String(r["station"])), 19, UI.COL_DIM))
		_detail.add_child(UI.label("Time: %.1f s" % Crafting.craft_time(_sel), 19, UI.COL_DIM))
		_detail.add_child(UI.label("Materials", 21, UI.COL_ACCENT))
		_ing_lines(r["ing"])
		var bl := Crafting.blocker(_sel)
		if _craft_id == _sel:
			_bar = ProgressBar.new()
			_bar.custom_minimum_size = Vector2(0, 30)
			_bar.max_value = 1.0
			_bar.show_percentage = false
			_detail.add_child(_bar)
		else:
			var b := UI.button("Craft" if bl == "" else bl, func():
				_craft_id = _sel
				_craft_len = Crafting.craft_time(_sel)
				_craft_t = 0.0
				Sfx.play("click")
				refresh(), Vector2(0, 58), true)
			b.disabled = bl != "" or _craft_id != ""
			_detail.add_child(b)
	else:
		var s: Dictionary = Data.structures[_sel]
		_detail.add_child(UI.label(String(s["name"]), 26, UI.COL_ACCENT, true))
		_detail.add_child(UI.label(String(s["desc"]), 19, UI.COL_TEXT, true))
		_detail.add_child(UI.label("Materials", 21, UI.COL_ACCENT))
		_ing_lines(_cost(_sel))
		var ok := Inv.missing(_cost(_sel)).is_empty()
		var b2 := UI.button("Place" if ok else "Missing materials", func():
			var sid := _sel
			close()
			if Game.world:
				Game.world.begin_build(sid), Vector2(0, 58), true)
		b2.disabled = not ok
		_detail.add_child(b2)


func _process(delta: float) -> void:
	if not is_open or _craft_id == "":
		return
	_craft_t += delta
	if _bar:
		_bar.value = clampf(_craft_t / maxf(_craft_len, 0.01), 0.0, 1.0)
	if _craft_t >= _craft_len:
		var id := _craft_id
		_craft_id = ""
		var e := Crafting.craft(id)
		if e != "":
			Game.toast(e, "warn")
		refresh()
