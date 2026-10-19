class_name NightController
extends Node
## One night of survival: time, power, doors, lights, cameras, animatronic AI,
## Golden Grayson events, evidence objects, power-out and jumpscares.

signal died(who: String)
signal won()
signal clue_collected(id: String)

const HOUR_LEN := 75.0
## AI levels (0-20) per night: grayson, benny, brutus, rook
const LEVELS := {
	1: {"grayson": 0, "benny": 3, "brutus": 2, "rook": 1},
	2: {"grayson": 2, "benny": 5, "brutus": 4, "rook": 3},
	3: {"grayson": 4, "benny": 8, "brutus": 7, "rook": 6},
	4: {"grayson": 6, "benny": 11, "brutus": 10, "rook": 9},
	5: {"grayson": 8, "benny": 12, "brutus": 12, "rook": 10},
}
const INTERVAL := {"grayson": 3.1, "benny": 4.6, "brutus": 4.9, "rook": 5.0}
const BENNY_GRAPH := {
	"stage": [["dining", 1.0], ["backstage", 0.6]],
	"dining": [["backstage", 0.5], ["supply", 0.6], ["whall", 0.8]],
	"backstage": [["dining", 0.5], ["whall", 0.7]],
	"supply": [["whall", 0.8], ["wcorner", 0.7]],
	"whall": [["wcorner", 1.0], ["supply", 0.4]],
	"wcorner": [["ldoor", 1.3], ["supply", 0.25], ["whall", 0.25]],
}
const BRUTUS_GRAPH := {
	"stage": [["dining", 1.0]],
	"dining": [["kitchen", 1.0], ["restroom", 0.6]],
	"kitchen": [["restroom", 0.5], ["ehall", 0.8], ["dining", 0.3]],
	"restroom": [["kitchen", 0.6], ["ehall", 0.7]],
	"ehall": [["ecorner", 0.9], ["rdoor", 0.25], ["kitchen", 0.3]],
	"ecorner": [["rdoor", 1.2], ["ehall", 0.3]],
}
const GRAYSON_PATH := ["stage", "dining", "restroom", "kitchen", "ehall", "ecorner"]

var world: WorldBuilder
var chars: Dictionary = {}
var hud = null
var night: int = 1
var active: bool = false
var sim: bool = false          # headless simulation (no audio/visual polish)
var hour_len: float = HOUR_LEN
var time_s: float = 0.0
var hour: int = 0
var power: float = 100.0
var doors := {"left": false, "right": false}
var door_anim := {"left": 0.0, "right": 0.0}
var light_on := {"left": false, "right": false}
var monitor_up: bool = false
var cur_cam: String = "1A"
var cam_glitch: float = 0.0
var watch_time: float = 0.0
var yaw: float = 0.0
var power_out: bool = false
var po_phase: int = 0
var po_timer: float = 0.0
var dying: bool = false
var dying_who: String = ""
var js_t: float = 0.0
var ai: Dictionary = {}
var rng := RandomNumberGenerator.new()
var clue_plan: Array = []
var clue_nodes: Dictionary = {}
var found_tonight: Array = []
var golden_events: Array = []
var golden_state: String = "none"   # none, cam, office, anomaly
var golden_timer: float = 0.0
var golden_seen: float = 0.0
var golden_armed: bool = false
var golden_event: Dictionary = {}
var rook_bangs: int = 0
var ambient_timer: float = 6.0
var kitchen_timer: float = 5.0
var stage_music: AudioStreamPlayer3D
var light_player: AudioStreamPlayer
var hovered_clue: String = ""
var hover_golden: bool = false
var cause_stats: Dictionary = {}
var po_face_light: OmniLight3D
var js_light: OmniLight3D
var js_screamed: bool = false
var shake: float = 0.0
var _flick_t: float = 0.0


func setup(w: WorldBuilder, c: Dictionary, h) -> void:
	world = w
	chars = c
	hud = h
	po_face_light = OmniLight3D.new()
	po_face_light.light_color = Color(0.9, 0.85, 0.7)
	po_face_light.omni_range = 2.0
	po_face_light.light_energy = 0.0
	world.root.add_child(po_face_light)
	js_light = OmniLight3D.new()
	js_light.omni_range = 3.0
	js_light.light_energy = 0.0
	js_light.shadow_enabled = false
	world.root.add_child(js_light)
	stage_music = AudioStreamPlayer3D.new()
	stage_music.stream = Sfx.streams.get("stage_music")
	stage_music.unit_size = 6.0
	stage_music.volume_db = -14.0
	stage_music.pitch_scale = 0.94
	world.root.add_child(stage_music)
	stage_music.position = Vector3(0, 2.0, -21)


# ================================================================ lifecycle
func start(n: int, run_seed: int) -> void:
	night = n
	active = true
	dying = false
	power_out = false
	po_phase = 0
	time_s = 0.0
	hour = 0
	power = 100.0
	doors = {"left": false, "right": false}
	door_anim = {"left": 0.0, "right": 0.0}
	light_on = {"left": false, "right": false}
	monitor_up = false
	cur_cam = "1A"
	yaw = 0.0
	rook_bangs = 0
	found_tonight = []
	golden_state = "none"
	golden_armed = false
	shake = 0.0
	rng.seed = hash("rt:%d:%d:%d" % [run_seed, n, Time.get_ticks_usec()])
	if GameState.has_arg("--fixed-rt"):
		rng.seed = hash("rt:%d:%d" % [run_seed, n])
	_init_ai()
	for k in chars.keys():
		chars[k].visible = k != "golden"
		chars[k].set_eye_glow(0.6)
	_place_all()
	_update_cove_visual(true)
	# evidence
	for id in clue_nodes.keys():
		if is_instance_valid(clue_nodes[id]):
			clue_nodes[id].queue_free()
	clue_nodes.clear()
	clue_plan = ClueSystem.plan(run_seed, n, GameState.found, world.clue_spots)
	for e in clue_plan:
		e["spawned"] = false
	golden_events = ClueSystem.golden_schedule(n, GameState.found, rng)
	for e in golden_events:
		e["done"] = false
	# doors/lights visuals
	for s in ["left", "right"]:
		_door_visual(s)
		world.office["light_" + s].light_energy = 0.0
	if not sim:
		world.office.cam.current = true
		Sfx.loop("amb_hum", -16.0)
		Sfx.loop("amb_fan", -20.0)
		Sfx.loop("amb_drone", -15.0)
		Sfx.loop("amb_vent", -26.0)
		if stage_music.stream:
			stage_music.play()
	for L in world.lights:
		if L.light and L.mode != "manual":
			L.light.visible = true


