extends RefCounted
## Interactable objects found at landmark sites: containers, log terminals, machines, gates, pylons, NPC.

const Interactable = preload("res://scripts/world/interactable.gd")
const MK = preload("res://scripts/gfx/mesh_kit.gd")


# ======================================================================= Container
class LootContainer extends Interactable:
	var cid: String = ""
	var table: String = "supply"
	var group: String = ""          # opened-counter key (e.g. "supply", "outpost_locker")
	var fixed: Dictionary = {}      # guaranteed items {id: n}
	var style: String = "crate"
	var lid: Node3D
	var opened: bool = false

	func setup(p_cid: String, p_table: String, p_group: String, p_style: String, p_fixed: Dictionary = {}) -> void:
		cid = p_cid
		table = p_table
		group = p_group
		style = p_style
		fixed = p_fixed
		interact_radius = 2.4
		var b := MK.Builder.new(hash(p_cid))
		b.jitter = 0.04
		match style:
			"locker":
				b.box(Vector3(0.9, 1.9, 0.6), Color(0.45, 0.5, 0.55), Vector3(0, 0.95, 0))
				b.box(Vector3(0.82, 0.9, 0.04), Color(0.5, 0.56, 0.6), Vector3(0, 1.4, -0.32))
				b.box(Vector3(0.82, 0.8, 0.04), Color(0.5, 0.56, 0.6), Vector3(0, 0.45, -0.32))
				b.box(Vector3(0.08, 0.2, 0.05), Color(0.9, 0.8, 0.3), Vector3(0.3, 1.0, -0.35))
			"cache":
				b.box(Vector3(1.4, 0.8, 0.9), Color(0.38, 0.4, 0.44), Vector3(0, 0.4, 0))
				b.box(Vector3(1.5, 0.14, 1.0), Color(0.55, 0.58, 0.64), Vector3(0, 0.85, 0))
				b.box(Vector3(0.9, 0.1, 0.05), Color(0.4, 0.9, 0.95), Vector3(0, 0.5, -0.47))
			"treasure":
				b.box(Vector3(1.3, 0.7, 0.8), Color(0.55, 0.38, 0.2), Vector3(0, 0.35, 0))
				b.cyl(0.4, 0.4, 1.3, Color(0.62, 0.43, 0.24), Vector3(-0.65, 0.7, 0), Vector3(0, 0, -90), 8)
				b.box(Vector3(1.34, 0.12, 0.84), Color(0.9, 0.75, 0.25), Vector3(0, 0.55, 0))
				b.sphere(Vector3(0.12, 0.12, 0.12), Color(0.5, 0.95, 1.0), Vector3(0, 0.95, 0), Vector3.ZERO, 3, 6)
			_:
				b.box(Vector3(1.0, 0.8, 0.8), Color(0.60, 0.44, 0.26), Vector3(0, 0.4, 0))
				b.box(Vector3(1.04, 0.1, 0.84), Color(0.45, 0.33, 0.2), Vector3(0, 0.82, 0))
				b.box(Vector3(0.1, 0.84, 0.84), Color(0.4, 0.3, 0.2), Vector3(-0.3, 0.42, 0))
				b.box(Vector3(0.1, 0.84, 0.84), Color(0.4, 0.3, 0.2), Vector3(0.3, 0.42, 0))
		add_child(SiteUtil.mesh_inst(b, 0.0 if style != "cache" else 0.2))
		var sz := Vector3(1.2, 1.0, 0.9) if style != "locker" else Vector3(0.9, 1.9, 0.6)
		SiteUtil.solid(self, sz, Vector3(0, sz.y * 0.5, 0))
		opened = Game.opened.has(cid)
		if opened:
			_mark_open()

	func _mark_open() -> void:
		enabled = false
		scale = Vector3(1, 0.85, 1)

	func get_prompt(_p: Node) -> String:
		return "Open %s" % {"crate": "Supply Crate", "locker": "Locker", "cache": "Cache", "treasure": "Treasure Chest"}.get(style, "Container")

	func can_interact(_p: Node) -> bool:
		return enabled and not opened

	func interact(_p: Node) -> void:
		if opened:
			return
		opened = true
		Game.opened[cid] = 1
		if group != "":
			Game.opened[group] = int(Game.opened.get(group, 0)) + 1
		var got := {}
		for id in fixed:
			got[id] = int(fixed[id])
		if table != "":
			for e in Data.loot_tables[table]:
				if randf() <= float(e[3]):
					var n := randi_range(int(e[1]), int(e[2]))
					got[e[0]] = int(got.get(e[0], 0)) + n
		if got.is_empty() and table != "":
			var e0: Array = Data.loot_tables[table][0]
			got[e0[0]] = 1
		for id in got:
			Game.give_item(id, int(got[id]))
			Game.toast("+%d %s" % [int(got[id]), Data.item_name(id)], "item")
		Game.add_xp(12)
		Sfx.play("chest")
		Game.progress_changed.emit()
		if Game.world:
			Game.world.spawn_burst(global_position + Vector3(0, 0.9, 0), Color(1, 0.9, 0.5), 10, 3.0)
		_mark_open()


