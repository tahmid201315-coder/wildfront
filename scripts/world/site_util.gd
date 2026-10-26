class_name SiteUtil
extends RefCounted

const MK = preload("res://scripts/gfx/mesh_kit.gd")

static func mesh_inst(b: MK.Builder, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(MK.style_material(0.0, 0.2, emissive))
	return mi


static func solid(parent: Node, size: Vector3, pos: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	parent.add_child(sb)
	return sb