func stop() -> void:
	active = false
	if not sim:
		Sfx.stop_all()
		stage_music.stop()
	po_face_light.light_energy = 0.0


func _init_ai() -> void:
	ai = {}
	var lv: Dictionary = LEVELS[night]
	for who in ["grayson", "benny", "brutus", "rook"]:
		ai[who] = {"loc": "stage", "level": lv[who], "timer": INTERVAL[who] * rng.randf_range(0.8, 1.6), "door_t": 0.0, "blocked": 0.0, "left_stage": false}
	ai.rook.loc = "cove"
	ai.rook["stage"] = 0
	ai.rook["state"] = "cove"   # cove, out, run
	ai.rook["wait"] = 0.0
	ai.rook["lock"] = 0.0
	ai.rook["run_d"] = 0.0
	ai.grayson["inside"] = false


func _apply_hour_bonus() -> void:
	# difficulty ramps through the night
	if hour == 2:
		ai.benny.level += 1
	if hour == 3:
		ai.brutus.level += 1
		ai.rook.level += 1
		if ai.grayson.level == 0:
			ai.grayson.level = 1
	if hour == 4:
		for w in ["benny", "brutus", "rook", "grayson"]:
			ai[w].level += 1


# ================================================================ main loop
func _process(delta: float) -> void:
	if not active:
		return
	step(delta)


func step(delta: float) -> void:
	if dying:
		_jumpscare_update(delta)
		return
	time_s += delta
	var new_hour := int(time_s / hour_len)
	if new_hour != hour:
		hour = new_hour
		if hour >= 6:
			_win()
			return
		_apply_hour_bonus()
	_power_update(delta)
	if not power_out:
		_ai_update(delta)
		_rook_update(delta)
		_golden_update(delta)
	else:
		_power_out_update(delta)
	_doors_update(delta)
	_clues_update()
	if sim:
		return
	_visual_update(delta)
	_ambient_update(delta)


func hours_f() -> float:
	return time_s / hour_len


func clock_text() -> String:
	var total_min := int(time_s / hour_len * 60.0)
	return "%02d:%02d" % [min(int(total_min / 60.0), 6), total_min % 60 if total_min < 360 else 0]


func usage() -> int:
	if power_out:
		return 0
	var u := 1
	if monitor_up: u += 1
	if doors.left: u += 1
	if doors.right: u += 1
	if light_on.left: u += 1
	if light_on.right: u += 1
	return u


func _power_update(delta: float) -> void:
	if power_out:
		return
	var rate := 0.068 * (1.0 + 0.035 * (night - 1))
	power -= rate * usage() * delta
	if power <= 0.0:
		power = 0.0
		_start_power_out()


# ================================================================ controls
func toggle_door(side: String) -> void:
	if power_out or dying or not active:
		return
	doors[side] = not doors[side]
	if not sim:
		Sfx.play_at("door_close" if doors[side] else "door_open", world.root, Vector3(3.5 if side == "right" else -3.5, 1.5, 15.6), -2.0)


func toggle_light(side: String) -> void:
	if power_out or dying or not active:
		return
	light_on[side] = not light_on[side]
	var other := "right" if side == "left" else "left"
	if light_on[side]:
		light_on[other] = false
		var who := _at_door(side)
		if who != "" and not sim:
			Sfx.play("thump", -2.0, 0.9)
			Sfx.play("static", -24.0, 1.0)


func set_monitor(up: bool) -> void:
	if power_out or dying or not active:
		return
	if up == monitor_up:
		return
	monitor_up = up
	watch_time = 0.0
	if sim:
		_on_monitor_change()
		return
	Sfx.play("cam_up" if up else "cam_down", -10.0)
	if up:
		world.cams[cur_cam].node.current = true
		cam_glitch = 0.4
	else:
		world.office.cam.current = true
	_on_monitor_change()


func _on_monitor_change() -> void:
	if not monitor_up:
		# Grayson waits inside the office for the tablet to come down
		if ai.grayson.get("inside", false):
			_count("attack_grayson_inside")
			_jumpscare("grayson", 0.35)
			return
		if golden_state == "cam" and golden_armed:
			_golden_to_office()
		ai.rook.lock = rng.randf_range(0.8, max(1.0, 16.0 - ai.rook.level * 0.8))
	else:
		if golden_state == "office":
			_golden_vanish(true)


func select_cam(id: String) -> void:
	if not world.cams.has(id) or dying:
		return
	if id == cur_cam:
		return
	cur_cam = id
	watch_time = 0.0
	cam_glitch = 0.35
	if not sim:
		Sfx.play("cam_switch", -12.0)
		if monitor_up:
			world.cams[id].node.current = true


func cycle_cam(dir: int) -> void:
	var order := ["1A", "1B", "1C", "5", "7", "6", "3", "2A", "2B", "4A", "4B"]
	var i := order.find(cur_cam)
	select_cam(order[(i + dir + order.size()) % order.size()])