# ======================================================================= Log terminal
class LogTerminal extends Interactable:
	var log_id: String = ""

	func setup(p_log: String, style: String = "terminal") -> void:
		log_id = p_log
		interact_radius = 2.3
		var b := MK.Builder.new(hash(p_log))
		b.jitter = 0.04
		if style == "journal":
			b.box(Vector3(0.9, 0.7, 0.6), Color(0.5, 0.36, 0.22), Vector3(0, 0.35, 0))
			b.box(Vector3(0.5, 0.06, 0.38), Color(0.92, 0.88, 0.75), Vector3(0, 0.74, 0), Vector3(-10, 0, 0))
		elif style == "stone":
			b.box(Vector3(0.9, 1.5, 0.3), Color(0.5, 0.5, 0.46), Vector3(0, 0.75, 0))
			b.box(Vector3(0.6, 0.9, 0.05), Color(0.35, 0.8, 0.7), Vector3(0, 0.85, -0.17))
		else:
			b.box(Vector3(0.9, 1.0, 0.6), Color(0.28, 0.3, 0.34), Vector3(0, 0.5, 0))
			b.box(Vector3(0.7, 0.5, 0.08), Color(0.12, 0.14, 0.17), Vector3(0, 1.15, -0.1), Vector3(-15, 0, 0))
			b.box(Vector3(0.6, 0.4, 0.02), Color(0.4, 0.95, 0.85), Vector3(0, 1.15, -0.15), Vector3(-15, 0, 0))
		add_child(SiteUtil.mesh_inst(b, 0.35))
		SiteUtil.solid(self, Vector3(0.9, 1.1, 0.6), Vector3(0, 0.55, 0))

	func get_prompt(_p: Node) -> String:
		return "Read: %s" % Data.logs[log_id]["title"]

	func interact(_p: Node) -> void:
		Sfx.play("log")
		Game.read_log(log_id)
		if Game.world and Game.world.hud:
			Game.world.hud.log_requested.emit(log_id)


# ======================================================================= Generator
class Generator extends Interactable:
	var on: bool = false
	var lamp: MeshInstance3D
	var light: OmniLight3D

	func setup() -> void:
		interact_radius = 3.0
		var b := MK.Builder.new(7)
		b.box(Vector3(2.4, 1.8, 1.6), Color(0.36, 0.38, 0.42), Vector3(0, 0.9, 0))
		b.box(Vector3(2.5, 0.2, 1.7), Color(0.55, 0.4, 0.28), Vector3(0, 1.85, 0))
		b.cyl(0.3, 0.3, 1.2, Color(0.5, 0.52, 0.56), Vector3(0.7, 1.9, 0.2), Vector3.ZERO, 8)
		b.box(Vector3(0.9, 0.6, 0.06), Color(0.12, 0.14, 0.17), Vector3(-0.4, 1.1, -0.83))
		add_child(SiteUtil.mesh_inst(b, 0.0))
		var lb := MK.Builder.new(8)
		lb.box(Vector3(0.7, 0.4, 0.04), Color(1, 0.3, 0.2), Vector3.ZERO)
		lamp = SiteUtil.mesh_inst(lb, 1.2)
		lamp.position = Vector3(-0.4, 1.1, -0.86)
		add_child(lamp)
		light = OmniLight3D.new()
		light.light_color = Color(1, 0.4, 0.3)
		light.light_energy = 0.8
		light.omni_range = 6.0
		light.position = Vector3(-0.4, 1.4, -1.5)
		add_child(light)
		SiteUtil.solid(self, Vector3(2.4, 2.0, 1.6), Vector3(0, 1.0, 0))
		on = Game.flag("generator_on")
		if on:
			_apply_on()

	func _apply_on() -> void:
		var lb := MK.Builder.new(9)
		lb.box(Vector3(0.7, 0.4, 0.04), Color(0.3, 1.0, 0.5), Vector3.ZERO)
		lamp.mesh = lb.commit(MK.style_material(0.0, 0.2, 1.2))
		light.light_color = Color(0.3, 1.0, 0.5)

	func get_prompt(_p: Node) -> String:
		if on:
			return "Generator running"
		if Inv.count("power_cell") <= 0:
			return "Generator (needs a Power Cell)"
		return "Restart Generator"

	func can_interact(_p: Node) -> bool:
		return not on

	func interact(_p: Node) -> void:
		if Inv.count("power_cell") <= 0:
			Sfx.play("invalid")
			Game.toast("The generator is dead. A Power Cell from the mine could restart it.", "warn")
			return
		on = true
		Game.set_flag("generator_on", true)
		Game.grant_unlock("facility")
		Game.add_stat("interact:generator")
		Game.add_xp(60)
		Sfx.play("pylon")
		Game.toast("The generator hums to life. The workshop is online.", "quest")
		_apply_on()


