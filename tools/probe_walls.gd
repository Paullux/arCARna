extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	if n == 20:
		var space := (main.get_node("Player") as Node3D).get_world_3d().direct_space_state
		print("=== Rayons horizontaux à y=1.5, depuis x=0 vers +x et -x ===")
		for z in [6.0, 12.0, 30.0, 45.0]:
			for dir in [1.0, -1.0]:
				var from := Vector3(0, 1.5, z)
				var to := Vector3(80 * dir, 1.5, z)
				var q := PhysicsRayQueryParameters3D.create(from, to)
				var hit := space.intersect_ray(q)
				if hit:
					var col = hit.collider
					print("z=%.0f dir=%+.0f -> mur à x=%.1f sur '%s'" % [z, dir, hit.position.x, col.get_parent().name if col else "?"])
				else:
					print("z=%.0f dir=%+.0f -> AUCUN mur (passe à travers)" % [z, dir])
		return true
	return n > 60