func set_look(y: float) -> void:
	yaw = clamp(y, -1.15, 1.15)


# ================================================================ AI
func _roll(level: int) -> bool:
	return rng.randi_range(1, 20) <= level


func is_watched(loc: String) -> bool:
	return monitor_up and world.LOC_CAM.get(loc, "") == cur_cam


func _at_door(side: String) -> String:
	var dloc := "ldoor" if side == "left" else "rdoor"
	for w in ["benny", "brutus", "grayson"]:
		if ai[w].loc == dloc:
			return w
	return ""


func _ai_update(delta: float) -> void:
	for who in ["benny", "brutus", "grayson"]:
		var a: Dictionary = ai[who]
		# door standoff: real-time patience
		if a.loc == "ldoor" or a.loc == "rdoor":
			var side := "left" if a.loc == "ldoor" else "right"
			if doors[side]:
				a.blocked += delta
				if a.blocked > 1.2 + rng.randf() * 0.5:
					var back: Array = ["dining", "supply", "backstage"] if side == "left" else ["dining", "kitchen", "restroom"]
					if who == "grayson":
						back = ["ehall"]
					_move(who, back[rng.randi_range(0, back.size() - 1)])
					_count("blocked_" + who)
			else:
				a.door_t -= delta
				if a.door_t <= 0.0:
					_count("attack_" + who)
					_jumpscare(who, 0.0)
					return
			continue
		a.timer -= delta
		if a.timer > 0.0:
			continue
		a.timer = INTERVAL[who] * (rng.randf_range(0.5, 1.5) if who == "brutus" else rng.randf_range(0.85, 1.15))
		if who == "grayson":
			_grayson_tick(a)
			continue
		if not _roll(a.level):
			continue
		var graph: Dictionary = BENNY_GRAPH if who == "benny" else BRUTUS_GRAPH
		if not graph.has(a.loc):
			continue
		var opts: Array = graph[a.loc]
		_move(who, _weighted(opts))


func _weighted(opts: Array) -> String:
	var total := 0.0
	for o in opts:
		total += o[1]
	var r := rng.randf() * total
	for o in opts:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return opts[opts.size() - 1][0]


func _grayson_tick(a: Dictionary) -> void:
	if a.get("inside", false):
		return
	# the leader waits until the band leaves the stage (or the night gets late)
	if a.loc == "stage" and (ai.benny.loc == "stage" or ai.brutus.loc == "stage") and hour < 3:
		return
	if is_watched(a.loc):
		return   # freezes while being watched
	if a.loc == "ecorner" and doors.right:
		_move("grayson", "ehall")   # a closed door always turns him back
		return
	if not _roll(a.level):
		return
	if a.loc == "ecorner":
		if monitor_up and cur_cam != "4B":
			_move("grayson", "office")
			a.inside = true
		else:
			_laugh(world.spot_for("ecorner", "grayson")[0])
		return
	var i := GRAYSON_PATH.find(a.loc)
	if i >= 0 and i < GRAYSON_PATH.size() - 1:
		_move("grayson", GRAYSON_PATH[i + 1])
		_laugh(world.spot_for(GRAYSON_PATH[i + 1], "grayson")[0])


func _move(who: String, loc: String) -> void:
	var a: Dictionary = ai[who]
	var from: String = a.loc
	# a watched camera glitches when something leaves / enters its view
	if monitor_up and (world.LOC_CAM.get(from, "") == cur_cam or world.LOC_CAM.get(loc, "") == cur_cam):
		cam_glitch = 1.6
		if not sim:
			Sfx.play("static", -20.0)
	a.loc = loc
	a.blocked = 0.0
	if from == "stage":
		a.left_stage = true
	if loc == "ldoor" or loc == "rdoor":
		var base: float = lerp(11.0, 6.0, (night - 1) / 4.0)
		a.door_t = base + rng.randf_range(-1.0, 1.5)
	if loc != "office":
		a.inside = false
	_place(who)
	if sim:
		return
	var pos: Vector3 = world.spot_for(loc, who)[0]
	var snd: String = {"benny": "step_metal", "brutus": "step_hoof", "grayson": "step_heavy", "rook": "step_metal"}[who]
	var vol := -4.0 if (loc == "ldoor" or loc == "rdoor" or loc.ends_with("corner")) else -2.0
	Sfx.play_at(snd, world.root, pos + Vector3(0, 0.3, 0), vol, rng.randf_range(0.85, 1.1))
	if who == "brutus" and (loc == "kitchen" or loc == "dining"):
		Sfx.play_at("tray", world.root, pos + Vector3(0, 1, 0), -6.0, rng.randf_range(0.9, 1.1))


func _laugh(pos: Vector3) -> void:
	if not sim:
		Sfx.play_at("laugh_grayson", world.root, pos + Vector3(0, 2, 0), 2.0, rng.randf_range(0.9, 1.05), 60.0)


func _place(who: String) -> void:
	var a: Dictionary = ai[who]
	var m: Animatronic = chars[who]
	var sp: Array = world.spot_for(a.loc, who)
	m.place(sp[0], sp[1])
	m.anim = "idle"
	match a.loc:
		"stage":
			m.set_pose("perform")
			m.anim = "strum" if who == "benny" else ("sing" if who == "grayson" else "idle")
		"ldoor", "rdoor":
			m.set_pose("door")
			m.anim = "twitchy"
		"office":
			m.set_pose("lurk")
		_:
			m.set_pose("lurk")
			if rng.randf() < 0.3:
				m.anim = "twitchy"
	m.visible = a.loc != "office"


func _place_all() -> void:
	for w in ["grayson", "benny", "brutus"]:
		_place(w)
	_place_rook()
	chars.golden.visible = false
	chars.golden.global_position = Vector3(0, -40, 0)


