extends "res://scripts/ui/modal.gd"
## Journal: Wildlings (collection), Bestiary (discovery log), Quests, Lore.

var tab: String = "wildlings"
var selected_uid: String = ""
var world: Node = null
var confirm: Node = null      # ConfirmDialog, assigned by the HUD

var _tabs: Dictionary = {}
var _content: Control


func _init() -> void:
	super._init("Journal", Game.State.PAUSE, true)


func _build() -> void:
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for t in [["wildlings", "Wildlings"], ["bestiary", "Bestiary"], ["quests", "Quests"], ["lore", "Lore"]]:
		var key: String = t[0]
		var b := UI.button(t[1], func(): set_tab(key), Vector2(150, 52))
		tabs.add_child(b)
		_tabs[key] = b
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	Game.collection_changed.connect(func(): if is_open: refresh())


func open_tab(t: String) -> void:
	tab = t
	if is_open:
		refresh()
	else:
		open()


func set_tab(t: String) -> void:
	tab = t
	refresh()


func refresh() -> void:
	if _content == null:
		return
	for k in _tabs:
		_tabs[k].disabled = (k == tab)
	UI.clear(_content)
	match tab:
		"wildlings": _build_wildlings()
		"bestiary": _build_bestiary()
		"quests": _build_quests()
		"lore": _build_lore()


func _scroll_list() -> Array:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


# ------------------------------------------------------------ Wildlings
func _build_wildlings() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	if Game.creatures.is_empty():
		_content.remove_child(row)
		row.queue_free()
		_content.add_child(UI.label("You have not befriended any Wildlings yet.\nFind one in the meadow and offer it food using the action button.", 24, UI.COL_DIM, true))
		return
	if Game.find_creature(selected_uid).is_empty():
		selected_uid = Game.active_uid if Game.active_uid != "" else Game.creatures[0]["uid"]
	var l := _scroll_list()
	l[0].custom_minimum_size = Vector2(380, 0)
	row.add_child(l[0])
	for c in Game.creatures:
		var def: Dictionary = Data.creatures[c["species"]]
		var status := ""
		if c["uid"] == Game.active_uid:
			status = "  [Companion]"
		elif str(c["assigned"]) != "":
			status = "  [Working]"
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s%s  Lv %d%s" % ["* " if c["favorite"] else "", c["name"], int(c["level"]), status]
		if c["uid"] == selected_uid:
			b.add_theme_stylebox_override("normal", UI.style(UI.COL_PANEL_LIGHT.lightened(0.1), 12, UI.COL_ACCENT, 3, 14))
		var uid: String = c["uid"]
		b.pressed.connect(func():
			selected_uid = uid
			Sfx.play("click")
			refresh())
		l[1].add_child(b)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(det)
	_fill_creature_details(det)


