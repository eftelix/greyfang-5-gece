class_name WorldBuilder
extends RefCounted
## Builds the whole Greyfang Lahmacun Sarayı as a real 3D environment.
## Coordinates: X = east, -Z = north, Y = up. Office at the south end.
##
## Layout (top view, FNAF-1 logic adapted):
##   [5 Bakım]  [1A Sahne ...........]  [7 Tuvalet]
##   [1C Korsan][1B Yemek Salonu.....]  [6 Mutfak ]
##   [3 Depo][2A]   (blok)    [4A]
##           [2B][  OFİS   ][4B]

var root: Node3D
var cams: Dictionary = {}        # id -> {node: Camera3D, name, yaw0, pan, pitch}
var spots: Dictionary = {}       # loc -> {char -> [pos, yaw]}
var clue_spots: Array = []
var lights: Array = []           # {light, mat, energy, mode, group, phase}
var office: Dictionary = {}
var fan_blades: Node3D
var stage_lights: Array = []
var cam_env: Environment
var main_env: Environment
var rook_path: Array = []
var curtain_l: Node3D
var curtain_r: Node3D
var cove_sign: Label3D
var rng := RandomNumberGenerator.new()

const H_HALL := 4.2
const H_ROOM := 3.0

const CAM_NAMES := {
	"1A": "Sahne", "1B": "Yemek Salonu", "1C": "Korsan Köşesi", "2A": "Batı Koridoru",
	"2B": "Batı Köşe", "3": "Depo", "4A": "Doğu Koridoru", "4B": "Doğu Köşe",
	"5": "Bakım Odası", "6": "Mutfak", "7": "Tuvaletler",
}
const LOC_CAM := {
	"stage": "1A", "dining": "1B", "cove": "1C", "backstage": "5", "supply": "3",
	"whall": "2A", "wcorner": "2B", "restroom": "7", "kitchen": "6", "ehall": "4A", "ecorner": "4B",
}


func build(parent: Node3D) -> void:
	rng.seed = 2018
	root = Node3D.new()
	root.name = "World"
	parent.add_child(root)
	_environment()
	_shell()
	_stage()
	_dining()
	_pirate_cove()
	_backstage()
	_restrooms()
	_kitchen()
	_supply()
	_halls()
	_office()
	_cameras()
	_spots()