# ---------------------------------------------------------------- Captain Rook
func _place_rook() -> void:
	var m: Animatronic = chars.rook
	var r: Dictionary = ai.rook
	m.visible = true
	match r.state:
		"cove":
			match int(r.stage):
				0:
					m.place(Vector3(-12.6, 0.4, -9.0), 90.0)
					m.set_pose("stand")
				1:
					m.place(Vector3(-10.9, 0.4, -9.2), 90.0)
					m.set_pose("peek")
				2:
					m.place(Vector3(-10.5, 0.4, -9.0), 90.0)
					m.set_pose("ready")
			m.anim = "idle"
		"out":
			m.place(Vector3(-9.0, 0.0, -8.4), 120.0)
			m.set_pose("ready")
			m.anim = "twitchy"
		"run":
			m.set_pose("run")
			m.anim = "run"


func _update_cove_visual(instant: bool = false) -> void:
	var st: int = int(ai.rook.stage)
	if ai.rook.state != "cove":
		st = 3
	var open_amt: float = [0.0, 0.35, 0.8, 1.0][st]
	world.curtain_l.set_meta("target", open_amt)
	if instant:
		_apply_curtain(open_amt)
	world.cove_sign.text = "KAPTAN ROOK'UN\nKORSAN KÖŞESİ" if st < 3 else "ÜZGÜNÜZ!\nŞU AN KAPALI"


func _apply_curtain(v: float) -> void:
	world.curtain_l.rotation_degrees.y = -v * 70.0
	world.curtain_r.rotation_degrees.y = v * 70.0
	world.curtain_l.set_meta("cur", v)


func _rook_update(delta: float) -> void:
	var r: Dictionary = ai.rook
	r.lock = max(0.0, r.lock - delta)
	match r.state:
		"cove":
			r.timer -= delta
			if r.timer <= 0.0:
				r.timer = INTERVAL.rook
				if not monitor_up and r.lock <= 0.0 and _roll(r.level):
					r.stage += 1
					if not sim:
						Sfx.play_at("curtain", world.root, Vector3(-10, 1.5, -9), -6.0)
					if r.stage >= 3:
						r.state = "out"
						r.wait = 0.0
					_place_rook()
					_update_cove_visual()
		"out":
			r.wait += delta
			# viewing the west hall (or waiting too long) sends him running
			if r.wait > 22.0 - night * 1.5 or (monitor_up and cur_cam == "2A" and r.wait > 0.8):
				r.state = "run"
				r.run_d = 0.0
				_place_rook()
				if not sim:
					Sfx.play_at("rook_run", world.root, Vector3(-4.75, 1.0, 8.0), 4.0, 1.0, 60.0)
					Sfx.play("scream_rook", -26.0, 1.6)
		"run":
			r.run_d += delta * 6.8
			var pts: Array = world.rook_path
			var total := 0.0
			var arrived := true
			for i in range(1, pts.size()):
				var seg: float = pts[i - 1].distance_to(pts[i])
				if r.run_d <= total + seg:
					var p: Vector3 = pts[i - 1].lerp(pts[i], (r.run_d - total) / seg)
					chars.rook.global_position = p
					chars.rook.face_point(pts[i] + (pts[i] - pts[i - 1]) * 0.01)
					arrived = false
					break
				total += seg
			if monitor_up and cur_cam == "2A" and chars.rook.global_position.z > 0.0 and chars.rook.global_position.z < 11.0:
				cam_glitch = max(cam_glitch, 0.3)
			if arrived:
				if doors.left:
					var drain := 1.0 + 3.0 * rook_bangs
					rook_bangs += 1
					power = max(0.0, power - drain)
					_count("rook_blocked")
					if not sim:
						Sfx.play_at("knock", world.root, Vector3(-3.6, 1.4, 15.6), 4.0)
					r.state = "cove"
					r.stage = rng.randi_range(0, 1)
					r.timer = INTERVAL.rook
					_place_rook()
					_update_cove_visual()
				else:
					_count("attack_rook")
					_jumpscare("rook", 0.0)


# ---------------------------------------------------------------- Golden Grayson
func _golden_update(delta: float) -> void:
	var hf := hours_f()
	if golden_state == "none":
		for e in golden_events:
			if e.done or hf < e.hour:
				continue
			e.done = true
			golden_event = e
			if e.kind == "anomaly":
				_golden_anomaly()
			else:
				golden_state = "cam"
				golden_timer = 60.0 if night == 5 else 34.0
				golden_seen = 0.0
				golden_armed = false
				var m: Animatronic = chars.golden
				var sp: Array = world.spot_for("golden_2b", "golden")
				m.place(sp[0], sp[1])
				m.set_pose("slump", true)
				m.anim = "still"
				m.visible = true
				m.set_eye_glow(2.5)
				if not sim:
					Sfx.play_at("golden_whisper", world.root, Vector3(-5, 1.5, 11), -8.0, 0.8)
			break
		return
	golden_timer -= delta
	match golden_state:
		"cam":
			if monitor_up and cur_cam == "2B":
				golden_seen += delta
				cam_glitch = max(cam_glitch, 0.12 + 0.1 * sin(time_s * 9.0))
				if golden_seen > 0.6:
					golden_armed = true
			if golden_timer <= 0.0 and not golden_armed:
				# missed it; on night 5 the memory comes back later (never lost to bad luck)
				if night == 5 and golden_event.kind == "memory" and hf < 5.4:
					golden_event.done = false
					golden_event.hour = hf + 0.35
				_golden_vanish(false)
		"office":
			if golden_timer <= 0.0:
				_count("attack_golden")
				_jumpscare("golden", 0.0)
		"anomaly":
			if golden_timer <= 0.0:
				_golden_vanish(false)


