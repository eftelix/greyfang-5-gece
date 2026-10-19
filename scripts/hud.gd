class_name HUD
extends CanvasLayer
## In-night interface: office overlay, camera feed UI + map, power/time,
## voicemail subtitles, toasts, flashes and hallucinations.

var nc: NightController
var root: Control
var fx: ColorRect
var fx_mat: ShaderMaterial
var cam_ui: Control
var office_ui: Control
var lbl_night: Label
var lbl_clock: Label
var lbl_power: Label
var usage_bars: Array = []
var lbl_cam: Label
var lbl_cam_name: Label
var lbl_rec: Label
var lbl_audio_only: Label
var lbl_clues: Label
var lbl_hint: Label
var lbl_tip: Label
var map_panel: Control
var map_buttons: Dictionary = {}
var monitor_bar: Panel
var toast_box: VBoxContainer
var flash_rect: ColorRect
var halluc: Label
var sub_panel: PanelContainer
var sub_label: RichTextLabel
var sub_hint: Label
var _flash_t: float = 0.0
var _flash_dur: float = 0.0
var _flash_c: Color = Color(0, 0, 0, 0)
var _halluc_t: float = 0.0
var _sub_full: String = ""
var _sub_chars: float = 0.0
var _golden_face: bool = false
var hint_t: float = 0.0
var monitor_hover_armed: bool = true
var _t: float = 0.0

const MAP_ORIGIN := Vector2(10, 4)
const MAP_SCALE := 7.0


func build(controller: NightController) -> void:
	nc = controller
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	fx = ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://assets/shaders/screen_fx.gdshader")
	fx.material = fx_mat
	root.add_child(fx)
	_build_office_ui()
	_build_cam_ui()
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(0, 0, 0, 0)
	root.add_child(flash_rect)
	halluc = _label("", 72, Color(0.9, 0.8, 0.3))
	halluc.set_anchors_preset(Control.PRESET_FULL_RECT)
	halluc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	halluc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	halluc.visible = false
	root.add_child(halluc)
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-300, 70)
	toast_box.size = Vector2(600, 200)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)
	_build_subtitles()


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_office_ui() -> void:
	office_ui = Control.new()
	office_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	office_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(office_ui)
	lbl_night = _label("GECE 1", 30, Color(0.92, 0.9, 0.85))
	lbl_night.position = Vector2(24, 16)
	root.add_child(lbl_night)
	lbl_clock = _label("00:00", 44, Color(0.95, 0.95, 0.95))
	lbl_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_clock.position = Vector2(-170, 10)
	lbl_clock.size = Vector2(150, 50)
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_clock)
	var pw := Control.new()
	pw.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pw.position = Vector2(24, -96)
	pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pw)
	lbl_power = _label("Güç: 100%", 26, Color(0.95, 0.95, 0.9))
	pw.add_child(lbl_power)
	var ul := _label("Kullanım:", 22, Color(0.85, 0.85, 0.8))
	ul.position = Vector2(0, 38)
	pw.add_child(ul)
	for i in 5:
		var r := ColorRect.new()
		r.size = Vector2(16, 26)
		r.position = Vector2(110 + i * 20, 38)
		r.color = Color(0.2, 0.2, 0.2)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pw.add_child(r)
		usage_bars.append(r)
	monitor_bar = Panel.new()
	monitor_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	monitor_bar.position = Vector2(-260, -46)
	monitor_bar.size = Vector2(520, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.55)
	sb.border_color = Color(0.85, 0.85, 0.85, 0.7)
	sb.set_border_width_all(2)
	monitor_bar.add_theme_stylebox_override("panel", sb)
	monitor_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(monitor_bar)
	var ml := _label("▲   KAMERALAR  [BOŞLUK]   ▲", 18, Color(0.9, 0.9, 0.9))
	ml.set_anchors_preset(Control.PRESET_FULL_RECT)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	monitor_bar.add_child(ml)
	lbl_hint = _label("Q / E: Kapılar     A / D: Koridor ışıkları     BOŞLUK: Kameralar     J: Kanıt günlüğü     Fare kenarlara: Etrafa bak", 17, Color(0.8, 0.8, 0.75))
	lbl_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_hint.position = Vector2(-520, -84)
	lbl_hint.size = Vector2(1040, 30)
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_hint)