# ================================================================ primitives
func box(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO, p: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	(p if p else root).add_child(mi)
	return mi


func cyl(pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot := Vector3.ZERO, p: Node3D = null, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	(p if p else root).add_child(mi)
	return mi


func sph(pos: Vector3, r: float, mat: Material, scl := Vector3.ONE, p: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	(p if p else root).add_child(mi)
	return mi


func label(pos: Vector3, text: String, size: int, col: Color, rot := Vector3.ZERO, shaded := true, px := 0.004, p: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.shaded = shaded
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot
	(p if p else root).add_child(l)
	return l


func quad_img(pos: Vector3, size: Vector2, tex_name: String, rot := Vector3.ZERO, p: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = Mats.image(tex_name)
	mi.position = pos
	mi.rotation_degrees = rot
	(p if p else root).add_child(mi)
	return mi


func omni(pos: Vector3, col: Color, energy: float, rng_m: float, mode: String = "steady", shadow := false, group := "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	root.add_child(l)
	lights.append({"light": l, "mat": null, "energy": energy, "mode": mode, "group": group, "phase": rng.randf() * 100.0})
	return l


func spot(pos: Vector3, target: Vector3, col: Color, energy: float, rng_m: float, angle: float, mode := "steady", shadow := true, group := "") -> SpotLight3D:
	var l := SpotLight3D.new()
	root.add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if abs((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_color = col
	l.light_energy = energy
	l.spot_range = rng_m
	l.spot_angle = angle
	l.shadow_enabled = shadow
	lights.append({"light": l, "mat": null, "energy": energy, "mode": mode, "group": group, "phase": rng.randf() * 100.0})
	return l


## fluorescent ceiling fixture + light
func fluoro(pos: Vector3, mode: String, energy := 1.2, rng_m := 9.0, col := Color(0.82, 0.92, 0.85), group := "") -> void:
	box(pos + Vector3(0, 0.04, 0), Vector3(1.3, 0.08, 0.32), Mats.color(Color(0.2, 0.2, 0.2), 0.6, 0.4))
	var m := Mats.unique_emissive(col, 1.4 if mode != "dead" else 0.0)
	box(pos + Vector3(0, -0.01, 0), Vector3(1.2, 0.04, 0.22), m)
	if mode == "dead":
		return
	var l := omni(pos + Vector3(0, -0.3, 0), col, energy, rng_m, mode, false, group)
	lights[lights.size() - 1]["mat"] = m
	l.omni_attenuation = 1.0


func bulb(pos: Vector3, mode: String, energy := 0.9, rng_m := 7.0, col := Color(1.0, 0.75, 0.45), shadow := false, group := "") -> void:
	cyl(pos + Vector3(0, 0.45, 0), 0.006, 0.006, 0.9, Mats.color(Color(0.05, 0.05, 0.05)))
	var m := Mats.unique_emissive(col, 3.0)
	sph(pos, 0.06, m)
	omni(pos + Vector3(0, -0.1, 0), col, energy, rng_m, mode, shadow, group)
	lights[lights.size() - 1]["mat"] = m


# ================================================================ walls
## wall along Z at x (thickness 0.2) with openings [[z0, z1, top]]
func wall_x(x: float, z0: float, z1: float, h: float, openings: Array = [], lower: Material = null, upper: Material = null) -> void:
	_wall(true, x, z0, z1, h, openings, lower, upper)


func wall_z(z: float, x0: float, x1: float, h: float, openings: Array = [], lower: Material = null, upper: Material = null) -> void:
	_wall(false, z, x0, x1, h, openings, lower, upper)


func _wall(along_z: bool, c: float, a0: float, a1: float, h: float, openings: Array, lower: Material, upper: Material) -> void:
	if lower == null:
		lower = Mats.surface("walltile", "wall_tiles", Color(0.95, 0.95, 0.92), 0.6, 0.35)
	if upper == null:
		upper = Mats.surface("plaster", "plaster", Color(0.9, 0.86, 0.8), 0.35)
	var segs := []
	var cur := a0
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p[0] < q[0])
	for o in ops:
		if o[0] > cur:
			segs.append([cur, o[0], 0.0, h])
		segs.append([o[0], o[1], o[2], h])  # lintel
		cur = o[1]
	if cur < a1:
		segs.append([cur, a1, 0.0, h])
	var wain := 1.25
	for s in segs:
		var seg_len: float = s[1] - s[0]
		var mid: float = (s[0] + s[1]) * 0.5
		var y0: float = s[2]
		var y1: float = s[3]
		if y1 - y0 <= 0.01:
			continue
		var parts := []
		if y0 < wain:
			parts.append([y0, wain, lower])
			parts.append([wain, y1, upper])
		else:
			parts.append([y0, y1, upper])
		for pt in parts:
			var hh: float = pt[1] - pt[0]
			if hh <= 0.0:
				continue
			var pos := Vector3(c, (pt[0] + pt[1]) * 0.5, mid) if along_z else Vector3(mid, (pt[0] + pt[1]) * 0.5, c)
			var size := Vector3(0.2, hh, seg_len) if along_z else Vector3(seg_len, hh, 0.2)
			box(pos, size, pt[2])
		# skirting / chair rail
		var rail := Mats.color(Color(0.35, 0.12, 0.08), 0.6)
		if y0 < wain:
			var rp := Vector3(c, wain, mid) if along_z else Vector3(mid, wain, c)
			box(rp, Vector3(0.24, 0.06, seg_len) if along_z else Vector3(seg_len, 0.06, 0.24), rail)


func floor_ceiling(x0: float, x1: float, z0: float, z1: float, h: float, floor_mat: Material, ceil_mat: Material = null) -> void:
	box(Vector3((x0 + x1) * 0.5, -0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), floor_mat)
	if ceil_mat == null:
		ceil_mat = Mats.surface("ceil", "concrete", Color(0.45, 0.43, 0.4), 0.5)
	box(Vector3((x0 + x1) * 0.5, h + 0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), ceil_mat)


# ================================================================ environment
func _environment() -> void:
	main_env = Environment.new()
	main_env.background_mode = Environment.BG_COLOR
	main_env.background_color = Color(0, 0, 0)
	main_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	main_env.ambient_light_color = Color(0.32, 0.36, 0.42)
	main_env.ambient_light_energy = 0.12
	main_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	main_env.tonemap_exposure = 1.1
	main_env.glow_enabled = true
	main_env.glow_intensity = 0.6
	main_env.glow_bloom = 0.05
	main_env.fog_enabled = true
	main_env.fog_light_color = Color(0.05, 0.06, 0.07)
	main_env.fog_density = 0.03
	main_env.ssao_enabled = true
	main_env.ssao_intensity = 1.6
	main_env.adjustment_enabled = true
	main_env.adjustment_saturation = 0.85
	main_env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = main_env
	root.add_child(we)
	# security-camera look: brighter (IR gain), desaturated, cold
	cam_env = main_env.duplicate()
	cam_env.ambient_light_color = Color(0.55, 0.62, 0.6)
	cam_env.ambient_light_energy = 0.55
	cam_env.tonemap_exposure = 1.7
	cam_env.adjustment_saturation = 0.35
	cam_env.adjustment_brightness = 1.05
	cam_env.adjustment_contrast = 1.2
	cam_env.fog_density = 0.02
	cam_env.glow_intensity = 0.9


func _shell() -> void:
	var hall_floor := Mats.surface("floor", "floor_tiles", Color(1, 1, 1), 0.5, 0.6)
	var dark_floor := Mats.surface("floor2", "floor_tiles", Color(0.6, 0.6, 0.62), 0.5, 0.6)
	var concrete := Mats.surface("concrete", "concrete", Color(0.8, 0.78, 0.74), 0.4)
	var white_tile := Mats.surface("wtile", "wall_tiles", Color(0.95, 0.95, 0.95), 0.9, 0.3)
	var red_tile := Mats.surface("rtile", "floor_tiles", Color(1.0, 0.75, 0.7), 0.8, 0.55)
	var brick := Mats.surface("brick", "brick", Color(1, 1, 1), 0.6)
	# main hall: stage + dining
	floor_ceiling(-10, 10, -24, 0, H_HALL, hall_floor)
	wall_z(-24, -10, 10, H_HALL)
	wall_x(-10, -24, 0, H_HALL, [[-16.6, -15.4, 2.3], [-11.5, -6.5, 3.0]])
	wall_x(10, -24, 0, H_HALL, [[-13.0, -11.6, 2.3], [-3.6, -2.2, 2.3]])
	wall_z(0, -10, 10, H_HALL, [[-6.0, -3.5, 2.6], [3.5, 6.0, 2.6]])
	# backstage / maintenance
	floor_ceiling(-18, -10, -24, -15, H_ROOM, concrete)
	wall_z(-24, -18, -10, H_ROOM, [], concrete, concrete)
	wall_x(-18, -24, -15, H_ROOM, [], concrete, concrete)
	wall_z(-15, -18, -10, H_ROOM, [], concrete, concrete)
	# pirate cove alcove
	floor_ceiling(-14, -10, -12, -6, H_ROOM, dark_floor)
	wall_z(-12, -14, -10, H_ROOM, [], Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8))
	wall_z(-6, -14, -10, H_ROOM, [], Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8))
	wall_x(-14, -12, -6, H_ROOM, [], Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8))
	# restrooms
	floor_ceiling(10, 17, -17, -8, H_ROOM, Mats.surface("rfloor", "wall_tiles", Color(0.8, 0.82, 0.85), 1.2, 0.3))
	wall_z(-17, 10, 17, H_ROOM, [], white_tile, white_tile)
	wall_z(-8, 10, 17, H_ROOM, [], white_tile, white_tile)
	wall_x(17, -17, -8, H_ROOM, [], white_tile, white_tile)
	# kitchen
	floor_ceiling(10, 19, -7, 3, H_ROOM + 0.2, red_tile)
	wall_z(-7, 10, 19, H_ROOM + 0.2, [], white_tile, white_tile)
	wall_z(3, 10, 19, H_ROOM + 0.2, [[13.0, 14.2, 2.2]], white_tile, white_tile)
	wall_x(19, -7, 3, H_ROOM + 0.2, [], white_tile, brick)
	box(Vector3(13.6, 1.1, 3.05), Vector3(1.2, 2.2, 0.08), Mats.surface("metaldoor", "metal", Color(0.8, 0.8, 0.8), 0.6, 0.5, 0.6))
	label(Vector3(13.6, 2.35, 2.98), "SERVİS KAPISI", 40, Color(0.8, 0.2, 0.1), Vector3(0, 180, 0))
	# west hall + corner, east hall + corner
	floor_ceiling(-6, -3.5, 0, 19, H_ROOM, hall_floor)
	floor_ceiling(3.5, 6, 0, 19, H_ROOM, hall_floor)
	wall_x(-6, 0, 19, H_ROOM, [[5.0, 6.4, 2.3]])
	wall_x(-3.5, 0, 19, H_ROOM, [[14.6, 16.6, 2.4]])
	wall_z(19, -6, -3.5, H_ROOM)
	wall_x(6, 0, 19, H_ROOM)
	wall_x(3.5, 0, 19, H_ROOM, [[14.6, 16.6, 2.4]])
	wall_z(19, 3.5, 6, H_ROOM)
	# supply closet
	floor_ceiling(-11, -6, 3, 9, H_ROOM, concrete)
	wall_z(3, -11, -6, H_ROOM, [], concrete, concrete)
	wall_z(9, -11, -6, H_ROOM, [], concrete, concrete)
	wall_x(-11, 3, 9, H_ROOM, [], concrete, concrete)
	# office
	floor_ceiling(-3.5, 3.5, 10, 19, 2.9, Mats.surface("ofloor", "floor_tiles", Color(0.55, 0.55, 0.58), 0.7, 0.5), Mats.surface("oceil", "concrete", Color(0.3, 0.3, 0.3), 0.6))
	wall_z(10, -3.5, 3.5, 2.9, [], Mats.surface("owall", "wall_tiles", Color(0.55, 0.6, 0.62), 0.7, 0.4), Mats.surface("oplaster", "plaster", Color(0.5, 0.48, 0.45), 0.4))
	wall_z(19, -3.5, 3.5, 2.9, [], Mats.surface("owall", "wall_tiles", Color(0.55, 0.6, 0.62), 0.7, 0.4), Mats.surface("oplaster", "plaster", Color(0.5, 0.48, 0.45), 0.4))
	# fill block between halls (unreachable)
	box(Vector3(0, 1.5, 5.0), Vector3(7.0, 3.0, 10.0), Mats.surface("plaster", "plaster", Color(0.9, 0.86, 0.8), 0.35))


# ================================================================ rooms
func _stage() -> void:
	var wood := Mats.surface("stagewood", "wood", Color(0.7, 0.62, 0.55), 0.7, 0.6)
	box(Vector3(0, 0.35, -21.75), Vector3(12, 0.7, 4.5), wood)
	box(Vector3(0, 0.35, -19.48), Vector3(12, 0.7, 0.06), Mats.color(Color(0.35, 0.06, 0.05), 0.7))
	# star backdrop
	box(Vector3(0, 2.4, -23.85), Vector3(13, 4.0, 0.1), Mats.image("stage_backdrop"))
	# side curtains (red velvet)
	for sx in [-1, 1]:
		box(Vector3(sx * 6.4, 2.1, -21.0), Vector3(0.5, 4.2, 5.5), Mats.surface("velvet", "curtain", Color(1.2, 0.4, 0.4), 1.2))
	box(Vector3(0, 3.95, -19.6), Vector3(13, 0.5, 0.3), Mats.surface("velvet", "curtain", Color(1.2, 0.4, 0.4), 1.2))
	# neon sign
	var neon := label(Vector3(0, 3.45, -23.75), "GREYFANG", 160, Color(1.0, 0.25, 0.2), Vector3.ZERO, false, 0.008)
	neon.outline_size = 12
	neon.outline_modulate = Color(0.4, 0.0, 0.0)
	label(Vector3(0, 2.85, -23.75), "LAHMACUN SARAYI", 90, Color(1.0, 0.75, 0.3), Vector3.ZERO, false, 0.006)
	omni(Vector3(0, 3.2, -23.0), Color(1.0, 0.3, 0.2), 0.7, 5.0, "flicker", false, "stage")
	# speakers
	for sx in [-1, 1]:
		box(Vector3(sx * 5.3, 1.25, -22.8), Vector3(0.9, 1.1, 0.7), Mats.color(Color(0.06, 0.06, 0.06), 0.8))
		cyl(Vector3(sx * 5.3, 1.3, -22.43), 0.3, 0.3, 0.04, Mats.color(Color(0.15, 0.15, 0.15), 0.4), Vector3(90, 0, 0))
	# mic stand and small drum kit behind
	cyl(Vector3(0.4, 1.3, -20.4), 0.015, 0.015, 1.2, Mats.color(Color(0.1, 0.1, 0.1), 0.3, 0.8))
	cyl(Vector3(0.4, 0.72, -20.4), 0.2, 0.2, 0.03, Mats.color(Color(0.1, 0.1, 0.1), 0.3, 0.8))
	cyl(Vector3(-1.2, 1.0, -23.0), 0.32, 0.32, 0.5, Mats.color(Color(0.5, 0.1, 0.1), 0.4), Vector3(90, 0, 0))
	cyl(Vector3(1.4, 1.1, -23.0), 0.25, 0.25, 0.25, Mats.color(Color(0.5, 0.1, 0.1), 0.4))
	# party decorations: hanging stars
	for i in 9:
		var x := -5.0 + i * 1.25
		cyl(Vector3(x, 3.7, -20.0), 0.004, 0.004, 0.8, Mats.color(Color(0.6, 0.6, 0.6)))
		box(Vector3(x, 3.25, -20.0), Vector3(0.18, 0.18, 0.02), Mats.color(Color(0.8, 0.7, 0.3), 0.4, 0.6), Vector3(0, 0, 45))
	# stage lights (one broken)
	var s1 := spot(Vector3(-3.5, 4.0, -16.5), Vector3(-2.5, 1.5, -21), Color(0.75, 0.6, 1.0), 2.2, 9.0, 24.0, "flicker", true, "stage")
	stage_lights.append(s1)
	var s2 := spot(Vector3(3.5, 4.0, -16.5), Vector3(2.0, 1.5, -21), Color(1.0, 0.75, 0.55), 1.8, 9.0, 26.0, "steady", true, "stage")
	stage_lights.append(s2)
	spot(Vector3(0, 4.1, -17.5), Vector3(0, 1.5, -21), Color(0.9, 0.9, 1.0), 1.3, 8.0, 18.0, "buzz", false, "stage")
	spot(Vector3(0.5, 3.3, -14.5), Vector3(0, 1.9, -21), Color(1.0, 0.85, 0.7), 1.6, 10.0, 28.0, "steady", false, "stage")
	# truss
	box(Vector3(0, 4.05, -16.6), Vector3(10, 0.15, 0.15), Mats.color(Color(0.15, 0.15, 0.15), 0.4, 0.8))
	clue_spots.append({"id": "s_stage_l", "cam": "1A", "kind": "floor", "pos": Vector3(-4.5, 0.71, -19.9), "yaw": 20.0})
	clue_spots.append({"id": "s_stage_r", "cam": "1A", "kind": "surface", "pos": Vector3(5.3, 1.81, -22.6), "yaw": -10.0})
	clue_spots.append({"id": "s_stage_front", "cam": "1A", "kind": "floor", "pos": Vector3(2.2, 0.0, -18.6), "yaw": 60.0})


func _table(pos: Vector3, rot_y: float = 0.0) -> void:
	var marble := Mats.surface("marble", "marble", Color(1, 1, 1), 0.6, 0.25)
	var steel := Mats.color(Color(0.3, 0.3, 0.32), 0.35, 0.85)
	var red := Mats.color(Color(0.62, 0.07, 0.05), 0.45)
	var t := Node3D.new()
	t.position = pos
	t.rotation_degrees.y = rot_y
	root.add_child(t)
	box(Vector3(0, 0.76, 0), Vector3(1.2, 0.05, 0.8), marble, Vector3.ZERO, t)
	cyl(Vector3(0, 0.38, 0), 0.04, 0.04, 0.74, steel, Vector3.ZERO, t)
	cyl(Vector3(0, 0.02, 0), 0.28, 0.3, 0.04, steel, Vector3.ZERO, t)
	for side in [-1, 1]:
		for k in [-0.3, 0.3]:
			var c := Node3D.new()
			c.position = Vector3(k, 0, side * 0.7)
			c.rotation_degrees.y = 0.0 if side == 1 else 180.0
			if rng.randf() < 0.15:
				c.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			t.add_child(c)
			box(Vector3(0, 0.45, 0), Vector3(0.42, 0.04, 0.42), red, Vector3.ZERO, c)
			box(Vector3(0, 0.75, 0.2), Vector3(0.42, 0.55, 0.04), red, Vector3(-6, 0, 0), c)
			for lx in [-0.18, 0.18]:
				for lz in [-0.18, 0.18]:
					cyl(Vector3(lx, 0.22, lz), 0.015, 0.015, 0.45, steel, Vector3.ZERO, c)
	# tabletop details: napkin holder, pul biber, ayran glasses, old plates
	box(Vector3(0.0, 0.84, 0.0), Vector3(0.12, 0.12, 0.06), steel, Vector3.ZERO, t)
	cyl(Vector3(0.15, 0.83, 0.05), 0.03, 0.03, 0.09, Mats.color(Color(0.6, 0.1, 0.05), 0.5), Vector3.ZERO, t)
	if rng.randf() < 0.6:
		cyl(Vector3(-0.35, 0.83, 0.15), 0.035, 0.03, 0.11, Mats.color(Color(0.95, 0.95, 0.92), 0.3), Vector3.ZERO, t)
	if rng.randf() < 0.5:
		cyl(Vector3(0.3, 0.79, -0.2), 0.16, 0.14, 0.02, Mats.color(Color(0.85, 0.85, 0.8), 0.4), Vector3.ZERO, t)


func _dining() -> void:
	var cols := [-7.0, -3.2, 3.2, 7.0]
	var rows := [-14.0, -9.5, -5.0]
	for z in rows:
		for x in cols:
			_table(Vector3(x, 0, z), 0.0)
	# lights: one working, one flickering, one dead, one dim near the counter
	fluoro(Vector3(-4.5, H_HALL - 0.1, -12), "flicker", 1.3, 10.0)
	fluoro(Vector3(4.5, H_HALL - 0.1, -12), "dead")
	fluoro(Vector3(-4.5, H_HALL - 0.1, -5), "dead")
	fluoro(Vector3(4.5, H_HALL - 0.1, -5), "buzz", 1.0, 9.0)
	fluoro(Vector3(0, H_HALL - 0.1, -8.5), "strobe", 0.9, 8.0)
	# emergency exit signs (green) over the halls
	for x in [-4.75, 4.75]:
		var m := Mats.unique_emissive(Color(0.1, 0.9, 0.3), 2.0)
		box(Vector3(x, 2.85, -0.13), Vector3(0.7, 0.22, 0.04), m)
		label(Vector3(x, 2.85, -0.16), "ACİL ÇIKIŞ", 40, Color(0.9, 1.0, 0.9), Vector3(0, 180, 0), false, 0.003)
		omni(Vector3(x, 2.6, -0.5), Color(0.2, 0.9, 0.4), 0.35, 3.5, "steady")
	# service counter with cash register (KASA-1) and menu boards
	var counter_mat := Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8)
	box(Vector3(8.6, 0.55, -6.5), Vector3(0.8, 1.1, 5.0), counter_mat)
	box(Vector3(8.6, 1.12, -6.5), Vector3(0.95, 0.05, 5.1), Mats.surface("marble", "marble", Color(1, 1, 1), 0.6, 0.25))
	box(Vector3(8.6, 1.3, -5.0), Vector3(0.4, 0.3, 0.35), Mats.color(Color(0.15, 0.15, 0.16), 0.5, 0.4))
	box(Vector3(8.45, 1.5, -5.0), Vector3(0.05, 0.12, 0.25), Mats.unique_emissive(Color(0.2, 0.5, 0.25), 0.5))
	label(Vector3(8.18, 1.25, -5.0), "KASA-1", 24, Color(0.9, 0.9, 0.9), Vector3(0, -90, 0), true, 0.003)
	# glass display with dusty trays
	box(Vector3(8.6, 1.4, -7.8), Vector3(0.8, 0.5, 1.8), Mats.color(Color(0.6, 0.7, 0.7, 1.0), 0.05, 0.3))
	var steel := Mats.color(Color(0.6, 0.6, 0.62), 0.3, 0.9)
	for i in 3:
		cyl(Vector3(8.6, 1.2, -8.4 + i * 0.6), 0.22, 0.22, 0.02, steel)
	# menu boards (old 2018 prices)
	var boards := [
		["LAHMACUN", "LAHMACUN ........ 8 TL\nFINDIK LAHMACUN . 6 TL\nACILI LAHMACUN .. 9 TL\nÇİFT LAHMACUN .. 15 TL"],
		["PİDE", "KIYMALI PİDE ... 14 TL\nKAŞARLI PİDE ... 13 TL\nKUŞBAŞILI ..... 17 TL\nKARIŞIK ....... 16 TL"],
		["İÇECEK & TATLI", "AYRAN (AÇIK) .... 3 TL\nŞALGAM .......... 3 TL\nÇAY ............ 1.5 TL\nKÜNEFE ......... 12 TL"],
	]
	for i in boards.size():
		var bz := -14.0 + i * 2.6
		box(Vector3(9.86, 3.0, bz), Vector3(0.06, 1.3, 2.3), Mats.color(Color(0.08, 0.07, 0.06), 0.8))
		label(Vector3(9.82, 3.45, bz), boards[i][0], 64, Color(0.95, 0.75, 0.3), Vector3(0, -90, 0), true, 0.005)
		label(Vector3(9.82, 2.8, bz), boards[i][1], 36, Color(0.9, 0.88, 0.8), Vector3(0, -90, 0), true, 0.004)
	# wall posters & kids drawings, birthday banner
	quad_img(Vector3(-9.88, 2.4, -2.5), Vector2(2.4, 1.2), "band_poster.jpg", Vector3(0, 90, 0))
	for i in 3:
		quad_img(Vector3(-9.88, 1.6, -14.0 + i * 0.7), Vector2(0.45, 0.56), "drawing_%d" % i, Vector3(0, 90, rng.randf_range(-6, 6)))
	label(Vector3(0, 3.6, -0.15), "İYİ Kİ DOĞDUN!", 80, Color(0.9, 0.6, 0.2), Vector3(0, 180, 0), true, 0.006)
	# clock frozen at 23:47
	cyl(Vector3(-9.88, 3.0, -8.5), 0.3, 0.3, 0.04, Mats.color(Color(0.9, 0.9, 0.85), 0.5), Vector3(0, 0, 90))
	box(Vector3(-9.84, 3.0, -8.5), Vector3(0.01, 0.2, 0.02), Mats.color(Color(0.05, 0.05, 0.05)), Vector3(-0, 0, 0))
	box(Vector3(-9.83, 3.08, -8.43), Vector3(0.01, 0.02, 0.17), Mats.color(Color(0.05, 0.05, 0.05)), Vector3(70, 0, 0))
	clue_spots.append({"id": "s_din_t1", "cam": "1B", "kind": "surface", "pos": Vector3(-3.2, 0.79, -9.5), "yaw": 30.0})
	clue_spots.append({"id": "s_din_t2", "cam": "1B", "kind": "surface", "pos": Vector3(3.2, 0.79, -14.0), "yaw": -20.0})
	clue_spots.append({"id": "s_din_floor", "cam": "1B", "kind": "floor", "pos": Vector3(-1.2, 0.0, -3.0), "yaw": 70.0})
	clue_spots.append({"id": "s_din_counter", "cam": "1B", "kind": "surface", "pos": Vector3(8.6, 1.15, -4.3), "yaw": 90.0})


func _pirate_cove() -> void:
	var st := Mats.surface("stagewood", "wood", Color(0.7, 0.62, 0.55), 0.7, 0.6)
	box(Vector3(-12.2, 0.2, -9.0), Vector3(3.4, 0.4, 5.6), st)
	# curtains: two panels that can open
	curtain_l = Node3D.new()
	curtain_l.position = Vector3(-10.05, 0, -11.5)
	root.add_child(curtain_l)
	box(Vector3(0, 1.5, 1.25), Vector3(0.12, 3.0, 2.5), Mats.surface("curtain2", "curtain", Color(1.9, 1.6, 1.9), 1.5), Vector3.ZERO, curtain_l)
	curtain_r = Node3D.new()
	curtain_r.position = Vector3(-10.05, 0, -6.5)
	root.add_child(curtain_r)
	box(Vector3(0, 1.5, -1.25), Vector3(0.12, 3.0, 2.5), Mats.surface("curtain2", "curtain", Color(1.9, 1.6, 1.9), 1.5), Vector3.ZERO, curtain_r)
	# sign
	box(Vector3(-9.2, 0.6, -12.4), Vector3(0.06, 1.2, 0.06), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8))
	box(Vector3(-9.2, 1.3, -12.4), Vector3(0.05, 0.55, 1.1), Mats.surface("wood", "wood", Color(0.9, 0.85, 0.75), 0.8))
	cove_sign = label(Vector3(-9.17, 1.32, -12.4), "KAPTAN ROOK'UN\nKORSAN KÖŞESİ", 40, Color(0.95, 0.85, 0.6), Vector3(0, 90, 0), true, 0.0035)
	label(Vector3(-9.95, 3.2, -9.0), "☠", 120, Color(0.9, 0.9, 0.8), Vector3(0, 90, 0), true, 0.006)
	spot(Vector3(-9.0, 3.3, -9.0), Vector3(-10.1, 1.0, -9.0), Color(0.7, 0.4, 1.0), 1.0, 5.0, 35.0, "steady", false, "cove")
	omni(Vector3(-12.0, 2.5, -9.0), Color(0.6, 0.35, 0.8), 0.6, 4.0, "steady", false, "cove")
	spot(Vector3(-10.4, 2.9, -7.6), Vector3(-11.6, 1.2, -9.0), Color(0.75, 0.55, 1.0), 1.8, 6.0, 40.0, "buzz", false, "cove")
	clue_spots.append({"id": "s_cove_floor", "cam": "1C", "kind": "floor", "pos": Vector3(-8.6, 0.0, -10.6), "yaw": 15.0})
	clue_spots.append({"id": "s_cove_wall", "cam": "1C", "kind": "wall", "pos": Vector3(-9.89, 1.0, -5.7), "yaw": 90.0})


func _backstage() -> void:
	var wood := Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8)
	var metal := Mats.surface("metal", "metal", Color(0.9, 0.9, 0.9), 0.8, 0.5, 0.6)
	# workbench
	box(Vector3(-15.5, 0.9, -23.4), Vector3(3.0, 0.08, 0.9), wood)
	for x in [-16.9, -14.1]:
		box(Vector3(x, 0.45, -23.4), Vector3(0.08, 0.9, 0.8), metal)
	# spare heads on shelf (creepy): a spare wolf head and a bird head
	box(Vector3(-17.75, 1.6, -19.5), Vector3(0.45, 0.05, 3.5), wood)
	box(Vector3(-17.75, 2.2, -19.5), Vector3(0.45, 0.05, 3.5), wood)
	for i in 3:
		var hz := -20.8 + i * 1.2
		sph(Vector3(-17.7, 1.85, hz), 0.2, Mats.fur(Color(0.4, 0.41, 0.42) if i != 1 else Color(0.3, 0.23, 0.5)))
		sph(Vector3(-17.55, 1.9, hz - 0.08), 0.045, Mats.color(Color(0.85, 0.83, 0.78), 0.3))
		sph(Vector3(-17.55, 1.9, hz + 0.08), 0.045, Mats.color(Color(0.85, 0.83, 0.78), 0.3))
	# endoskeleton parts and wires
	for i in 5:
		cyl(Vector3(-13.0 + rng.randf_range(-1, 1), 0.05, -22.5 + rng.randf_range(-1, 1)), 0.03, 0.03, 0.8, Mats.color(Color(0.2, 0.2, 0.2), 0.4, 0.8), Vector3(90, rng.randf_range(0, 180), 0))
	# old server terminal (GFNG-SRV01)
	box(Vector3(-15.0, 1.15, -23.5), Vector3(0.5, 0.42, 0.45), Mats.color(Color(0.75, 0.72, 0.62), 0.6))
	box(Vector3(-15.0, 1.16, -23.27), Vector3(0.38, 0.3, 0.02), Mats.unique_emissive(Color(0.1, 0.35, 0.15), 0.6))
	label(Vector3(-15.0, 1.42, -23.26), "GFNG-SRV01", 20, Color(0.2, 0.2, 0.2), Vector3.ZERO, true, 0.003)
	box(Vector3(-17.0, 0.6, -16.0), Vector3(1.2, 1.2, 1.0), Mats.color(Color(0.25, 0.27, 0.25), 0.6, 0.6))
	label(Vector3(-16.38, 0.9, -16.0), "ELEKTRİK PANOSU\nYÜKSEK GERİLİM", 24, Color(0.9, 0.8, 0.1), Vector3(0, 90, 0), true, 0.003)
	bulb(Vector3(-14.0, 2.5, -19.5), "flicker", 0.9, 8.0, Color(1.0, 0.7, 0.4), true)
	clue_spots.append({"id": "s_back_bench", "cam": "5", "kind": "surface", "pos": Vector3(-16.3, 0.95, -23.2), "yaw": 10.0})
	clue_spots.append({"id": "s_back_shelf", "cam": "5", "kind": "surface", "pos": Vector3(-17.7, 1.63, -18.0), "yaw": 90.0})
	clue_spots.append({"id": "s_back_floor", "cam": "5", "kind": "floor", "pos": Vector3(-12.6, 0.0, -20.0), "yaw": 40.0})
	clue_spots.append({"id": "s_back_wall", "cam": "5", "kind": "wall", "pos": Vector3(-14.5, 1.7, -23.89), "yaw": 0.0})


func _restrooms() -> void:
	var stall := Mats.color(Color(0.45, 0.2, 0.18), 0.5)
	for i in 3:
		var z := -16.8 + i * 1.6 + 1.6
		box(Vector3(15.5, 1.0, z), Vector3(3.0, 2.0, 0.05), stall)
	box(Vector3(14.0, 1.0, -12.0), Vector3(0.05, 2.0, 0.01), stall)
	for i in 3:
		var z := -16.0 + i * 1.6
		box(Vector3(14.0, 1.0, z), Vector3(0.05, 2.0, 1.0), stall, Vector3(0, -20 if i == 1 else 0, 0))
		cyl(Vector3(16.5, 0.22, z), 0.2, 0.18, 0.44, Mats.color(Color(0.9, 0.9, 0.9), 0.2))
	# sinks + mirror
	for i in 2:
		box(Vector3(10.35, 0.85, -10.0 + i * 0.9), Vector3(0.5, 0.15, 0.6), Mats.color(Color(0.9, 0.9, 0.88), 0.2))
	box(Vector3(10.12, 1.6, -9.55), Vector3(0.03, 0.8, 1.6), Mats.color(Color(0.3, 0.32, 0.33), 0.05, 0.9))
	label(Vector3(11.0, 2.4, -7.93), "BAY  |  BAYAN", 48, Color(0.2, 0.3, 0.6), Vector3(0, 180, 0), true, 0.004)
	fluoro(Vector3(12.5, H_ROOM - 0.1, -12.5), "strobe", 1.0, 8.0)
	clue_spots.append({"id": "s_rest_sink", "cam": "7", "kind": "surface", "pos": Vector3(10.4, 0.93, -9.1), "yaw": 90.0})
	clue_spots.append({"id": "s_rest_floor", "cam": "7", "kind": "floor", "pos": Vector3(12.2, 0.0, -15.6), "yaw": 30.0})
	clue_spots.append({"id": "s_rest_wall", "cam": "7", "kind": "wall", "pos": Vector3(12.0, 1.4, -16.89), "yaw": 0.0})


func _kitchen() -> void:
	var steel := Mats.surface("steel", "metal", Color(1.1, 1.1, 1.1), 1.0, 0.35, 0.8)
	var brick := Mats.surface("brick", "brick", Color(1, 1, 1), 0.6)
	# stone oven (taş fırın): dome + arch opening
	var oven := Node3D.new()
	oven.position = Vector3(17.6, 0, -2.0)
	root.add_child(oven)
	box(Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 3.2), brick, Vector3.ZERO, oven)
	sph(Vector3(0, 1.0, 0), 1.3, brick, Vector3(1.0, 0.9, 1.2), oven)
	box(Vector3(-1.05, 1.35, 0), Vector3(0.6, 0.7, 1.2), Mats.color(Color(0.02, 0.01, 0.01)), Vector3.ZERO, oven)
	cyl(Vector3(0.2, 2.9, 0), 0.25, 0.25, 1.5, brick, Vector3.ZERO, oven)
	var ember := Mats.unique_emissive(Color(1.0, 0.3, 0.05), 0.8)
	box(Vector3(-0.9, 1.05, 0), Vector3(0.4, 0.06, 0.8), ember, Vector3.ZERO, oven)
	omni(Vector3(16.2, 1.3, -2.0), Color(1.0, 0.35, 0.1), 0.6, 4.0, "buzz", false, "kitchen")
	# wooden peel
	box(Vector3(16.0, 1.2, -0.2), Vector3(0.05, 2.0, 0.05), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8), Vector3(0, 0, -20))
	# prep counters
	box(Vector3(12.5, 0.45, -6.3), Vector3(4.5, 0.9, 0.8), steel)
	box(Vector3(12.5, 0.92, -6.3), Vector3(4.6, 0.04, 0.85), steel)
	box(Vector3(14.0, 0.45, 2.3), Vector3(4.0, 0.9, 0.8), steel)
	# dough balls, trays stack, flour sacks
	for i in 6:
		sph(Vector3(11.2 + i * 0.3, 1.0, -6.3), 0.1, Mats.color(Color(0.92, 0.88, 0.78), 0.9), Vector3(1, 0.6, 1))
	for i in 5:
		cyl(Vector3(13.8, 0.96 + i * 0.02, -6.2), 0.3, 0.3, 0.015, Mats.color(Color(0.6, 0.6, 0.62), 0.3, 0.95))
	for i in 3:
		box(Vector3(18.4, 0.3, 1.8 - i * 0.6), Vector3(0.5, 0.6, 0.4), Mats.color(Color(0.85, 0.82, 0.72), 0.95), Vector3(0, rng.randf_range(-15, 15), 0))
	# hanging metal trays on the wall
	for i in 4:
		cyl(Vector3(10.2, 2.0, -5.5 + i * 0.75), 0.3, 0.3, 0.02, Mats.color(Color(0.6, 0.6, 0.62), 0.3, 0.95), Vector3(0, 0, 90))
	# ayran fridge (glowing)
	var fridge := Node3D.new()
	fridge.position = Vector3(11.0, 0, 2.4)
	root.add_child(fridge)
	box(Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.7), Mats.color(Color(0.8, 0.1, 0.08), 0.5), Vector3.ZERO, fridge)
	var glass := Mats.unique_emissive(Color(0.65, 0.85, 1.0), 0.35)
	box(Vector3(0, 1.0, -0.36), Vector3(0.85, 1.6, 0.02), glass, Vector3.ZERO, fridge)
	for r in 4:
		for c in 4:
			cyl(Vector3(-0.3 + c * 0.2, 0.4 + r * 0.38, -0.25), 0.04, 0.045, 0.22, Mats.color(Color(0.95, 0.95, 0.95), 0.3), Vector3.ZERO, fridge)
	label(Vector3(0, 1.95, -0.37), "AYRAN", 52, Color(1, 1, 1), Vector3(0, 180, 0), false, 0.004, fridge)
	omni(Vector3(11.0, 1.2, 1.6), Color(0.6, 0.85, 1.0), 0.5, 3.5, "buzz", false, "kitchen")
	fluoro(Vector3(13.5, H_ROOM + 0.1, -2.5), "flicker", 0.8, 8.0)
	clue_spots.append({"id": "s_kit_counter", "cam": "6", "kind": "surface", "pos": Vector3(12.0, 0.95, -6.1), "yaw": 0.0})
	clue_spots.append({"id": "s_kit_counter2", "cam": "6", "kind": "surface", "pos": Vector3(14.8, 0.95, 2.2), "yaw": 180.0})
	clue_spots.append({"id": "s_kit_floor", "cam": "6", "kind": "floor", "pos": Vector3(15.2, 0.0, -3.8), "yaw": 50.0})
	clue_spots.append({"id": "s_kit_wall", "cam": "6", "kind": "wall", "pos": Vector3(13.0, 1.6, -6.89), "yaw": 0.0})


