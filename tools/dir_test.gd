extends SceneTree

var main: Node
var n: int = 0
var start := Vector3.ZERO

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	var gm := get_root().get_node("GameManager")
	if n == 20:
		gm.start_race()  # débloque
		start = p.global_position
		Input.action_press("accelerate")
	if n == 70:
		Input.action_release("accelerate")
		var dir := (p.global_position - start)
		print(">> JOUEUR avance vers : ", dir.normalized().snapped(Vector3(0.1,0.1,0.1)), " (dx=%.0f dz=%.0f)" % [dir.x, dir.z])
		# sens de la spline du trafic au départ
		var tm := main.get_node("TrafficManager")
		var curve = tm.get("_curve")
		var sp = tm.get("_start_prog")
		var a = curve.sample_baked(sp)
		var b = curve.sample_baked(sp + 10.0)
		print(">> SPLINE (progress croissant) au départ : ", (b-a).normalized().snapped(Vector3(0.1,0.1,0.1)))
		print(">> start_prog - 10 est à : ", curve.sample_baked(sp - 10.0).snapped(Vector3(1,1,1)))
		return true
	return n > 90
