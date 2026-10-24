extends RefCounted
## Small modal panels: confirmation dialog, lore reader, storage chest, farming plot,
## creature rest station and the build menu. Each is a Modal subclass defined here.

const Modal = preload("res://scripts/ui/modal.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")


# ------------------------------------------------------------ confirm dialog
class ConfirmDialog extends "res://scripts/ui/modal.gd":
	var _text: Label
	var _yes: Callable
	var _yes_btn: Button

	func _init() -> void:
		super._init("Confirm", Game.State.PAUSE, false)
		max_size = Vector2(700, 340)

	func _build() -> void:
		_text = UI.label("", 22, UI.COL_TEXT, true)
		_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(_text)
		var row := HBoxContainer.new()
		body.add_child(row)
		_yes_btn = UI.button("Confirm", func():
			var cb := _yes
			close()
			if cb.is_valid():
				cb.call(), Vector2(0, 58), true)
		_yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_yes_btn)
		var no := UI.button("Cancel", close, Vector2(0, 58))
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(no)

	func ask(title: String, text: String, on_yes: Callable, yes_label: String = "Confirm") -> void:
		title_label.text = title
		_text.text = text
		_yes = on_yes
		_yes_btn.text = yes_label
		if not is_open:
			is_open = true
			visible = true
			_fit()
			move_to_front()


# ------------------------------------------------------------ lore reader (DIALOGUE state)
class LorePanel extends "res://scripts/ui/modal.gd":
	var _title: Label
	var _text: Label

	func _init() -> void:
		super._init("", Game.State.DIALOGUE, true)
		max_size = Vector2(820, 420)

	func _build() -> void:
		_text = UI.label("", 24, UI.COL_TEXT, true)
		_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(_text)
		body.add_child(UI.button("Continue", close, Vector2(0, 58), true))

	func show_lore(key: String) -> void:
		if not Data.lore.has(key):
			return
		title_label.text = Data.lore[key]["title"]
		_text.text = Data.lore[key]["text"]
		Game.unlock_lore(key)
		open()


# ------------------------------------------------------------ storage chest
class ChestPanel extends "res://scripts/ui/modal.gd":
	const MAX_KINDS := 16
	var structure: Node = null
	var _row: HBoxContainer

	func _init() -> void:
		super._init("Storage Chest", Game.State.INVENTORY, true)

	func _build() -> void:
		_row = HBoxContainer.new()
		_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(_row)
		Inv.changed.connect(func(): if is_open: refresh())

	func open_for(s: Node) -> void:
		structure = s
		if not s.state.has("items"):
			s.state["items"] = {}
		if is_open:
			refresh()
		else:
			open()

	func _items() -> Dictionary:
		return structure.state["items"]

	func _column(title: String) -> VBoxContainer:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(title, 24, UI.COL_ACCENT))
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		v.add_child(sc)
		_row.add_child(v)
		return inner

	func refresh() -> void:
		if structure == null or _row == null:
			return
		UI.clear(_row)
		var pack := _column("Your pack")
		var seen: Dictionary = {}
		for s in Inv.slots:
			if s != null:
				seen[s["id"]] = Inv.count(s["id"])
		if seen.is_empty():
			pack.add_child(UI.label("Pack is empty.", 20, UI.COL_DIM))
		for id in seen:
			pack.add_child(_entry(id, seen[id], "Store", true))
		var chest := _column("Chest (%d / %d kinds)" % [_items().size(), MAX_KINDS])
		if _items().is_empty():
			chest.add_child(UI.label("The chest is empty.", 20, UI.COL_DIM))
		for id in _items():
			chest.add_child(_entry(id, int(_items()[id]), "Take", false))

	func _entry(id: String, n: int, verb: String, to_chest: bool) -> Control:
		var r := HBoxContainer.new()
		r.add_child(UI.ItemIcon.new(id, 44))
		var l := UI.label("%s x%d" % [Data.item_name(id), n], 21)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UI.button(verb, func(): _move(id, 1, to_chest), Vector2(90, 48)))
		r.add_child(UI.button(verb + " all", func(): _move(id, n, to_chest), Vector2(120, 48)))
		return r

	func _move(id: String, n: int, to_chest: bool) -> void:
		var items := _items()
		if to_chest:
			if not items.has(id) and items.size() >= MAX_KINDS:
				Game.toast("The chest is full.", "warn")
				return
			var amt := mini(n, Inv.count(id))
			if amt > 0 and Inv.remove(id, amt):
				items[id] = int(items.get(id, 0)) + amt
		else:
			var have := int(items.get(id, 0))
			var amt2 := mini(mini(n, have), Inv.free_space_for(id))
			if amt2 <= 0:
				Game.toast("Your pack is full.", "warn")
				return
			if Inv.add(id, amt2) == 0:
				items[id] = have - amt2
				if int(items[id]) <= 0:
					items.erase(id)
		refresh()


