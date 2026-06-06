extends CharacterBody3D
## Contrôleur de voiture arcade "fake physics" (Jalon 1).
## Modèle : vitesse avant scalaire + cap (rotation.y) + grip qui aligne
## progressivement la vélocité réelle sur le cap. Drift = grip réduit.
## AUCUNE simulation réaliste. Tout en _physics_process.

# --- Paramètres exposés pour tuning rapide dans l'inspecteur ---
@export_group("Vitesse")
@export var max_speed: float = 105.0
@export var nitro_speed: float = 165.0
@export var accel: float = 36.0
@export var brake_force: float = 120.0
@export var coast_drag: float = 20.0          ## décélération roue libre
@export var reverse_speed: float = 28.0       ## vitesse max en marche arrière

@export_group("Direction / Grip")
@export var turn_rate: float = 4.5            ## rad/s à pleine vitesse (haut = tourne plus serré)
@export var grip: float = 10.0                ## alignement vélocité→cap (haut = adhérent)
@export var drift_grip: float = 1.6           ## grip réduit pendant le drift
@export var handbrake_turn_mult: float = 1.6  ## le frein à main fait tourner plus fort

@export_group("Nitro")
@export var nitro_boost_mult: float = 1.0     ## accel supplémentaire sous nitro
@export var nitro_drain: float = 0.35         ## conso/s quand le boost est actif
@export var drift_nitro_gain: float = 0.25    ## charge/s en drift
@export var nitro_glow_strength: float = 0.7  ## intensité d'émission de la caisse sous nitro
@export var nitro_underglow_extra: float = 2.5 ## boost de l'underglow sous nitro

@export_group("Énergie")
@export var energy_drain: float = 0.004        ## conso/s en roulant (carburant)
@export var shock_speed_loss: float = 14.0     ## perte de vitesse en 1 frame = choc
@export var shock_cost: float = 0.05           ## énergie perdue par choc encaissé
@export var stall_grace: float = 2.5           ## sec en panne (énergie 0) avant game over

@export_group("Audio")
@export var engine_pitch_min: float = 0.7
@export var engine_pitch_max: float = 2.0
@export var near_miss_nitro: float = 0.08   ## bonus nitro au frôlement d'un véhicule
@export var explosion_volume_db: float = 6.0
@export var explosion_count: int = 4        ## nombre de détonations en chaîne
@export var explosion_interval: float = 0.33 ## intervalle entre détonations (s)

@export_group("Divers")
@export var gravity: float = 30.0
@export var mesh_roll: float = 0.12           ## inclinaison visuelle dans les virages
@export var rebound_keep: float = 0.55        ## fraction de vitesse gardée au rebond sur un néon
@export var rebound_deflect: float = 0.6      ## intensité de la déviation du cap au rebond

# --- État runtime (lisible par la caméra / le HUD) ---
var forward_speed: float = 0.0
var is_drifting: bool = false
var nitro_active: bool = false
var is_stalled: bool = false
var _stall_timer: float = 0.0
var _glow: float = 0.0
var _car_mat: StandardMaterial3D
var _underglow: OmniLight3D
var _underglow_base: float = 2.5
var _aura: MeshInstance3D
var _aura_mat: StandardMaterial3D
var _aura_base: Color
var _aura_amt: float = 0.0
var _exploded: bool = false
var _sfx: Dictionary = {}
var _was_nitro: bool = false
var _near_cd: Dictionary = {}
var _shock_frame: int = -100
var _ride_height: float = 1.0      ## hauteur de repos au-dessus de la piste
var _ride_calibrated: bool = false
var _air_frames: int = 0           ## frames consécutives sans sol sous la voiture
@onready var _traffic: Node = get_node_or_null("../TrafficManager")
@onready var _ground: Node = get_node_or_null("../Ground")  ## plane sombre = hors piste

@onready var car_mesh: Node3D = $CarMesh