func _golden_anomaly() -> void:
	var m: Animatronic = chars.golden
	if rng.randf() < 0.55:
		var sp: Array = world.spot_for("golden_stage", "golden")
		m.place(sp[0], sp[1])
		m.set_pose("twisted", true)
		m.anim = "twitchy"
		m.visible = true
		golden_state = "anomaly"
		golden_timer = 8.0
	else:
		if hud and not sim:
			hud.hallucination(["11 DAKİKA", "KİMSE KAPATMADI", "KOŞ", "O BURADA DEĞİL", "SİL"][rng.randi_range(0, 4)])
			Sfx.play("golden_whisper", -6.0, 0.7)


func _golden_to_office() -> void:
	golden_state = "office"
	golden_timer = 2.6
	var m: Animatronic = chars.golden
	var sp: Array = world.spot_for("office", "golden")
	m.place(sp[0], sp[1])
	m.set_pose("slump", true)
	m.anim = "still"
	m.visible = true
	m.set_eye_glow(4.0)
	js_light.global_position = sp[0] + Vector3(0, 1.6, 1.2)
	js_light.light_color = Color(1.0, 0.8, 0.4)
	js_light.light_energy = 0.7
	if not sim:
		Sfx.play("golden_whisper", 0.0, 0.6)
		Sfx.play("thump", 0.0, 0.7)
		if hud:
			hud.flash(Color(0.3, 0.25, 0.0, 0.35), 0.5)


func _golden_vanish(survived: bool) -> void:
	golden_state = "none"
	golden_armed = false
	chars.golden.visible = false
	chars.golden.global_position = Vector3(0, -40, 0)
	if js_light:
		js_light.light_energy = 0.0
	chars.golden.set_eye_glow(0.6)
	if survived:
		_count("golden_survived")
		if not sim:
			Sfx.play("static", -18.0)


func try_pick_golden() -> bool:
	if golden_state != "cam" or not monitor_up or cur_cam != "2B":
		return false
	golden_armed = true
	var mem: String = golden_event.get("memory", "")
	if mem != "" and not GameState.found.has(mem):
		_collect(mem)
		if not sim:
			Sfx.play("scream_golden", -18.0, 0.6)
	return true


# ================================================================ doors, power out
func _doors_update(delta: float) -> void:
	for s in ["left", "right"]:
		var tgt := 1.0 if doors[s] else 0.0
		door_anim[s] = move_toward(door_anim[s], tgt, delta * 3.2)
		if not sim:
			_door_visual(s)


func _door_visual(s: String) -> void:
	var d: Node3D = world.office["door_" + s]
	d.position.y = lerp(3.75, 1.2, door_anim[s])


func _start_power_out() -> void:
	power_out = true
	po_phase = 0
	po_timer = rng.randf_range(4.0, 9.0)
	doors.left = false
	doors.right = false
	light_on.left = false
	light_on.right = false
	if monitor_up:
		monitor_up = false
		if not sim:
			world.office.cam.current = true
			Sfx.play("cam_down", -6.0)
	golden_state = "none"
	chars.golden.visible = false
	if not sim:
		Sfx.play("power_down", 0.0)
		Sfx.stop_loop("amb_hum")
		Sfx.stop_loop("amb_fan")
		Sfx.stop_loop("light_buzz")
		stage_music.stop()
		for L in world.lights:
			if L.light:
				L.light.visible = false
			if L.mat:
				L.mat.emission_energy_multiplier = 0.0
	_count("power_out")


func _power_out_update(delta: float) -> void:
	po_timer -= delta
	match po_phase:
		0:
			if po_timer <= 0.0:
				po_phase = 1
				po_timer = rng.randf_range(6.0, 16.0)
				ai.grayson.loc = "ldoor"
				var m: Animatronic = chars.grayson
				var sp: Array = world.spot_for("ldoor", "grayson")
				m.place(sp[0], sp[1])
				m.set_pose("powerout")
				m.anim = "sing"
				m.visible = true
				m.set_eye_glow(4.0)
				if not sim:
					Sfx.loop("musicbox", -4.0)
		1:
			if not sim:
				po_face_light.global_position = chars.grayson.global_position + Vector3(0.9, 2.2, 0.0)
				po_face_light.omni_range = 3.0
				po_face_light.light_energy = 2.6 if fmod(time_s * 2.7, 1.0) < 0.7 and rng.randf() > 0.06 else 0.0
			if po_timer <= 0.0:
				po_phase = 2
				po_timer = rng.randf_range(1.5, 4.0)
				po_face_light.light_energy = 0.0
				chars.grayson.set_eye_glow(0.0)
				if not sim:
					Sfx.stop_loop("musicbox")
		2:
			if po_timer <= 0.0:
				_count("attack_powerout")
				_jumpscare("grayson", 0.0)


# ================================================================ evidence
func _clues_update() -> void:
	var hf := hours_f()
	for e in clue_plan:
		if e.spawned or hf < e.reveal_hour:
			continue
		e.spawned = true
		if GameState.found.has(e.id):
			continue
		_spawn_clue(e)