func _build_cam_ui() -> void:
	cam_ui = Control.new()
	cam_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_ui.visible = false
	root.add_child(cam_ui)
	# border frame
	var frame := ReferenceRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 14
	frame.offset_top = 14
	frame.offset_right = -14
	frame.offset_bottom = -14
	frame.border_color = Color(0.85, 0.85, 0.85, 0.6)
	frame.border_width = 2
	frame.editor_only = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_ui.add_child(frame)
	lbl_rec = _label("● REC", 24, Color(1.0, 0.15, 0.1))
	lbl_rec.position = Vector2(36, 64)
	cam_ui.add_child(lbl_rec)
	lbl_cam = _label("CAM 1A", 40, Color(0.95, 0.95, 0.95))
	lbl_cam.position = Vector2(36, 128)
	cam_ui.add_child(lbl_cam)
	lbl_cam_name = _label("Sahne", 24, Color(0.85, 0.85, 0.85))
	lbl_cam_name.position = Vector2(38, 174)
	cam_ui.add_child(lbl_cam_name)
	lbl_audio_only = _label("", 34, Color(0.95, 0.95, 0.95))
	lbl_audio_only.set_anchors_preset(Control.PRESET_CENTER)
	lbl_audio_only.position = Vector2(-300, -120)
	lbl_audio_only.size = Vector2(600, 60)
	lbl_audio_only.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cam_ui.add_child(lbl_audio_only)
	lbl_clues = _label("", 18, Color(0.85, 0.8, 0.55))
	lbl_clues.position = Vector2(36, 100)
	cam_ui.add_child(lbl_clues)
	lbl_tip = _label("", 20, Color(1.0, 0.9, 0.5))
	lbl_tip.visible = false
	cam_ui.add_child(lbl_tip)
	# map
	map_panel = Control.new()
	map_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	map_panel.position = Vector2(-320, -345)
	map_panel.size = Vector2(300, 330)
	map_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	cam_ui.add_child(map_panel)
	map_panel.draw.connect(_draw_map)
	var cam_pos := {
		"1A": Vector3(0, 0, -21.5), "1B": Vector3(0, 0, -10.0), "1C": Vector3(-13.2, 0, -9), "5": Vector3(-15.5, 0, -20.5),
		"7": Vector3(14.0, 0, -13.0), "6": Vector3(15.0, 0, -2.0), "3": Vector3(-11.5, 0, 6.0),
		"2A": Vector3(-4.75, 0, 4.0), "2B": Vector3(-4.75, 0, 13.0), "4A": Vector3(4.75, 0, 4.0), "4B": Vector3(4.75, 0, 13.0),
	}
	for id in cam_pos.keys():
		var b := Button.new()
		b.text = "CAM\n" + id
		b.add_theme_font_size_override("font_size", 11)
		b.size = Vector2(40, 32)
		b.custom_minimum_size = Vector2(40, 32)
		b.position = _map_pt(cam_pos[id]) - Vector2(20, 16)
		b.focus_mode = Control.FOCUS_NONE
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.25, 0.25, 0.25, 0.95)
		n.border_color = Color(0.9, 0.9, 0.9)
		n.set_border_width_all(2)
		var s := n.duplicate()
		s.bg_color = Color(0.55, 0.75, 0.1, 0.95)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", n.duplicate())
		b.add_theme_stylebox_override("pressed", s)
		b.set_meta("sel", s)
		b.set_meta("norm", n)
		b.pressed.connect(func(): nc.select_cam(id))
		map_panel.add_child(b)
		map_buttons[id] = b
	var you := _label("SEN ■", 12, Color(1, 1, 1))
	you.position = _map_pt(Vector3(0.0, 0, 15.5)) - Vector2(16, 6)
	map_panel.add_child(you)


func _map_pt(w: Vector3) -> Vector2:
	return MAP_ORIGIN + Vector2((w.x + 19.0) * MAP_SCALE, (w.z + 24.5) * MAP_SCALE)


