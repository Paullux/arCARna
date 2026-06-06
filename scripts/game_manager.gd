extends Node
## GameManager — autoload singleton.
## Jalon 1 : on n'a besoin que d'une jauge de nitro stub pour que le drift
## ait quelque chose à charger. Le reste (score, combo, tours) arrivera aux
## jalons suivants.

signal nitro_changed(value: float)
signal energy_changed(value: float)
signal game_over_changed(is_over: bool)
signal lap_completed(lap: int, lap_time: float)

# --- Tours / chrono ---
var current_lap: int = 0
var last_lap_time: float = 0.0
var best_lap_time: float = 0.0
var race_started: bool = false
var can_drive: bool = false      ## faux pendant le compte à rebours
var _lap_start: float = 0.0

## Appelé par le compte à rebours au "START".
func start_race() -> void:
	race_started = true
	can_drive = true
	current_lap = 1
	_lap_start = _now()

## Temps écoulé sur le tour courant (s).
func current_lap_time() -> float:
	if not race_started or is_game_over:
		return 0.0
	return _now() - _lap_start

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Appelé par la ligne d'arrivée à chaque passage sur le damier.
func register_lap_crossing() -> void:
	# Ignore le passage au spawn : la course démarre via start_race() (compte à rebours).
	if is_game_over or not race_started:
		return
	last_lap_time = _now() - _lap_start
	if best_lap_time == 0.0 or last_lap_time < best_lap_time:
		best_lap_time = last_lap_time
		_save_best()
	current_lap += 1
	_lap_start = _now()
	lap_completed.emit(current_lap, last_lap_time)

## Nitro normalisé 0..1 (segmenté plus tard).
var nitro: float = 0.0
## Énergie 0..1 — ressource de survie (carburant + bouclier), recharge aux stands.
var energy: float = 1.0
var is_game_over: bool = false
var is_recharging: bool = false   ## vrai quand la voiture est dans les stands

const NITRO_MAX: float = 1.0
const ENERGY_MAX: float = 1.0

const SAVE_PATH := "user://arcarna.save"

func _ready() -> void:
	# Icône de fenêtre (visible aussi en lançant depuis l'éditeur)
	var tex: Texture2D = load("res://assets/images/ico/arCARna.png")
	if tex:
		DisplayServer.set_icon(tex.get_image())
	_setup_buses()
	_load_best()

## Crée les bus audio Music / SFX (routés vers Master) s'ils n'existent pas.
func _setup_buses() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")

func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best_lap_time = f.get_double()
			f.close()

func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_double(best_lap_time)
		f.close()

## Remet l'état à neuf (au (re)démarrage d'une course ; l'autoload persiste).
func reset_run() -> void:
	energy = ENERGY_MAX
	nitro = 0.0
	is_game_over = false
	game_over_reason = ""
	is_recharging = false
	current_lap = 0
	last_lap_time = 0.0
	race_started = false
	can_drive = false
	# best_lap_time conservé (persiste entre les parties)
	energy_changed.emit(energy)
	nitro_changed.emit(nitro)
	game_over_changed.emit(false)

func add_energy(amount: float) -> void:
	if is_game_over:
		return
	var before := energy
	energy = clamp(energy + amount, 0.0, ENERGY_MAX)
	if energy != before:
		energy_changed.emit(energy)

## Raison du game over : "fuel" (carburant vide), "crash" (choc de trop),
## "offtrack" (sortie de piste), ou "" (générique).
var game_over_reason: String = ""

func trigger_game_over(reason: String = "") -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over_reason = reason
	game_over_changed.emit(true)

func add_nitro(amount: float) -> void:
	var before := nitro
	nitro = clamp(nitro + amount, 0.0, NITRO_MAX)
	if nitro != before:
		nitro_changed.emit(nitro)

func consume_nitro(amount: float) -> void:
	add_nitro(-amount)
