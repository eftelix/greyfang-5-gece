class_name Animatronic
extends Node3D
## Procedurally built, jointed animatronic model + pose/animation system.
## One instance per character; the AI moves this single instance between rooms,
## so every camera always shows the same, consistent body.
##
## Local space: character faces +Z, its left side is +X.

var kind: String = "grayson"
var joints: Dictionary = {}
var _cur: Dictionary = {}       # joint -> Vector3 (radians) current
var _target: Dictionary = {}    # joint -> Vector3 (radians) pose target
var pose_name: String = "stand"
var anim: String = "idle"       # idle, run, strum, jumpscare, servo, still, twitchy
var look_target = null          # Vector3 or null
var look_weight: float = 0.0
var root_offset_y: float = 0.0
var _root_y_target: float = 0.0
var _t: float = 0.0
var _twitch_timer: float = 2.0
var _twitch: Dictionary = {}
var _run_phase: float = 0.0
var pupils: Array = []           # emissive pupil materials
var body: Node3D
var speed: float = 6.0
var pick_area: Area3D
var tray: Node3D = null

const JOINT_NAMES := ["hips", "spine", "chest", "neck", "head", "jaw", "sh_l", "el_l", "sh_r", "el_r",
	"hip_l", "kn_l", "hip_r", "kn_r", "hand_l", "hand_r"]

var rng := RandomNumberGenerator.new()


func setup(k: String) -> void:
	kind = k
	name = k.capitalize()
	rng.seed = hash(k)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	match kind:
		"grayson":
			_build_wolf(false)
		"golden":
			_build_wolf(true)
		"benny":
			_build_rooster()
		"brutus":
			_build_boar()
		"rook":
			_build_crow()
	for j in JOINT_NAMES:
		if joints.has(j):
			_cur[j] = joints[j].rotation
			_target[j] = Vector3.ZERO
	set_pose("stand", true)


