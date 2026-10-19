extends Node
## Persistent game progress: run seed, reached night, found evidence, settings.
## Saved to user://greyfang_save.json

var SAVE_PATH := "user://greyfang_save.json"

var run_seed: int = 0
var night: int = 1              # night to play next
var max_night_reached: int = 1
var found: Array = []           # clue ids found in this run (order of discovery)
var found_night: Dictionary = {} # clue id -> night found
var deduction_done: bool = false
var ending_id: String = ""
var master_volume: float = 0.8
var mouse_look: bool = true
var has_run: bool = false

# command line flags for automated testing
var args: PackedStringArray = PackedStringArray()


func _ready() -> void:
	args = OS.get_cmdline_user_args()
	for a in ["--autoshot", "--flowtest", "--simtest", "--cluetest", "--showcase", "--audiotest"]:
		if args.has(a):
			# automated tests never touch the player's real save
			SAVE_PATH = "user://greyfang_test_save.json"
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_setup_input()
	load_game()
	_apply_volume()


func _setup_input() -> void:
	var map := {
		"door_left": [KEY_Q],
		"door_right": [KEY_E],
		"light_left": [KEY_A],
		"light_right": [KEY_D],
		"monitor": [KEY_SPACE, KEY_S],
		"journal": [KEY_J, KEY_TAB],
		"look_left": [KEY_LEFT],
		"look_right": [KEY_RIGHT],
		"pause": [KEY_ESCAPE],
		"cam_prev": [KEY_LEFT],
		"cam_next": [KEY_RIGHT],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func new_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		seed_value = r.randi_range(100000, 999999)
	run_seed = seed_value
	night = 1
	max_night_reached = 1
	found = []
	found_night = {}
	deduction_done = false
	ending_id = ""
	has_run = true
	save_game()


func add_clue(id: String, n: int) -> bool:
	if found.has(id):
		return false
	found.append(id)
	found_night[id] = n
	save_game()
	return true


func complete_night(n: int) -> void:
	if n >= night:
		night = min(n + 1, 6)
	max_night_reached = max(max_night_reached, min(n + 1, 6))
	save_game()


func save_game() -> void:
	var d := {
		"run_seed": run_seed, "night": night, "max_night_reached": max_night_reached,
		"found": found, "found_night": found_night, "deduction_done": deduction_done,
		"ending_id": ending_id, "master_volume": master_volume, "has_run": has_run,
		"mouse_look": mouse_look,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	run_seed = int(d.get("run_seed", 0))
	night = int(d.get("night", 1))
	max_night_reached = int(d.get("max_night_reached", 1))
	found = d.get("found", [])
	found_night = d.get("found_night", {})
	deduction_done = bool(d.get("deduction_done", false))
	ending_id = str(d.get("ending_id", ""))
	master_volume = float(d.get("master_volume", 0.8))
	has_run = bool(d.get("has_run", false))
	mouse_look = bool(d.get("mouse_look", true))


func set_volume(v: float) -> void:
	master_volume = clamp(v, 0.0, 1.0)
	_apply_volume()
	save_game()


func _apply_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(master_volume, 0.0001)))


func has_arg(a: String) -> bool:
	return args.has(a)


func arg_value(prefix: String, default_value: String = "") -> String:
	for a in args:
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return default_value
