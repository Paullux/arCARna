extends Node3D
## Trafic IA : voitures qui suivent la spline CenterLine à vitesse fixe, en
## voies, recoloriées (shader car_tint). Collision (AnimatableBody3D) pour que
## les chocs comptent. Pooling implicite : on crée N voitures une fois, elles
## bouclent.

const CAR_SCENE := preload("res://assets/models/futuristic_car.glb")
const TINT_SHADER := preload("res://assets/shaders/car_tint.gdshader")

@export var count: int = 12
@export var speed: float = 55.0          ## vitesse le long de la spline
@export var car_scale: float = 2.2
@export var lane_offsets: PackedFloat32Array = [-15.0, 0.0, 15.0]
@export var spline_node: NodePath        ## optionnel ; sinon CenterLine du Track

var _curve: Curve3D
var _length: float = 0.0
var _start_prog: float = 0.0
var _cars: Array = []      # [{body, progress, lane}]
var _albedo_tex: Texture2D
var _has_tex: bool = false

func _ready() -> void:
	_albedo_tex = _get_car_texture()
	_has_tex = _albedo_tex != null
	_curve = _build_curve()
	if _curve == null:
		push_warning("[Traffic] CenterLine introuvable")
		return
	_length = _curve.get_baked_length()
	_start_prog = _find_start_progress()
	for i in count:
		_spawn(i)

## Progression sur la spline la plus proche de la ligne de départ (monde ~ x=0,z=44).
func _find_start_progress() -> float:
	var best := 0.0
	var bestd := INF
	var d := 0.0
	while d < _length:
		var p := _curve.sample_baked(d)
		var dist := Vector2(p.x, p.z - 44.0).length()
		if dist < bestd:
			bestd = dist
			best = d
		d += 4.0
	return best

func _physics_process(delta: float) -> void:
	if _curve == null:
		return
	var space := get_world_3d().direct_space_state
	for c in _cars:
		if GameManager.can_drive:        # bloquées sur la grille avant le START
			c.progress = fmod(c.progress + speed * delta, _length)
		var pos: Vector3 = _curve.sample_baked(c.progress)
		var ahead: Vector3 = _curve.sample_baked(fmod(c.progress + 3.0, _length))
		var tan := ahead - pos
		tan.y = 0.0
		if tan.length() < 0.001:
			continue
		tan = tan.normalized()
		var side := tan.cross(Vector3.UP).normalized()
		var p: Vector3 = pos + side * float(c.lane)
		var body: AnimatableBody3D = c.body
		p.y = _ground_y(space, p, body.get_rid()) + 0.2
		body.global_position = p
		body.look_at(p + tan, Vector3.UP)

## Nombre total de concurrents (trafic + joueur).
func racer_count() -> int:
	return _cars.size() + 1

## Classement du joueur (1 = en tête). On projette la position du joueur sur la
## spline et on compte les voitures « devant » (écart vers l'avant < demi-tour).
func player_rank(player_global: Vector3) -> int:
	if _curve == null:
		return 1
	var pprog := _curve.get_closest_offset(player_global)
	var ahead := 0
	for c in _cars:
		var gap: float = fposmod(c.progress - pprog, _length)
		if gap > 0.5 and gap < _length * 0.5:
			ahead += 1
	return ahead + 1

## Distance horizontale (XZ) entre un point et la ligne centrale de la piste.
## Sert à détecter la sortie de piste (au-delà de la largeur jouable).
func dist_from_center(p: Vector3) -> float:
	if _curve == null:
		return 0.0
	var cp := _curve.get_closest_point(Vector3(p.x, 0.0, p.z))
	return Vector2(p.x - cp.x, p.z - cp.z).length()

