extends "res://scripts/ui/modal.gd"
## Pack (inventory grid) and Craft tabs.

const Crafting = preload("res://scripts/crafting/crafting.gd")

var tab: String = "pack"
var selected_slot: int = -1
var selected_recipe: String = ""
var station: String = ""
var world: Node = null

var _tab_pack: Button
var _tab_craft: Button
var _content: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer


func _init() -> void:
	super._init("Pack", Game.State.INVENTORY, true)


func _build() -> void:
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	_tab_pack = UI.button("Pack", func(): set_tab("pack"), Vector2(160, 52))
	_tab_craft = UI.button("Craft", func(): set_tab("craft"), Vector2(160, 52))
	tabs.add_child(_tab_pack)
	tabs.add_child(_tab_craft)
	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	Inv.changed.connect(_on_inv_changed)


func _on_inv_changed() -> void:
	if is_open:
		refresh()


func open_tab(t: String, st: String = "") -> void:
	tab = t
	station = st
	state_id = Game.State.CRAFTING if t == "craft" and st != "" else Game.State.INVENTORY
	if is_open:
		refresh()
	else:
		open()
	if t == "pack":
		Quests.notify_event("open_inventory", "", 1)


func set_tab(t: String) -> void:
	tab = t
	refresh()


func refresh() -> void:
	if _content == null:
		return
	title_label.text = "Pack  (%d / %d slots)" % [_used_slots(), Data.PACK_SLOTS] if tab == "pack" else "Crafting"
	_tab_pack.disabled = tab == "pack"
	_tab_craft.disabled = tab == "craft"
	UI.clear(_content)
	if tab == "pack":
		_build_pack()
	else:
		_build_craft()


func _used_slots() -> int:
	var n := 0
	for s in Inv.slots:
		if s != null:
			n += 1
	return n


# ------------------------------------------------------------ pack
func _build_pack() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	scroll.add_child(grid)
	for i in Inv.slots.size():
		grid.add_child(_slot_button(i))
	_right = VBoxContainer.new()
	_right.custom_minimum_size = Vector2(330, 0)
	_content.add_child(_right)
	_fill_details()


func _slot_button(i: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 84)
	b.focus_mode = Control.FOCUS_NONE
	var s = Inv.slots[i]
	if i == selected_slot:
		b.add_theme_stylebox_override("normal", UI.style(UI.COL_PANEL_LIGHT.lightened(0.1), 12, UI.COL_ACCENT, 3, 6))
	if s != null:
		var icon := UI.ItemIcon.new(s["id"], 64)
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.position = Vector2(10, 6)
		b.add_child(icon)
		var q := UI.label("x%d" % int(s["n"]), 18)
		q.position = Vector2(46, 56)
		q.add_theme_color_override("font_outline_color", Color.BLACK)
		q.add_theme_constant_override("outline_size", 6)
		b.add_child(q)
	b.pressed.connect(func():
		selected_slot = i
		Sfx.play("click")
		refresh())
	return b


func _fill_details() -> void:
	UI.clear(_right)
	var s = null
	if selected_slot >= 0 and selected_slot < Inv.slots.size():
		s = Inv.slots[selected_slot]
	if s == null:
		_right.add_child(UI.label("Select an item to see details.", 20, UI.COL_DIM, true))
		_right.add_child(UI.spacer(10))
		_right.add_child(UI.button("Sort pack", func():
			Inv.sort_items()
			selected_slot = -1
			refresh(), Vector2(0, 52)))
		return
	var d: Dictionary = Data.get_item(s["id"])
	var head := HBoxContainer.new()
	head.add_child(UI.ItemIcon.new(s["id"], 72))
	var hv := VBoxContainer.new()
	hv.add_child(UI.label(d["name"], 26, UI.COL_ACCENT))
	hv.add_child(UI.label("%s  -  x%d (max %d)" % [str(d["kind"]).capitalize(), int(s["n"]), int(d["stack"])], 18, UI.COL_DIM))
	head.add_child(hv)
	_right.add_child(head)
	_right.add_child(UI.label(d["desc"], 20, UI.COL_TEXT, true))
	var effects: Array = []
	if d.has("hunger"):
		effects.append("Hunger +%d" % int(d["hunger"]))
	if d.has("heal"):
		effects.append("Health +%d" % int(d["heal"]))
	if d.has("heat_resist"):
		effects.append("Heat protection %d s" % int(d["heat_resist"]))
	if d.has("trust"):
		effects.append("Offer to a Wildling")
	if not effects.is_empty():
		_right.add_child(UI.label(", ".join(effects), 19, UI.COL_GOOD, true))
	_right.add_child(UI.spacer(6))
	var kind: String = d["kind"]
	if (kind == "food" or kind == "consumable") and not d.has("trust"):
		_right.add_child(UI.button("Use / Eat", func():
			Game.use_item(s["id"])
			refresh(), Vector2(0, 54), true))
	if kind == "building" and world != null:
		_right.add_child(UI.button("Place (build mode)", func():
			var kit: String = s["id"]
			close()
			world.build_manager.start(kit), Vector2(0, 54), true))
	_right.add_child(UI.button("Drop 1", func():
		if world != null and Inv.remove(s["id"], 1):
			world.spawn_pickup_near_player(s["id"], 1)
			refresh(), Vector2(0, 48)))
	_right.add_child(UI.button("Sort pack", func():
		Inv.sort_items()
		selected_slot = -1
		refresh(), Vector2(0, 48)))


