extends Control
## HUD : cadran de vitesse (dessiné), jauges énergie/nitro, tours + chrono,
## écran de game over avec flash et redémarrage.

@export var player_path: NodePath

var _player: Node
var _lap_label: Label
var _info_label: Label
var _over_label: Label
var _count_label: Label
var _flash: float = 0.0

var _traffic: Node

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_traffic = get_node_or_null("/root/Main/TrafficManager")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lap_label = _make_label(Vector2(28, 22), 30, HORIZONTAL_ALIGNMENT_LEFT)
	_info_label = _make_label(Vector2(28, 62), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_over_label = _make_label(Vector2.ZERO, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_over_label.set_anchors_preset(Control.PRESET_CENTER)
	_over_label.visible = false
	if GameManager.game_over_changed.connect(_on_game_over) != OK:
		pass

func _make_label(pos: Vector2, fsize: int, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.horizontal_alignment = align
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	return l

func _on_game_over(over: bool) -> void:
	if over:
		_flash = 1.0

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	if GameManager.is_game_over and Input.is_action_just_pressed("nitro"):
		get_tree().reload_current_scene()
		return
	# textes tours / chrono
	if GameManager.race_started:
		var pos_txt := ""
		if _traffic != null and _player != null:
			pos_txt = "   P%d/%d" % [_traffic.player_rank(_player.global_position), _traffic.racer_count()]
		_lap_label.text = "TOUR %d%s" % [GameManager.current_lap, pos_txt]
		var cur := "%s" % _fmt(GameManager.current_lap_time())
		var best := ("  MEILLEUR %s" % _fmt(GameManager.best_lap_time)) if GameManager.best_lap_time > 0.0 else ""
		_info_label.text = "%s%s" % [cur, best]
	else:
		_lap_label.text = ""
		_info_label.text = ("MEILLEUR %s" % _fmt(GameManager.best_lap_time)) if GameManager.best_lap_time > 0.0 else ""
	_over_label.visible = GameManager.is_game_over
	if GameManager.is_game_over:
		_over_label.text = "%s\n\n[Espace] pour rejouer" % _game_over_text()
		_over_label.size = Vector2(600, 220)
		_over_label.position = (size - _over_label.size) * 0.5
	queue_redraw()

func _game_over_text() -> String:
	match GameManager.game_over_reason:
		"fuel":
			return "⛽ PANNE SÈCHE ⛽\nPlus de carburant"
		"crash":
			return "💥 CHOC DE TROP 💥\nVoiture détruite"
		"offtrack":
			return "🚧 SORTIE DE PISTE 🚧\nHors circuit"
		_:
			return "💥 EXPLOSION 💥"

func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]

func _draw() -> void:
	if _player == null:
		return
	# --- Flash plein écran sur game over ---
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash))

	# --- Cadran de vitesse (bas droite) ---
	var c := Vector2(size.x - 140, size.y - 130)
	var r := 100.0
	var a0 := deg_to_rad(140.0)
	var a1 := deg_to_rad(400.0)
	var spd: float = absf(_player.forward_speed)
	var vmax: float = _player.nitro_speed
	var frac := clampf(spd / vmax, 0.0, 1.0)
	# fond
	draw_arc(c, r, a0, a1, 64, Color(0.12, 0.13, 0.18), 14.0, true)
	# valeur
	var av := a0 + (a1 - a0) * frac
	var col := Color(0.2, 0.9, 1.0)
	if _player.nitro_active:
		col = Color(1.0, 0.5, 0.1)
	draw_arc(c, r, a0, av, 64, col, 14.0, true)
	# graduations
	for i in 11:
		var ta := a0 + (a1 - a0) * (i / 10.0)
		var d := Vector2(cos(ta), sin(ta))
		draw_line(c + d * (r - 14), c + d * (r - 2), Color(0.5, 0.55, 0.65), 2.0)
	# aiguille
	var nd := Vector2(cos(av), sin(av))
	draw_line(c, c + nd * (r - 18), Color(1, 1, 1), 3.0)
	draw_circle(c, 6, Color(0.9, 0.9, 1.0))
	# chiffre
	var f := ThemeDB.fallback_font
	var txt := "%d" % int(spd)
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
	draw_string(f, c + Vector2(-ts.x * 0.5, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	draw_string(f, c + Vector2(-22, 50), "u/s", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.75, 0.85))

	# --- Jauge énergie (bas gauche) ---
	_draw_bar(Vector2(28, size.y - 70), Vector2(320, 26), GameManager.energy,
		Color(1, 0.25, 0.2), Color(0.2, 1, 0.4), "ÉNERGIE", 0)
	# --- Jauge nitro ---
	_draw_bar(Vector2(28, size.y - 116), Vector2(320, 20), GameManager.nitro,
		Color(0.1, 0.5, 0.9), Color(0.2, 0.9, 1.0), "NITRO", 3)

func _draw_bar(pos: Vector2, sz: Vector2, value: float, low: Color, high: Color, label: String, segments: int) -> void:
	var f := ThemeDB.fallback_font
	draw_string(f, pos + Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.85, 0.95))
	draw_rect(Rect2(pos, sz), Color(0.1, 0.11, 0.16))
	var fill := clampf(value, 0.0, 1.0)
	var col := low.lerp(high, fill)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2((sz.x - 4) * fill, sz.y - 4)), col)
	draw_rect(Rect2(pos, sz), Color(0.4, 0.45, 0.55), false, 2.0)
	if segments > 1:
		for i in range(1, segments):
			var x := pos.x + sz.x * (float(i) / segments)
			draw_line(Vector2(x, pos.y), Vector2(x, pos.y + sz.y), Color(0, 0, 0, 0.6), 2.0)
