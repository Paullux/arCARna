extends SceneTree

var main: Node
var cam: Camera3D
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	# Rendu net : couper glow + émission, lumière forte
	var we := main.get_node("WorldEnvironment") as WorldEnvironment
	we.environment.glow_enabled = false
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(1, 1, 1)
	we.environment.ambient_light_energy = 1.5
	for m in main.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				sm.emission_enabled = false
				mi.set_surface_override_material(i, sm)
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
		var img := get_root().get_texture().get_image()
		img.save_png("res://tools/topdown.png")
		print("SAVED topdown.png ", img.get_width(), "x", img.get_height())
		return true
	return false