func _ready() -> void:
	GameManager.reset_run()
	_setup_glow()
	_setup_sfx()

func _setup_glow() -> void:
	var mi := _find_mesh(car_mesh)
	if mi:
		var base := mi.get_active_material(0)
		if base is StandardMaterial3D:
			_car_mat = (base as StandardMaterial3D).duplicate()
			_car_mat.emission_enabled = true
			if _car_mat.albedo_texture != null:
				_car_mat.emission_texture = _car_mat.albedo_texture
			_car_mat.emission = Color.WHITE
			_car_mat.emission_energy_multiplier = 0.0
			mi.set_surface_override_material(0, _car_mat)
	_underglow = get_node_or_null("CarMesh/Underglow")
	if _underglow:
		_underglow_base = _underglow.light_energy
	_aura = get_node_or_null("CarMesh/RechargeAura")
	if _aura:
		var am := _aura.get_surface_override_material(0)
		if am is StandardMaterial3D:
			_aura_mat = (am as StandardMaterial3D).duplicate()
			_aura.set_surface_override_material(0, _aura_mat)
			_aura_base = _aura_mat.albedo_color
		_aura.visible = false

const TEX_EXPLOSION := preload("res://assets/images/texture/explosion.png")
const TEX_SPARKS := preload("res://assets/images/texture/etincelle.png")
const BURST_SHADER := preload("res://assets/shaders/vfx_burst.gdshader")

const SFX := {
	"engine": preload("res://assets/SFX/engine_loop.ogg"),
	"nitro": preload("res://assets/SFX/nitro.ogg"),
	"drift": preload("res://assets/SFX/drift.ogg"),
	"impact": preload("res://assets/SFX/impact_sparks.ogg"),
	"explosion": preload("res://assets/SFX/explosion.ogg"),
	"recharge": preload("res://assets/SFX/recharge.ogg"),
	"whoosh": preload("res://assets/SFX/whoosh_pass.ogg"),
}

func _setup_sfx() -> void:
	for k in SFX:
		var p := AudioStreamPlayer.new()
		p.stream = SFX[k]
		p.bus = "SFX"
		add_child(p)
		_sfx[k] = p
	# boucles
	for k in ["engine", "drift", "recharge"]:
		if _sfx[k].stream is AudioStreamOggVorbis:
			(_sfx[k].stream as AudioStreamOggVorbis).loop = true
	_sfx["engine"].volume_db = -7.0
	_sfx["drift"].volume_db = -9.0
	_sfx["nitro"].volume_db = -3.0
	_sfx["recharge"].volume_db = -8.0
	_sfx["whoosh"].volume_db = -4.0
	_sfx["impact"].volume_db = -12.5
	_sfx["engine"].play()
	# zone de détection near-miss (couche 2 = trafic uniquement)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 6.0
	cs.shape = sph
	cs.position = Vector3(0, 0.8, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_near_miss)

func _update_sfx(delta: float) -> void:
	var e: AudioStreamPlayer = _sfx["engine"]
	var t := engine_pitch_min + (engine_pitch_max - engine_pitch_min) * clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
	e.pitch_scale = lerpf(e.pitch_scale, t, 5.0 * delta)
	if nitro_active and not _was_nitro:
		_sfx["nitro"].play()
	_was_nitro = nitro_active
	_loop_sfx("drift", is_drifting)
	_loop_sfx("recharge", GameManager.is_recharging)

func _loop_sfx(key: String, want: bool) -> void:
	var p: AudioStreamPlayer = _sfx[key]
	if want and not p.playing:
		p.play()
	elif not want and p.playing:
		p.stop()

func _on_near_miss(body: Node) -> void:
	if GameManager.is_game_over:
		return
	if Engine.get_physics_frames() - _shock_frame < 8:
		return   # c'était un choc, pas un frôlement
	if _near_cd.has(body):
		return
	_near_cd[body] = true
	get_tree().create_timer(1.5).timeout.connect(func(): _near_cd.erase(body))
	_sfx["whoosh"].play()
	GameManager.add_nitro(near_miss_nitro)

