extends MeshInstance3D
## Traînée lumineuse derrière la voiture pendant le nitro : ruban émissif
## additif qui s'estompe avec l'âge. Construit en espace monde (top_level).

@export var player_path: NodePath
@export var color: Color = Color(0.5, 0.9, 1.0)
@export var width: float = 1.8
@export var lifetime: float = 0.45      ## durée de vie d'un point (s)
@export var min_step: float = 0.6       ## distance mini entre points
@export var y_offset: float = 0.25

var _player: Node3D
var _pts: Array = []   # [{p:Vector3, age:float}]
var _im: ImmediateMesh

func _ready() -> void:
	_player = get_node_or_null(player_path)
	top_level = true
	_im = ImmediateMesh.new()
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	material_override = m
	global_position = Vector3.ZERO

func _process(delta: float) -> void:
	if _player == null:
		return
	# vieillissement / purge
	for pt in _pts:
		pt.age += delta
	while not _pts.is_empty() and _pts[0].age >= lifetime:
		_pts.pop_front()

	# ajout d'un point en nitro
	if _player.nitro_active:
		var p := _player.global_position + Vector3.UP * y_offset
		if _pts.is_empty() or _pts[-1].p.distance_to(p) >= min_step:
			_pts.append({"p": p, "age": 0.0})

	_rebuild()

func _rebuild() -> void:
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _pts.size()
	for i in n:
		var p: Vector3 = _pts[i].p
		var prev: Vector3 = _pts[max(i - 1, 0)].p
		var nxt: Vector3 = _pts[min(i + 1, n - 1)].p
		var dir := (nxt - prev)
		dir.y = 0.0
		if dir.length() < 0.001:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var fade: float = 1.0 - _pts[i].age / lifetime          # 1 (récent) -> 0 (vieux)
		var taper: float = float(i) / float(n - 1)               # fin à la queue
		var hw := width * 0.5 * (0.25 + 0.75 * taper)
		var a := clampf(fade, 0.0, 1.0)
		var c := Color(color.r, color.g, color.b, a)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side * hw)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side * hw)
	_im.surface_end()
