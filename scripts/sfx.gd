extends Node
## Audio manager. All streams are synthesized WAVs from tools/gen_audio.py.

const NAMES := [
	"amb_hum", "amb_fan", "amb_drone", "amb_vent", "door_close", "door_open", "light_buzz",
	"cam_switch", "cam_up", "cam_down", "static", "knock", "power_down", "step_heavy",
	"step_metal", "step_hoof", "rook_run", "pots", "tray", "curtain", "metal_distant",
	"laugh_grayson", "golden_whisper", "voice_selim", "voice_hakan", "voice_dila", "voice_owner",
	"tape_click", "beep", "musicbox", "stage_music", "chime6", "scream_grayson", "scream_benny",
	"scream_brutus", "scream_rook", "scream_golden", "clue_found", "ui_click", "thump",
]
const LOOPING := ["amb_hum", "amb_fan", "amb_drone", "amb_vent", "light_buzz", "static",
	"voice_selim", "voice_hakan", "voice_dila", "voice_owner", "stage_music", "musicbox"]

var streams: Dictionary = {}       # one-shot versions (play / play_at)
var loop_streams: Dictionary = {}  # looping versions (loop)
var loops: Dictionary = {}   # name -> AudioStreamPlayer
var _pool: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			var s = load(path)
			streams[n] = s
			if s is AudioStreamWAV and LOOPING.has(n):
				# a one-shot play of a looping stream would never stop (endless crackle)
				var w: AudioStreamWAV = s.duplicate()
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
				loop_streams[n] = w
			else:
				loop_streams[n] = s
		else:
			push_warning("Missing sound: " + path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(n: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not streams.has(n):
		return null
	var p: AudioStreamPlayer = null
	for c in _pool:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _pool[0]
	p.stream = streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


func play_at(n: String, parent: Node3D, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 40.0) -> void:
	if not streams.has(n) or parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func loop(n: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if loops.has(n):
		var lp: AudioStreamPlayer = loops[n]
		lp.volume_db = volume_db
		lp.pitch_scale = pitch
		if not lp.playing:
			lp.play()
		return lp
	if not loop_streams.has(n):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = loop_streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	loops[n] = p
	return p


func set_loop_volume(n: String, volume_db: float) -> void:
	if loops.has(n):
		loops[n].volume_db = volume_db


func stop_loop(n: String) -> void:
	if loops.has(n):
		loops[n].stop()


func stop_all() -> void:
	for n in loops.keys():
		loops[n].stop()
	for p in _pool:
		p.stop()