func _spawn_clue(e: Dictionary) -> void:
	var c: Dictionary = StoryData.clue(e.id)
	var s: Dictionary = e.spot
	var n := Node3D.new()
	n.name = "Clue_" + e.id
	world.root.add_child(n)
	n.global_position = s.pos
	n.rotation_degrees.y = s.yaw
	var glint := Mats.unique_emissive(Color(1.0, 0.95, 0.75), 0.25)
	n.set_meta("glint", glint)
	var size := Vector3(0.5, 0.4, 0.5)
	if s.kind == "wall":
		if c.type == "env" and c.has("label"):
			var l := Label3D.new()
			l.text = c.label
			l.font_size = 64
			l.pixel_size = 0.004
			l.modulate = Color(0.25, 0.08, 0.06)
			l.shaded = true
			n.add_child(l)
			l.position = Vector3(0, 0, 0.02)
			var under := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.9, 0.6)
			under.mesh = q
			under.material_override = glint
			glint.albedo_color = Color(0.3, 0.28, 0.25)
			glint.emission_energy_multiplier = 0.08
			under.position = Vector3(0, 0, 0.01)
			n.add_child(under)
		else:
			var paper := MeshInstance3D.new()
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.42, 0.56)
			paper.mesh = q2
			paper.material_override = glint
			glint.albedo_color = Color(0.92, 0.9, 0.82)
			paper.position = Vector3(0, 0, 0.012)
			paper.rotation_degrees.z = rng.randf_range(-8, 8)
			n.add_child(paper)
			var pin := MeshInstance3D.new()
			var ps := SphereMesh.new()
			ps.radius = 0.02
			ps.height = 0.04
			pin.mesh = ps
			pin.material_override = Mats.color(Color(0.8, 0.1, 0.1))
			pin.position = Vector3(0, 0.24, 0.03)
			n.add_child(pin)
		size = Vector3(0.9, 0.7, 0.3)
	else:
		match c.type:
			"doc":
				for k in 3:
					var b := MeshInstance3D.new()
					var bm := BoxMesh.new()
					bm.size = Vector3(0.3, 0.004, 0.42)
					b.mesh = bm
					b.material_override = glint if k == 2 else Mats.color(Color(0.85, 0.82, 0.72), 0.9)
					glint.albedo_color = Color(0.93, 0.9, 0.8)
					b.position = Vector3(k * 0.015, 0.004 + k * 0.004, k * 0.01)
					b.rotation_degrees.y = k * 7.0
					n.add_child(b)
				var folder := MeshInstance3D.new()
				var fm := BoxMesh.new()
				fm.size = Vector3(0.34, 0.006, 0.46)
				folder.mesh = fm
				folder.material_override = Mats.color(Color(0.75, 0.55, 0.2), 0.8)
				folder.position = Vector3(-0.04, 0.0, 0.0)
				folder.rotation_degrees.y = -12.0
				n.add_child(folder)
			"tape":
				var body := MeshInstance3D.new()
				var tb := BoxMesh.new()
				tb.size = Vector3(0.24, 0.07, 0.15)
				body.mesh = tb
				body.material_override = Mats.color(Color(0.08, 0.08, 0.08), 0.5)
				body.position = Vector3(0, 0.035, 0)
				n.add_child(body)
				var lab := MeshInstance3D.new()
				var lb := BoxMesh.new()
				lb.size = Vector3(0.16, 0.005, 0.08)
				lab.mesh = lb
				lab.material_override = glint
				glint.albedo_color = Color(0.9, 0.85, 0.6)
				lab.position = Vector3(0, 0.072, 0)
				n.add_child(lab)
				var led := MeshInstance3D.new()
				var ls := SphereMesh.new()
				ls.radius = 0.012
				ls.height = 0.024
				led.mesh = ls
				led.material_override = Mats.unique_emissive(Color(1, 0.1, 0.05), 2.0)
				led.position = Vector3(0.09, 0.07, 0.05)
				n.add_child(led)
			"footage":
				var vhs := MeshInstance3D.new()
				var vb := BoxMesh.new()
				vb.size = Vector3(0.2, 0.03, 0.12)
				vhs.mesh = vb
				vhs.material_override = Mats.color(Color(0.05, 0.05, 0.05), 0.4)
				vhs.position = Vector3(0, 0.015, 0)
				n.add_child(vhs)
				var vl := MeshInstance3D.new()
				var vlb := BoxMesh.new()
				vlb.size = Vector3(0.14, 0.004, 0.07)
				vl.mesh = vlb
				vl.material_override = glint
				glint.albedo_color = Color(0.95, 0.95, 0.95)
				vl.position = Vector3(0, 0.032, 0)
				n.add_child(vl)
			"syslog":
				var lap := MeshInstance3D.new()
				var lbm := BoxMesh.new()
				lbm.size = Vector3(0.36, 0.03, 0.26)
				lap.mesh = lbm
				lap.material_override = Mats.color(Color(0.2, 0.2, 0.22), 0.5)
				lap.position = Vector3(0, 0.015, 0)
				n.add_child(lap)
				var scr := MeshInstance3D.new()
				var sbm := BoxMesh.new()
				sbm.size = Vector3(0.34, 0.24, 0.015)
				scr.mesh = sbm
				scr.material_override = glint
				glint.albedo_color = Color(0.2, 0.9, 0.35)
				glint.emission = Color(0.2, 0.9, 0.35)
				glint.emission_energy_multiplier = 1.2
				scr.position = Vector3(0, 0.14, -0.13)
				scr.rotation_degrees.x = -15.0
				n.add_child(scr)
			"env":
				# small physical trace (name tag / module)
				var tag := MeshInstance3D.new()
				var tgm := BoxMesh.new()
				tgm.size = Vector3(0.14, 0.01, 0.09)
				tag.mesh = tgm
				tag.material_override = glint
				glint.albedo_color = Color(0.85, 0.8, 0.7)
				tag.position = Vector3(0, 0.006, 0)
				n.add_child(tag)
				var cable := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.006
				cm.bottom_radius = 0.006
				cm.height = 0.35
				cable.mesh = cm
				cable.material_override = Mats.color(Color(0.1, 0.1, 0.1))
				cable.position = Vector3(0.12, 0.006, 0.05)
				cable.rotation_degrees = Vector3(90, 40, 0)
				n.add_child(cable)
	var a := Area3D.new()
	a.collision_layer = 2
	a.collision_mask = 0
	a.set_meta("clue", e.id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.3, 0)
	a.add_child(cs)
	n.add_child(a)
	n.set_meta("cam", s.cam)
	clue_nodes[e.id] = n