func _supply() -> void:
	var wood := Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8)
	for i in 3:
		box(Vector3(-10.7, 0.5 + i * 0.6, 6.0), Vector3(0.5, 0.04, 5.0), wood)
	for i in 10:
		box(Vector3(-10.7, 0.66 + (i % 3) * 0.6, 4.0 + i * 0.4), Vector3(0.4, 0.28, 0.35), Mats.color(Color(0.62, 0.48, 0.3), 0.9))
	label(Vector3(-10.48, 0.66, 4.4), "PEÇETE", 20, Color(0.1, 0.1, 0.1), Vector3(0, 90, 0), true, 0.003)
	label(Vector3(-10.48, 1.26, 5.6), "KARTON TABAK", 20, Color(0.1, 0.1, 0.1), Vector3(0, 90, 0), true, 0.003)
	box(Vector3(-7.0, 0.35, 3.5), Vector3(0.7, 0.7, 0.6), Mats.color(Color(0.6, 0.46, 0.28), 0.9))
	box(Vector3(-7.2, 0.95, 3.6), Vector3(0.5, 0.5, 0.5), Mats.color(Color(0.58, 0.44, 0.27), 0.9), Vector3(0, 20, 0))
	cyl(Vector3(-8.2, 0.2, 8.4), 0.2, 0.18, 0.4, Mats.color(Color(0.8, 0.7, 0.1), 0.6))
	cyl(Vector3(-8.2, 0.9, 8.5), 0.015, 0.015, 1.4, wood, Vector3(10, 0, 0))
	# wall clock (from the footage clue)
	cyl(Vector3(-8.5, 2.2, 8.88), 0.22, 0.22, 0.04, Mats.color(Color(0.9, 0.9, 0.85), 0.5), Vector3(90, 0, 0))
	bulb(Vector3(-8.5, 2.5, 6.0), "flicker", 0.6, 6.0)
	clue_spots.append({"id": "s_sup_shelf", "cam": "3", "kind": "surface", "pos": Vector3(-10.6, 1.13, 7.2), "yaw": 90.0})
	clue_spots.append({"id": "s_sup_floor", "cam": "3", "kind": "floor", "pos": Vector3(-9.0, 0.0, 7.6), "yaw": 10.0})
	clue_spots.append({"id": "s_sup_box", "cam": "3", "kind": "surface", "pos": Vector3(-7.0, 0.71, 3.5), "yaw": -30.0})


