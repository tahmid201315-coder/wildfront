extends "res://scripts/ui/modal.gd"
## Inventory + equipment. Tap an item for details, then Use / Equip / Drop.

var _grid: GridContainer
var _detail: VBoxContainer
var _equip_row: HBoxContainer
var _count_label: Label
var _sel: int = -1
var _sel_equip: String = ""


class Slot extends Button:
	var data: Dictionary = {}
	var item_icon: Control
	var selected: bool = false

	func _init(d: Dictionary = {}) -> void:
		data = d
		custom_minimum_size = Vector2(78, 78)
		focus_mode = Control.FOCUS_NONE
		flat = false
		text = ""
		if not d.is_empty():
			item_icon = UI.ItemIcon.new(String(d["id"]), 56)
			item_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			item_icon.position = Vector2(11, 6)
			add_child(item_icon)

	func _draw() -> void:
		if data.is_empty():
			return
		var f := ThemeDB.fallback_font
		if int(data.get("n", 1)) > 1:
			var t := "x%d" % int(data["n"])
			draw_string_outline(f, Vector2(size.x - 6 - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(size.x - 6 - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		var it: Dictionary = Data.items.get(String(data["id"]), {})
		var md := float(it.get("dur", 0))
		if md > 0.0 and data.has("dur"):
			var fr := clampf(float(data["dur"]) / md, 0.0, 1.0)
			draw_rect(Rect2(8, size.y - 10, size.x - 16, 4), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(8, size.y - 10, (size.x - 16) * fr, 4), Color(0.4, 0.9, 0.4).lerp(Color(0.95, 0.3, 0.2), 1.0 - fr))
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), UI.COL_ACCENT, false, 3.0)


func _init() -> void:
	super._init("Inventory", Game.State.INVENTORY, true)
	max_size = Vector2(1180, 660)


func _build() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	row.add_child(left)
	_equip_row = HBoxContainer.new()
	left.add_child(_equip_row)
	var hb := HBoxContainer.new()
	left.add_child(hb)
	_count_label = UI.label("", 20, UI.COL_DIM)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_count_label)
	hb.add_child(UI.button("Sort", func():
		Inv.sort_inventory()
		_sel = -1
		refresh(), Vector2(110, 46)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 6
	sc.add_child(_grid)
	var dp := PanelContainer.new()
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dp.custom_minimum_size.x = 340
	row.add_child(dp)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.add_child(_detail)


func refresh() -> void:
	UI.clear(_grid)
	UI.clear(_equip_row)
	var cap: int = Inv.capacity()
	var used := 0
	for i in cap:
		var d: Dictionary = Inv.slots[i]
		var b := Slot.new(d)
		if not d.is_empty():
			used += 1
		b.selected = (i == _sel and _sel_equip == "")
		var idx := i
		b.pressed.connect(func():
			_sel = idx
			_sel_equip = ""
			Sfx.play("click")
			refresh())
		_grid.add_child(b)
	_count_label.text = "Pack: %d / %d slots" % [used, cap]
	for slot in ["weapon", "armor", "suit", "pack"]:
		var col := VBoxContainer.new()
		var e: Dictionary = Game.equip.get(slot, {})
		var b2 := Slot.new(e)
		b2.selected = (_sel_equip == slot)
		var sname: String = slot
		b2.pressed.connect(func():
			_sel_equip = sname
			_sel = -1
			Sfx.play("click")
			refresh())
		col.add_child(b2)
		col.add_child(UI.label({"weapon": "Weapon", "armor": "Armour", "suit": "Suit", "pack": "Pack"}[slot], 16, UI.COL_DIM))
		_equip_row.add_child(col)
	_show_detail()


func _show_detail() -> void:
	UI.clear(_detail)
	var d: Dictionary = {}
	if _sel_equip != "":
		d = Game.equip.get(_sel_equip, {})
	elif _sel >= 0 and _sel < Inv.slots.size():
		d = Inv.slots[_sel]
	if d.is_empty():
		var w: Dictionary = Game.weapon_item()
		_detail.add_child(UI.label("Select an item.", 22, UI.COL_DIM))
		_detail.add_child(UI.spacer(10))
		_detail.add_child(UI.label("Defence: %d%%" % int(Game.damage_reduction() * 100.0), 20, UI.COL_TEXT))
		_detail.add_child(UI.label("Heat protection: %d%%" % int(Game.heat_protection() * 100.0), 20, UI.COL_TEXT))
		_detail.add_child(UI.label("Cold protection: %d%%" % int(Game.cold_protection() * 100.0), 20, UI.COL_TEXT))
		_detail.add_child(UI.label("Weapon: %s (damage %d)" % [w["name"], int(w["dmg"])], 20, UI.COL_TEXT))
		return
	var id := String(d["id"])
	var it: Dictionary = Data.items[id]
	var head := HBoxContainer.new()
	head.add_child(UI.ItemIcon.new(id, 64))
	head.add_child(UI.label(String(it["name"]), 26, UI.COL_ACCENT, true))
	_detail.add_child(head)
	_detail.add_child(UI.label(String(it["desc"]), 20, UI.COL_TEXT, true))
	var stats := []
	if it.has("hunger"): stats.append("Hunger +%d" % int(it["hunger"]))
	if it.has("health"): stats.append("Health %+d" % int(it["health"]))
	if it.has("stamina"): stats.append("Stamina +%d" % int(it["stamina"]))
	if it.has("dmg"): stats.append("Damage %d, reach %.1f m" % [int(it["dmg"]), float(it["reach"])])
	if it.has("tool"): stats.append("%s tier %d" % [String(it["tool"]).capitalize(), int(it["tier"])])
	if it.has("def"): stats.append("Defence %d%%" % int(float(it["def"]) * 100.0))
	if it.has("heat"): stats.append("Heat protection %d%%" % int(float(it["heat"]) * 100.0))
	if it.has("cold"): stats.append("Cold protection %d%%" % int(float(it["cold"]) * 100.0))
	if it.has("slots"): stats.append("+%d pack slots" % int(it["slots"]))
	if d.has("dur") and float(it.get("dur", 0)) > 0:
		stats.append("Durability %d / %d" % [int(d["dur"]), int(it["dur"])])
	for s in stats:
		_detail.add_child(UI.label(s, 19, UI.COL_GOOD))
	_detail.add_child(UI.spacer(6))
	if _sel_equip != "":
		_detail.add_child(UI.button("Unequip", func():
			var e: String = Inv.unequip(_sel_equip)
			if e != "":
				Game.toast(e, "warn")
			_sel_equip = ""
			refresh(), Vector2(0, 54), true))
		return
	var usable: bool = it.has("hunger") or it.has("health") or it.has("stamina") or it.has("heat_ward") or it.has("repair")
	var equippable: bool = String(it["cat"]) == "weapon" or it.has("slot")
	if usable:
		_detail.add_child(UI.button("Use", func():
			Game.use_item(id)
			Sfx.play("eat" if it.has("hunger") else "heal")
			refresh(), Vector2(0, 54), true))
	if equippable:
		_detail.add_child(UI.button("Equip", func():
			var e: String = Inv.equip_slot_index(_sel)
			if e != "":
				Game.toast(e, "warn")
			else:
				Sfx.play("equip")
			_sel = -1
			refresh(), Vector2(0, 54), true))
	var n := int(d.get("n", 1))
	if not (String(it["cat"]) == "quest"):
		_detail.add_child(UI.button("Drop %s" % ("all" if n > 1 else "item"), func():
			var e2: Dictionary = Inv.remove_slot(_sel)
			if not e2.is_empty() and Game.world:
				Game.world.drop_pickup(String(e2["id"]), int(e2.get("n", 1)))
			_sel = -1
			refresh(), Vector2(0, 50)))