# ------------------------------------------------------------ farming plot
class PlotPanel extends "res://scripts/ui/modal.gd":
	var structure: Node = null
	var _content: VBoxContainer

	func _init() -> void:
		super._init("Farming Plot", Game.State.INVENTORY, true)
		max_size = Vector2(760, 480)

	func _build() -> void:
		_content = VBoxContainer.new()
		_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(_content)

	func open_for(s: Node) -> void:
		structure = s
		if is_open:
			refresh()
		else:
			open()

	func refresh() -> void:
		if structure == null or _content == null:
			return
		UI.clear(_content)
		var st: Dictionary = structure.state
		var crop := str(st.get("crop", ""))
		if crop == "":
			_content.add_child(UI.label("The soil is empty. Plant a seed, water it, and wait for it to grow.", 22, UI.COL_TEXT, true))
			var seeds: Array = []
			for s in Inv.slots:
				if s != null and Data.get_item(s["id"])["kind"] == "seed" and not seeds.has(s["id"]):
					seeds.append(s["id"])
			if seeds.is_empty():
				_content.add_child(UI.label("You have no seeds. Craft Sunberry Seeds from berries in the Pack.", 20, UI.COL_BAD, true))
			for sid in seeds:
				_content.add_child(UI.button("Plant %s (x%d)" % [Data.item_name(sid), Inv.count(sid)], func():
					if structure.plant(sid):
						Game.toast("Planted!", "info")
						Sfx.play("gather")
					refresh(), Vector2(0, 58), true))
			return
		var growth := float(st.get("growth", 0.0))
		var pct := int(clampf(growth / structure.CROP_GROW_TIME, 0.0, 1.0) * 100.0)
		var water := float(st.get("water", 0.0))
		_content.add_child(UI.label("Crop: %s" % Data.item_name(crop), 26, UI.COL_ACCENT))
		_content.add_child(UI.label("Growth: %d%%" % pct, 22, UI.COL_GOOD if pct >= 100 else UI.COL_TEXT))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 28)
		bar.value = pct
		_content.add_child(bar)
		_content.add_child(UI.label("Water: %s" % ("watered (%d s left)" % int(water) if water > 0.0 else "dry - crops only grow while watered"), 20, UI.COL_ACCENT2 if water > 0.0 else UI.COL_BAD, true))
		_content.add_child(UI.button("Water the plot", func():
			structure.water_plot()
			Sfx.play("gather")
			Game.toast("Watered.", "info")
			refresh(), Vector2(0, 56), water <= 0.0))
		var hb := UI.button("Harvest", func():
			if structure.harvest():
				Game.toast("Harvested!", "info")
			refresh(), Vector2(0, 56), pct >= 100)
		hb.disabled = pct < 100
		_content.add_child(hb)


