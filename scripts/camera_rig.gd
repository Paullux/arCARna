extends Node3D
## CameraRig — caméra dynamique (Jalon 2).
## - SpringArm3D : recul + lissage + anti-collision automatique.
## - FOV + longueur de bras pilotés par la vitesse (fabrique de vitesse).
## - Lookahead : la caméra vise un point en avant, décalé selon la direction,
##   pour anticiper les virages (lisibilité + sensation de vitesse).
## Le lookahead sur spline Path3D (vrai circuit) affinera ça au Jalon 3.

@export_group("FOV")
@export var base_fov: float = 70.0
@export var max_fov: float = 92.0
@export var nitro_fov_boost: float = 1.3

@export_group("Recul")
@export var base_dolly: float = 0.0           ## recul additionnel à l'arrêt
@export var max_dolly: float = 2.5            ## recul additionnel à pleine vitesse

@export_group("Lookahead")
@export var look_height: float = 2.2          ## hauteur du point visé (regarde plus loin, moins le sol)
@export var look_ahead_dist: float = 10.0     ## distance du point visé devant la voiture
@export var look_side_amount: float = 6.0     ## décalage latéral max selon la direction
@export var look_smooth: float = 6.0          ## lissage du point visé

@export_group("Réactivité")
@export var lerp_speed: float = 4.0

@onready var camera: Camera3D = $Camera3D

## Le rig est enfant du Player (CharacterBody3D).
@onready var player: CharacterBody3D = get_parent()

var _look_target: Vector3
var _base_cam_z: float = 0.0

func _ready() -> void:
	_base_cam_z = camera.position.z
	_look_target = player.global_position

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var s: float = clampf(player.forward_speed / player.max_speed, 0.0, 1.0)
	var boost: float = nitro_fov_boost if player.nitro_active else 1.0

	# FOV + recul de la caméra selon la vitesse
	camera.fov = lerpf(camera.fov, base_fov + (max_fov - base_fov) * s * boost, lerp_speed * delta)
	var target_z: float = _base_cam_z + base_dolly + (max_dolly - base_dolly) * s
	camera.position.z = lerpf(camera.position.z, target_z, lerp_speed * delta)

	# Point visé : devant la voiture, décalé latéralement selon la direction
	var steer: float = Input.get_axis("steer_right", "steer_left")
	var fwd: Vector3 = -player.global_transform.basis.z
	var right: Vector3 = player.global_transform.basis.x
	var desired: Vector3 = player.global_position \
		+ fwd * look_ahead_dist * (0.4 + 0.6 * s) \
		- right * steer * look_side_amount * s \
		+ Vector3.UP * look_height
	_look_target = _look_target.lerp(desired, clampf(look_smooth * delta, 0.0, 1.0))

	if camera.global_position.distance_to(_look_target) > 0.05:
		camera.look_at(_look_target, Vector3.UP)
