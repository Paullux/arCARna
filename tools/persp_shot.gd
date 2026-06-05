extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var pc := main.get_node("Player/CameraRig/Camera3D") as Camera3D
	pc.make_current()
	if n == 60:
		var img := get_root().get_texture().get_image()
		img.save_png("res://tools/persp.png")
		print("SAVED persp.png")
		return true
	return false