# ------------------------------------------------------------------ helpers
func _m(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _sph(r: float, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = max(6, int(segs * 0.5))
	return s


func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = max(h, r * 2.0 + 0.001)
	c.radial_segments = 14
	c.rings = 6
	return c


func _cyl(top: float, bot: float, h: float, segs: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _prism(sz: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = sz
	return p


func _joint(parent: Node3D, jname: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = jname
	n.position = pos
	parent.add_child(n)
	joints[jname] = n
	return n


func _pupil(parent: Node3D, pos: Vector3, r: float, c: Color = Color(1, 1, 0.95)) -> void:
	var m := Mats.unique_emissive(c, 0.6)
	pupils.append(m)
	_m(parent, _sph(r, 8), m, pos)


func set_eye_glow(e: float) -> void:
	for m in pupils:
		m.emission_energy_multiplier = e


# ------------------------------------------------------------------ skeleton
## Builds hips/torso/arms/legs. Returns nothing; joints dict is filled.
func _build_body(sp: Dictionary) -> void:
	var fur: Material = sp.fur
	var belly: Material = sp.get("belly", fur)
	var metal: Material = Mats.color(Color(0.16, 0.16, 0.17), 0.45, 0.8)
	var hips := _joint(body, "hips", Vector3(0, sp.hip_h, 0))
	# pelvis
	_m(hips, _sph(sp.pelvis_w), sp.get("pelvis_mat", fur), Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.0, 0.7, 0.85))
	var spine := _joint(hips, "spine", Vector3(0, 0.12, 0))
	var torso_h: float = sp.torso_h
	var trad: float = sp.torso_r
	_m(spine, _cap(trad, torso_h), fur, Vector3(0, torso_h * 0.42, 0), Vector3.ZERO, sp.get("torso_scale", Vector3(1.0, 1.0, 0.85)))
	if sp.has("belly"):
		_m(spine, _sph(trad * 0.82), belly, Vector3(0, torso_h * 0.36, trad * 0.5), Vector3.ZERO, Vector3(0.95, 1.35, 0.55))
	var chest := _joint(spine, "chest", Vector3(0, torso_h * 0.62, 0))
	# neck
	var neck := _joint(chest, "neck", Vector3(0, sp.get("neck_y", 0.26), sp.get("neck_z", 0.0)))
	_m(neck, _cyl(0.08, 0.1, 0.22), metal, Vector3(0, 0.08, 0))
	_m(neck, _cyl(0.13, 0.15, 0.08), fur, Vector3(0, -0.02, 0))
	_joint(neck, "head", Vector3(0, 0.16, 0))
	# arms
	for side in [1, -1]:
		var s: String = "l" if side == 1 else "r"
		var sh := _joint(chest, "sh_" + s, Vector3(side * sp.sh_x, sp.get("sh_y", 0.12), 0))
		_m(sh, _sph(sp.arm_r * 1.25), sp.get("shoulder_mat", fur), Vector3.ZERO)
		_m(sh, _cap(sp.arm_r, sp.upper), sp.get("arm_mat", fur), Vector3(0, -sp.upper * 0.5, 0))
		var el := _joint(sh, "el_" + s, Vector3(0, -sp.upper, 0))
		_m(el, _sph(sp.arm_r * 0.62, 10), metal, Vector3.ZERO)
		_m(el, _cap(sp.arm_r * 0.92, sp.fore), sp.get("arm_mat", fur), Vector3(0, -sp.fore * 0.5, 0))
		var hand := _joint(el, "hand_" + s, Vector3(0, -sp.fore - 0.02, 0))
		_build_hand(hand, sp, side)
	# legs
	for side in [1, -1]:
		var s: String = "l" if side == 1 else "r"
		var hp := _joint(hips, "hip_" + s, Vector3(side * sp.hip_x, -0.05, 0))
		_m(hp, _cap(sp.leg_r, sp.thigh), sp.get("thigh_mat", fur), Vector3(0, -sp.thigh * 0.45, 0))
		var kn := _joint(hp, "kn_" + s, Vector3(0, -sp.thigh, 0))
		_m(kn, _sph(sp.leg_r * 0.62, 10), metal, Vector3.ZERO)
		if sp.get("bird_legs", false):
			# thin scaly bird shins with exposed piston
			_m(kn, _cyl(sp.leg_r * 0.45, sp.leg_r * 0.4, sp.shin), sp.shin_mat, Vector3(0, -sp.shin * 0.5, 0))
			_m(kn, _cyl(0.02, 0.02, sp.shin * 0.8), metal, Vector3(0.05 * side, -sp.shin * 0.5, -0.04))
		else:
			_m(kn, _cap(sp.leg_r * 0.88, sp.shin), sp.get("shin_mat", fur), Vector3(0, -sp.shin * 0.5, 0))
		var foot := Node3D.new()
		foot.position = Vector3(0, -sp.shin, 0)
		kn.add_child(foot)
		_build_foot(foot, sp, side)


func _build_hand(hand: Node3D, sp: Dictionary, side: int) -> void:
	var style: String = sp.get("hand", "paw")
	var hm: Material = sp.get("hand_mat", sp.fur)
	if style == "hook" and side == -1:
		var metal := Mats.color(Color(0.55, 0.56, 0.58), 0.3, 0.95)
		_m(hand, _cyl(0.07, 0.06, 0.12), Mats.color(Color(0.1, 0.08, 0.06), 0.7), Vector3(0, 0.0, 0))
		_m(hand, _cyl(0.018, 0.018, 0.16), metal, Vector3(0, -0.12, 0))
		# curved hook made of segments
		var prev := Vector3(0, -0.2, 0)
		for i in 7:
			var a := deg_to_rad(i * 30.0)
			var p := Vector3(0, -0.2 - sin(a) * 0.1, (1.0 - cos(a)) * 0.1)
			if i > 0:
				var seg := _m(hand, _cyl(0.017 - i * 0.0018, 0.018 - i * 0.0018, (p - prev).length() + 0.01), metal, (prev + p) * 0.5)
				seg.basis = Basis(Quaternion(Vector3.UP, (p - prev).normalized()))
			prev = p
		return
	_m(hand, _sph(sp.arm_r * 1.05), hm, Vector3(0, -0.06, 0.01), Vector3.ZERO, Vector3(1.0, 1.15, 0.7))
	var nf := 3 if style != "wing" else 4
	for i in nf:
		var fx: float = (i - (nf - 1) * 0.5) * sp.arm_r * 0.55
		if style == "wing":
			_m(hand, _prism(Vector3(0.06, 0.22, 0.02)), sp.get("feather_mat", hm), Vector3(fx, -0.2, 0.0), Vector3(180, 0, fx * 80.0))
		else:
			_m(hand, _cap(0.026, 0.13), hm, Vector3(fx, -0.16, 0.03), Vector3(-15, 0, 0))
			if style == "claw":
				_m(hand, _prism(Vector3(0.02, 0.05, 0.02)), Mats.color(Color(0.15, 0.14, 0.12), 0.5), Vector3(fx, -0.245, 0.05), Vector3(165, 0, 0))
	# thumb
	_m(hand, _cap(0.025, 0.1), hm, Vector3(side * sp.arm_r * 0.9, -0.08, 0.05), Vector3(-30, 0, side * 40.0))


func _build_foot(foot: Node3D, sp: Dictionary, _side: int) -> void:
	var style: String = sp.get("foot", "paw")
	match style:
		"paw":
			_m(foot, _cap(0.11, 0.36), sp.get("foot_mat", sp.fur), Vector3(0, -0.07, 0.1), Vector3(90, 0, 0), Vector3(1.15, 0.75, 1))
			for i in 3:
				_m(foot, _sph(0.045, 8), sp.get("foot_mat", sp.fur), Vector3((i - 1) * 0.065, -0.08, 0.27))
		"talon":
			var tm: Material = sp.shin_mat
			for i in 3:
				var a := deg_to_rad((i - 1) * 28.0)
				_m(foot, _cap(0.028, 0.3), tm, Vector3(sin(a) * 0.12, -0.03, cos(a) * 0.12), Vector3(90, rad_to_deg(a), 0))
				_m(foot, _prism(Vector3(0.03, 0.07, 0.03)), Mats.color(Color(0.1, 0.1, 0.1), 0.5), Vector3(sin(a) * 0.27, -0.05, cos(a) * 0.27), Vector3(100, rad_to_deg(a), 0))
			_m(foot, _cap(0.025, 0.16), tm, Vector3(0, -0.03, -0.08), Vector3(-90, 0, 0))
		"hoof":
			_m(foot, _cyl(0.11, 0.13, 0.14), Mats.color(Color(0.12, 0.09, 0.08), 0.6), Vector3(0, -0.07, 0.04), Vector3.ZERO, Vector3(1, 1, 1.25))
			_m(foot, _box(Vector3(0.012, 0.13, 0.12)), Mats.color(Color(0.05, 0.04, 0.04)), Vector3(0, -0.07, 0.12))


# ------------------------------------------------------------------ characters
func _build_wolf(golden: bool) -> void:
	var fur_c := Color(0.40, 0.41, 0.42) if not golden else Color(0.60, 0.47, 0.16)
	var light_c := Color(0.58, 0.58, 0.57) if not golden else Color(0.70, 0.58, 0.27)
	var fur := Mats.fur(fur_c, 3.0)
	var light := Mats.fur(light_c, 3.0)
	var dark := Mats.color(Color(0.05, 0.05, 0.05), 0.6)
	var sp := {
		"fur": fur, "belly": light, "hip_h": 1.02, "pelvis_w": 0.33, "torso_r": 0.37, "torso_h": 1.0,
		"sh_x": 0.44, "sh_y": 0.1, "arm_r": 0.1, "upper": 0.42, "fore": 0.4, "hip_x": 0.18,
		"leg_r": 0.14, "thigh": 0.5, "shin": 0.44, "hand": "claw", "foot": "paw",
		"torso_scale": Vector3(1.05, 1.0, 0.85), "neck_y": 0.28,
	}
	_build_body(sp)
	var head: Node3D = joints.head
	_m(head, _sph(0.26), fur, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	for sx in [1, -1]:
		_m(head, _sph(0.13), fur, Vector3(sx * 0.17, 0.11, 0.07))
	# long wolf snout
	_m(head, _cap(0.1, 0.46), light, Vector3(0, 0.14, 0.27), Vector3(90, 0, 0), Vector3(1.15, 0.85, 1))
	_m(head, _cap(0.09, 0.3), fur, Vector3(0, 0.2, 0.24), Vector3(80, 0, 0), Vector3(1.0, 0.6, 1))
	_m(head, _sph(0.055, 10), dark, Vector3(0, 0.18, 0.5), Vector3.ZERO, Vector3(1.3, 0.9, 1))
	# mouth interior and teeth (wide creepy grin)
	_m(head, _box(Vector3(0.16, 0.03, 0.3)), Mats.color(Color(0.12, 0.02, 0.02)), Vector3(0, 0.075, 0.3))
	var tooth := Mats.color(Color(0.86, 0.83, 0.72), 0.5)
	for sx in [1, -1]:
		for k in 5:
			_m(head, _prism(Vector3(0.028, 0.05, 0.025)), tooth, Vector3(sx * (0.088 - k * 0.006), 0.07, 0.17 + k * 0.065), Vector3(180, 0, 0))
	for k in 3:
		_m(head, _prism(Vector3(0.025, 0.045, 0.02)), tooth, Vector3((k - 1) * 0.04, 0.07, 0.47), Vector3(180, 0, 0))
	var jaw := _joint(head, "jaw", Vector3(0, 0.08, 0.1))
	_m(jaw, _cap(0.08, 0.36), light, Vector3(0, -0.035, 0.18), Vector3(90, 0, 0), Vector3(1.1, 0.6, 1))
	for sx in [1, -1]:
		for k in 5:
			_m(jaw, _prism(Vector3(0.026, 0.045, 0.022)), tooth, Vector3(sx * (0.075 - k * 0.006), 0.0, 0.06 + k * 0.06))
	# eyes
	for sx in [1, -1]:
		if golden:
			_m(head, _sph(0.06, 12), Mats.color(Color(0.01, 0.01, 0.01), 0.3), Vector3(sx * 0.1, 0.26, 0.2))
			_pupil(head, Vector3(sx * 0.1, 0.26, 0.255), 0.009)
		else:
			_m(head, _sph(0.062, 12), Mats.color(Color(0.85, 0.83, 0.78), 0.3), Vector3(sx * 0.1, 0.26, 0.2))
			_m(head, _sph(0.036, 10), Mats.color(Color(0.35, 0.22, 0.1), 0.3), Vector3(sx * 0.1, 0.26, 0.245))
			_pupil(head, Vector3(sx * 0.1, 0.26, 0.275), 0.013)
		_m(head, _sph(0.068, 12), fur, Vector3(sx * 0.1, 0.29, 0.2), Vector3(-20, 0, 0), Vector3(1.05, 0.45, 1.0))
		_m(head, _box(Vector3(0.13, 0.035, 0.07)), Mats.fur(fur_c.darkened(0.35)), Vector3(sx * 0.1, 0.325, 0.21), Vector3(0, 0, -sx * 14.0))
		# pointed ears
		_m(head, _prism(Vector3(0.15, 0.27, 0.07)), fur, Vector3(sx * 0.15, 0.45, -0.03), Vector3(0, 0, -sx * 12.0))
		_m(head, _prism(Vector3(0.08, 0.17, 0.02)), Mats.color(fur_c.darkened(0.55), 0.9), Vector3(sx * 0.148, 0.43, 0.01), Vector3(0, 0, -sx * 12.0))
	# top hat
	var hat := Node3D.new()
	hat.position = Vector3(0.0, 0.43, -0.02)
	hat.rotation_degrees = Vector3(-6, 0, 7)
	head.add_child(hat)
	var hat_c := Color(0.04, 0.04, 0.04) if not golden else Color(0.12, 0.09, 0.04)
	_m(hat, _cyl(0.19, 0.19, 0.02, 20), Mats.color(hat_c, 0.7), Vector3(0, 0.0, 0))
	_m(hat, _cyl(0.12, 0.13, 0.24, 20), Mats.color(hat_c, 0.7), Vector3(0, 0.13, 0))
	_m(hat, _cyl(0.132, 0.132, 0.045, 20), Mats.color(Color(0.2, 0.2, 0.2), 0.5), Vector3(0, 0.035, 0))
	# black bow tie
	var chest: Node3D = joints.chest
	for sx in [1, -1]:
		_m(chest, _prism(Vector3(0.14, 0.16, 0.05)), dark, Vector3(sx * 0.075, 0.2, 0.3), Vector3(0, 0, sx * 90.0))
	_m(chest, _box(Vector3(0.05, 0.06, 0.06)), dark, Vector3(0, 0.2, 0.31))
	# tail
	var tail := _m(joints.hips, _cap(0.09, 0.5), fur, Vector3(0, -0.1, -0.33), Vector3(-140, 0, 0))
	tail.scale = Vector3(1, 1, 0.9)
	# chest panel seams (worn suit)
	_m(chest, _box(Vector3(0.3, 0.01, 0.01)), Mats.color(Color(0.1, 0.1, 0.1)), Vector3(0, -0.05, 0.31))
	if not golden:
		# microphone in right hand
		var mic := Node3D.new()
		mic.position = Vector3(0, -0.08, 0.06)
		mic.rotation_degrees = Vector3(70, 0, 0)
		joints.hand_r.add_child(mic)
		_m(mic, _cyl(0.022, 0.018, 0.22), dark, Vector3(0, 0.05, 0))
		_m(mic, _sph(0.045, 10), Mats.color(Color(0.4, 0.4, 0.42), 0.35, 0.9), Vector3(0, 0.19, 0))
	else:
		# torn suit: exposed endoskeleton on the arm & loose wires
		_m(joints.el_l, _cyl(0.03, 0.03, 0.3), Mats.color(Color(0.2, 0.2, 0.2), 0.4, 0.8), Vector3(0.06, -0.2, 0.05))
		var wire := Mats.color(Color(0.5, 0.1, 0.05), 0.6)
		_m(joints.chest, _cyl(0.008, 0.008, 0.3), wire, Vector3(0.12, -0.25, 0.3), Vector3(10, 0, 20))
		_m(joints.chest, _cyl(0.008, 0.008, 0.25), Mats.color(Color(0.1, 0.2, 0.6), 0.6), Vector3(0.15, -0.28, 0.29), Vector3(-10, 0, -15))


func _build_rooster() -> void:
	var purple := Color(0.30, 0.23, 0.52)
	var fur := Mats.fur(purple, 3.5)
	var dark_f := Mats.fur(Color(0.19, 0.15, 0.38), 3.5)
	var red := Mats.color(Color(0.7, 0.06, 0.05), 0.6)
	var leg := Mats.fur(Color(0.55, 0.32, 0.16), 4.0)
	var sp := {
		"fur": fur, "belly": dark_f, "hip_h": 1.2, "pelvis_w": 0.36, "torso_r": 0.45, "torso_h": 1.05,
		"sh_x": 0.5, "sh_y": 0.12, "arm_r": 0.11, "upper": 0.46, "fore": 0.42, "hip_x": 0.17,
		"leg_r": 0.15, "thigh": 0.5, "shin": 0.55, "hand": "wing", "foot": "talon",
		"bird_legs": true, "shin_mat": leg, "feather_mat": dark_f,
		"torso_scale": Vector3(1.05, 1.08, 0.92), "neck_y": 0.36,
	}
	_build_body(sp)
	# body feathers
	var spine: Node3D = joints.spine
	for i in 46:
		var a := rng.randf_range(-PI, PI)
		var y := rng.randf_range(0.0, 0.85)
		var rr := 0.44 * sqrt(max(0.15, 1.0 - pow((y - 0.42) / 0.62, 2)))
		var p := Vector3(sin(a) * rr * 1.05, y, cos(a) * rr * 0.92)
		var f := _m(spine, _prism(Vector3(0.13, 0.22, 0.03)), fur if i % 3 else dark_f, p, Vector3(180 + rng.randf_range(-15, 15), rad_to_deg(a), rng.randf_range(-10, 10)))
		f.translate_object_local(Vector3(0, 0, 0.0))
	# shoulder feather capes
	for side in [1, -1]:
		var s: String = "l" if side == 1 else "r"
		for i in 6:
			_m(joints["sh_" + s], _prism(Vector3(0.1, 0.24, 0.03)), dark_f, Vector3(side * 0.05, -0.12 - i * 0.05, rng.randf_range(-0.08, 0.08)), Vector3(180, 90 * side, rng.randf_range(-20, 20)))
	# tail fan
	for i in 7:
		var a := (i - 3) * 16.0
		_m(joints.hips, _prism(Vector3(0.14, 0.7, 0.03)), dark_f if i % 2 else fur, Vector3(sin(deg_to_rad(a)) * 0.15, 0.35, -0.38), Vector3(-25, 0, a))
	var head: Node3D = joints.head
	head.scale = Vector3(1.25, 1.25, 1.25)
	_m(head, _sph(0.24), fur, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(0.95, 1.05, 1.0))
	# comb
	var combs := [Vector3(0, 0.47, 0.09), Vector3(0, 0.5, 0.0), Vector3(0, 0.48, -0.09), Vector3(0, 0.43, -0.16), Vector3(0, 0.43, 0.16)]
	for i in combs.size():
		_m(head, _sph(0.085 - i * 0.008), red, combs[i], Vector3.ZERO, Vector3(0.5, 1.35, 1.0))
	# beak
	var beak := Mats.color(Color(0.86, 0.6, 0.18), 0.55)
	_m(head, _cyl(0.0, 0.09, 0.28), beak, Vector3(0, 0.19, 0.33), Vector3(90, 0, 0), Vector3(1.3, 1, 0.8))
	var jaw := _joint(head, "jaw", Vector3(0, 0.15, 0.2))
	_m(jaw, _cyl(0.0, 0.07, 0.2), beak, Vector3(0, -0.015, 0.11), Vector3(90, 0, 0), Vector3(1.15, 1, 0.5))
	for sx in [1, -1]:
		_m(jaw, _cap(0.035, 0.15), red, Vector3(sx * 0.03, -0.09, 0.07))
		_m(head, _sph(0.078, 12), Mats.color(Color(0.92, 0.9, 0.86), 0.3), Vector3(sx * 0.1, 0.27, 0.15))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.07
		ring.outer_radius = 0.1
		_m(head, ring, red, Vector3(sx * 0.1, 0.27, 0.19), Vector3(90, 0, 0))
		_m(head, _sph(0.04, 10), Mats.color(Color(0.2, 0.32, 0.6), 0.3), Vector3(sx * 0.1, 0.27, 0.215))
		_pupil(head, Vector3(sx * 0.1, 0.27, 0.25), 0.014)
		_m(head, _box(Vector3(0.12, 0.03, 0.06)), dark_f, Vector3(sx * 0.1, 0.36, 0.17), Vector3(0, 0, -sx * 18.0))
	for i in 5:
		_m(head, _prism(Vector3(0.07, 0.2, 0.03)), dark_f, Vector3(rng.randf_range(-0.1, 0.1), 0.25, -0.22), Vector3(-60, rng.randf_range(-30, 30), 180))
	# red bow tie
	var chest: Node3D = joints.chest
	for sx in [1, -1]:
		_m(chest, _prism(Vector3(0.16, 0.18, 0.05)), red, Vector3(sx * 0.085, 0.26, 0.36), Vector3(0, 0, sx * 90.0))
	_m(chest, _box(Vector3(0.06, 0.07, 0.06)), red, Vector3(0, 0.26, 0.37))
	# electric guitar strapped across the body
	var g := Node3D.new()
	g.name = "Guitar"
	g.position = Vector3(0.0, -0.32, 0.5)
	g.rotation_degrees = Vector3(0, 0, -62)
	chest.add_child(g)
	var wood := Mats.color(Color(0.55, 0.22, 0.08), 0.45)
	var sun := Mats.color(Color(0.85, 0.55, 0.15), 0.45)
	_m(g, _cyl(0.2, 0.2, 0.06, 20), wood, Vector3(0, -0.12, 0), Vector3(90, 0, 0), Vector3(1.0, 1, 1.15))
	_m(g, _cyl(0.16, 0.16, 0.062, 20), sun, Vector3(0, 0.1, 0), Vector3(90, 0, 0))
	_m(g, _cyl(0.13, 0.13, 0.065, 20), Mats.color(Color(0.92, 0.9, 0.85), 0.4), Vector3(0.06, -0.06, 0.01), Vector3(90, 0, 0), Vector3(0.6, 1, 0.8))
	_m(g, _box(Vector3(0.06, 0.62, 0.035)), Mats.color(Color(0.3, 0.17, 0.08), 0.5), Vector3(0, 0.52, 0))
	_m(g, _box(Vector3(0.09, 0.16, 0.035)), Mats.color(Color(0.92, 0.9, 0.85), 0.4), Vector3(0, 0.9, 0))
	for k in 3:
		_m(g, _box(Vector3(0.004, 0.95, 0.004)), Mats.color(Color(0.75, 0.75, 0.75), 0.3, 1.0), Vector3((k - 1) * 0.015, 0.35, 0.04))
	# strap
	_m(chest, _box(Vector3(0.06, 0.95, 0.02)), Mats.color(Color(0.12, 0.08, 0.06)), Vector3(0.0, -0.05, 0.4), Vector3(0, 0, 40))


func _build_boar() -> void:
	var fur_c := Color(0.47, 0.28, 0.27)
	var fur := Mats.fur(fur_c, 3.0)
	var pink := Mats.color(Color(0.74, 0.46, 0.47), 0.75)
	var dark := Mats.color(Color(0.08, 0.05, 0.05))
	var sp := {
		"fur": fur, "belly": Mats.fur(Color(0.55, 0.36, 0.35), 3.0), "hip_h": 0.98, "pelvis_w": 0.42,
		"torso_r": 0.45, "torso_h": 0.95, "sh_x": 0.5, "sh_y": 0.08, "arm_r": 0.125, "upper": 0.4,
		"fore": 0.38, "hip_x": 0.2, "leg_r": 0.16, "thigh": 0.46, "shin": 0.42, "hand": "paw",
		"foot": "hoof", "torso_scale": Vector3(1.18, 1.0, 0.95), "neck_y": 0.22,
	}
	_build_body(sp)
	var head: Node3D = joints.head
	_m(head, _sph(0.3), fur, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.1, 1.0, 1.05))
	# snout
	_m(head, _cyl(0.13, 0.15, 0.24), pink, Vector3(0, 0.15, 0.31), Vector3(90, 0, 0))
	_m(head, _cyl(0.135, 0.135, 0.025), Mats.color(Color(0.82, 0.55, 0.56), 0.7), Vector3(0, 0.15, 0.43), Vector3(90, 0, 0))
	for sx in [1, -1]:
		_m(head, _sph(0.03, 8), dark, Vector3(sx * 0.05, 0.15, 0.44), Vector3.ZERO, Vector3(1, 1.4, 0.5))
	var jaw := _joint(head, "jaw", Vector3(0, 0.05, 0.12))
	_m(jaw, _cap(0.1, 0.3), fur, Vector3(0, -0.02, 0.13), Vector3(90, 0, 0), Vector3(1.3, 0.55, 1))
	_m(jaw, _box(Vector3(0.18, 0.02, 0.2)), Mats.color(Color(0.3, 0.05, 0.06)), Vector3(0, 0.02, 0.15))
	var ivory := Mats.color(Color(0.9, 0.86, 0.72), 0.4)
	for sx in [1, -1]:
		# curved tusks
		var t1 := Node3D.new()
		t1.position = Vector3(sx * 0.13, 0.0, 0.22)
		t1.rotation_degrees = Vector3(25, 0, -sx * 28.0)
		jaw.add_child(t1)
		_m(t1, _cyl(0.014, 0.03, 0.16), ivory, Vector3(0, 0.08, 0))
		var t2 := Node3D.new()
		t2.position = Vector3(0, 0.16, 0)
		t2.rotation_degrees = Vector3(-35, 0, sx * 40.0)
		t1.add_child(t2)
		_m(t2, _cyl(0.002, 0.014, 0.12), ivory, Vector3(0, 0.06, 0))
		# eyes with lashes
		_m(head, _sph(0.06, 12), Mats.color(Color(0.9, 0.86, 0.8), 0.3), Vector3(sx * 0.12, 0.29, 0.21))
		_m(head, _sph(0.034, 10), Mats.color(Color(0.4, 0.2, 0.08), 0.3), Vector3(sx * 0.12, 0.29, 0.255))
		_pupil(head, Vector3(sx * 0.12, 0.29, 0.283), 0.012)
		_m(head, _sph(0.066, 12), fur, Vector3(sx * 0.12, 0.315, 0.21), Vector3(-25, 0, 0), Vector3(1.05, 0.45, 1))
		for k in 3:
			_m(head, _box(Vector3(0.008, 0.05, 0.008)), dark, Vector3(sx * (0.09 + k * 0.03), 0.345, 0.25), Vector3(-30, 0, -sx * (10.0 + k * 22.0)))
		_m(head, _box(Vector3(0.1, 0.015, 0.04)), dark, Vector3(sx * 0.12, 0.375, 0.23), Vector3(0, 0, -sx * 10.0))
		_m(head, _sph(0.06, 8), Mats.color(Color(0.72, 0.38, 0.4), 0.8), Vector3(sx * 0.18, 0.18, 0.2), Vector3.ZERO, Vector3(1, 0.7, 0.5))
		# ears
		_m(head, _prism(Vector3(0.17, 0.22, 0.06)), fur, Vector3(sx * 0.24, 0.42, -0.03), Vector3(0, 0, -sx * 48.0))
		_m(head, _prism(Vector3(0.1, 0.14, 0.02)), pink, Vector3(sx * 0.235, 0.41, 0.0), Vector3(0, 0, -sx * 48.0))
	for i in 5:
		_m(head, _prism(Vector3(0.05, 0.13, 0.03)), Mats.fur(fur_c.darkened(0.4)), Vector3(rng.randf_range(-0.06, 0.06), 0.5, rng.randf_range(-0.08, 0.06)), Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
	# bib "LAHMACUN TIME!"
	var chest: Node3D = joints.chest
	var bib := _m(chest, _box(Vector3(0.56, 0.6, 0.025)), Mats.color(Color(0.86, 0.8, 0.66), 0.95), Vector3(0, -0.12, 0.42), Vector3(-8, 0, 0))
	var lbl := Label3D.new()
	lbl.text = "LAHMACUN\nTIME!"
	lbl.font_size = 64
	lbl.pixel_size = 0.0016
	lbl.modulate = Color(0.45, 0.12, 0.08)
	lbl.outline_size = 0
	lbl.shaded = true
	lbl.position = Vector3(0, 0.02, 0.016)
	bib.add_child(lbl)
	_m(chest, _box(Vector3(0.03, 0.3, 0.02)), Mats.color(Color(0.86, 0.8, 0.66)), Vector3(0.2, 0.22, 0.33), Vector3(-30, 0, -20))
	_m(chest, _box(Vector3(0.03, 0.3, 0.02)), Mats.color(Color(0.86, 0.8, 0.66)), Vector3(-0.2, 0.22, 0.33), Vector3(-30, 0, 20))
	# metal tray with lahmacun in the left hand
	tray = Node3D.new()
	tray.name = "Tray"
	tray.position = Vector3(0.0, -0.12, 0.12)
	joints.hand_l.add_child(tray)
	_m(tray, _cyl(0.3, 0.3, 0.02, 24), Mats.color(Color(0.6, 0.6, 0.62), 0.3, 0.95), Vector3(0, 0, 0))
	_m(tray, _cyl(0.26, 0.26, 0.012, 20), Mats.color(Color(0.72, 0.38, 0.16), 0.8), Vector3(0, 0.016, 0))
	for i in 18:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.22
		_m(tray, _sph(0.014, 6), Mats.color(Color(0.55, 0.1, 0.05) if i % 3 else Color(0.2, 0.45, 0.15)), Vector3(cos(a) * r, 0.024, sin(a) * r), Vector3.ZERO, Vector3(1, 0.4, 1))


func _build_crow() -> void:
	var black := Mats.fur(Color(0.07, 0.07, 0.08), 4.0, 0.85)
	var ragged := Mats.fur(Color(0.13, 0.13, 0.15), 4.0)
	var metal := Mats.color(Color(0.3, 0.3, 0.32), 0.4, 0.9)
	var leg := Mats.color(Color(0.22, 0.2, 0.18), 0.5, 0.7)
	var sp := {
		"fur": black, "hip_h": 1.05, "pelvis_w": 0.3, "torso_r": 0.3, "torso_h": 0.95,
		"sh_x": 0.38, "sh_y": 0.1, "arm_r": 0.085, "upper": 0.44, "fore": 0.42, "hip_x": 0.15,
		"leg_r": 0.12, "thigh": 0.5, "shin": 0.52, "hand": "hook", "foot": "talon",
		"bird_legs": true, "shin_mat": leg, "feather_mat": ragged, "neck_y": 0.26, "neck_z": 0.05,
		"torso_scale": Vector3(1.0, 1.0, 0.9),
	}
	_build_body(sp)
	# ragged feathers (torn suit, gaps show metal)
	var spine: Node3D = joints.spine
	for i in 30:
		var a := rng.randf_range(-PI, PI)
		var y := rng.randf_range(0.05, 0.8)
		_m(spine, _prism(Vector3(0.1, rng.randf_range(0.15, 0.32), 0.02)), ragged if i % 2 else black, Vector3(sin(a) * 0.3, y, cos(a) * 0.27), Vector3(180 + rng.randf_range(-20, 20), rad_to_deg(a), rng.randf_range(-25, 25)))
	_m(spine, _cyl(0.04, 0.04, 0.5), metal, Vector3(0.12, 0.3, 0.2), Vector3(10, 0, 5))
	for side in [1, -1]:
		var s: String = "l" if side == 1 else "r"
		for i in 7:
			_m(joints["sh_" + s], _prism(Vector3(0.09, rng.randf_range(0.25, 0.45), 0.02)), ragged, Vector3(side * 0.08, -0.15 - i * 0.05, -0.05), Vector3(180, 90 * side, rng.randf_range(-25, 10)))
	var head: Node3D = joints.head
	_m(head, _sph(0.22), black, Vector3(0, 0.2, 0))
	var beak := Mats.color(Color(0.5, 0.45, 0.28), 0.5)
	_m(head, _cyl(0.0, 0.095, 0.44), beak, Vector3(0, 0.17, 0.38), Vector3(95, 0, 0), Vector3(1.1, 1, 0.85))
	var jaw := _joint(head, "jaw", Vector3(0, 0.12, 0.16))
	_m(jaw, _cyl(0.0, 0.075, 0.34), beak, Vector3(0, -0.01, 0.17), Vector3(88, 0, 0), Vector3(1.0, 1, 0.5))
	# left eye (amber), right eye patch
	_m(head, _sph(0.06, 12), Mats.color(Color(0.85, 0.75, 0.45), 0.3), Vector3(0.1, 0.26, 0.15))
	_m(head, _sph(0.032, 10), Mats.color(Color(0.6, 0.35, 0.05), 0.3), Vector3(0.1, 0.26, 0.195))
	_pupil(head, Vector3(0.1, 0.26, 0.22), 0.013, Color(1.0, 0.75, 0.3))
	_m(head, _sph(0.065, 12), black, Vector3(0.1, 0.29, 0.15), Vector3(-25, 0, 0), Vector3(1.05, 0.45, 1))
	_m(head, _cyl(0.075, 0.075, 0.02), Mats.color(Color(0.03, 0.03, 0.03), 0.5), Vector3(-0.1, 0.26, 0.18), Vector3(90, 0, 25))
	var strap := TorusMesh.new()
	strap.inner_radius = 0.218
	strap.outer_radius = 0.232
	_m(head, strap, Mats.color(Color(0.05, 0.04, 0.03), 0.6), Vector3(0, 0.25, 0), Vector3(0, 0, 25))
	for i in 3:
		_m(head, _prism(Vector3(0.06, 0.22, 0.02)), black, Vector3(0, 0.4, -0.05 - i * 0.05), Vector3(-30 - i * 15, 0, 0))
	for i in 8:
		_m(joints.neck, _prism(Vector3(0.08, 0.2, 0.02)), ragged, Vector3(sin(i * 0.8) * 0.15, 0.0, cos(i * 0.8) * 0.15), Vector3(180, rad_to_deg(i * 0.8), 0))


# ------------------------------------------------------------------ poses
func _pose_table(p: String) -> Dictionary:
	var d := {}
	match p:
		"stand":
			d = {"sh_l": Vector3(0, 0, 8), "sh_r": Vector3(0, 0, -8), "el_l": Vector3(-12, 0, 0), "el_r": Vector3(-12, 0, 0)}
		"perform":
			match kind:
				"grayson":
					d = {"sh_r": Vector3(-55, 0, -12), "el_r": Vector3(-85, 0, 0), "sh_l": Vector3(-25, 0, 25), "el_l": Vector3(-40, 0, 0), "head": Vector3(-5, 0, 0)}
				"benny":
					d = {"sh_r": Vector3(-35, 0, -10), "el_r": Vector3(-70, -40, 0), "sh_l": Vector3(-45, 0, 30), "el_l": Vector3(-60, 30, 0)}
				"brutus":
					d = {"sh_l": Vector3(-40, 0, 25), "el_l": Vector3(-65, 0, 0), "sh_r": Vector3(-15, 0, -15), "el_r": Vector3(-30, 0, 0), "head": Vector3(0, -8, 0)}
				_:
					d = {"sh_r": Vector3(-80, 0, -25), "el_r": Vector3(-30, 0, 0), "chest": Vector3(15, 0, 0)}
		"lurk":
			d = {"spine": Vector3(8, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(12, 0, 0), "jaw": Vector3(6, 0, 0),
				"sh_l": Vector3(4, 0, 6), "sh_r": Vector3(4, 0, -6), "el_l": Vector3(-6, 0, 0), "el_r": Vector3(-6, 0, 0)}
			if kind == "brutus":
				d["sh_l"] = Vector3(-40, 0, 25)
				d["el_l"] = Vector3(-65, 0, 0)
		"door":
			d = {"spine": Vector3(18, 0, 0), "chest": Vector3(16, 0, 0), "head": Vector3(-14, 0, 0), "jaw": Vector3(12, 0, 0),
				"sh_l": Vector3(-95, 0, 25), "el_l": Vector3(-20, 0, 0), "sh_r": Vector3(0, 0, -8), "el_r": Vector3(-10, 0, 0),
				"hip_l": Vector3(-25, 0, 0), "hip_r": Vector3(-25, 0, 0), "kn_l": Vector3(40, 0, 0), "kn_r": Vector3(40, 0, 0)}
		"peek":
			d = {"spine": Vector3(10, -25, 0), "chest": Vector3(15, -15, 0), "head": Vector3(10, 25, -20), "jaw": Vector3(10, 0, 0),
				"sh_r": Vector3(-90, 0, -10), "el_r": Vector3(-40, 0, 0), "sh_l": Vector3(5, 0, 5)}
		"ready":
			d = {"spine": Vector3(20, 0, 0), "chest": Vector3(15, 0, 0), "head": Vector3(-15, 0, 0), "jaw": Vector3(25, 0, 0),
				"sh_l": Vector3(-30, 0, 40), "sh_r": Vector3(-60, 0, -40), "el_l": Vector3(-30, 0, 0), "el_r": Vector3(-50, 0, 0),
				"hip_l": Vector3(-30, 0, 5), "kn_l": Vector3(45, 0, 0), "hip_r": Vector3(10, 0, -5), "kn_r": Vector3(30, 0, 0)}
		"run":
			d = {"spine": Vector3(25, 0, 0), "chest": Vector3(10, 0, 0), "head": Vector3(-20, 0, 0), "jaw": Vector3(20, 0, 0)}
		"jumpscare":
			d = {"spine": Vector3(-5, 0, 0), "chest": Vector3(5, 0, 0), "head": Vector3(-12, 0, 0), "jaw": Vector3(38, 0, 0),
				"sh_l": Vector3(-110, 0, 30), "sh_r": Vector3(-110, 0, -30), "el_l": Vector3(-30, 0, 0), "el_r": Vector3(-30, 0, 0)}
		"slump":
			d = {"hips": Vector3(-8, 0, 0), "spine": Vector3(22, 0, 0), "chest": Vector3(18, 0, 0), "head": Vector3(30, 0, 22), "jaw": Vector3(14, 0, 0),
				"hip_l": Vector3(-86, -12, 0), "hip_r": Vector3(-86, 12, 0), "kn_l": Vector3(8, 0, 0), "kn_r": Vector3(14, 0, 0),
				"sh_l": Vector3(8, 0, 22), "sh_r": Vector3(8, 0, -22), "el_l": Vector3(-14, 0, 0), "el_r": Vector3(-10, 0, 0)}
		"twisted":
			d = {"head": Vector3(10, 0, 95), "jaw": Vector3(30, 0, 0), "sh_l": Vector3(-170, 0, 10), "el_l": Vector3(-10, 0, 0),
				"sh_r": Vector3(20, 0, -40), "chest": Vector3(-10, 0, 15)}
		"powerout":
			d = {"head": Vector3(5, 0, -6), "sh_r": Vector3(-55, 0, -12), "el_r": Vector3(-85, 0, 0), "sh_l": Vector3(5, 0, 8), "jaw": Vector3(4, 0, 0)}
	return d


func set_pose(p: String, instant: bool = false) -> void:
	pose_name = p
	var d := _pose_table(p)
	for j in _target.keys():
		var deg: Vector3 = d.get(j, Vector3.ZERO)
		_target[j] = Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))
		if instant:
			_cur[j] = _target[j]
			joints[j].rotation = _target[j]
	_root_y_target = 0.0
	if p == "slump":
		_root_y_target = -0.86
	elif p == "door":
		_root_y_target = -0.07
	if instant:
		root_offset_y = _root_y_target
		body.position.y = root_offset_y


func place(pos: Vector3, yaw_deg: float) -> void:
	global_position = pos
	rotation = Vector3(0, deg_to_rad(yaw_deg), 0)


func face_point(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(d.x, d.z)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var k := 1.0 - exp(-speed * delta)
	# random servo twitches make idle bodies feel "alive but wrong"
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = rng.randf_range(1.5, 5.5)
		_twitch.clear()
		if anim == "idle" or anim == "twitchy":
			var amp := 10.0 if anim == "idle" else 28.0
			_twitch["head"] = Vector3(deg_to_rad(rng.randf_range(-amp, amp) * 0.5), deg_to_rad(rng.randf_range(-amp, amp)), deg_to_rad(rng.randf_range(-amp, amp) * 0.6))
			if rng.randf() < 0.3:
				_twitch["jaw"] = Vector3(deg_to_rad(rng.randf_range(5, 22)), 0, 0)
	for j in _target.keys():
		var tgt: Vector3 = _target[j]
		if _twitch.has(j):
			tgt += _twitch[j]
		tgt += _proc_offset(j)
		var c: Vector3 = _cur[j]
		var kk := k
		if anim == "jumpscare" or anim == "run":
			kk = 1.0 - exp(-18.0 * delta)
		c = c.lerp(tgt, kk)
		_cur[j] = c
		joints[j].rotation = c
	root_offset_y = lerp(root_offset_y, _root_y_target, k)
	var bob := 0.0
	if anim == "run":
		_run_phase += delta * 11.0
		bob = abs(sin(_run_phase)) * 0.07
	var shake := Vector3.ZERO
	if anim == "jumpscare":
		shake = Vector3(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012), 0)
	body.position = Vector3(0, root_offset_y + bob, 0) + shake
	if tray and is_instance_valid(tray):
		# the tray stays level whatever the arm does
		tray.global_basis = Basis(Vector3.UP, global_rotation.y)


func _proc_offset(j: String) -> Vector3:
	var o := Vector3.ZERO
	match anim:
		"idle", "twitchy", "still":
			if j == "chest":
				o.x = sin(_t * 1.1) * 0.02
		"strum":
			if j == "el_r":
				o.x = sin(_t * 9.0) * 0.18
			if j == "head":
				o.x = sin(_t * 4.5) * 0.06
			if j == "chest":
				o.z = sin(_t * 2.2) * 0.04
		"sing":
			if j == "jaw":
				o.x = max(0.0, sin(_t * 7.0)) * 0.35
			if j == "head":
				o.y = sin(_t * 1.3) * 0.15
		"run":
			var s := sin(_run_phase)
			match j:
				"hip_l": o.x = -s * 0.9
				"hip_r": o.x = s * 0.9
				"kn_l": o.x = 0.5 + max(0.0, s) * 0.9
				"kn_r": o.x = 0.5 + max(0.0, -s) * 0.9
				"sh_l": o.x = s * 0.9
				"sh_r": o.x = -s * 0.9
				"el_l", "el_r": o.x = -0.6
				"jaw": o.x = abs(s) * 0.3
		"jumpscare":
			match j:
				"jaw": o.x = sin(_t * 32.0) * 0.18
				"head": o = Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07), rng.randf_range(-0.05, 0.05))
	if j == "head" and look_target != null and look_weight > 0.0:
		var lt: Vector3 = look_target
		var local := to_local(lt) - Vector3(0, 1.9, 0)
		var yaw := clampf(atan2(local.x, local.z), -1.2, 1.2)
		var pitch := clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
		o += Vector3(pitch, yaw, 0) * look_weight
	return o


func add_pick_area(meta_name: String) -> void:
	pick_area = Area3D.new()
	pick_area.collision_layer = 2
	pick_area.collision_mask = 0
	pick_area.set_meta("pick", meta_name)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 2.0, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 1.0, 0)
	pick_area.add_child(cs)
	body.add_child(pick_area)
