extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	var track = main.get_node("Track")
	var ts = track  # track_setup est sur le noeud Track
	print("PitZone AABB = ", ts._pit_aabb())
	for c in track.find_children("Neon_*", "MeshInstance3D", true, false):
		var bodies = c.find_children("*", "StaticBody3D", true, false)
		if bodies.size() > 0:
			var cs = bodies[0].find_children("*", "CollisionShape3D", true, false)[0]
			var nf = cs.shape.get_faces().size() / 3 if cs.shape else 0
			print("%s : collision = %d triangles" % [c.name, nf])
		else:
			print("%s : pas de collision" % c.name)
	quit()
