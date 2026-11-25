extends Node
## Audio feedback autoload: a small pool of players plus music: the title
## theme (one track, looping) or the in-game playlist (each track once, then
## the next, round and round; it carries on where it was between matches).
## Missing files are reported once and then skipped, never fatal.

const POOL := 10
const DIR := "res://assets/sfx/"
const TITLE_THEME := "res://assets/music/sneak_rat.ogg"
const GAME_PLAYLIST := ["res://assets/music/mr_bones.mp3", "res://assets/music/ratcano_run.ogg", "res://assets/music/rat_grass_valley.mp3"]

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _next := 0
var _music: AudioStreamPlayer
var _playlist: Array = []        # the tracks being played in turn ([] = one track, looping)
var _track := -1                 # which of them is playing
var music_path := ""             # what's playing now


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
	_music.finished.connect(_on_music_finished)


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
	## One track, looping (the title theme). Already playing it: carries on.
	_playlist = []
	if path == music_path and _music.playing:
		return
	_start(path)


func play_playlist(paths: Array) -> void:
	## Each track in turn, round and round. Already playing this list: carries
	## on with the current track (a new match doesn't restart the music).
	if paths == _playlist and _music.playing:
		return
	_playlist = paths.duplicate()
	_track = 0
	_start(String(_playlist[0]))


func title_theme() -> void:
	play_music(TITLE_THEME)


func game_music() -> void:
	play_playlist(GAME_PLAYLIST)


func _start(path: String) -> void:
	var stream := _load(path)
	music_path = path
	if stream == null:
		_music.stop()
		return
	# the file's own loop setting decides nothing: we loop or move on ourselves
	if "loop" in stream:
		stream.set("loop", false)
	_music.stream = stream
	_music.play()


func _on_music_finished() -> void:
	if _playlist.is_empty():
		_music.play()   # the title theme: round again
		return
	_track = (_track + 1) % _playlist.size()
	_start(String(_playlist[_track]))


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