func _halls() -> void:
	# posters, bench, extinguisher
	quad_img(Vector3(-5.89, 1.7, 3.0), Vector2(1.6, 0.85), "band_poster.jpg", Vector3(0, 90, 0))
	quad_img(Vector3(5.89, 1.7, 3.0), Vector2(1.6, 0.85), "band_poster.jpg", Vector3(0, -90, 0))
	for i in 3:
		quad_img(Vector3(-3.61, 1.5, 7.0 + i * 0.6), Vector2(0.4, 0.5), "drawing_%d" % i, Vector3(0, -90, rng.randf_range(-8, 8)))
		quad_img(Vector3(3.61, 1.5, 6.0 + i * 0.6), Vector2(0.4, 0.5), "drawing_%d" % ((i + 1) % 3), Vector3(0, 90, rng.randf_range(-8, 8)))
	box(Vector3(5.7, 0.25, 8.0), Vector3(0.4, 0.06, 1.6), Mats.surface("wood", "wood", Color(0.8, 0.8, 0.8), 0.8))
	cyl(Vector3(-5.85, 0.4, 12.5), 0.09, 0.09, 0.55, Mats.color(Color(0.75, 0.05, 0.03), 0.4))
	label(Vector3(5.89, 2.3, 11.5), "ÇOCUK DOĞUM GÜNÜ\nPAKETLERİ — SORUNUZ!", 32, Color(0.85, 0.5, 0.2), Vector3(0, -90, 0), true, 0.004)
	label(Vector3(-5.89, 2.3, 11.5), "GECE 23.00'TEN SONRA\nPERSONEL KALAMAZ", 30, Color(0.8, 0.15, 0.1), Vector3(0, 90, 0), true, 0.004)
	# hall lights
	bulb(Vector3(-4.75, 2.6, 4.0), "flicker", 0.5, 6.0, Color(1.0, 0.8, 0.55))
	bulb(Vector3(4.75, 2.6, 6.0), "buzz", 0.45, 6.0, Color(1.0, 0.8, 0.55))
	omni(Vector3(-4.75, 2.7, 12.0), Color(0.9, 0.2, 0.15), 0.25, 4.0, "steady")
	omni(Vector3(4.75, 2.7, 12.0), Color(0.9, 0.2, 0.15), 0.25, 4.0, "steady")
	# door spot lights (player-controlled)
	office["light_left"] = spot(Vector3(-3.9, 2.85, 14.9), Vector3(-5.0, 1.0, 15.7), Color(0.95, 0.95, 0.85), 0.0, 6.0, 55.0, "manual", true)
	office["light_right"] = spot(Vector3(3.9, 2.85, 14.9), Vector3(5.0, 1.0, 15.7), Color(0.95, 0.95, 0.85), 0.0, 6.0, 55.0, "manual", true)
	clue_spots.append({"id": "s_wh_floor", "cam": "2A", "kind": "floor", "pos": Vector3(-4.4, 0.0, 6.5), "yaw": 30.0})
	clue_spots.append({"id": "s_wh_wall", "cam": "2A", "kind": "wall", "pos": Vector3(-3.61, 0.9, 9.0), "yaw": -90.0})
	clue_spots.append({"id": "s_wc_floor", "cam": "2B", "kind": "floor", "pos": Vector3(-5.3, 0.0, 10.8), "yaw": 70.0})
	clue_spots.append({"id": "s_wc_wall", "cam": "2B", "kind": "wall", "pos": Vector3(-5.89, 1.5, 10.6), "yaw": 90.0})
	clue_spots.append({"id": "s_eh_floor", "cam": "4A", "kind": "floor", "pos": Vector3(5.0, 0.0, 5.0), "yaw": -20.0})
	clue_spots.append({"id": "s_eh_bench", "cam": "4A", "kind": "surface", "pos": Vector3(5.7, 0.29, 8.4), "yaw": 90.0})
	clue_spots.append({"id": "s_ec_floor", "cam": "4B", "kind": "floor", "pos": Vector3(5.2, 0.0, 10.9), "yaw": -60.0})
	clue_spots.append({"id": "s_ec_wall", "cam": "4B", "kind": "wall", "pos": Vector3(5.89, 1.3, 10.5), "yaw": -90.0})


