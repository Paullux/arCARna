extends SceneTree

var main: Node
var cam: Camera3D
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	cam = Camera3D.new()
	cam.fov = 55.0
	get_root().add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 45.0
	cam.position = Vector3(7, 60, 109)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()

func _process(_d: float) -> bool:
	n += 1
	cam.make_current()
	if n == 60:
		get_root().get_texture().get_image().save_png("res://tools/traffic.png")
		print("SAVED traffic.png")
		return true
	return false
