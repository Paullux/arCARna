extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	var p := main.get_node("Player") as CharacterBody3D
	var gm := get_root().get_node("GameManager")
	if n == 10:
		gm.energy = 0.30
		print(">> énergie forcée à 30% (voiture dans les stands)")
	if n == 70:
		main.get_node("PitZone").set_physics_process(false)
		gm.energy = 0.0
		gm.energy_changed.emit(0.0)
		print(">> stands coupés + énergie à 0 (calage)")
	if n % 15 == 0:
		print("f%4d  énergie=%4.0f%%  calée=%s  fwd=%.2f  timer=%.2f  gameover=%s" % [
			n, gm.energy * 100.0, p.is_stalled, p.forward_speed, p.get("_stall_timer"), gm.is_game_over])
	if gm.is_game_over:
		print(">> GAME OVER déclenché à la frame ", n, " (timer=%.2f)" % p.get("_stall_timer"))
		return true
	if n >= 700:
		print(">> game over NON déclenché")
		return true
	return false
