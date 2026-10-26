extends "res://scripts/ui/modal.gd"
## Storage box: tap a stack to move it between the box and your pack.

const InvPanel = preload("res://scripts/ui/inventory_panel.gd")
const BOX_SLOTS := 24

var box: Node = null
var _box_grid: GridContainer
var _pack_grid: GridContainer


func _init() -> void:
	super._init("Storage Box", Game.State.INVENTORY, true)
	max_size = Vector2(1100, 640)


func _build() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for side in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UI.label("Storage box" if side == 0 else "Your pack", 22, UI.COL_ACCENT))
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(sc)
		var g := GridContainer.new()
		g.columns = 5
		sc.add_child(g)
		if side == 0:
			_box_grid = g
		else:
			_pack_grid = g


func show_for(b: Node) -> void:
	box = b
	open()


func refresh() -> void:
	if box == null:
		return
	UI.clear(_box_grid)
	UI.clear(_pack_grid)
	for i in BOX_SLOTS:
		var d: Dictionary = box.storage[i] if i < box.storage.size() else {}
		var s := InvPanel.Slot.new(d)
		var idx := i
		s.pressed.connect(func():
			if idx < box.storage.size():
				var e: Dictionary = box.storage[idx]
				if Inv.add_entry(e):
					box.storage.remove_at(idx)
					Sfx.play("click")
				else:
					Game.toast("Your pack is full.", "warn")
				refresh())
		_box_grid.add_child(s)
	for i in Inv.capacity():
		var d2: Dictionary = Inv.slots[i]
		var s2 := InvPanel.Slot.new(d2)
		var j := i
		s2.pressed.connect(func():
			if Inv.slots[j].is_empty():
				return
			if box.storage.size() >= BOX_SLOTS:
				Game.toast("The box is full.", "warn")
				return
			box.storage.append(Inv.remove_slot(j))
			Sfx.play("click")
			refresh())
		_pack_grid.add_child(s2)
