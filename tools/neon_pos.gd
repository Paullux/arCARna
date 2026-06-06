extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	var tm = main.get_node("TrafficManager")
	var track = main.get_node("Track")
	for c in track.find_children("Neon_*", "MeshInstance3D", true, false):
		var arr = c.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var gt = c.global_transform
		var dmin := INF
		var dmax := -INF
		var dsum := 0.0
		var cnt := 0
		for v in verts:
			var w: Vector3 = gt * v
			var d = tm.dist_from_center(Vector3(w.x, 0, w.z))
			dmin = minf(dmin, d); dmax = maxf(dmax, d); dsum += d; cnt += 1
		print("%s : dist_centre min=%.1f moy=%.1f max=%.1f (verts=%d)" % [c.name, dmin, dsum/cnt, dmax, cnt])
	quit()