func _office() -> void:
	var desk_wood := Mats.surface("deskwood", "wood", Color(0.55, 0.5, 0.45), 0.9)
	var steel := Mats.surface("metal", "metal", Color(0.9, 0.9, 0.9), 0.8, 0.5, 0.6)
	# desk
	box(Vector3(0, 0.78, 12.4), Vector3(3.6, 0.07, 1.1), desk_wood)
	box(Vector3(-1.4, 0.38, 12.4), Vector3(0.7, 0.76, 1.0), desk_wood)
	box(Vector3(1.4, 0.38, 12.4), Vector3(0.7, 0.76, 1.0), desk_wood)
	for d in 2:
		box(Vector3(-1.4, 0.25 + d * 0.3, 12.95), Vector3(0.6, 0.22, 0.02), Mats.color(Color(0.15, 0.13, 0.12), 0.6))
	# CRT monitors
	for i in 2:
		var x := -0.7 + i * 1.3
		box(Vector3(x, 1.05, 12.25), Vector3(0.55, 0.45, 0.5), Mats.color(Color(0.72, 0.7, 0.62), 0.6))
		var scr := Mats.unique_emissive(Color(0.15, 0.4, 0.2), 0.7)
		box(Vector3(x, 1.06, 12.51), Vector3(0.44, 0.34, 0.02), scr)
		lights.append({"light": null, "mat": scr, "energy": 0.7, "mode": "buzz", "group": "office", "phase": rng.randf() * 10.0})
	label(Vector3(-0.7, 1.08, 12.53), "GÜVENLİK\nSİSTEMİ v2.3\n> BAĞLI", 22, Color(0.5, 1.0, 0.6), Vector3.ZERO, false, 0.003)
	label(Vector3(0.6, 1.08, 12.53), "ELEKTRİK\nŞEBEKE: ESKİ\nYEDEK: YOK", 22, Color(0.5, 1.0, 0.6), Vector3.ZERO, false, 0.003)
	# fan
	var fan := Node3D.new()
	fan.position = Vector3(1.35, 0.82, 12.3)
	root.add_child(fan)
	cyl(Vector3(0, 0.02, 0), 0.12, 0.14, 0.04, steel, Vector3.ZERO, fan)
	cyl(Vector3(0, 0.2, 0), 0.02, 0.02, 0.36, steel, Vector3.ZERO, fan)
	var cage := TorusMesh.new()
	cage.inner_radius = 0.2
	cage.outer_radius = 0.22
	var cm := MeshInstance3D.new()
	cm.mesh = cage
	cm.material_override = steel
	cm.position = Vector3(0, 0.45, 0.02)
	cm.rotation_degrees = Vector3(90, 0, 0)
	fan.add_child(cm)
	fan_blades = Node3D.new()
	fan_blades.position = Vector3(0, 0.45, 0.04)
	fan.add_child(fan_blades)
	for k in 3:
		var bl := box(Vector3(0, 0.1, 0), Vector3(0.09, 0.18, 0.01), Mats.color(Color(0.3, 0.3, 0.3), 0.4, 0.7), Vector3.ZERO, null)
		bl.get_parent().remove_child(bl)
		var arm := Node3D.new()
		arm.rotation_degrees = Vector3(0, 0, k * 120.0)
		fan_blades.add_child(arm)
		arm.add_child(bl)
	fan.rotation_degrees.y = -20.0
	# tea glass on saucer, papers, phone, lahmacun box
	cyl(Vector3(-1.5, 0.82, 12.2), 0.06, 0.06, 0.008, Mats.color(Color(0.85, 0.85, 0.85), 0.3))
	cyl(Vector3(-1.5, 0.87, 12.2), 0.028, 0.022, 0.09, Mats.color(Color(0.6, 0.15, 0.05, 1.0), 0.05))
	for i in 4:
		box(Vector3(-0.1 + rng.randf_range(-0.4, 0.4), 0.82 + i * 0.003, 12.55 + rng.randf_range(-0.1, 0.05)), Vector3(0.21, 0.002, 0.3), Mats.color(Color(0.9, 0.88, 0.8), 0.9), Vector3(0, rng.randf_range(-30, 30), 0))
	box(Vector3(1.6, 0.86, 12.6), Vector3(0.35, 0.06, 0.35), Mats.color(Color(0.85, 0.75, 0.55), 0.9))
	label(Vector3(1.6, 0.893, 12.6), "GREYFANG", 20, Color(0.6, 0.1, 0.05), Vector3(-90, 0, 0), true, 0.003)
	box(Vector3(-1.0, 0.84, 12.65), Vector3(0.2, 0.06, 0.12), Mats.color(Color(0.15, 0.15, 0.15), 0.5))
	# hanging lamp
	cyl(Vector3(0, 2.6, 14.2), 0.005, 0.005, 0.6, Mats.color(Color(0.05, 0.05, 0.05)))
	cyl(Vector3(0, 2.25, 14.2), 0.08, 0.3, 0.2, Mats.color(Color(0.2, 0.25, 0.2), 0.5, 0.4))
	var lm := Mats.unique_emissive(Color(1.0, 0.75, 0.45), 3.0)
	sph(Vector3(0, 2.13, 14.2), 0.06, lm)
	var lamp := omni(Vector3(0, 2.0, 14.2), Color(1.0, 0.72, 0.45), 1.1, 7.0, "office_lamp", true, "office")
	lights[lights.size() - 1]["mat"] = lm
	office["lamp"] = lamp
	# poster, drawings, calendar frozen in March 2018
	quad_img(Vector3(0.0, 2.0, 10.12), Vector2(2.2, 1.2), "band_poster.jpg")
	label(Vector3(0.0, 2.68, 10.12), "KUTLAYALIM!", 72, Color(0.9, 0.3, 0.2), Vector3.ZERO, true, 0.005)
	for i in 3:
		quad_img(Vector3(1.6 + i * 0.45, 1.6, 10.12), Vector2(0.38, 0.48), "drawing_%d" % i, Vector3(0, 0, rng.randf_range(-8, 8)))
	box(Vector3(-2.2, 1.7, 10.12), Vector3(0.5, 0.6, 0.01), Mats.color(Color(0.92, 0.9, 0.85), 0.9))
	label(Vector3(-2.2, 1.85, 10.14), "MART 2018", 36, Color(0.7, 0.1, 0.1), Vector3.ZERO, true, 0.003)
	label(Vector3(-2.2, 1.62, 10.14), "Pt Sa Ça Pe Cu Ct Pz\n         1  2  3  4\n 5  6  7  8  9 10 11\n12 13 [14] 15 16 17 18", 16, Color(0.1, 0.1, 0.1), Vector3.ZERO, true, 0.0022)
	# side walls: door frames + button panels
	for side in [-1, 1]:
		var x: float = side * 3.5
		box(Vector3(x - side * 0.02, 2.45, 15.6), Vector3(0.28, 0.12, 2.2), Mats.color(Color(0.2, 0.2, 0.2), 0.4, 0.8))
		for zz in [14.55, 16.65]:
			box(Vector3(x - side * 0.02, 1.2, zz), Vector3(0.28, 2.4, 0.12), Mats.color(Color(0.2, 0.2, 0.2), 0.4, 0.8))
		# hazard stripes
		box(Vector3(x - side * 0.17, 2.36, 15.6), Vector3(0.02, 0.06, 2.0), Mats.color(Color(0.8, 0.65, 0.1), 0.5))
		# shutter door
		var door := box(Vector3(x, 3.7, 15.6), Vector3(0.1, 2.4, 2.0), Mats.surface("shutter", "metal", Color(0.7, 0.7, 0.72), 1.5, 0.45, 0.7))
		for k in 6:
			box(Vector3(side * -0.06, -1.0 + k * 0.4, 0), Vector3(0.02, 0.04, 1.96), Mats.color(Color(0.25, 0.25, 0.25), 0.4, 0.8), Vector3.ZERO, door)
		office["door_" + ("left" if side < 0 else "right")] = door
		# button panel
		var panel := Node3D.new()
		panel.position = Vector3(x - side * 0.12, 1.35, 13.8)
		root.add_child(panel)
		box(Vector3.ZERO, Vector3(0.04, 0.6, 0.3), Mats.color(Color(0.35, 0.35, 0.33), 0.5, 0.5), Vector3.ZERO, panel)
		var sname := "left" if side < 0 else "right"
		var dbm := Mats.unique_emissive(Color(0.8, 0.1, 0.05), 0.3)
		var lbm := Mats.unique_emissive(Color(0.9, 0.9, 0.85), 0.2)
		cyl(Vector3(-side * 0.03, 0.13, 0), 0.07, 0.07, 0.05, dbm, Vector3(0, 0, 90), panel)
		cyl(Vector3(-side * 0.03, -0.13, 0), 0.07, 0.07, 0.05, lbm, Vector3(0, 0, 90), panel)
		label(Vector3(-side * 0.025, 0.24, 0), "KAPI", 18, Color(0.9, 0.9, 0.9), Vector3(0, -side * 90.0, 0), true, 0.0025, panel)
		label(Vector3(-side * 0.025, -0.02, 0), "IŞIK", 18, Color(0.9, 0.9, 0.9), Vector3(0, -side * 90.0, 0), true, 0.0025, panel)
		office["btn_mat_door_" + sname] = dbm
		office["btn_mat_light_" + sname] = lbm
		_button_area(panel, Vector3(-side * 0.03, 0.13, 0), "door_" + sname)
		_button_area(panel, Vector3(-side * 0.03, -0.13, 0), "light_" + sname)
	# chair (behind the player, mostly unseen)
	box(Vector3(0, 0.5, 17.1), Vector3(0.6, 0.08, 0.6), Mats.color(Color(0.1, 0.1, 0.1), 0.6))
	# player head anchor
	var head := Node3D.new()
	head.name = "PlayerHead"
	head.position = Vector3(0, 1.3, 16.7)
	root.add_child(head)
	office["head"] = head
	var cam := Camera3D.new()
	cam.name = "OfficeCam"
	cam.fov = 78.0
	cam.near = 0.05
	cam.far = 80.0
	head.add_child(cam)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	office["cam"] = cam
	var lis := AudioListener3D.new()
	head.add_child(lis)
	lis.make_current()   # the player always hears from the office, even on cameras
	office["listener"] = lis