# ======================================================================= Gate (seal gate / core gate)
class Gate extends Interactable:
	var gate_id: String = ""
	var need_item: String = ""
	var door_body: StaticBody3D
	var door_mesh: MeshInstance3D
	var open: bool = false
	var width: float = 8.0
	var needs_pylons: bool = false
	var text_closed: String = ""

	func setup(p_id: String, p_need: String, p_w: float, col: Color, p_pylons: bool = false) -> void:
		gate_id = p_id
		need_item = p_need
		width = p_w
		needs_pylons = p_pylons
		interact_radius = 4.5
		var b := MK.Builder.new(hash(p_id))
		b.box(Vector3(p_w, 7.0, 1.2), col, Vector3(0, 3.5, 0))
		for i in 4:
			b.box(Vector3(0.18, 6.4, 0.3), col.lightened(0.25), Vector3(-p_w * 0.35 + i * p_w * 0.23, 3.5, -0.7))
		b.box(Vector3(1.4, 1.4, 0.4), Color(0.2, 0.9, 0.7), Vector3(0, 4.2, -0.75), Vector3(0, 0, 45))
		door_mesh = SiteUtil.mesh_inst(b, 0.25)
		add_child(door_mesh)
		door_body = SiteUtil.solid(self, Vector3(p_w, 7.0, 1.2), Vector3(0, 3.5, 0))
		open = Game.flag("gate_" + gate_id)
		if open:
			_set_open(true)

	func _set_open(v: bool) -> void:
		open = v
		if v:
			door_body.get_child(0).disabled = true
			door_mesh.position.y = -7.2
			enabled = false

	func get_prompt(_p: Node) -> String:
		if needs_pylons and int(Game.stat("interact:pylon")) < 3:
			return "Core Gate (the pylons are dormant)"
		if need_item != "" and Inv.count(need_item) <= 0:
			return "%s (needs %s)" % [Data.sites[gate_id]["name"] if Data.sites.has(gate_id) else "Gate", Data.item_name(need_item)]
		return "Open %s" % (Data.sites[gate_id]["name"] if Data.sites.has(gate_id) else "Gate")

	func can_interact(_p: Node) -> bool:
		return enabled and not open

	func interact(_p: Node) -> void:
		if needs_pylons and int(Game.stat("interact:pylon")) < 3:
			Sfx.play("invalid")
			Game.toast("Three pylons nearby must be activated first.", "warn")
			return
		if need_item != "" and Inv.count(need_item) <= 0:
			Sfx.play("invalid")
			Game.toast("You need the %s." % Data.item_name(need_item), "warn")
			return
		Game.set_flag("gate_" + gate_id, true)
		Game.add_stat("interact:" + ("core_gate" if needs_pylons else "seal_gate"))
		Game.add_xp(80)
		Sfx.play("gate")
		Game.toast("The gate grinds open.", "quest")
		if Game.world and Game.world.hud:
			Game.world.hud.banner("THE GATE OPENS", "")
		open = true
		enabled = false
		door_body.get_child(0).disabled = true
		var tw := create_tween()
		tw.tween_property(door_mesh, "position:y", -7.2, 3.0)


