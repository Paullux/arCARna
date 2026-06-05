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
		print("=== Zone départ : # = route. X -90..115 pas4 (gauche->droite), Z -8..50 pas4 ===")
		var z := -8.0
		while z <= 50.0:
			var row := "z=%4.0f " % z
			var x := -90.0
			while x <= 115.0:
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z))
				var hit := space.intersect_ray(q)
				var par := ((hit.collider as Node).get_parent() if hit and hit.collider else null)
				row += "#" if (par != null and par.name.begins_with("Sol")) else "."
				x += 4.0
			print(row)
			z += 4.0
		var pl := main.get_node("Player") as Node3D
		print("Spawn voiture : ", pl.global_position.round())
		return true
	return n > 60
