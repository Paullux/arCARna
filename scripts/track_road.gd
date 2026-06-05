@tool
extends Node3D
## Génère une route procédurale roulable (ruban + collision) le long d'une
## spline fermée passant par `waypoints`. Crée aussi un Path3D enfant (pour
## le trafic / les tours / le lookahead caméra) et applique le shader néon.
## Modifie `waypoints` puis coche `rebuild` dans l'inspecteur pour reconstruire.

@export var width: float = 14.0
@export var handle_scale: float = 0.5
@export var bake_interval: float = 1.0
@export var u_scale: float = 8.0          ## longueur monde par unité U (pointillés)
@export var road_material: Material
@export var rebuild: bool = false:
	set(v):
		if v:
			_build()

## Ligne de course (monde), relevée sur le .glb par vue de dessus.
@export var waypoints: PackedVector3Array = PackedVector3Array([
	Vector3(-37.6, 0, -18.6),
	Vector3(32.4, 0, -18.6),
	Vector3(50.4, 0, -29.6),
	Vector3(41.4, 0, -46.6),
	Vector3(22.4, 0, -48.0),
	Vector3(11.4, 0, -37.6),
	Vector3(1.4, 0, -32.0),
	Vector3(-6.6, 0, -42.0),
	Vector3(-14.6, 0, -50.0),
	Vector3(-25.6, 0, -47.6),
	Vector3(-29.6, 0, -37.6),
	Vector3(-39.6, 0, -27.6),
	Vector3(-49.6, 0, -28.6),
])

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	if waypoints.size() < 3:
		return

	var curve := _make_curve()

	# Path3D enfant (réutilisé par les autres systèmes)
	var path := Path3D.new()
	path.name = "Path3D"
	path.curve = curve
	add_child(path)

	# Ruban de route
	var baked := curve.get_baked_points()
	var mesh := _build_ribbon(baked)
	var mi := MeshInstance3D.new()
	mi.name = "RoadMesh"
	mi.mesh = mesh
	if road_material:
		mi.material_override = road_material
	add_child(mi)
	mi.create_trimesh_collision()

func _make_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	var n := waypoints.size()
	for i in range(n + 1):
		var idx := i % n
		var p := waypoints[idx]
		var prev := waypoints[(idx - 1 + n) % n]
		var nxt := waypoints[(idx + 1) % n]
		var tan := (nxt - prev) * 0.5 * handle_scale
		curve.add_point(p, -tan, tan)
	return curve

func _build_ribbon(baked: PackedVector3Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := width * 0.5
	var m := baked.size()
	var dist := 0.0
	for i in range(m):
		var p := baked[i]
		var prev := baked[(i - 1 + m) % m]
		var nxt := baked[(i + 1) % m]
		var tangent := (nxt - prev)
		tangent.y = 0.0
		if tangent.length() < 0.001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		var side := tangent.cross(Vector3.UP).normalized() * half
		if i > 0:
			dist += p.distance_to(baked[i - 1])
		var u := dist / u_scale
		verts.push_back(p + side)
		uvs.push_back(Vector2(u, 0.0))
		verts.push_back(p - side)
		uvs.push_back(Vector2(u, 1.0))
	for i in range(m):
		var a := i * 2
		var b := ((i + 1) % m) * 2
		# deux triangles par segment (double face gérée par le shader cull_disabled)
		indices.append_array([a, b, a + 1, b, b + 1, a + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
