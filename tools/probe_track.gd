extends SceneTree

var main: Node
var n: int = 0
var done: bool = false

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	if n == 20 and not done:
		done = true
		var space := (main.get_node("Player") as Node3D).get_world_3d().direct_space_state
		print("=== Carte Sol (# route). X:-60..60 (gauche-droite), Z:0(haut)..62(bas) ===")
		var best := Vector3.ZERO
		var best_score := -1
		var z := 0.0
		while z <= 62.0:
			var row := "z=%4.0f " % z
			var x := -60.0
			while x <= 60.0:
				var hit := _ray(space, x, z)
				if hit.y > -5.0:
					row += "#"
					# score = voisins route (cherche zone large)
					var s := 0
					for dx in [-3, 0, 3]:
						for dz in [-3, 0, 3]:
							if _ray(space, x + dx, z + dz).y > -5.0:
								s += 1
					if s > best_score:
						best_score = s
						best = Vector3(x, hit.y, z)
				else:
					row += "."
				x += 3.0
			print(row)
			z += 3.0
		print("MEILLEUR SPAWN ~ ", best, " (voisins=", best_score, "/9)")
		return true
	return n > 120

func _ray(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 50, z), Vector3(x, -20, z))
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(0, -999, 0)
