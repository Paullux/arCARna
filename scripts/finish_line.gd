extends Area3D
## Ligne d'arrivée (sur le damier) : compte un tour à chaque passage de la
## voiture, avec un petit cooldown pour éviter les doubles détections.

@export var cooldown: float = 3.0
var _timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_enter)

func _on_enter(b: Node) -> void:
	if b is CharacterBody3D and _timer <= 0.0:
		_timer = cooldown
		GameManager.register_lap_crossing()

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
