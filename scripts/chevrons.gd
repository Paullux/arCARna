extends Node3D
## Pose des chevrons néon magenta (flèches de direction) le long du tracé,
## orientés dans le sens de la course. La hauteur est trouvée par raycast sur
## le Sol. Sert aussi de première spline centrale (réutilisable pour les tours).

@export var spacing: float = 14.0
@export var chev_width: float = 8.0
@export var chev_len: float = 5.0
@export var min_gap: float = 9.0   ## écarte les chevrons superposés (replis de piste)
@export var waypoint_scale: float = 2.0   ## les waypoints ont été relevés à l'échelle ×60
@export var y_offset: float = 0.15
@export var color: Color = Color(1.0, 0.15, 0.8)
@export var emit_energy: float = 4.0

## Ligne centrale (monde), relevée sur la piste par vue de dessus.
@export var waypoints: PackedVector3Array = PackedVector3Array([
	Vector3(-27.2, 0, 10.9), Vector3(30.2, 0, 8.6), Vector3(49.8, 0, 12.9),
	Vector3(57.0, 0, 27.1), Vector3(49.2, 0, 39.4), Vector3(31.8, 0, 37.1),
	Vector3(20.3, 0, 30.0), Vector3(7.2, 0, 32.0), Vector3(0.7, 0, 40.0),
	Vector3(10.5, 0, 48.6), Vector3(2.3, 0, 56.6), Vector3(-14.1, 0, 51.4),
	Vector3(-28.9, 0, 45.7), Vector3(-51.8, 0, 41.4), Vector3(-57.0, 0, 27.1),
	Vector3(-48.5, 0, 17.1),
])

var _mat: StandardMaterial3D
var _mesh: ArrayMesh

func _ready() -> void:
	_build.call_deferred()

func _build() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = emit_energy
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = _make_chevron_mesh()

	# Points : priorité au mesh CenterLine du .glb ; sinon waypoints à la main.
	var pts := _waypoints_from_centerline()
	if pts.size() >= 3:
		print("[Chevrons] CenterLine: ", pts.size(), " points ordonnés")
	else:
		pts = PackedVector3Array()
		for w in waypoints:
			pts.append(w * waypoint_scale)
		print("[Chevrons] fallback waypoints manuels")

	var curve := _make_curve(pts)
	var length := curve.get_baked_length()
	var space := get_world_3d().direct_space_state
	var placed: Array[Vector3] = []
	var d := 0.0
	while d < length:
		var pos := curve.sample_baked(d)
		var ahead := curve.sample_baked(fmod(d + 1.0, length))
		var tan := ahead - pos
		tan.y = 0.0
		if tan.length() < 0.001:
			d += spacing
			continue
		tan = tan.normalized()
		# saute si trop proche d'un chevron déjà posé (replis de piste)
		var too_close := false
		for pp in placed:
			if Vector2(pp.x - pos.x, pp.z - pos.z).length() < min_gap:
				too_close = true
				break
		if too_close:
			d += spacing
			continue
		placed.append(pos)
		var y := _ground_y(space, pos)
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = _mat
		var basis := Basis()
		var right := tan.cross(Vector3.UP).normalized()
		basis.x = right
		basis.y = Vector3.UP
		basis.z = -tan          # -Z = sens de marche
		mi.transform = Transform3D(basis, Vector3(pos.x, y + y_offset, pos.z))
		add_child(mi)
		d += spacing

func _ground_y(space: PhysicsDirectSpaceState3D, pos: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(pos.x, 60, pos.z), Vector3(pos.x, -20, pos.z))
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.5

func _make_curve(pts: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var n := pts.size()
	for i in range(n + 1):
		var idx := i % n
		var p := pts[idx]
		var prev := pts[(idx - 1 + n) % n]
		var nxt := pts[(idx + 1) % n]
		var tan := (nxt - prev) * 0.25
		curve.add_point(p, -tan, tan)
	return curve

## Lit le mesh "CenterLine" du circuit, déduplique par XZ, ordonne via la
## connectivité des arêtes (boucle fermée). Retourne les points en monde.
func _waypoints_from_centerline() -> PackedVector3Array:
	var track := get_node_or_null("../Track")
	if track == null:
		return PackedVector3Array()
	var mi: MeshInstance3D = null
	for c in track.find_children("CenterLine*", "MeshInstance3D", true, false):
		mi = c
		break
	if mi == null or mi.mesh == null:
		return PackedVector3Array()

	var arr := mi.mesh.surface_get_arrays(0)
	var lverts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or idx.size() < 3:
		return PackedVector3Array()
	var gt := mi.global_transform

	# Déduplique par cellule XZ (monde) -> id unique + position représentative
	var q := 1.0
	var cell_to_uid := {}
	var uid_pos: Array[Vector3] = []
	var vert_uid := PackedInt32Array()
	vert_uid.resize(lverts.size())
	for i in lverts.size():
		var w: Vector3 = gt * lverts[i]
		w.y = 0.0   # sécurité : on ignore la hauteur (évite les pics de la CenterLine)
		var key := Vector2i(roundi(w.x / q), roundi(w.z / q))
		if not cell_to_uid.has(key):
			cell_to_uid[key] = uid_pos.size()
			uid_pos.append(w)
		vert_uid[i] = cell_to_uid[key]

	# Adjacence via arêtes des triangles
	var adj := {}
	for t in range(0, idx.size(), 3):
		var a := vert_uid[idx[t]]
		var b := vert_uid[idx[t + 1]]
		var c2 := vert_uid[idx[t + 2]]
		for pair in [[a, b], [b, c2], [c2, a]]:
			if pair[0] == pair[1]:
				continue
			_link(adj, pair[0], pair[1])
			_link(adj, pair[1], pair[0])

	# Parcours de la boucle
	if uid_pos.size() < 3:
		return PackedVector3Array()
	var ordered := PackedVector3Array()
	var prev := -1
	var cur := 0
	for _i in uid_pos.size():
		ordered.append(uid_pos[cur])
		var nexts: Array = adj.get(cur, [])
		var nxt := -1
		for nb in nexts:
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

func _make_chevron_mesh() -> ArrayMesh:
	# chevron "»" : deux branches formant une flèche pointant vers -Z
	var w := chev_width * 0.5
	var l := chev_len
	var t := chev_len * 0.35   # épaisseur de branche
	var verts := PackedVector3Array([
		# branche gauche
		Vector3(-w, 0, l), Vector3(-w + t, 0, l), Vector3(0, 0, -l + t),
		Vector3(-w, 0, l), Vector3(0, 0, -l + t), Vector3(0, 0, -l),
		# branche droite
		Vector3(w, 0, l), Vector3(0, 0, -l), Vector3(0, 0, -l + t),
		Vector3(w, 0, l), Vector3(0, 0, -l + t), Vector3(w - t, 0, l),
	])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
