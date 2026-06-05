extends SceneTree

var main: Node
var cam: Camera3D
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	cam = Camera3D.new()
	cam.fov = 60.0
	get_root().add_child(cam)
	cam.look_at_from_position(Vector3(0, 22, 105), Vector3(0, 3, 48), Vector3.UP)
	cam.make_current()

func _process(_d: float) -> bool:
	n += 1
	cam.make_current()
	if n == 25:
		get_root().get_node("GameManager").trigger_game_over()
	if n == 34:
		get_root().get_texture().get_image().save_png("res://tools/explosion.png")
		print("SAVED explosion.png")
		return true
	return false