func _spawn(i: int) -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 2   # couche 2 uniquement (le rayon de sol = couche 1 l'ignore)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.6, 4.4)
	cs.shape = box
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)

	var model := CAR_SCENE.instantiate()
	model.scale = Vector3.ONE * car_scale
	model.rotation.y = PI           # front du modèle vers -Z (= avant du body)
	body.add_child(model)

	var col := Color.from_hsv(randf(), 0.9, 0.95)
	_tint(model, col)

	add_child(body)
	# grille de départ : rangées derrière la ligne, voies en alternance
	var lanes := lane_offsets.size()
	var prog := fposmod(_start_prog - 10.0 - float(i / lanes) * 8.0, _length)
	_cars.append({"body": body, "progress": prog, "lane": lane_offsets[i % lanes]})

func _tint(root: Node, col: Color) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var sm := ShaderMaterial.new()
			sm.shader = TINT_SHADER
			sm.set_shader_parameter("albedo_tex", _albedo_tex)
			sm.set_shader_parameter("has_tex", _has_tex)
			sm.set_shader_parameter("tint", col)
			m.set_surface_override_material(s, sm)

func _get_car_texture() -> Texture2D:
	var tmp := CAR_SCENE.instantiate()
	var tex: Texture2D = null
	for mi in tmp.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).mesh.surface_get_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture:
			tex = (mat as StandardMaterial3D).albedo_texture
			break
	tmp.free()
	return tex

func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector3, exclude: RID) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 120, p.z), Vector3(p.x, -20, p.z))
	q.exclude = [exclude]
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 1.0

# --- Lecture de la CenterLine (comme les chevrons) ---
func _build_curve() -> Curve3D:
	var mi := _find_centerline()
	if mi == null:
		return null
	var pts := _ordered_points(mi)
	if pts.size() < 3:
		return null
	var curve := Curve3D.new()
	curve.bake_interval = 2.0
	var n := pts.size()
	for i in range(n + 1):
		var idx := i % n
		var p := pts[idx]
		var prev := pts[(idx - 1 + n) % n]
		var nxt := pts[(idx + 1) % n]
		var tan := (nxt - prev) * 0.25
		curve.add_point(p, -tan, tan)
	return curve

func _find_centerline() -> MeshInstance3D:
	if not spline_node.is_empty():
		return get_node_or_null(spline_node) as MeshInstance3D
	var track := get_node_or_null("../Track")
	if track == null:
		return null
	for c in track.find_children("CenterLine*", "MeshInstance3D", true, false):
		return c
	return null

func _ordered_points(mi: MeshInstance3D) -> PackedVector3Array:
	var arr := mi.mesh.surface_get_arrays(0)
	var lverts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or idx.size() < 3:
		return PackedVector3Array()
	var gt := mi.global_transform
	var cell_to_uid := {}
	var uid_pos: Array[Vector3] = []
	var vert_uid := PackedInt32Array()
	vert_uid.resize(lverts.size())
	for i in lverts.size():
		var w: Vector3 = gt * lverts[i]
		w.y = 0.0
		var key := Vector2i(roundi(w.x), roundi(w.z))
		if not cell_to_uid.has(key):
			cell_to_uid[key] = uid_pos.size()
			uid_pos.append(w)
		vert_uid[i] = cell_to_uid[key]
	var adj := {}
	for t in range(0, idx.size(), 3):
		var a := vert_uid[idx[t]]
		var b := vert_uid[idx[t + 1]]
		var c2 := vert_uid[idx[t + 2]]
		for pair in [[a, b], [b, c2], [c2, a]]:
			if pair[0] != pair[1]:
				_link(adj, pair[0], pair[1])
				_link(adj, pair[1], pair[0])
	var ordered := PackedVector3Array()
	var prev := -1
	var cur := 0
	for _i in uid_pos.size():
		ordered.append(uid_pos[cur])
		var nxt := -1
		for nb in adj.get(cur, []):
			if nb != prev:
				nxt = nb
				break
		if nxt == -1 or nxt == 0:
			break
		prev = cur
		cur = nxt
	return ordered

func _link(adj: Dictionary, a: int, b: int) -> void:
	if not adj.has(a):
		adj[a] = []
	if not adj[a].has(b):
		adj[a].append(b)
