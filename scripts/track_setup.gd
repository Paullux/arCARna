extends Node3D
## Configure le circuit .glb (Sol + Neon_Rouge/Blue/Vert + CenterLine).
##  - Sol        : surface roulable (collision), garde sa texture.
##  - Neon_*      : matériau émissif coloré (glow via WorldEnvironment).
##  - CenterLine  : masquée (sert juste de spline aux chevrons).

@export var neon_energy: float = 0.5           ## glow de fond (entre les segments)
@export var neon_animated: bool = true         ## segments lumineux qui défilent
@export var neon_seg_strength: float = 6.0
@export var neon_seg_freq: float = 20.0        ## densité des segments (le long de l'UV)
@export var neon_seg_speed: float = 0.12
@export var sol_dark: bool = true              ## assombrit la route si sa texture est trop claire
@export var neon_solid: PackedStringArray = ["Neon_Rouge", "Neon_Blue"]  ## néons avec collision (barrière)

const NEON_SHADER := preload("res://assets/shaders/tube_neon.gdshader")

const NEON_COLORS := {
	"Neon_Rouge": Color(1.0, 0.08, 0.08),
	"Neon_Blue": Color(0.15, 0.45, 1.0),
	"Neon_Vert": Color(0.2, 1.0, 0.45),
}

func _ready() -> void:
	var pit_aabb := _pit_aabb()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var nm := mi.name
		if nm.begins_with("Sol"):
			if sol_dark:
				var sm := StandardMaterial3D.new()
				sm.albedo_color = Color(0.03, 0.03, 0.05)
				sm.roughness = 0.8
				sm.metallic = 0.0
				mi.material_override = sm
			mi.create_trimesh_collision()
		elif nm.begins_with("CenterLine"):
			mi.visible = false
		else:
			for key in NEON_COLORS:
				if nm.begins_with(key):
					_apply_neon(mi, NEON_COLORS[key])
					if _is_solid(nm):
						_build_neon_collision(mi, pit_aabb)   # barrière, trouée devant le stand
					break

## AABB monde de la PitZone (pour trouer la collision néon devant le stand).
func _pit_aabb() -> AABB:
	var pit := get_node_or_null("../PitZone")
	if pit == null:
		return AABB()
	for c in pit.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if cs.shape is BoxShape3D:
			var hs: Vector3 = (cs.shape as BoxShape3D).size * 0.5
			var gt := cs.global_transform
			var box := AABB(gt.origin, Vector3.ZERO)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						box = box.expand(gt * Vector3(sx * hs.x, sy * hs.y, sz * hs.z))
			return box
	return AABB()

## Construit la collision d'un néon en sautant les triangles au-dessus de la
## PitZone (en XZ) → laisse un passage pour entrer/sortir du stand.
func _build_neon_collision(mi: MeshInstance3D, skip: AABB) -> void:
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var gt := mi.global_transform
	var faces := PackedVector3Array()
	var has_skip := skip.size.length() > 0.01
	var count: int = idx.size() if (idx != null and idx.size() >= 3) else verts.size()
	var get_v := func(k: int) -> int: return idx[k] if (idx != null and idx.size() >= 3) else k
	for t in range(0, count - 2, 3):
		var la: Vector3 = verts[get_v.call(t)]
		var lb: Vector3 = verts[get_v.call(t + 1)]
		var lc: Vector3 = verts[get_v.call(t + 2)]
		if has_skip:
			var wc: Vector3 = gt * ((la + lb + lc) / 3.0)
			if wc.x >= skip.position.x and wc.x <= skip.end.x \
					and wc.z >= skip.position.z and wc.z <= skip.end.z:
				continue                      # triangle devant le stand : pas de collision
		faces.append(la); faces.append(lb); faces.append(lc)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)                        # hérite du transform du mesh (faces locales)

func _is_solid(nm: String) -> bool:
	for prefix in neon_solid:
		if nm.begins_with(prefix):
			return true
	return false

func _apply_neon(mi: MeshInstance3D, col: Color) -> void:
	if neon_animated:
		var sm := ShaderMaterial.new()
		sm.shader = NEON_SHADER
		sm.set_shader_parameter("neon_color", col)
		sm.set_shader_parameter("base_glow", neon_energy)
		sm.set_shader_parameter("pulse_strength", neon_seg_strength)
		sm.set_shader_parameter("pulse_freq", neon_seg_freq)
		sm.set_shader_parameter("pulse_speed", neon_seg_speed)
		mi.material_override = sm
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = col * 0.15
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = neon_energy
		m.roughness = 0.4
		mi.material_override = m