func clue_cam_counts() -> Dictionary:
	var d := {}
	for id in clue_nodes.keys():
		if is_instance_valid(clue_nodes[id]):
			d[clue_nodes[id].get_meta("cam")] = true
	return d


func try_pick_clue(id: String) -> bool:
	if not clue_nodes.has(id) or not is_instance_valid(clue_nodes[id]):
		return false
	if clue_nodes[id].get_meta("cam") != cur_cam:
		return false
	_collect(id)
	clue_nodes[id].queue_free()
	clue_nodes.erase(id)
	return true


func _collect(id: String) -> void:
	if GameState.add_clue(id, night):
		found_tonight.append(id)
		clue_collected.emit(id)
		if not sim:
			Sfx.play("clue_found", -4.0)


func remaining_clues_tonight() -> int:
	var n := 0
	for e in clue_plan:
		if not GameState.found.has(e.id):
			n += 1
	return n


# ================================================================ visuals & ambience
func _visual_update(delta: float) -> void:
	_flick_t += delta
	var head: Node3D = world.office.head
	head.rotation.y = lerp_angle(head.rotation.y, yaw, 1.0 - exp(-8.0 * delta))
	if shake > 0.0:
		shake = max(0.0, shake - delta * 2.0)
		world.office.cam.rotation_degrees.z = rng.randf_range(-1, 1) * shake * 3.0
	else:
		world.office.cam.rotation_degrees.z = 0.0
	if world.fan_blades:
		world.fan_blades.rotation.z += delta * (18.0 if not power_out else max(0.0, 6.0 - po_timer))
	# security camera pan
	if monitor_up:
		watch_time += delta
		var cd: Dictionary = world.cams[cur_cam]
		var c: Camera3D = cd.node
		c.rotation.y = cd.yaw0 + sin(time_s * 0.35) * cd.pan
	cam_glitch = max(0.0, cam_glitch - delta)
	# curtain animation
	var cur: float = world.curtain_l.get_meta("cur", 0.0)
	var tgt: float = world.curtain_l.get_meta("target", 0.0)
	if abs(cur - tgt) > 0.001:
		_apply_curtain(move_toward(cur, tgt, delta * 1.5))
	# door lights
	for s in ["left", "right"]:
		var L: SpotLight3D = world.office["light_" + s]
		var on: bool = light_on[s] and not power_out
		L.light_energy = (2.4 + (rng.randf() * 0.6 if rng.randf() < 0.1 else 0.0)) if on else 0.0
		var bm: StandardMaterial3D = world.office["btn_mat_light_" + s]
		bm.emission_energy_multiplier = 2.5 if on else 0.15
		var dm: StandardMaterial3D = world.office["btn_mat_door_" + s]
		dm.emission_energy_multiplier = 2.5 if doors[s] and not power_out else 0.25
	if light_on.left or light_on.right:
		Sfx.loop("light_buzz", -12.0)
	else:
		Sfx.stop_loop("light_buzz")
	# characters look at whoever is watching them
	for w in ["grayson", "benny", "brutus", "rook"]:
		var m: Animatronic = chars[w]
		var loc: String = ai[w].loc
		if is_watched(loc) and ai[w].get("state", "") != "run":
			m.look_target = world.cams[cur_cam].pos
			m.look_weight = move_toward(m.look_weight, 1.0, delta * 0.5)
			m.set_eye_glow(1.2)
		elif loc == "ldoor" or loc == "rdoor":
			m.look_target = world.office.head.global_position
			m.look_weight = 1.0
			m.set_eye_glow(1.6)
		else:
			m.look_weight = move_toward(m.look_weight, 0.0, delta * 0.3)
	if not power_out:
		_flicker_lights(delta)


func _flicker_lights(_delta: float) -> void:
	for L in world.lights:
		if L.mode == "manual":
			continue
		var e: float = L.energy
		var f := 1.0
		var ph: float = L.phase + _flick_t
		match L.mode:
			"flicker":
				var n := sin(ph * 13.0) * sin(ph * 7.3) * sin(ph * 2.1)
				f = 0.0 if n > 0.55 else (0.55 + 0.45 * sin(ph * 40.0) if n > 0.4 else 1.0)
			"strobe":
				f = 1.0 if fmod(ph * 1.7, 1.0) < 0.08 or (fmod(ph * 0.37, 1.0) < 0.05) else 0.05
			"buzz":
				f = 0.9 + 0.1 * sin(ph * 60.0)
			"office_lamp":
				var n2 := sin(ph * 3.1) * sin(ph * 1.7) * sin(ph * 0.9)
				f = 0.15 if n2 > 0.7 else 1.0
			_:
				f = 1.0
		if L.light:
			L.light.light_energy = e * f
		if L.mat:
			L.mat.emission_energy_multiplier = 2.0 * f


func _ambient_update(delta: float) -> void:
	ambient_timer -= delta
	if ambient_timer <= 0.0:
		ambient_timer = rng.randf_range(9.0, 22.0)
		var spots_amb := [Vector3(-15, 1.5, -20), Vector3(14, 1.5, -12), Vector3(15, 1.5, 0), Vector3(-9, 1.5, 6), Vector3(0, 3, -10)]
		Sfx.play_at("metal_distant", world.root, spots_amb[rng.randi_range(0, spots_amb.size() - 1)], -2.0, rng.randf_range(0.7, 1.2), 60.0)
	# Brutus is heard in the kitchen far more than seen
	if ai.brutus.loc == "kitchen" and not power_out:
		kitchen_timer -= delta
		if kitchen_timer <= 0.0:
			kitchen_timer = rng.randf_range(3.5, 8.0)
			var loud := monitor_up and cur_cam == "6"
			Sfx.play("pots" if rng.randf() < 0.6 else "tray", -4.0 if loud else -20.0, rng.randf_range(0.85, 1.15))
	stage_music.volume_db = -10.0 if monitor_up and cur_cam == "1A" else -24.0