func _fill_creature_details(det: VBoxContainer) -> void:
	var c := Game.find_creature(selected_uid)
	if c.is_empty():
		return
	var def: Dictionary = Data.creatures[c["species"]]
	det.add_child(UI.label("%s  (%s)" % [c["name"], def["name"]], 28, UI.COL_ACCENT))
	det.add_child(UI.label("%s  -  %s" % [str(def["rarity"]).capitalize(), str(def["temperament"]).capitalize()], 19, UI.COL_DIM))
	det.add_child(UI.label(def["desc"], 20, UI.COL_TEXT, true))
	var mhp := Game.creature_max_hp(c)
	det.add_child(UI.label("Level %d     Health %d / %d     Bond %d%%" % [int(c["level"]), int(minf(float(c["hp"]), mhp)), int(mhp), int(c["bond"])], 21, UI.COL_GOOD))
	det.add_child(UI.label("Ability: %s" % def["ability_name"], 22, UI.COL_ACCENT2))
	det.add_child(UI.label(def["ability_desc"], 19, UI.COL_TEXT, true))
	det.add_child(UI.label("Habitat: %s\nFavorite food: %s" % [def["habitat"], Data.item_name(def["food"])], 19, UI.COL_DIM, true))
	var wd: Dictionary = def.get("work", {})
	if wd.has("item"):
		det.add_child(UI.label("Can work at a Rest Station: produces %s." % Data.item_name(wd["item"]), 18, UI.COL_DIM, true))
	det.add_child(UI.spacer(4))
	var uid: String = c["uid"]
	var r1 := HBoxContainer.new()
	det.add_child(r1)
	if uid == Game.active_uid:
		r1.add_child(UI.button("Dismiss companion", func():
			Game.set_active("")
			refresh(), Vector2(0, 52)))
	else:
		r1.add_child(UI.button("Set as companion", func():
			if str(c["assigned"]) != "" and world != null and world.build_manager.structures.has(c["assigned"]):
				world.build_manager.structures[c["assigned"]].unassign()
			Game.set_active(uid)
			refresh(), Vector2(0, 52), true))
	r1.add_child(UI.button("Unfavorite" if c["favorite"] else "Favorite", func():
		c["favorite"] = not c["favorite"]
		refresh(), Vector2(0, 52)))
	var r2 := HBoxContainer.new()
	det.add_child(r2)
	var feed_id := ""
	for f in def["foods"]:
		if Inv.count(f) > 0:
			feed_id = f
			break
	var fb := UI.button("Feed %s" % (Data.item_name(feed_id) if feed_id != "" else "(no food)"), func():
		if Inv.remove(feed_id, 1):
			c["bond"] = minf(float(c["bond"]) + (8.0 if feed_id == def["food"] else 4.0), 100.0)
			c["hp"] = Game.creature_max_hp(c)
			Sfx.play_voice(c["species"])
			Game.toast("%s enjoyed the meal." % c["name"], "info")
			refresh(), Vector2(0, 52))
	fb.disabled = feed_id == ""
	r2.add_child(fb)
	r2.add_child(UI.button("Release", func():
		if confirm != null:
			confirm.ask("Release %s?" % c["name"], "%s will return to the wild and leave your collection. This cannot be undone." % c["name"], func():
				if world != null and str(c["assigned"]) != "" and world.build_manager.structures.has(c["assigned"]):
					world.build_manager.structures[c["assigned"]].unassign()
				Game.release_creature(uid)
				selected_uid = ""
				refresh()), Vector2(0, 52)))


# ------------------------------------------------------------ Bestiary
func _build_bestiary() -> void:
	var l := _scroll_list()
	_content.add_child(l[0])
	var found := 0
	var total := Data.creatures.size()
	for id in Data.creatures:
		if Game.discovered_species.has(id):
			found += 1
	l[1].add_child(UI.label("Discovered %d of %d species" % [found, total], 22, UI.COL_ACCENT))
	for id in Data.creatures:
		var def: Dictionary = Data.creatures[id]
		var panel := PanelContainer.new()
		var v := VBoxContainer.new()
		panel.add_child(v)
		if Game.discovered_species.has(id):
			var owned := false
			for c in Game.creatures:
				if c["species"] == id:
					owned = true
			v.add_child(UI.label("%s   (%s, %s)" % [def["name"], str(def["rarity"]).capitalize(), Data.regions[def["region"]]["name"]], 24, UI.COL_ACCENT))
			v.add_child(UI.label(def["desc"], 19, UI.COL_TEXT, true))
			v.add_child(UI.label("Habitat: %s   Temperament: %s" % [def["habitat"], str(def["temperament"]).capitalize()], 18, UI.COL_DIM, true))
			if def.get("hostile", false):
				v.add_child(UI.label("Hostile. Watch for red warning circles on the ground.", 18, UI.COL_BAD, true))
			elif owned:
				v.add_child(UI.label("Favorite food: %s     Ability: %s" % [Data.item_name(def["food"]), def["ability_name"]], 18, UI.COL_GOOD, true))
			else:
				v.add_child(UI.label("Befriend it to learn its favorite food and ability.", 18, UI.COL_DIM, true))
		else:
			var silhouette := ColorRect.new()
			silhouette.color = Color(0.03, 0.05, 0.07)
			silhouette.custom_minimum_size = Vector2(0, 26)
			v.add_child(UI.label("??? Unknown Wildling", 24, Color(0.45, 0.5, 0.52)))
			v.add_child(UI.label("Explore Aetherwild to discover it.", 18, Color(0.4, 0.45, 0.48)))
		l[1].add_child(panel)