func _draw_map() -> void:
	var c := Color(0.9, 0.9, 0.9, 0.85)
	var rooms := [
		[-10, 10, -24, 0], [-18, -10, -24, -15], [-14, -10, -12, -6], [10, 17, -17, -8], [10, 19, -7, 3],
		[-6, -3.5, 0, 19], [3.5, 6, 0, 19], [-11, -6, 3, 9], [-3.5, 3.5, 10, 19],
	]
	map_panel.draw_rect(Rect2(Vector2.ZERO, map_panel.size), Color(0, 0, 0, 0.45))
	for r in rooms:
		var a := _map_pt(Vector3(r[0], 0, r[2]))
		var b := _map_pt(Vector3(r[1], 0, r[3]))
		map_panel.draw_rect(Rect2(a, b - a), c, false, 2.0)
	# stage
	var s0 := _map_pt(Vector3(-6, 0, -24))
	var s1 := _map_pt(Vector3(6, 0, -19.5))
	map_panel.draw_rect(Rect2(s0, s1 - s0), Color(0.9, 0.9, 0.9, 0.35), true)


func set_night(n: int) -> void:
	lbl_night.text = "GECE %d" % n
	hint_t = 25.0 if n == 1 else 10.0


func _process(delta: float) -> void:
	_t += delta
	if nc == null:
		return
	var up := nc.monitor_up
	cam_ui.visible = up and nc.active
	office_ui.visible = not up
	monitor_bar.visible = nc.active and not nc.power_out and not nc.dying
	lbl_clock.text = nc.clock_text()
	lbl_power.text = "Güç: %d%%" % int(ceil(nc.power))
	lbl_power.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if nc.power < 15.0 else Color(0.95, 0.95, 0.9))
	var u := nc.usage()
	for i in usage_bars.size():
		var col := Color(0.2, 0.2, 0.2)
		if i < u:
			col = Color(0.3, 0.9, 0.3) if i < 2 else (Color(0.95, 0.85, 0.2) if i < 3 else Color(0.95, 0.25, 0.2))
		usage_bars[i].color = col
	if hint_t > 0.0:
		hint_t -= delta
		lbl_hint.modulate.a = clamp(hint_t / 3.0, 0.0, 1.0)
	lbl_hint.visible = hint_t > 0.0 and not up
	# post effect
	if _golden_face:
		fx_mat.set_shader_parameter("noise_amt", 0.35 + randf() * 0.3)
		fx_mat.set_shader_parameter("glitch", 1.0)
		fx_mat.set_shader_parameter("tint", Vector3(1.0, 0.85, 0.4))
		fx_mat.set_shader_parameter("tint_amt", 0.6)
	elif up:
		var g := nc.cam_glitch
		var noise := 0.12
		var dark := 0.0
		lbl_audio_only.text = ""
		if nc.cur_cam == "6":
			# broken kitchen camera: picture drops out, audio keeps working
			var on := fmod(_t * 0.9, 3.0) < 1.1 or fmod(_t * 2.3, 1.0) < 0.1
			if not on:
				dark = 0.97
				noise = 0.4
				lbl_audio_only.text = "GÖRÜNTÜ YOK — SADECE SES"
		fx_mat.set_shader_parameter("noise_amt", noise + (0.08 if nc.golden_state == "cam" and nc.cur_cam == "2B" else 0.0))
		fx_mat.set_shader_parameter("glitch", clamp(g, 0.0, 1.0))
		fx_mat.set_shader_parameter("barrel", 0.12)
		fx_mat.set_shader_parameter("scan_amt", 0.16)
		fx_mat.set_shader_parameter("tint_amt", 0.5)
		fx_mat.set_shader_parameter("tint", Vector3(0.85, 1.0, 0.9))
		fx_mat.set_shader_parameter("vignette", 1.3)
		fx_mat.set_shader_parameter("dark", dark)
		if g > 0.9:
			lbl_audio_only.text = "SİNYAL KESİNTİSİ"
	else:
		fx_mat.set_shader_parameter("noise_amt", 0.045 if not nc.power_out else 0.08)
		fx_mat.set_shader_parameter("glitch", 0.0 if nc.golden_state != "office" else 0.12)
		fx_mat.set_shader_parameter("barrel", 0.0)
		fx_mat.set_shader_parameter("scan_amt", 0.0)
		fx_mat.set_shader_parameter("tint_amt", 0.15 if nc.golden_state != "office" else 0.5)
		fx_mat.set_shader_parameter("tint", Vector3(1.0, 0.92, 0.82) if nc.golden_state != "office" else Vector3(1.0, 0.85, 0.3))
		fx_mat.set_shader_parameter("vignette", 1.9)
		fx_mat.set_shader_parameter("dark", 0.0)
	if up:
		lbl_rec.visible = fmod(_t, 1.2) < 0.7
		lbl_cam.text = "CAM " + nc.cur_cam
		lbl_cam_name.text = nc.world.CAM_NAMES[nc.cur_cam]
		var rem := nc.remaining_clues_tonight()
		lbl_clues.text = ("Bu gece sistemde iz bırakmış %d kayıt dışı nesne var." % rem) if rem > 0 else "Bu gece için kayıt dışı nesne yok."
		for id in map_buttons.keys():
			var b: Button = map_buttons[id]
			var sel: bool = id == nc.cur_cam
			var st: StyleBoxFlat = b.get_meta("sel") if sel else b.get_meta("norm")
			# a corrupted camera flickers when something wrong is there
			if id == "2B" and nc.golden_state == "cam" and fmod(_t * 5.0, 1.0) < 0.3:
				st = b.get_meta("sel")
			b.add_theme_stylebox_override("normal", st)
		map_panel.queue_redraw()
	# flash
	if _flash_t > 0.0:
		_flash_t -= delta
		flash_rect.color = Color(_flash_c.r, _flash_c.g, _flash_c.b, _flash_c.a * clamp(_flash_t / max(_flash_dur, 0.01), 0.0, 1.0))
	if _halluc_t > 0.0:
		_halluc_t -= delta
		halluc.visible = fmod(_halluc_t, 0.25) < 0.17
		if _halluc_t <= 0.0:
			halluc.visible = false
	# subtitles typewriter
	if sub_panel.visible and _sub_chars < _sub_full.length():
		_sub_chars += delta * 42.0
		sub_label.visible_characters = int(_sub_chars)
	_update_toasts(delta)