# ------------------------------------------------------------ creature rest station
class RestPanel extends "res://scripts/ui/modal.gd":
	var structure: Node = null
	var _content: VBoxContainer

	func _init() -> void:
		super._init("Creature Rest Station", Game.State.INVENTORY, true)
		max_size = Vector2(860, 560)

	func _build() -> void:
		_content = VBoxContainer.new()
		_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(_content)

	func open_for(s: Node) -> void:
		structure = s
		if is_open:
			refresh()
		else:
			open()

	func refresh() -> void:
		if structure == null or _content == null:
			return
		UI.clear(_content)
		var st: Dictionary = structure.state
		var uid := str(st.get("uid", ""))
		var c := Game.find_creature(uid)
		if c.is_empty():
			_content.add_child(UI.label("No Wildling is resting here. Assign one (not your active companion) and it will produce materials over time.", 21, UI.COL_TEXT, true))
		else:
			var wd: Dictionary = Data.creatures[c["species"]]["work"]
			_content.add_child(UI.label("%s is resting here." % c["name"], 26, UI.COL_ACCENT))
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 26)
			bar.value = structure.work_progress() * 100.0
			_content.add_child(bar)
			_content.add_child(UI.label("Next %s in %d s.  Stored: %d / %d" % [Data.item_name(wd["item"]), int(float(wd["interval"]) * (1.0 - structure.work_progress())), int(st.get("stored", 0)), int(wd["cap"])], 20, UI.COL_TEXT, true))
			var r := HBoxContainer.new()
			_content.add_child(r)
			var collect := UI.button("Collect", func():
				var n: int = structure.collect_work()
				if n > 0:
					Sfx.play("pickup")
					Game.toast("Collected %d %s." % [n, Data.item_name(wd["item"])], "info")
				refresh(), Vector2(0, 54), int(st.get("stored", 0)) > 0)
			collect.disabled = int(st.get("stored", 0)) <= 0
			r.add_child(collect)
			r.add_child(UI.button("Stop assignment", func():
				structure.unassign()
				refresh(), Vector2(0, 54)))
		_content.add_child(UI.label("Available Wildlings", 22, UI.COL_ACCENT2))
		var any := false
		for cr in Game.creatures:
			if cr["uid"] == Game.active_uid or cr["uid"] == uid:
				continue
			if str(cr["assigned"]) != "" and cr["assigned"] != structure.sid:
				continue
			var cuid: String = cr["uid"]
			var wd2: Dictionary = Data.creatures[cr["species"]].get("work", {})
			if wd2.is_empty():
				continue
			any = true
			_content.add_child(UI.button("Assign %s  (makes %s)" % [cr["name"], Data.item_name(wd2["item"])], func():
				if structure.assign_creature(cuid):
					Sfx.play("click")
				refresh(), Vector2(0, 52)))
		if not any:
			_content.add_child(UI.label("None available. Befriend more Wildlings or dismiss your companion in the Journal.", 19, UI.COL_DIM, true))


# ------------------------------------------------------------ build menu
class BuildMenu extends "res://scripts/ui/modal.gd":
	var world: Node = null
	var _list: VBoxContainer

	func _init() -> void:
		super._init("Build", Game.State.INVENTORY, true)
		max_size = Vector2(760, 560)

	func _build() -> void:
		body.add_child(UI.label("Choose a kit from your pack. Walk and look to move the preview, then Place.", 20, UI.COL_DIM, true))
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(sc)
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_list)

	func refresh() -> void:
		if _list == null:
			return
		UI.clear(_list)
		var any := false
		for id in Data.items:
			var d: Dictionary = Data.items[id]
			if d["kind"] == "building" and Inv.count(id) > 0:
				any = true
				var kit: String = id
				var row := Button.new()
				row.custom_minimum_size = Vector2(0, 70)
				row.focus_mode = Control.FOCUS_NONE
				row.alignment = HORIZONTAL_ALIGNMENT_LEFT
				row.text = "      %s  x%d   -  %s" % [d["name"], Inv.count(id), d["desc"]]
				var ic := UI.ItemIcon.new(id, 52)
				ic.position = Vector2(8, 9)
				row.add_child(ic)
				row.pressed.connect(func():
					close()
					world.build_manager.start(kit))
				_list.add_child(row)
		if not any:
			_list.add_child(UI.label("You have no building kits. Craft them in the Pack > Craft tab (shelter pieces need a workbench nearby).", 21, UI.COL_BAD, true))