# ================================================================ win / death
func _win() -> void:
	active = false
	if not sim:
		Sfx.stop_all()
		stage_music.stop()
		Sfx.play("chime6", 0.0)
	won.emit()


func _jumpscare(who: String, delay: float) -> void:
	if dying:
		return
	dying = true
	dying_who = who
	js_t = -delay
	js_screamed = false
	if sim:
		active = false
		died.emit(who)
		return
	golden_state = "none"
	chars.golden.visible = who == "golden"
	if monitor_up:
		monitor_up = false
		world.office.cam.current = true
		Sfx.play("cam_down", -4.0)
	world.office.cam.rotation_degrees.z = 0.0
	stage_music.stop()
	Sfx.stop_loop("musicbox")
	var m: Animatronic = chars[who]
	m.visible = true
	m.set_pose("jumpscare")
	m.anim = "jumpscare"
	m.set_eye_glow(5.0)
	m.look_weight = 0.0
	if who == "brutus":
		Sfx.play("tray", 2.0, 0.8)
	if who == "grayson":
		Sfx.play("power_down", -6.0, 1.4)


func _jumpscare_update(delta: float) -> void:
	js_t += delta
	if js_t < 0.0:
		return
	var who := dying_who
	var m: Animatronic = chars[who]
	var cam: Camera3D = world.office.cam
	var head: Node3D = world.office.head
	head.rotation.y = lerp_angle(head.rotation.y, 0.0, 1.0 - exp(-10.0 * delta))
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam.global_transform.basis.x
	var dist := 1.1
	var lateral := 0.0
	var dur := 1.5
	var light_e := 2.2
	match who:
		"grayson":
			# lights die, eyes in the dark, then a slow lean and a lunge
			if js_t < 0.7:
				dist = 2.6
				light_e = 0.0
				_set_office_dark(true)
			else:
				_set_office_dark(false)
				dist = lerp(2.2, 1.12, clamp((js_t - 0.7) / 0.18, 0.0, 1.0))
				light_e = 2.6 if rng.randf() > 0.15 else 0.3
			dur = 2.1
		"benny":
			dist = lerp(1.8, 1.0, clamp(js_t / 0.15, 0.0, 1.0))
			lateral = lerp(-0.6, 0.0, clamp(js_t / 0.15, 0.0, 1.0))
		"brutus":
			light_e = 1.3
			dist = lerp(1.7, 1.12, clamp(js_t / 0.12, 0.0, 1.0))
			lateral = 0.06 * sin(js_t * 30.0)
		"rook":
			dist = lerp(3.4, 1.15, clamp(js_t / 0.3, 0.0, 1.0))
			lateral = lerp(-1.6, 0.0, clamp(js_t / 0.3, 0.0, 1.0))
		"golden":
			dist = 0.95
			dur = 2.4
			light_e = 1.6 if rng.randf() > 0.3 else 0.0
	js_light.global_position = cam.global_position + fwd * 0.3 + Vector3(0, 0.35, 0)
	js_light.light_color = Color(1.0, 0.85, 0.7) if who != "golden" else Color(1.0, 0.8, 0.4)
	js_light.light_energy = light_e
	var target_head := cam.global_position + fwd * dist + right * lateral + Vector3(0, -0.05, 0)
	m.face_point(cam.global_position)
	var head_j: Node3D = m.joints.head
	var hpos := head_j.global_position + head_j.global_transform.basis.y * 0.22
	m.global_position += target_head - hpos
	# scream once: immediately, or after Grayson's 0.7 s blackout
	if not js_screamed and js_t >= (0.7 if who == "grayson" else 0.0):
		js_screamed = true
		Sfx.play("scream_" + who, 4.0)
		if who != "grayson":
			Sfx.play("scream_grayson", 3.0)   # Grayson's roar is layered under every jumpscare
		shake = 1.4
		if hud:
			hud.flash(Color(0.5, 0.0, 0.0, 0.35) if who != "golden" else Color(0.6, 0.5, 0.1, 0.5), 0.6)
			if who == "golden":
				hud.golden_face(true)
	if shake > 0.0:
		shake = max(0.0, shake - delta)
		cam.rotation_degrees.z = rng.randf_range(-3, 3) * shake
		cam.rotation_degrees.x = -6.0 + rng.randf_range(-2, 2) * shake
	if js_t > dur:
		cam.rotation_degrees = Vector3(-6, 0, 0)
		js_light.light_energy = 0.0
		_set_office_dark(false)
		active = false
		dying = false
		if hud:
			hud.golden_face(false)
		died.emit(who)


func _set_office_dark(dark: bool) -> void:
	for L in world.lights:
		if L.group == "office" and L.light:
			L.light.visible = not dark


func _count(k: String) -> void:
	cause_stats[k] = cause_stats.get(k, 0) + 1


# ================================================================ picking (mouse)
## returns {kind: "clue"/"golden"/"button", id}
func pick_at(screen_pos: Vector2) -> Dictionary:
	var cam: Camera3D = world.cams[cur_cam].node if monitor_up else world.office.cam
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 30.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 2 if monitor_up else 4)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.collider
	if col.has_meta("clue"):
		var id: String = col.get_meta("clue")
		if clue_nodes.has(id) and clue_nodes[id].get_meta("cam") == cur_cam:
			return {"kind": "clue", "id": id}
		return {}
	if col.has_meta("pick"):
		return {"kind": "golden", "id": "golden"}
	if col.has_meta("btn"):
		return {"kind": "button", "id": col.get_meta("btn")}
	return {}
