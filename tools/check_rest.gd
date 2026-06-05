extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	if n % 30 == 0:
		print("frame ", n, " player.y=%.2f on_floor=%s" % [p.global_position.y, p.is_on_floor()])
	if n >= 150:
		return true
	return false
