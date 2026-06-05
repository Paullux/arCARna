extends SceneTree

var main: Node
var n: int = 0
var start := Vector3.ZERO

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	if n == 30:
		start = p.global_position
		Input.action_press("accelerate")
	if n > 30 and n <= 150 and n % 30 == 0:
		print("frame ", n, " pos=", p.global_position.round(), " dist_parcourue=%.1f" % start.distance_to(p.global_position))
	if n >= 150:
		Input.action_release("accelerate")
		return true
	return false
