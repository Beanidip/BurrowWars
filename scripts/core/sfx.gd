extends Node
## Audio feedback autoload: a small pool of players plus looping music.
## Missing files are reported once and then skipped, never fatal.

const POOL := 10
const DIR := "res://assets/sfx/"

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Config.apply_audio()   # makes sure the Music and SFX buses exist
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_music.play)


func _exit_tree() -> void:
	# closing: stop and let go of every stream so nothing is left playing
	_music.stop()
	_music.stream = null
	for p in _players:
		p.stop()
		p.stream = null
	_cache.clear()


func play(sound: String, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	var stream := _load(DIR + sound + ".wav")
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.2, pitch + randf_range(-jitter, jitter))
	p.play()


func play_music(path: String) -> void:
	var stream := _load(path)
	if stream == null:
		return
	_music.stream = stream
	_music.play()


func set_music_volume(v: float) -> void:
	## (The Music bus carries the volume; Config holds the value.)
	Config.apply_audio()
	_music.stream_paused = v <= 0.001


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		Log.warn("missing audio asset: " + path)
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s
