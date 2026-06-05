extends SceneTree

var main: Node
var cam: Camera3D
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 275.0
	cam.position = Vector3(0, 160, 60)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	get_root().add_child(cam)
	cam.make_current()

func _process(_d: float) -> bool:
	n += 1
	cam.make_current()
	if n == 3:
		# Affiche la texture brute du Sol (retire le shader néon) + repères
		for mi in main.find_children("Sol*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).set_surface_override_material(0, null)
		var we := main.get_node("WorldEnvironment") as WorldEnvironment
		we.environment.glow_enabled = false
		we.environment.ambient_light_color = Color(1, 1, 1)
		we.environment.ambient_light_energy = 2.0
		# repères : rouge=(0,0) vert=(40,0) jaune=(0,40) bleu=(0,-? -> z négatif n/a)
		_mark(Vector3(0, 14, 0), Color(1, 0, 0))
		_mark(Vector3(40, 14, 0), Color(0, 1, 0))
		_mark(Vector3(0, 14, 40), Color(1, 1, 0))
		_mark(Vector3(0, 14, 80), Color(0, 0.5, 1))
	if n == 12:
		get_root().get_texture().get_image().save_png("res://tools/sol_tex.png")
		print("SAVED sol_tex.png")
		return true
	return false

func _mark(pos: Vector3, c: Color) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(5, 5, 5); b.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.emission_enabled = true; m.emission = c
	m.emission_energy_multiplier = 5.0
	b.mesh.surface_set_material(0, m); b.position = pos
	get_root().add_child(b)
