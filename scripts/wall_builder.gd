extends Node3D
## Génère collision murs + rebouchage de trous pour un Sol .glb imparfait.
##
## 1) Échantillonne le Sol par raycast (grille) -> masque "route".
## 2) Étiquette les zones "vide" (non-route) en composantes connexes.
##    - Grande zone / touchant le bord  = extérieur ou infield  -> on MURE.
##    - Petite zone enclavée            = trou du mesh          -> on REBOUCHE.
## 3) Mur vertical sur les cellules de route au contact d'une zone à murer ;
##    sol plat horizontal sur les trous.
## Indépendant de la qualité du mesh (sandwich, surfaces fines, perforations).

@export var cell: float = 4.0
@export var wall_height: float = 5.0
@export var floor_thickness: float = 2.0
@export var auto_area: bool = true          ## calcule la zone depuis l'AABB du Sol
@export var area_margin: float = 8.0
@export var area_min := Vector2(-66, -6)     ## utilisé seulement si auto_area = false
@export var area_max := Vector2(66, 68)
@export var sol_name_prefix: String = "Sol"
@export var min_void_size: int = 20   ## sous ce nb de cellules, un vide = trou à reboucher
@export var debug_visible: bool = false

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _nx: int
var _nz: int

func _ready() -> void:
	_build.call_deferred()

func _build() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state

	if auto_area:
		_compute_area_from_sol()

	_nx = int((area_max.x - area_min.x) / cell) + 1
	_nz = int((area_max.y - area_min.y) / cell) + 1

	var road := {}
	for ix in _nx:
		for iz in _nz:
			var x := area_min.x + ix * cell
			var z := area_min.y + iz * cell
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -20, z))
			var hit := space.intersect_ray(q)
			if hit and hit.collider and _is_sol(hit.collider):
				road[Vector2i(ix, iz)] = hit.position.y

	# Composantes connexes des vides
	var wall_void := {}    # cellules vides à murer
	var hole_void := {}    # cellules vides à reboucher
	var seen := {}
	for ix in _nx:
		for iz in _nz:
			var c := Vector2i(ix, iz)
			if road.has(c) or seen.has(c):
				continue
			var comp: Array[Vector2i] = []
			var touches := false
			var stack: Array[Vector2i] = [c]
			seen[c] = true
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				comp.append(cur)
				if cur.x == 0 or cur.y == 0 or cur.x == _nx - 1 or cur.y == _nz - 1:
					touches = true
				for d in DIRS:
					var nb: Vector2i = cur + d
					if _in_grid(nb) and not road.has(nb) and not seen.has(nb):
						seen[nb] = true
						stack.append(nb)
			var worthy := touches or comp.size() >= min_void_size
			for cc in comp:
				if worthy:
					wall_void[cc] = true
				else:
					hole_void[cc] = true

	var body := StaticBody3D.new()
	body.name = "WallCollision"
	add_child(body)

	# Sol solide (filet anti-enfoncement) sous CHAQUE cellule de route :
	# sommet JUSTE SOUS le Sol lisse pour éviter les marches qui bloqueraient.
	for keyv in road:
		var y: float = road[keyv]
		_add_box(body, keyv, y - 0.4 - floor_thickness * 0.5, floor_thickness, Color(0.2, 0.3, 1.0))

	# Murs : sur les cellules HORS-PISTE adjacentes à la route (juste à
	# l'extérieur du bord) -> on ne mange pas la largeur roulable.
	var nwall := 0
	for keyv in wall_void:
		var vcell: Vector2i = keyv
		var hy := INF
		for d in DIRS:
			var nb: Vector2i = vcell + d
			if road.has(nb):
				hy = road[nb]
				break
		if hy != INF:
			_add_box(body, vcell, hy + wall_height * 0.5, wall_height, Color(0, 1, 0))
			nwall += 1

	# Rebouchage : sol plat sur les trous, à la hauteur des voisins route
	var nhole := 0
	for keyv in hole_void:
		var key: Vector2i = keyv
		var ys := 0.0
		var cnt := 0
		for d in DIRS:
			if road.has(key + d):
				ys += road[key + d]
				cnt += 1
		var hy: float = (ys / cnt) if cnt > 0 else 0.4
		_add_box(body, key, hy - floor_thickness * 0.5, floor_thickness, Color(1, 0.5, 0))
		nhole += 1

	print("[WallBuilder] murs=", nwall, " trous_rebouchés=", nhole, " (route=", road.size(), " cellules)")

func _add_box(body: StaticBody3D, key: Vector2i, y_center: float, height: float, dbg_col: Color) -> void:
	var x := area_min.x + key.x * cell
	var z := area_min.y + key.y * cell
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cell, height, cell)
	cs.shape = box
	cs.position = Vector3(x, y_center, z)
	body.add_child(cs)
	if debug_visible:
		var dbg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		dbg.mesh = bm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = dbg_col
		dm.emission_enabled = true
		dm.emission = dbg_col
		dm.emission_energy_multiplier = 3.0
		dbg.material_override = dm
		dbg.position = cs.position
		add_child(dbg)

func _compute_area_from_sol() -> void:
	var tree := get_tree()
	for mi in tree.get_root().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with(sol_name_prefix) and m.mesh != null:
			var world := m.global_transform * m.mesh.get_aabb()
			area_min = Vector2(world.position.x - area_margin, world.position.z - area_margin)
			area_max = Vector2(world.end.x + area_margin, world.end.z + area_margin)
			print("[WallBuilder] zone auto: ", area_min, " -> ", area_max)
			return

func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < _nx and c.y >= 0 and c.y < _nz

func _is_sol(col: Object) -> bool:
	var p := (col as Node).get_parent()
	return p != null and p.name.begins_with(sol_name_prefix)