## Sprite billboard qui grossit (s0 -> s1) et s'estompe sur `dur` secondes.
func _spawn_burst(tex: Texture2D, pos: Vector3, s0: float, s1: float, dur: float, brightness: float, threshold: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = BURST_SHADER
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("brightness", brightness)
	mat.set_shader_parameter("threshold", threshold)
	mat.set_shader_parameter("fade", 1.0)
	mi.material_override = mat
	get_parent().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * s0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * s1, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(f): mat.set_shader_parameter("fade", f), 1.0, 0.0, dur)
	tw.set_parallel(false)
	tw.tween_callback(mi.queue_free)

func _explode() -> void:
	car_mesh.visible = false
	for k in ["engine", "drift", "recharge"]:
		if _sfx.has(k):
			_sfx[k].stop()
	_explode_visuals()
	_play_explosion_chain()

## Enchaîne plusieurs détonations (son + boule de feu) à intervalle régulier.
func _play_explosion_chain() -> void:
	for i in explosion_count:
		if i == 0:
			_boom()
		else:
			get_tree().create_timer(i * explosion_interval).timeout.connect(_boom)

func _boom() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SFX["explosion"]
	p.bus = "SFX"
	p.volume_db = explosion_volume_db
	p.pitch_scale = randf_range(0.85, 1.15)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	var off := Vector3(randf_range(-4, 4), randf_range(2, 7), randf_range(-4, 4))
	_spawn_burst(TEX_EXPLOSION, global_position + off, 4.0, randf_range(14.0, 24.0), 0.75, 2.3, 0.14)

## Gros fireball + débris (mini boules de feu) + flash, joué une seule fois.
func _explode_visuals() -> void:
	var scene := get_parent()
	var burst_pos := global_position + Vector3.UP * 6.0
	_spawn_burst(TEX_EXPLOSION, burst_pos, 6.0, 24.0, 0.9, 2.4, 0.14)

	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.5
	pm.spread = 180.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 80.0
	pm.gravity = Vector3(0, -45, 0)
	pm.damping_min = 8.0
	pm.damping_max = 20.0
	pm.scale_min = 4.0
	pm.scale_max = 10.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.7, 1.0))
	grad.set_color(1, Color(0.5, 0.04, 0.0, 0.0))
	grad.add_point(0.35, Color(1.0, 0.45, 0.05, 1.0))
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	pm.color_ramp = gtex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	p.draw_pass_1 = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = TEX_EXPLOSION   # débris = mini boules de feu
	p.material_override = mat
	scene.add_child(p)
	p.global_position = burst_pos
	p.emitting = true

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 12.0
	light.omni_range = 50.0
	scene.add_child(light)
	light.global_position = burst_pos
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(light.queue_free)

	get_tree().create_timer(2.5).timeout.connect(p.queue_free)

func _update_aura(delta: float) -> void:
	var want := 1.0 if GameManager.is_recharging else 0.0
	_aura_amt = move_toward(_aura_amt, want, 4.0 * delta)
	if _aura == null:
		return
	_aura.visible = _aura_amt > 0.01
	if not _aura.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.7 + 0.3 * sin(t * 6.0)
	_aura.scale = Vector3.ONE * (0.55 + 0.45 * _aura_amt) * (0.92 + 0.12 * sin(t * 6.0))
	if _aura_mat:
		_aura_mat.albedo_color = Color(_aura_base.r, _aura_base.g, _aura_base.b, _aura_base.a * _aura_amt * pulse)

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null

