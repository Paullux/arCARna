extends SceneTree

var main: Node
var n: int = 0

func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)

func _process(_d: float) -> bool:
	n += 1
	if n == 60:
		var tm := main.get_node("TrafficManager")
		var cars: Array = tm.get("_cars")
		print("Voitures trafic : ", cars.size())
		for i in min(5, cars.size()):
			var b: Node3D = cars[i]["body"]
			print("  car ", i, " pos=", b.global_position.round(), " lane=", cars[i]["lane"])
		print("texture trouvée : ", tm.get("_has_tex"))
		return true
	return n > 100