# ------------------------------------------------------------ Quests
func _build_quests() -> void:
	var l := _scroll_list()
	_content.add_child(l[0])
	var any := false
	l[1].add_child(UI.label("Active", 24, UI.COL_ACCENT))
	for id in Data.quest_order:
		if not Quests.active.has(id):
			continue
		any = true
		var q: Dictionary = Data.quests[id]
		var panel := PanelContainer.new()
		var v := VBoxContainer.new()
		panel.add_child(v)
		v.add_child(UI.label("%s   [%s]" % [q["name"], q["cat"]], 24, UI.COL_ACCENT2))
		v.add_child(UI.label(q["desc"], 19, UI.COL_TEXT, true))
		for i in q["objectives"].size():
			v.add_child(UI.label("- " + Quests.objective_text(id, i), 20, UI.COL_TEXT, true))
		var rw: Dictionary = q["reward"]
		var parts: Array = ["%d XP" % int(rw.get("xp", 0))]
		for it in rw.get("items", {}):
			parts.append("%d %s" % [rw["items"][it], Data.item_name(it)])
		v.add_child(UI.label("Reward: " + ", ".join(parts), 18, UI.COL_GOOD, true))
		if q["hint"] != "":
			v.add_child(UI.label("Tip: " + q["hint"], 18, UI.COL_DIM, true))
		l[1].add_child(panel)
	if not any:
		l[1].add_child(UI.label("No active quests. Level up or explore to unlock more.", 20, UI.COL_DIM, true))
	l[1].add_child(UI.label("Completed (%d)" % Quests.completed.size(), 24, UI.COL_ACCENT))
	for id in Data.quest_order:
		if Quests.completed.has(id):
			l[1].add_child(UI.label("  " + Data.quests[id]["name"], 20, UI.COL_GOOD))


# ------------------------------------------------------------ Lore
func _build_lore() -> void:
	var l := _scroll_list()
	_content.add_child(l[0])
	l[1].add_child(UI.label("Regions visited", 24, UI.COL_ACCENT))
	for rid in Data.regions:
		var seen: bool = Game.visited_regions.has(rid)
		l[1].add_child(UI.label(("%s - %s" % [Data.regions[rid]["name"], Data.regions[rid]["desc"]]) if seen else "??? Undiscovered region", 19, UI.COL_TEXT if seen else Color(0.45, 0.5, 0.52), true))
	l[1].add_child(UI.label("Lore entries", 24, UI.COL_ACCENT))
	for id in Data.lore:
		var panel := PanelContainer.new()
		var v := VBoxContainer.new()
		panel.add_child(v)
		if Game.lore_found.has(id):
			v.add_child(UI.label(Data.lore[id]["title"], 22, UI.COL_ACCENT2))
			v.add_child(UI.label(Data.lore[id]["text"], 19, UI.COL_TEXT, true))
		else:
			v.add_child(UI.label("??? Undiscovered entry", 20, Color(0.45, 0.5, 0.52)))
		l[1].add_child(panel)
	l[1].add_child(UI.label("Controls reminder", 24, UI.COL_ACCENT))
	l[1].add_child(UI.label("Left side: move (push fully to run). Right side: look; pinch to zoom. Jump hops and glides with a Glimmerwing. The round action button interacts. Pack opens inventory and crafting. Build places kits.", 19, UI.COL_DIM, true))
