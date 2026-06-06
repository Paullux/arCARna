extends SceneTree

var main: Node
var n: int = 0
var dmax: float = 0.0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	var tm := main.get_node("TrafficManager")
	var gm := get_root().get_node("GameManager")
	if n == 30:
		gm.start_race()
		Input.action_press("accelerate")
		Input.action_press("steer_right")   # fonce dans le bord en continu
	if n > 30:
		dmax = maxf(dmax, tm.dist_from_center(p.global_position))
	if n % 30 == 0:
		print("frame %d dist=%.1f dmax=%.1f y=%.2f over=%s" % [n, tm.dist_from_center(p.global_position), dmax, p.global_position.y, str(gm.is_game_over)])
	return n > 360
