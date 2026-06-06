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
	if n == 30:
		gm.start_race()
		p.global_position = Vector3(2, 6, 23)   # centre PitZone
	if n >= 32 and n % 10 == 0:
		var space := main.get_viewport().world_3d.direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP*2, p.global_position + Vector3.DOWN*80)
		q.collision_mask = 1; q.exclude = [p.get_rid()]
		var hit := space.intersect_ray(q)
		var who = (hit.collider.get_parent().name + "/" + hit.collider.name) if hit and hit.collider else "VIDE"
		print("frame %d pos=(%.0f,%.1f,%.0f) sol=%s over=%s recharge=%s" % [n, p.global_position.x, p.global_position.y, p.global_position.z, who, str(gm.is_game_over), str(gm.is_recharging)])
	return n > 90