## Colle la voiture à la surface de la piste (couche 1 uniquement → ignore le
## trafic). Corrige à la fois le décollage (poussée vers le haut) et
## l'enfoncement sous la piste (poussée vers le bas) dus à la dépénétration.
## La hauteur de repos est auto-calibrée au premier contact au sol.
func _stick_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 2.0
	var to := global_position + Vector3.DOWN * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1                     # décor seulement (piste / murs)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_check_offtrack(space)               # plus de sol proche : sortie de piste ?
		return
	_air_frames = 0
	# Contact avec le plane sombre (hors du Sol de la piste) = sortie de piste.
	if _ground != null and hit.collider == _ground \
			and not GameManager.is_game_over and GameManager.can_drive:
		GameManager.trigger_game_over("offtrack")
	var surface_y: float = hit.position.y
	if not _ride_calibrated:
		if is_on_floor():                    # premier appui franc : on mémorise l'offset
			_ride_height = global_position.y - surface_y
			_ride_calibrated = true
		return
	# replaque sur la surface (tant que l'écart reste raisonnable)
	var target_y: float = surface_y + _ride_height
	if absf(global_position.y - target_y) < 3.0:
		var gp := global_position
		gp.y = target_y
		global_position = gp
		if velocity.y < 0.0:
			velocity.y = 0.0

## Sortie de piste : si aucun sol (couche 1) n'est trouvé loin sous la voiture,
## elle est au-dessus du vide → game over + explosion (après une courte grâce
## pour ignorer les bosses/sauts ponctuels).
func _check_offtrack(space: PhysicsDirectSpaceState3D) -> void:
	if GameManager.is_game_over or not GameManager.can_drive:
		return
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 80.0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	if space.intersect_ray(q).is_empty():
		_air_frames += 1
		if _air_frames >= 18:                # ~0.3 s au-dessus du vide
			GameManager.trigger_game_over("offtrack")
	else:
		_air_frames = 0

## Rebond sur une barrière (néon/mur) : dévie le cap dans la direction réfléchie
## et décolle la voiture de la paroi → impossible de la traverser ou d'y rester collé.
func _rebound(normal: Vector3) -> void:
	var nrm := normal
	nrm.y = 0.0
	if nrm.length() < 0.05:
		return
	nrm = nrm.normalized()
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var bounced := hv.bounce(nrm)
	if bounced.length() > 0.1:
		var desired := atan2(-bounced.x, -bounced.z)   # cap = -basis.z
		rotation.y = lerp_angle(rotation.y, desired, rebound_deflect)
	global_position += nrm * 0.4                        # se décolle de la barrière

func _update_glow(delta: float) -> void:
	var target := 1.0 if nitro_active else 0.0
	_glow = move_toward(_glow, target, 6.0 * delta)
	if _car_mat:
		_car_mat.emission_energy_multiplier = _glow * nitro_glow_strength
	if _underglow:
		_underglow.light_energy = _underglow_base + _glow * nitro_underglow_extra

