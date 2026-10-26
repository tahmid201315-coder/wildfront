extends "res://scripts/ui/modal.gd"
## Skill tree: three branches of five skills each.

const BRANCHES := [["survival", "Survival"], ["combat", "Combat"], ["engineering", "Engineering"]]

var _points: Label
var _cols: HBoxContainer


func _init() -> void:
	super._init("Skills", Game.State.PAUSE, true)
	max_size = Vector2(1180, 660)


func _build() -> void:
	_points = UI.label("", 24, UI.COL_ACCENT)
	body.add_child(_points)
	_cols = HBoxContainer.new()
	_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_cols)


func refresh() -> void:
	if _cols == null:
		return
	_points.text = "Level %d    Skill points: %d" % [Game.level, Game.skill_points]
	UI.clear(_cols)
	for br in BRANCHES:
		var sc := ScrollContainer.new()
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_cols.add_child(sc)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
		v.add_child(UI.label(br[1], 26, UI.COL_ACCENT2))
		for id in Data.skills:
			var s: Dictionary = Data.skills[id]
			if s["branch"] != br[0]:
				continue
			var learned: bool = Game.has_skill(id)
			var why: String = Game.can_learn(id) if not learned else ""
			var txt := "%s%s\n%s\n%s" % [s["name"], "  [learned]" if learned else "  (cost %d)" % int(s["cost"]), s["desc"], why]
			var sid: String = id
			var b := UI.button(txt.strip_edges(), func():
				if Game.learn_skill(sid):
					Sfx.play("levelup")
				else:
					Sfx.play("invalid")
				refresh(), Vector2(0, 134), not learned and why == "")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.disabled = learned
			b.add_theme_font_size_override("font_size", 19)
			if not learned and why != "":
				b.add_theme_color_override("font_color", UI.COL_DIM)
			v.add_child(b)
