extends AudioStreamPlayer
## Radio embarquée : enchaîne les musiques en aléatoire, sans rejouer deux
## fois de suite le même morceau. Touche [N] = passer au morceau suivant.

const TRACKS := [
	"res://assets/musics/Futuristic cyberpunk racing soundtrack.mp3",
	"res://assets/musics/High-speed cyberpunk racing soundtrack.mp3",
	"res://assets/musics/Instrumental electronic music.mp3",
]

var _streams: Array = []
var _current: int = -1

func _ready() -> void:
	if AudioServer.get_bus_index("Music") != -1:
		bus = "Music"
	for path in TRACKS:
		var s = load(path)
		if s == null:
			continue
		if s is AudioStreamMP3:
			s.loop = false        # pas de boucle : on enchaîne sur le suivant
		_streams.append(s)
	if not finished.is_connected(_play_next):
		finished.connect(_play_next)
	_play_next()

func _play_next() -> void:
	if _streams.is_empty():
		return
	var i := _current
	while _streams.size() > 1 and i == _current:
		i = randi() % _streams.size()
	_current = i
	stream = _streams[i]
	play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_N:
			_play_next()
