class_name MusicPlayer
extends AudioStreamPlayer
## Lecteur de musique d'une scène (piste en boucle, réglée dans l'import .ogg).

@export_file("*.ogg") var track: String = ""
@export var volume := -8.0


func _ready() -> void:
	volume_db = volume
	bus = &"Master"
	if track != "" and ResourceLoader.exists(track):
		stream = load(track)
		play()


static func create(p_track: String) -> MusicPlayer:
	var m := MusicPlayer.new()
	m.track = p_track
	return m