func set_tip(text: String, pos: Vector2) -> void:
	lbl_tip.visible = text != ""
	lbl_tip.text = text
	lbl_tip.position = pos + Vector2(18, 10)


func flash(c: Color, dur: float) -> void:
	_flash_c = c
	flash_rect.color = c
	_flash_t = dur
	_flash_dur = dur


func hallucination(text: String) -> void:
	halluc.text = text
	_halluc_t = 1.6


func golden_face(on: bool) -> void:
	_golden_face = on


func toast(text: String, col: Color = Color(1, 0.95, 0.7), dur: float = 4.5) -> void:
	var l := _label(text, 22, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_meta("t", dur)
	toast_box.add_child(l)


func _update_toasts(delta: float) -> void:
	for c in toast_box.get_children():
		var t: float = c.get_meta("t") - delta
		c.set_meta("t", t)
		c.modulate.a = clamp(t, 0.0, 1.0)
		if t <= 0.0:
			c.queue_free()


# ---------------------------------------------------------------- subtitles (voicemail / tape)
func _build_subtitles() -> void:
	sub_panel = PanelContainer.new()
	sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_panel.position = Vector2(-480, -400)
	sub_panel.size = Vector2(960, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 0.78)
	sb.border_color = Color(0.5, 0.45, 0.35, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	sub_panel.add_theme_stylebox_override("panel", sb)
	sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_panel.add_child(v)
	sub_label = RichTextLabel.new()
	sub_label.bbcode_enabled = false
	sub_label.fit_content = false
	sub_label.custom_minimum_size = Vector2(920, 250)
	sub_label.add_theme_font_size_override("normal_font_size", 16)
	sub_label.add_theme_color_override("default_color", Color(0.92, 0.9, 0.85))
	sub_label.scroll_active = false
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub_label)
	sub_hint = _label("[ENTER] Mesajı geç", 14, Color(0.7, 0.7, 0.65))
	sub_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sub_hint)
	sub_panel.visible = false
	root.add_child(sub_panel)


func show_subtitle(text: String) -> void:
	_sub_full = text
	_sub_chars = 0.0
	sub_label.text = text
	sub_label.visible_characters = 0
	sub_panel.visible = true


func hide_subtitle() -> void:
	sub_panel.visible = false


func subtitle_done() -> bool:
	return _sub_chars >= _sub_full.length()