# ======================================================================= Pylon
class Pylon extends Interactable:
	var index: int = 0
	var active: bool = false
	var glow: MeshInstance3D
	var base_mat: ShaderMaterial
	var _t: float = 0.0

	func setup(i: int) -> void:
		index = i
		interact_radius = 3.0
		var b := MK.Builder.new(300 + i)
		b.cyl(0.9, 0.7, 0.6, Color(0.3, 0.32, 0.38), Vector3.ZERO, Vector3.ZERO, 8)
		b.cyl(0.35, 0.28, 3.2, Color(0.38, 0.4, 0.46), Vector3(0, 0.6, 0), Vector3.ZERO, 6)
		b.sphere(Vector3(0.5, 0.7, 0.5), Color(0.45, 0.9, 1.0), Vector3(0, 4.2, 0), Vector3.ZERO, 4, 8)
		add_child(SiteUtil.mesh_inst(b, 0.0))
		SiteUtil.solid(self, Vector3(1.4, 3.8, 1.4), Vector3(0, 1.9, 0))
		glow = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 10
		sm.rings = 5
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.4, 0.9, 1.0, 0.2)
		sm.material = m
		glow.mesh = sm
		glow.position = Vector3(0, 4.2, 0)
		add_child(glow)
		active = Game.flag("pylon_%d" % i)

	func get_prompt(_p: Node) -> String:
		return "Pylon %d (active)" % (index + 1) if active else "Activate Pylon %d" % (index + 1)

	func can_interact(_p: Node) -> bool:
		return not active and Game.world != null and not Game.flag("gate_core_gate")

	func interact(_p: Node) -> void:
		var w: Node = Game.world
		var next: int = w.pylon_next()
		if index != next:
			w.pylon_reset()
			Sfx.play("invalid")
			Game.toast("Wrong sequence. The pylons fall dark. Follow the pulsing light.", "warn")
			return
		active = true
		Game.set_flag("pylon_%d" % index, true)
		Game.add_stat("interact:pylon")
		Sfx.play("pylon", 1.0 + index * 0.25)
		Game.toast("Pylon %d activated." % (index + 1), "info")
		Game.add_xp(30)

	func _process(delta: float) -> void:
		_t += delta
		var m: StandardMaterial3D = glow.mesh.material
		var next: int = Game.world.pylon_next() if Game.world else 0
		if active:
			m.albedo_color = Color(0.4, 1.0, 0.7, 0.55)
		elif index == next and not Game.flag("gate_core_gate"):
			m.albedo_color = Color(1.0, 0.85, 0.3, 0.25 + 0.4 * (0.5 + 0.5 * sin(_t * 5.0)))
		else:
			m.albedo_color = Color(0.4, 0.5, 0.7, 0.12)


# ======================================================================= Survivor NPC
class Survivor extends Interactable:
	var talked: bool = false
	var body_m: Node3D

	func setup() -> void:
		interact_radius = 3.0
		var b := MK.Builder.new(401)
		b.cyl(0.25, 0.22, 0.9, Color(0.55, 0.4, 0.25), Vector3(0, 0.1, 0), Vector3(0, 0, 0), 7)
		b.blob(Vector3(0.28, 0.3, 0.2), Color(0.55, 0.5, 0.3), Vector3(0, 1.1, 0), 0.05, 1)
		b.sphere(Vector3(0.2, 0.22, 0.2), Color(0.85, 0.68, 0.52), Vector3(0, 1.6, 0), Vector3.ZERO, 4, 8)
		b.box(Vector3(0.45, 0.1, 0.45), Color(0.3, 0.25, 0.2), Vector3(0, 1.8, 0))
		b.cyl(0.07, 0.07, 0.7, Color(0.55, 0.4, 0.25), Vector3(-0.35, 0.7, 0), Vector3(0, 0, 20), 5)
		b.cyl(0.07, 0.07, 0.7, Color(0.55, 0.4, 0.25), Vector3(0.35, 0.7, 0), Vector3(0, 0, -20), 5)
		add_child(SiteUtil.mesh_inst(b, 0.0))
		talked = Game.stat("interact:survivor") > 0

	func get_prompt(_p: Node) -> String:
		return "Talk to Dane Ito"

	func interact(_p: Node) -> void:
		if talked:
			Game.toast("Dane: Bring the truth home, explorer.", "info")
			return
		talked = true
		Game.add_stat("interact:survivor")
		Game.add_xp(40)
		if Game.world:
			Game.world.hud.dialogue_requested.emit("survivor")