func _button_area(parent: Node3D, pos: Vector3, action: String) -> void:
	var a := Area3D.new()
	a.collision_layer = 4
	a.collision_mask = 0
	a.position = pos
	a.set_meta("btn", action)
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(0.12, 0.2, 0.2)
	cs.shape = s
	a.add_child(cs)
	parent.add_child(a)


# ================================================================ cameras
func _cam(id: String, pos: Vector3, look: Vector3, pan: float = 14.0, fov: float = 70.0) -> void:
	var c := Camera3D.new()
	c.name = "Cam_" + id
	c.fov = fov
	c.near = 0.05
	c.far = 60.0
	c.environment = cam_env
	root.add_child(c)
	c.look_at_from_position(pos, look, Vector3.UP)
	# camera housing visible from other cams
	box(pos + Vector3(0, 0.12, 0), Vector3(0.18, 0.12, 0.28), Mats.color(Color(0.8, 0.8, 0.78), 0.5))
	var red := Mats.unique_emissive(Color(1, 0.05, 0.05), 3.0)
	sph(pos + Vector3(0, 0.2, 0), 0.02, red)
	cams[id] = {"node": c, "name": CAM_NAMES[id], "yaw0": c.rotation.y, "pitch": c.rotation.x, "pan": deg_to_rad(pan), "pos": pos}


