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
		var origin := Vector3(0, 1.5, 12)
		print("=== Murs autour du spawn (0,1.5,12) ===")
		for d in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]:
			var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 12)
			var hit := space.intersect_ray(q)
			if hit:
				print("dir ", d, " -> ", hit.collider.get_parent().name, " à ", origin.distance_to(hit.position), " m")
			else:
				print("dir ", d, " -> libre (>12m)")
		# le spawn est-il DANS un mur ? test point
		var pq := PhysicsPointQueryParameters3D.new()
		pq.position = origin
		var res := space.intersect_point(pq, 8)
		print("colliders au point spawn: ", res.size())
		for r in res:
			print("   - ", r.collider.get_parent().name)
		return true
	return n > 60
