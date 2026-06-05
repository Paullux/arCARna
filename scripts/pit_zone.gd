extends Area3D
## Zone des stands : recharge l'énergie tant que la voiture est dedans.
## Un pad émissif pulse (plus vif quand on recharge) pour symboliser la charge.

@export var recharge_rate: float = 0.6    ## énergie/s rechargée
@export var pad_color: Color = Color(0.15, 1.0, 0.55)
@export var flow_axis: Vector2 = Vector2(0, 1)  ## sens des barres (x,z) selon l'orientation de la route

const PAD_SHADER := preload("res://assets/shaders/pad_charge.gdshader")

var _player_in: bool = false
var _mat: ShaderMaterial
@onready var pad: MeshInstance3D = $Pad

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if pad:
		_mat = ShaderMaterial.new()
		_mat.shader = PAD_SHADER
		_mat.set_shader_parameter("col", pad_color)
		_mat.set_shader_parameter("flow_axis", flow_axis)
		_mat.set_shader_parameter("active", 0.0)
		pad.material_override = _mat

func _on_enter(b: Node) -> void:
	if b is CharacterBody3D:
		_player_in = true

func _on_exit(b: Node) -> void:
	if b is CharacterBody3D:
		_player_in = false

func _physics_process(delta: float) -> void:
	var charging := _player_in and not GameManager.is_game_over
	GameManager.is_recharging = charging
	if charging:
		GameManager.add_energy(recharge_rate * delta)
	if _mat:
		_mat.set_shader_parameter("active", 1.0 if _player_in else 0.0)