func _cameras() -> void:
	_cam("1A", Vector3(0.0, 3.4, -14.8), Vector3(0, 1.6, -21.5), 10.0, 64.0)
	_cam("1B", Vector3(8.6, 3.7, -0.8), Vector3(-2.0, 0.6, -10.0), 16.0, 72.0)
	_cam("1C", Vector3(-4.5, 3.0, -3.5), Vector3(-10.5, 1.2, -9.0), 8.0, 62.0)
	_cam("5", Vector3(-10.6, 2.75, -15.6), Vector3(-15.5, 0.6, -21.5), 12.0, 72.0)
	_cam("7", Vector3(16.6, 2.75, -8.4), Vector3(11.0, 0.8, -14.5), 10.0, 72.0)
	_cam("6", Vector3(10.4, 2.9, 2.6), Vector3(16.0, 0.8, -4.0), 12.0, 72.0)
	_cam("3", Vector3(-6.4, 2.65, 8.6), Vector3(-10.0, 0.6, 4.2), 10.0, 72.0)
	_cam("2A", Vector3(-4.75, 2.75, 0.4), Vector3(-4.75, 0.6, 11.0), 6.0, 68.0)
	_cam("2B", Vector3(-3.75, 2.75, 14.3), Vector3(-5.0, 0.5, 10.2), 6.0, 74.0)
	_cam("4A", Vector3(4.75, 2.75, 0.4), Vector3(4.75, 0.6, 11.0), 6.0, 68.0)
	_cam("4B", Vector3(3.75, 2.75, 14.3), Vector3(5.0, 0.5, 10.2), 6.0, 74.0)
	var menu := Camera3D.new()
	menu.name = "MenuCam"
	menu.fov = 55.0
	root.add_child(menu)
	menu.look_at_from_position(Vector3(1.2, 1.7, -14.0), Vector3(0, 1.6, -21.0), Vector3.UP)
	office["menu_cam"] = menu


