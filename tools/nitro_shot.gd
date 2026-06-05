extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	(main.get_node("PitZone/Pad") as Node3D).visible = false

func _process(_d: float) -> bool:
	n += 1
	var pc := main.get_node("Player/CameraRig/Camera3D") as Camera3D
	pc.make_current()
	var gm := get_root().get_node("GameManager")
	if n == 20:
		gm.nitro = 1.0
		gm.nitro_changed.emit(1.0)
		Input.action_press("accelerate")
		Input.action_press("nitro")
	if n == 115:
		get_root().get_texture().get_image().save_png("res://tools/nitro.png")
		print("SAVED nitro.png")
		return true
	return false
