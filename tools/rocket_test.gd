extends SceneTree

var main: Node
var n: int = 0
var maxy: float = 0.0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	var gm := get_root().get_node("GameManager")
	if n == 30:
		gm.start_race()
		Input.action_press("accelerate")
	if n > 30:
		maxy = maxf(maxy, p.global_position.y)
	if n % 40 == 0:
		var tm := main.get_node("TrafficManager")
		var rank = tm.player_rank(p.global_position)
		print("frame %d : y=%.2f maxY=%.2f rank=P%d/%d" % [n, p.global_position.y, maxy, rank, tm.racer_count()])
	return n > 240