# ================================================================ AI spots
func _spots() -> void:
	# [position, yaw_deg]; yaw 0 faces +Z (south), 180 faces north
	spots = {
		"stage": {"benny": [Vector3(-2.6, 0.7, -21.0), 0.0], "grayson": [Vector3(0.0, 0.7, -21.2), 0.0], "brutus": [Vector3(2.6, 0.7, -21.0), 0.0]},
		"dining": {"benny": [Vector3(-5.1, 0, -7.3), 40.0], "grayson": [Vector3(0.0, 0, -11.7), 150.0], "brutus": [Vector3(5.1, 0, -7.3), 70.0]},
		"cove": {"rook": [Vector3(-12.2, 0.4, -9.0), 90.0]},
		"backstage": {"benny": [Vector3(-15.0, 0, -20.3), 40.0]},
		"supply": {"benny": [Vector3(-9.2, 0, 5.4), 40.0]},
		"whall": {"benny": [Vector3(-4.75, 0, 6.5), 180.0]},
		"wcorner": {"benny": [Vector3(-4.85, 0, 11.4), 15.0]},
		"ldoor": {"benny": [Vector3(-5.0, 0, 15.6), 90.0], "grayson": [Vector3(-4.95, 0, 15.6), 90.0], "rook": [Vector3(-4.9, 0, 15.6), 90.0]},
		"restroom": {"grayson": [Vector3(12.6, 0, -10.2), 60.0], "brutus": [Vector3(13.0, 0, -13.2), 40.0]},
		"kitchen": {"grayson": [Vector3(12.3, 0, 0.0), 160.0], "brutus": [Vector3(14.6, 0, -2.6), -130.0]},
		"ehall": {"grayson": [Vector3(4.75, 0, 5.0), 180.0], "brutus": [Vector3(4.75, 0, 7.6), 180.0]},
		"ecorner": {"grayson": [Vector3(4.7, 0, 11.3), -15.0], "brutus": [Vector3(4.95, 0, 12.4), -10.0]},
		"rdoor": {"grayson": [Vector3(4.95, 0, 15.6), -90.0], "brutus": [Vector3(4.9, 0, 15.6), -90.0]},
		"office": {"grayson": [Vector3(2.7, 0, 18.4), -150.0], "golden": [Vector3(0.0, 0, 14.0), 0.0]},
		"golden_2b": {"golden": [Vector3(-5.55, 0, 11.0), 70.0]},
		"golden_stage": {"golden": [Vector3(1.4, 0.7, -20.4), 0.0]},
		"hidden": {},
	}
	rook_path = [Vector3(-12.2, 0.4, -9.0), Vector3(-9.0, 0.0, -8.4), Vector3(-8.9, 0, -2.6), Vector3(-4.75, 0, -0.8), Vector3(-4.75, 0, 13.6), Vector3(-4.5, 0, 15.6)]


func spot_for(loc: String, who: String) -> Array:
	var d: Dictionary = spots.get(loc, {})
	if d.has(who):
		return d[who]
	return [Vector3(0, -50, 0), 0.0]
