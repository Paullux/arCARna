extends Node3D
## Compte à rebours en modèles 3D (count_3/2/1/start.glb) affichés devant la
## voiture, face caméra. Joue le bip et lance la course au "START".

const SEQ := ["count_3", "count_2", "count_1", "count_start"]
const COLORS := {
	"count_3": Color(1.0, 0.15, 0.15),
	"count_2": Color(1.0, 0.7, 0.1),
	"count_1": Color(0.2, 1.0, 0.3),
	"count_start": Color(0.4, 1.0, 0.6),
}
@export var model_scale: float = 6.0
@export var ahead: float = 17.0          ## distance devant la voiture
@export var up: float = 1.0              ## hauteur
@export var step_time: float = 1.0

var _player: Node3D
var _cam: Camera3D
var _beep: AudioStreamPlayer
var _current: Node3D

func _ready() -> void:
	_player = get_node_or_null("../Player")
	_cam = get_node_or_null("../Player/CameraRig/Camera3D")
	_beep = AudioStreamPlayer.new()
	_beep.stream = load("res://assets/SFX/bips.ogg")
	_beep.bus = "SFX"
	add_child(_beep)
	_run()

func _run() -> void:
	await get_tree().process_frame
	if _beep.stream:
		_beep.play()
	for i in SEQ.size():
		if SEQ[i] == "count_start":
			GameManager.start_race()
		_show(SEQ[i])
		await get_tree().create_timer(step_time).timeout
	_clear()
	queue_free()

func _show(model_name: String) -> void:
	_clear()
	var ps: PackedScene = load("res://assets/models/%s.glb" % model_name)
	if ps == null:
		return
	var m := ps.instantiate() as Node3D
	add_child(m)
	# matériau émissif coloré (feux de départ), visible de tous côtés
	var col: Color = COLORS.get(model_name, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	_current = m
	_place(m)
	var tw := create_tween()
	m.scale = Vector3.ONE * model_scale * 1.6
	tw.tween_property(m, "scale", Vector3.ONE * model_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Réoriente/replace le chiffre devant la voiture, face à la caméra (suivi continu).
func _place(m: Node3D) -> void:
	if _player == null:
		return
	var fwd := -_player.global_transform.basis.z
	m.global_position = _player.global_position + fwd * ahead + Vector3.UP * up
	if _cam:
		var target := _cam.global_position
		target.y = m.global_position.y      # reste droit
		m.look_at(target, Vector3.UP)
		m.rotate_object_local(Vector3.UP, PI)   # chiffres lisibles à l'endroit

func _process(_delta: float) -> void:
	if is_instance_valid(_current):
		_place(_current)

func _clear() -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
