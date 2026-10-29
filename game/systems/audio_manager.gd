class_name WolfAudioManager
extends Node
var player: AudioStreamPlayer
var tracks: Dictionary = {}
var music_volume: float = 0.55
var effects_volume: float = 0.7
var ambience_volume: float = 0.45
var loops_left: int = 1
var current_track: String = ""

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_finished)
	for name: String in ["cf","cg","ch","ci","cj"]:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/original/"+name+".mid")
		tracks[bytes.hex_encode().sha256_text()] = name

func play_midi(bytes: PackedByteArray, loops: int) -> void:
	var key: String = bytes.hex_encode().sha256_text()
	if not tracks.has(key): return
	current_track = tracks[key]
	var path: String = "res://assets/audio/"+current_track+".wav"
	if not ResourceLoader.exists(path): return
	player.stream = load(path)
	loops_left = loops
	player.volume_linear = music_volume
	player.play()

func stop_music() -> void:
	if player!=null: player.stop()

func _finished() -> void:
	if loops_left<0 or loops_left>1:
		if loops_left>1: loops_left-=1
		player.play()

func set_music(value: float) -> void:
	music_volume = value
	player.volume_linear = value
