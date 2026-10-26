extends "res://scripts/ui/modal.gd"
## Quest journal: active and completed quests, objectives, hints; plus the collected research logs.

var _tab: String = "quests"
var _list: VBoxContainer
var _detail: VBoxContainer
var _sel: String = ""
var _tab_btns: Dictionary = {}
signal open_skills


func _init() -> void:
	super._init("Journal", Game.State.PAUSE, true)
	max_size = Vector2(1180, 660)


func _build() -> void:
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for t in [["quests", "Quests"], ["logs", "Research Logs"]]:
		var key: String = t[0]
		var b := UI.button(t[1], func():
			_tab = key
			_sel = ""
			refresh(), Vector2(180, 48))
		tabs.add_child(b)
		_tab_btns[key] = b
	tabs.add_child(UI.button("Skills", func(): open_skills.emit(), Vector2(140, 48)))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 380
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var sc2 := ScrollContainer.new()
	sc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc2)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(_detail)


func refresh() -> void:
	if _list == null:
		return
	for k in _tab_btns:
		_tab_btns[k].disabled = k == _tab
	UI.clear(_list)
	UI.clear(_detail)
	if _tab == "quests":
		_refresh_quests()
	else:
		_refresh_logs()


func _entry_button(text: String, selected: bool, cb: Callable, col: Color = UI.COL_TEXT) -> Button:
	var b := UI.button(text, cb, Vector2(0, 52), selected)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", col)
	return b


func _refresh_quests() -> void:
	var act: Array = Quests.active_ids()
	var done: Array = []
	for id in Data.quest_order:
		if Quests.completed.has(id):
			done.append(id)
	if _sel == "" or not Data.quests.has(_sel):
		_sel = Quests.tracked_id if Quests.tracked_id != "" else (act[0] if not act.is_empty() else (done[done.size() - 1] if not done.is_empty() else ""))
	_list.add_child(UI.label("Active", 20, UI.COL_ACCENT))
	if act.is_empty():
		_list.add_child(UI.label("No active quests.", 18, UI.COL_DIM))
	for id in act:
		var q: Dictionary = Data.quests[id]
		var tag: String = "" if q["main"] else "  (side)"
		var star: String = "> " if id == Quests.tracked_id else ""
		var qid: String = id
		_list.add_child(_entry_button(star + q["name"] + tag, id == _sel, func():
			_sel = qid
			refresh()))
	_list.add_child(UI.spacer(10))
	_list.add_child(UI.label("Completed (%d)" % done.size(), 20, UI.COL_ACCENT2))
	for id in done:
		var qid2: String = id
		_list.add_child(_entry_button(Data.quests[id]["name"], id == _sel, func():
			_sel = qid2
			refresh(), UI.COL_DIM))
	if _sel == "":
		return
	var q2: Dictionary = Data.quests[_sel]
	_detail.add_child(UI.label(q2["name"], 30, UI.COL_ACCENT))
	_detail.add_child(UI.label("Main story" if q2["main"] else "Side quest", 18, UI.COL_DIM))
	_detail.add_child(UI.spacer(6))
	_detail.add_child(UI.label(q2["desc"], 21, UI.COL_TEXT, true))
	_detail.add_child(UI.spacer(10))
	_detail.add_child(UI.label("Objectives", 22, UI.COL_ACCENT2))
	var is_done := Quests.completed.has(_sel)
	for i in q2["objectives"].size():
		var o: Dictionary = q2["objectives"][i]
		var ok: bool = is_done or Quests.objective_done(o)
		var l := UI.label(("[x] " if ok else "[ ] ") + Quests.objective_text(_sel, i), 21, UI.COL_GOOD if ok else UI.COL_TEXT, true)
		_detail.add_child(l)
	if not is_done:
		_detail.add_child(UI.spacer(10))
		_detail.add_child(UI.label("Hint: " + String(q2["hint"]), 19, UI.COL_DIM, true))
	_detail.add_child(UI.spacer(10))
	var rw: Dictionary = q2["reward"]
	var rt := "Reward: %d XP" % int(rw.get("xp", 0))
	for iid in rw.get("items", {}):
		rt += ", %d %s" % [int(rw["items"][iid]), Data.item_name(iid)]
	_detail.add_child(UI.label(rt, 19, UI.COL_ACCENT, true))
	if not is_done:
		var sid: String = _sel
		_detail.add_child(UI.spacer(8))
		_detail.add_child(UI.button("Track this quest", func():
			Quests.track(sid)
			refresh(), Vector2(240, 52), sid != Quests.tracked_id))


func _refresh_logs() -> void:
	var total := Data.logs.size()
	_list.add_child(UI.label("Collected %d / %d" % [Game.logs_read.size(), total], 20, UI.COL_ACCENT))
	var first := ""
	for id in Data.logs:
		if Game.logs_read.has(id):
			if first == "":
				first = id
			var lid: String = id
			_list.add_child(_entry_button(Data.logs[id]["title"], id == _sel, func():
				_sel = lid
				refresh()))
	if Game.logs_read.is_empty():
		_list.add_child(UI.label("Find terminals and journals around the island.", 18, UI.COL_DIM, true))
		return
	if _sel == "" or not Game.logs_read.has(_sel):
		_sel = first
		refresh()
		return
	var d: Dictionary = Data.logs[_sel]
	_detail.add_child(UI.label(d["title"], 28, UI.COL_ACCENT, true))
	_detail.add_child(UI.label(d["author"], 18, UI.COL_DIM, true))
	_detail.add_child(UI.spacer(8))
	_detail.add_child(UI.label(d["text"], 21, UI.COL_TEXT, true))