# ------------------------------------------------------------ crafting
func _station_ok(st: String) -> bool:
	return world != null and world.station_nearby(st)


func _build_craft() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var recipes: Array = Crafting.visible_recipes("workbench")
	recipes.append_array(Crafting.visible_recipes("campfire").filter(func(r): return r["station"] == "campfire"))
	recipes.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]) or (int(a["level"]) == int(b["level"]) and a["name"] < b["name"]))
	if selected_recipe == "" and not recipes.is_empty():
		selected_recipe = recipes[0]["id"]
	var near := Callable(self, "_station_ok")
	for r in recipes:
		var why: String = Crafting.block_reason(r, near)
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 64)
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tag := ""
		if why == "":
			tag = "  [ready]"
		elif why.begins_with("Requires level"):
			tag = "  [locked]"
		row.text = "      " + str(r["name"]) + (" x%d" % int(r["qty"]) if int(r["qty"]) > 1 else "") + tag
		var ic := UI.ItemIcon.new(r["result"], 48)
		ic.position = Vector2(8, 8)
		row.add_child(ic)
		if why == "":
			row.add_theme_color_override("font_color", UI.COL_GOOD)
		elif why.begins_with("Requires level"):
			row.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
		if r["id"] == selected_recipe:
			row.add_theme_stylebox_override("normal", UI.style(UI.COL_PANEL_LIGHT.lightened(0.1), 12, UI.COL_ACCENT, 3, 14))
		var rid: String = r["id"]
		row.pressed.connect(func():
			selected_recipe = rid
			Sfx.play("click")
			refresh())
		list.add_child(row)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_right)
	_fill_recipe()


func _fill_recipe() -> void:
	if selected_recipe == "" or not Data.recipes.has(selected_recipe):
		return
	var r: Dictionary = Data.recipes[selected_recipe]
	var res: Dictionary = Data.get_item(r["result"])
	var head := HBoxContainer.new()
	head.add_child(UI.ItemIcon.new(r["result"], 72))
	var hv := VBoxContainer.new()
	hv.add_child(UI.label(res["name"] + (" x%d" % int(r["qty"]) if int(r["qty"]) > 1 else ""), 26, UI.COL_ACCENT))
	var st_name: String = Crafting.STATION_NAMES.get(r["station"], r["station"])
	hv.add_child(UI.label("%s  -  Level %d" % [st_name, int(r["level"])], 18, UI.COL_DIM))
	head.add_child(hv)
	_right.add_child(head)
	_right.add_child(UI.label(res["desc"], 20, UI.COL_TEXT, true))
	_right.add_child(UI.label("Ingredients", 22, UI.COL_ACCENT2))
	for id in r["ingredients"]:
		var need: int = int(r["ingredients"][id])
		var have: int = Inv.count(id)
		var row := HBoxContainer.new()
		row.add_child(UI.ItemIcon.new(id, 36))
		var col := UI.COL_GOOD if have >= need else UI.COL_BAD
		row.add_child(UI.label("%s  %d / %d" % [Data.item_name(id), have, need], 21, col))
		_right.add_child(row)
	var near := Callable(self, "_station_ok")
	var why: String = Crafting.block_reason(r, near)
	if why != "":
		_right.add_child(UI.label(why, 20, UI.COL_BAD, true))
	var cb := UI.button("Craft", func():
		var out: Dictionary = Crafting.craft(selected_recipe, near)
		if out["ok"]:
			Game.toast("Crafted " + res["name"], "info")
		else:
			Sfx.play("invalid")
			Game.toast(str(out["reason"]), "warn")
		refresh(), Vector2(0, 58), true)
	cb.disabled = why != ""
	_right.add_child(cb)
	if station == "campfire" and world != null:
		_right.add_child(UI.button("Rest by the fire", func():
			close()
			world.rest_at_campfire(), Vector2(0, 52)))
