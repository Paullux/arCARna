extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://assets/models/First_Track.glb")
	var root: Node = ps.instantiate()
	print("=== Arbre ===")
	_dump(root, 0)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var aabb := mi.mesh.get_aabb()
		var prim: int = mi.mesh.surface_get_primitive_type(0)
		print("--- ", mi.name, " : aabb=", aabb.size.snapped(Vector3(0.01,0.01,0.01)), " prim=", prim, " surfaces=", mi.mesh.get_surface_count())
		var mat := mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			print("    albedo=", sm.albedo_color, " tex=", sm.albedo_texture != null, " emit=", sm.emission_enabled)
	quit()

func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d) + n.name + " [" + n.get_class() + "]")
	for c in n.get_children():
		_dump(c, d + 1)
