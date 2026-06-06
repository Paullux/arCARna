extends SceneTree

func _init() -> void:
	for name in ["count_3", "count_2", "count_1", "count_start"]:
		var ps: PackedScene = load("res://assets/models/%s.glb" % name)
		if ps == null:
			print(name, " : LOAD FAIL")
			continue
		var root: Node = ps.instantiate()
		var aabb := AABB()
		var has := false
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var a := m.global_transform * m.mesh.get_aabb()
			aabb = a if not has else aabb.merge(a)
			has = true
		print(name, " : size=", aabb.size.snapped(Vector3(0.01,0.01,0.01)), " center=", (aabb.position + aabb.size*0.5).snapped(Vector3(0.01,0.01,0.01)))
	quit()
