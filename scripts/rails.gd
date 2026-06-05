extends Node3D
## Génère deux "boudins" néon (tubes émissifs) le long des bords de la piste.
## Lit le mesh CenterLine du circuit, mesure la largeur réelle par raycast à
## chaque point, et construit un tube fermé de chaque côté (rouge / bleu).

@export var radius: float = 0.35
@export var sides: int = 12
@export var sample_spacing: float = 3.0
@export var max_halfwidth: float = 16.0
@export var gap_tolerance: float = 3.0       ## trou max toléré avant de décider du bord
@export var smooth_passes: int = 8           ## lissage des boudins
@export var min_point_dist: float = 12.0     ## écarte les points rapprochés (évite les boucles)
@export var edge_inset: float = 0.4          ## décale le tube un peu vers l'intérieur
@export var left_color: Color = Color(1.0, 0.08, 0.08)   ## rouge (gauche)
@export var right_color: Color = Color(0.1, 0.35, 1.0)   ## bleu (droite)
@export var emit_energy: float = 1.4
@export var pulse_strength: float = 3.0
@export var pulse_speed: float = 9.0
@export var pulse_freq: float = 0.06

const TUBE_SHADER := preload("res://assets/shaders/tube_neon.gdshader")

func _ready() -> void:
	_build.call_deferred()

func _build() -> void:
	for _i in 3:
		await get_tree().physics_frame
	var pts := _waypoints_from_centerline()
	if pts.size() < 3:
		push_warning("[Rails] CenterLine introuvable")
		return
	var curve := _curve(pts)
	var space := get_world_3d().direct_space_state
	var length := curve.get_baked_length()
	var left: PackedVector3Array = []
	var right: PackedVector3Array = []
	var d := 0.0
	while d < length:
		var pos := curve.sample_baked(d)
		var ahead := curve.sample_baked(fmod(d + sample_spacing, length))
		var tan := ahead - pos
		tan.y = 0.0
		if tan.length() < 0.001:
			d += sample_spacing
			continue
		tan = tan.normalized()
		var rdir := tan.cross(Vector3.UP).normalized()
		var le := _edge(space, pos, -rdir)
		var re := _edge(space, pos, rdir)
		left.append(le + rdir * edge_inset + Vector3.UP * radius)
		right.append(re - rdir * edge_inset + Vector3.UP * radius)
		d += sample_spacing
	left = _smooth(left, smooth_passes)
	right = _smooth(right, smooth_passes)
	left = _dedup(left, min_point_dist)
	right = _dedup(right, min_point_dist)
	# Tube le long d'une courbe lissée continue (une seule ligne épaissie)
	var left_baked := _curve(left).get_baked_points()
	var right_baked := _curve(right).get_baked_points()
	_make_tube(left_baked, left_color, "RailL")
	_make_tube(right_baked, right_color, "RailR")
	print("[Rails] boudins continus : ", left_baked.size(), " pts/côté")

## Bord de piste : on avance vers l'extérieur, on garde le dernier point Sol ;
## on s'arrête dès qu'il y a un vide continu > gap_tolerance (vrai bord), ce
## qui évite de sauter vers le repli voisin tout en tolérant les petits trous.
func _edge(space: PhysicsDirectSpaceState3D, pos: Vector3, dir: Vector3) -> Vector3:
	var edge := pos
	var miss_run := 0.0
	var t := 1.0
	while t <= max_halfwidth:
		var p := pos + dir * t
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 80, p.z), Vector3(p.x, -20, p.z))
		var hit := space.intersect_ray(q)
		var par := ((hit.collider as Node).get_parent() if hit and hit.collider else null)
		if par != null and par.name.begins_with("Sol"):
			edge = hit.position
			miss_run = 0.0
		else:
			miss_run += 1.0
			if miss_run > gap_tolerance:
				break
		t += 1.0
	return edge

func _smooth(pts: PackedVector3Array, passes: int) -> PackedVector3Array:
	var n := pts.size()
	if n < 3:
		return pts
	for _p in passes:
		var out := PackedVector3Array()
		out.resize(n)
		for i in n:
			var a := pts[(i - 1 + n) % n]
			var b := pts[i]
			var c := pts[(i + 1) % n]
			out[i] = (a + b * 2.0 + c) * 0.25
		pts = out
	return pts

func _dedup(pts: PackedVector3Array, mind: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= mind:
			out.append(p)
	# évite un dernier point collé au premier (boucle fermée)
	while out.size() > 3 and out[out.size() - 1].distance_to(out[0]) < mind:
		out.remove_at(out.size() - 1)
	return out

func _make_tube(pts: PackedVector3Array, col: Color, nm: String) -> void:
	var m := pts.size()
	if m < 3:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	for i in m:
		var p := pts[i]
		var nxt := pts[(i + 1) % m]
		var prv := pts[(i - 1 + m) % m]
		if i > 0:
			dist += p.distance_to(pts[i - 1])
		var t := (nxt - prv).normalized()
		var r := t.cross(Vector3.UP)
		if r.length() < 0.001:
			r = Vector3.RIGHT
		r = r.normalized()
		var u := r.cross(t).normalized()
		for k in sides:
			var a := TAU * k / sides
			var n := (r * cos(a) + u * sin(a)).normalized()
			verts.append(p + n * radius)
			norms.append(n)
			uvs.append(Vector2(dist, float(k) / sides))
	for i in m:
		for k in sides:
			var a := i * sides + k
			var b := i * sides + (k + 1) % sides
			var c := ((i + 1) % m) * sides + k
			var d2 := ((i + 1) % m) * sides + (k + 1) % sides
			idx.append_array([a, c, b, b, c, d2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mat := ShaderMaterial.new()
	mat.shader = TUBE_SHADER
	mat.set_shader_parameter("neon_color", col)
	mat.set_shader_parameter("base_glow", emit_energy)
	mat.set_shader_parameter("pulse_strength", pulse_strength)
	mat.set_shader_parameter("pulse_speed", pulse_speed)
	mat.set_shader_parameter("pulse_freq", pulse_freq)

	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

func _curve(pts: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.5
	var n := pts.size()
	for i in range(n + 1):
		var idx := i % n
		var p := pts[idx]
		var prev := pts[(idx - 1 + n) % n]
		var nxt := pts[(idx + 1) % n]
		var tan := (nxt - prev) * 0.1
		curve.add_point(p, -tan, tan)
	return curve

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
