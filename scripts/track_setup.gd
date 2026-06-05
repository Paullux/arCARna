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

const NEON_SHADER := preload("res://assets/shaders/tube_neon.gdshader")

const NEON_COLORS := {
	"Neon_Rouge": Color(1.0, 0.08, 0.08),
	"Neon_Blue": Color(0.15, 0.45, 1.0),
	"Neon_Vert": Color(0.2, 1.0, 0.45),
}

func _ready() -> void:
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
					break

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
