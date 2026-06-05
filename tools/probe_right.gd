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
		print("=== Côté droit : # = route. X 50..120 (gauche->droite), Z -5..75 (haut->bas) ===")
		var z := -5.0
		while z <= 75.0:
			var row := "z=%4.0f " % z
			var x := 50.0
			while x <= 120.0:
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z))
				var hit := space.intersect_ray(q)
				var par := ((hit.collider as Node).get_parent() if hit and hit.collider else null)
				row += "#" if (par != null and par.name.begins_with("Sol")) else "."
				x += 3.0
			print(row)
			z += 4.0
		return true
	return n > 60