func _physics_process(delta: float) -> void:
	# --- Game over : la voiture roule en roue libre jusqu'à l'arrêt, sans contrôle
	if GameManager.is_game_over:
		if not _exploded:
			_exploded = true
			_explode()
		forward_speed = move_toward(forward_speed, 0.0, brake_force * delta)
		var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, brake_force * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		nitro_active = false
		_update_glow(delta)
		_update_aura(delta)
		return

	var throttle := Input.get_action_strength("accelerate")
	var braking := Input.get_action_strength("brake")
	# axe : steer_right (+1) .. steer_left (-1). On veut gauche = +rotation.y.
	var steer := Input.get_axis("steer_right", "steer_left")
	var handbrake := Input.is_action_pressed("drift")
	nitro_active = Input.is_action_pressed("nitro") and GameManager.nitro > 0.0

	# --- Compte à rebours : voiture bloquée à la ligne de départ
	if not GameManager.can_drive:
		throttle = 0.0
		braking = 0.0
		steer = 0.0
		handbrake = false
		nitro_active = false
		forward_speed = 0.0

	# --- Énergie à plat : la voiture cale (plus de gaz ni de frein moteur)
	is_stalled = GameManager.energy <= 0.0
	if is_stalled:
		throttle = 0.0
		braking = 0.0
		nitro_active = false

	var target_max := nitro_speed if nitro_active else max_speed

	# 1) Vitesse avant scalaire
	if throttle > 0.0:
		var a := accel * (1.0 + (nitro_boost_mult if nitro_active else 0.0)) * throttle
		forward_speed = move_toward(forward_speed, target_max, a * delta)
	elif braking > 0.0:
		# freine ; une fois à l'arrêt, passe en marche arrière
		var brake_target := -reverse_speed if forward_speed <= 0.5 else 0.0
		forward_speed = move_toward(forward_speed, brake_target, brake_force * braking * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, coast_drag * delta)
	# bridage doux : après le nitro, on laisse la survitesse redescendre vers max_speed
	if not nitro_active and forward_speed > max_speed:
		forward_speed = move_toward(forward_speed, max_speed, coast_drag * delta)

	# 2) Rotation du cap — d'autant plus marquée qu'on roule vite
	var speed_factor := clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
	var steer_amount := steer * turn_rate * speed_factor
	if handbrake and forward_speed > 5.0:
		steer_amount *= handbrake_turn_mult
	if forward_speed < -0.5:          # marche arrière : gauche/droite inversés
		steer_amount = -steer_amount
	rotation.y += steer_amount * delta

	# 3) Drift : on glisse quand on braque fort + vite, ou frein à main
	is_drifting = (handbrake and forward_speed > 8.0) \
		or (absf(steer) > 0.6 and forward_speed > max_speed * 0.6)
	var current_grip := drift_grip if is_drifting else grip

	# 4) Cap visé vs vélocité réelle, alignement progressif = grip
	var heading := -transform.basis.z          # avant local
	var desired_vel := heading * forward_speed
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	horiz_vel = horiz_vel.lerp(desired_vel, clampf(current_grip * delta, 0.0, 1.0))

	# 5) Gravité / collage au sol
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	var pre_speed := Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_stick_to_ground()
	var post_speed := Vector2(velocity.x, velocity.z).length()

	# 6) Choc : grosse perte de vitesse en une frame (impact mur/trafic)
	if pre_speed - post_speed > shock_speed_loss:
		if GameManager.energy <= 0.02:
			GameManager.trigger_game_over("crash")   # choc de trop (énergie épuisée)
		else:
			GameManager.add_energy(-shock_cost)
			forward_speed *= rebound_keep
			_shock_frame = Engine.get_physics_frames()
			if _sfx.has("impact"):
				_sfx["impact"].play()
			var cp := global_position + Vector3.UP * 1.0
			if get_slide_collision_count() > 0:
				cp = get_slide_collision(0).get_position()
				_rebound(get_slide_collision(0).get_normal())   # rebond néon/mur
			_spawn_burst(TEX_SPARKS, cp, 2.0, 13.0, 0.35, 2.2, 0.1)

	# 7) Énergie : se vide en roulant (carburant)
	if absf(forward_speed) > 2.0:
		GameManager.add_energy(-energy_drain * delta)

	# 8) Panne : à plat et immobile trop longtemps -> game over
	if is_stalled and absf(forward_speed) < 1.0:
		_stall_timer += delta
		if _stall_timer >= stall_grace:
			GameManager.trigger_game_over("fuel")
	else:
		_stall_timer = 0.0

	# 9) Économie nitro : le drift charge, le boost consomme
	if is_drifting:
		GameManager.add_nitro(drift_nitro_gain * delta)
	if nitro_active:
		GameManager.consume_nitro(nitro_drain * delta)

	# 7) Feedback visuel : roll dans les virages + glow nitro
	if car_mesh:
		car_mesh.rotation.z = lerpf(car_mesh.rotation.z, -steer * mesh_roll, 8.0 * delta)
	_update_glow(delta)
	_update_aura(delta)
	_update_sfx(delta)
