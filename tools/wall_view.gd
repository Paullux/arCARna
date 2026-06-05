extends SceneTree

var main: Node
var cam: Camera3D
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	(main.get_node("Walls") as Node).set("debug_visible", true)
	var marks := {
		Vector3(0, 14, 30): Color(1, 0, 0),    # origine z=30
		Vector3(40, 14, 30): Color(0, 1, 0),   # +x
		Vector3(0, 14, 60): Color(1, 1, 0),    # +z
		Vector3(0, 14, 0): Color(1, 0, 1),     # z=0
	}
	for pos in marks:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(4, 4, 4); b.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = marks[pos]; m.emission_enabled = true
		m.emission = marks[pos]; m.emission_energy_multiplier = 6.0
		b.mesh.surface_set_material(0, m); b.position = pos
		get_root().add_child(b)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 135.0
	cam.position = Vector3(0, 80, 30)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	get_root().add_child(cam)
	cam.make_current()

func _process(_d: float) -> bool:
	n += 1
	cam.make_current()
	if n == 30:
		get_root().get_texture().get_image().save_png("res://tools/walls.png")
		print("SAVED walls.png")
		return true
	return false
