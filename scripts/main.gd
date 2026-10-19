extends Node
## Greyfang: 5 GECE — game flow: menu, intro, nights, game over, deduction, endings.

var world: WorldBuilder
var chars: Dictionary = {}
var nc: NightController
var hud: HUD
var journal: Journal
var ui: CanvasLayer
var screens: Dictionary = {}
var state: String = "menu"
var theme_ui: Theme
var _menu_t: float = 0.0
var _voicemail_t: float = 0.0
var _last_death: String = ""
var _answers: Array = []
var _intro_label: RichTextLabel
var _intro_chars: float = 0.0
var _card_t: float = 0.0
var _card_night: int = 1
var monitor_hover_armed: bool = true
var _crash_t: float = 0.0
const YOUTUBE_URL := "https://www.youtube.com/@eftelix"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = WorldBuilder.new()
	var w3d := Node3D.new()
	w3d.name = "World3D"
	add_child(w3d)
	world.build(w3d)
	for k in ["grayson", "benny", "brutus", "rook", "golden"]:
		var a := Animatronic.new()
		world.root.add_child(a)
		a.setup(k)
		chars[k] = a
	chars.golden.add_pick_area("golden")
	chars.golden.visible = false
	nc = NightController.new()
	nc.name = "NightController"
	nc.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(nc)
	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.build(nc)
	hud.visible = false
	nc.setup(world, chars, hud)
	nc.died.connect(_on_died)
	nc.won.connect(_on_won)
	nc.clue_collected.connect(_on_clue)
	_build_theme()
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_build_screens()
	journal = Journal.new()
	journal.theme = theme_ui
	journal.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(journal)
	journal.build()
	journal.closed.connect(_on_journal_closed)
	if GameState.has_arg("--simtest"):
		await get_tree().process_frame
		_sim_test()
		get_tree().quit()
		return
	if GameState.has_arg("--cluetest"):
		_clue_test()
		get_tree().quit()
		return
	_show_menu()
	if GameState.has_arg("--autoshot"):
		await _autoshot()
		get_tree().quit()
		return
	if GameState.has_arg("--flowtest"):
		await _flowtest()
		get_tree().quit()
		return
	if GameState.has_arg("--audiotest"):
		GameState.args.append("--novoice")
		GameState.new_run(55)
		_start_night(1, true)
		await _wait(0.5)
		nc.set_monitor(true)
		for id in ["1A", "1B", "2A", "1A"]:
			nc.select_cam(id)
			await _wait(0.3)
		nc._move("benny", "dining")
		nc.set_monitor(false)
		nc.set_monitor(true)
		nc.set_monitor(false)
		await _wait(4.0)
		var still := []
		for pl in Sfx._pool:
			if pl.playing:
				still.append(pl.stream.resource_path.get_file())
		print("AUDIOTEST still playing after 4s: ", still)
		get_tree().quit()
		return
	if GameState.has_arg("--showcase"):
		await _showcase()
		get_tree().quit()
		return
	var direct := GameState.arg_value("--night", "")
	if direct != "":
		if GameState.run_seed == 0:
			GameState.new_run(int(GameState.arg_value("--seed", "-1")))
		_start_night(int(direct), true)


# ================================================================ theme & helpers
func _build_theme() -> void:
	theme_ui = Theme.new()
	theme_ui.default_font_size = 20
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.07, 0.07, 0.9)
	n.border_color = Color(0.45, 0.38, 0.3)
	n.set_border_width_all(1)
	n.set_content_margin_all(8)
	var h := n.duplicate()
	h.bg_color = Color(0.25, 0.06, 0.05, 0.95)
	h.border_color = Color(0.9, 0.3, 0.2)
	var p := h.duplicate()
	p.bg_color = Color(0.45, 0.1, 0.08, 1.0)
	var d := n.duplicate()
	d.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	d.border_color = Color(0.2, 0.2, 0.2)
	theme_ui.set_stylebox("normal", "Button", n)
	theme_ui.set_stylebox("hover", "Button", h)
	theme_ui.set_stylebox("pressed", "Button", p)
	theme_ui.set_stylebox("hover_pressed", "Button", p)
	theme_ui.set_stylebox("disabled", "Button", d)
	theme_ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_ui.set_color("font_color", "Button", Color(0.92, 0.88, 0.8))
	theme_ui.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	theme_ui.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	theme_ui.set_color("font_color", "Label", Color(0.9, 0.88, 0.82))
	var le := n.duplicate()
	theme_ui.set_stylebox("normal", "LineEdit", le)
	theme_ui.set_stylebox("focus", "LineEdit", h)
	theme_ui.set_color("font_color", "LineEdit", Color(0.95, 0.9, 0.8))


func _screen(sname: String, bg: Color = Color(0, 0, 0, 0.0)) -> Control:
	var c := Control.new()
	c.name = sname
	c.theme = theme_ui
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP if bg.a > 0.0 else Control.MOUSE_FILTER_IGNORE
	if bg.a > 0.0:
		var r := ColorRect.new()
		r.color = bg
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(r)
	c.visible = false
	ui.add_child(c)
	screens[sname] = c
	return c


func _lbl(parent: Node, text: String, size: int, col: Color = Color(0.92, 0.9, 0.85), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable, minw: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(minw, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _center_box(parent: Control, w: float = 520.0) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(w, 0)
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v


func _show_only(sname: String) -> void:
	for k in screens.keys():
		screens[k].visible = k == sname


# ================================================================ screens
var _menu_box: VBoxContainer
var _seed_edit: LineEdit
var _menu_info: Label
var _select_box: VBoxContainer
var _over_title: Label
var _over_info: Label
var _win_title: Label
var _win_info: Label
var _win_next: Button
var _card_label: Label
var _end_title: Label
var _end_text: RichTextLabel
var _ded_box: VBoxContainer
var _ded_result: Label
var _vol_slider: HSlider


func _build_screens() -> void:
	# ---- main menu (3D stage visible behind) ----
	var m := _screen("menu")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(shade)
	var left := VBoxContainer.new()
	left.position = Vector2(60, 60)
	left.custom_minimum_size = Vector2(460, 600)
	left.add_theme_constant_override("separation", 10)
	m.add_child(left)
	var t1 := _lbl(left, "GREYFANG", 76, Color(0.92, 0.9, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	t1.add_theme_color_override("font_shadow_color", Color(0.6, 0.05, 0.02, 0.9))
	t1.add_theme_constant_override("shadow_offset_x", 4)
	t1.add_theme_constant_override("shadow_offset_y", 4)
	t1.set_meta("flicker", true)
	_lbl(left, "5 GECE", 40, Color(0.85, 0.2, 0.15), HORIZONTAL_ALIGNMENT_LEFT)
	_lbl(left, "Greyfang Lahmacun Sarayı", 20, Color(0.75, 0.7, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 18)
	left.add_child(sp)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 8)
	left.add_child(_menu_box)
	_menu_info = _lbl(m, "", 16, Color(0.65, 0.62, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_menu_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_menu_info.position = Vector2(60, -70)
	_menu_info.size = Vector2(900, 60)

	# ---- night select ----
	var s := _screen("select", Color(0, 0, 0, 0.85))
	_select_box = _center_box(s, 420)

	# ---- settings ----
	var st := _screen("settings", Color(0, 0, 0, 0.85))
	var sv := _center_box(st, 520)
	_lbl(sv, "AYARLAR", 36)
	_lbl(sv, "Ses düzeyi", 20)
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.custom_minimum_size = Vector2(420, 30)
	_vol_slider.value_changed.connect(func(v): GameState.set_volume(v))
	sv.add_child(_vol_slider)
	var ml := CheckButton.new()
	ml.text = "Fareyi ekran kenarına götürerek etrafa bak"
	ml.button_pressed = GameState.mouse_look
	ml.toggled.connect(func(on):
		GameState.mouse_look = on
		GameState.save_game())
	sv.add_child(ml)
	_lbl(sv, "KONTROLLER\nQ / E — Sol / sağ kapı      A / D — Sol / sağ koridor ışığı\nBOŞLUK (veya ekranın altındaki çubuk) — Kamera tableti\nKamera açıkken: haritaya tıkla veya ← / → ile kamera değiştir\nKamerada şüpheli nesneye TIKLA — kanıt olarak kaydet\nFare ekran kenarında / ← → — Ofiste sola-sağa bak\nOfis duvarındaki düğmelere de tıklanabilir\nJ / TAB — Kanıt günlüğü      ESC — Duraklat", 16, Color(0.75, 0.72, 0.65))
	_btn(sv, "Geri", func(): _show_menu())

	# ---- intro ----
	var it := _screen("intro", Color(0, 0, 0, 1))
	var iv := _center_box(it, 860)
	_intro_label = RichTextLabel.new()
	_intro_label.custom_minimum_size = Vector2(860, 430)
	_intro_label.add_theme_font_size_override("normal_font_size", 22)
	_intro_label.add_theme_color_override("default_color", Color(0.88, 0.86, 0.8))
	iv.add_child(_intro_label)
	_btn(iv, "Devam  [ENTER]", func(): _intro_continue())

	# ---- night card ----
	var nc_s := _screen("card", Color(0, 0, 0, 1))
	var nv := _center_box(nc_s, 600)
	_card_label = _lbl(nv, "", 54)

	# ---- game over ----
	var go := _screen("gameover", Color(0, 0, 0, 0.9))
	var gv := _center_box(go, 700)
	_over_title = _lbl(gv, "YAKALANDIN", 60, Color(0.85, 0.12, 0.1))
	_over_info = _lbl(gv, "", 20, Color(0.8, 0.78, 0.7))
	_btn(gv, "Geceyi tekrar dene", func(): _start_night(GameState.night, false))
	_btn(gv, "Kanıt günlüğü", func(): _open_journal())
	_btn(gv, "Ana menü", func(): _show_menu())

	# ---- golden crash ----
	var cr := _screen("crash", Color(0, 0, 0, 1))
	var crv := _center_box(cr, 700)
	_lbl(crv, "greyfang_guvenlik.exe yanıt vermiyor.\n\nG-0 :: BELLEK HATASI 0x0E11\nKİMSE KAPATMADI", 22, Color(0.85, 0.82, 0.6))

	# ---- night complete ----
	var w := _screen("win", Color(0, 0, 0, 0.92))
	var wv := _center_box(w, 760)
	_win_title = _lbl(wv, "06:00", 80, Color(0.95, 0.95, 0.9))
	_win_info = _lbl(wv, "", 20, Color(0.82, 0.8, 0.72))
	_win_next = _btn(wv, "Sonraki gece", func(): _after_win())
	_btn(wv, "Kanıt günlüğü", func(): _open_journal())
	_btn(wv, "Ana menü", func(): _show_menu())

	# ---- pause ----
	var pz := _screen("pause", Color(0, 0, 0, 0.7))
	var pv := _center_box(pz, 400)
	_lbl(pv, "DURAKLATILDI", 40)
	_btn(pv, "Devam et", func(): _resume())
	_btn(pv, "Kanıt günlüğü", func(): _open_journal())
	_btn(pv, "Geceyi baştan başlat", func():
		get_tree().paused = false
		_start_night(GameState.night, false))
	_btn(pv, "Ana menü", func():
		get_tree().paused = false
		_show_menu())

	# ---- deduction (final report) ----
	var dd := _screen("deduction", Color(0.02, 0.02, 0.02, 0.97))
	var dsc := ScrollContainer.new()
	dsc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dsc.offset_left = 80
	dsc.offset_right = -80
	dsc.offset_top = 30
	dsc.offset_bottom = -30
	dd.add_child(dsc)
	_ded_box = VBoxContainer.new()
	_ded_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ded_box.add_theme_constant_override("separation", 10)
	dsc.add_child(_ded_box)

	# ---- ending ----
	var en := _screen("ending", Color(0, 0, 0, 1))
	var ev := _center_box(en, 900)
	_end_title = _lbl(ev, "", 46, Color(0.95, 0.85, 0.6))
	_end_text = RichTextLabel.new()
	_end_text.custom_minimum_size = Vector2(900, 420)
	_end_text.add_theme_font_size_override("normal_font_size", 20)
	_end_text.add_theme_color_override("default_color", Color(0.88, 0.86, 0.8))
	ev.add_child(_end_text)
	_btn(ev, "▶  Daha fazlası için: YouTube @eftelix", func(): OS.shell_open(YOUTUBE_URL))
	_btn(ev, "Ana menü", func(): _show_menu())


# ================================================================ menu
func _show_menu() -> void:
	state = "menu"
	get_tree().paused = false
	nc.stop()
	hud.visible = false
	journal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_scene()
	for c in _menu_box.get_children():
		c.queue_free()
	if GameState.has_run and GameState.night <= 5:
		_btn(_menu_box, "Devam et — Gece %d" % GameState.night, func(): _start_night(GameState.night, false))
	_btn(_menu_box, "Yeni oyun", func(): _new_game())
	var sh := HBoxContainer.new()
	_menu_box.add_child(sh)
	var sl := Label.new()
	sl.text = "Seed (boş = rastgele): "
	sl.add_theme_font_size_override("font_size", 15)
	sh.add_child(sl)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(140, 34)
	_seed_edit.placeholder_text = "örn. 482913"
	_seed_edit.theme = theme_ui
	sh.add_child(_seed_edit)
	if GameState.has_run:
		_btn(_menu_box, "Gece seç", func(): _show_select())
		_btn(_menu_box, "Kanıt günlüğü", func(): _open_journal())
	if GameState.has_run and GameState.night >= 6:
		_btn(_menu_box, "Sonuç raporu (son)", func(): _show_deduction())
	_btn(_menu_box, "Ayarlar ve kontroller", func():
		_vol_slider.value = GameState.master_volume
		_show_only("settings"))
	_btn(_menu_box, "▶  YouTube: @eftelix", func(): OS.shell_open(YOUTUBE_URL))
	_btn(_menu_box, "Çıkış", func(): get_tree().quit())
	var info := ""
	if GameState.has_run:
		info = "Seed: %d    •    Ulaşılan gece: %d    •    Bulunan kanıt: %d / %d" % [GameState.run_seed, min(GameState.max_night_reached, 5), GameState.found.size(), StoryData.CLUES.size()]
		if GameState.ending_id != "":
			info += "    •    " + StoryData.ENDINGS[GameState.ending_id].title
	_menu_info.text = info + "\nYapımcı: Eftelix — youtube.com/@eftelix   •   Açık kaynak (MIT)"
	_show_only("menu")


func _menu_scene() -> void:
	world.office.menu_cam.current = true
	for w in ["grayson", "benny", "brutus"]:
		var sp: Array = world.spot_for("stage", w)
		chars[w].visible = true
		chars[w].place(sp[0], sp[1])
		chars[w].set_pose("perform", true)
		chars[w].anim = "strum" if w == "benny" else "idle"
		chars[w].look_target = world.office.menu_cam.global_position
		chars[w].look_weight = 0.0
		chars[w].set_eye_glow(1.0)
	chars.rook.place(Vector3(-12.6, 0.4, -9.0), 90.0)
	chars.golden.visible = false
	nc.stage_music.stop()
	Sfx.stop_all()
	Sfx.loop("amb_drone", -14.0)
	Sfx.loop("stage_music", -24.0, 0.92)


func _new_game() -> void:
	var sd := -1
	if _seed_edit and _seed_edit.text.strip_edges().is_valid_int():
		sd = int(_seed_edit.text.strip_edges())
	GameState.new_run(sd)
	state = "intro"
	_show_only("intro")
	_intro_label.text = StoryData.INTRO
	_intro_label.visible_characters = 0
	_intro_chars = 0.0
	Sfx.stop_all()
	Sfx.loop("amb_drone", -12.0)


func _intro_continue() -> void:
	if _intro_chars < StoryData.INTRO.length():
		_intro_chars = StoryData.INTRO.length()
		return
	_start_night(1, false)


func _show_select() -> void:
	for c in _select_box.get_children():
		c.queue_free()
	_lbl(_select_box, "GECE SEÇ", 36)
	for n in range(1, 6):
		var b := _btn(_select_box, "Gece %d" % n, func(): _start_night(n, false))
		b.disabled = n > GameState.max_night_reached
	_btn(_select_box, "Geri", func(): _show_menu())
	_show_only("select")


# ================================================================ night flow
func _start_night(n: int, skip_card: bool) -> void:
	GameState.night = n
	get_tree().paused = false
	journal.visible = false
	nc.stop()
	_card_night = n
	if skip_card:
		_begin_night()
		return
	state = "card"
	_card_t = 0.0
	_card_label.text = "GECE %d\n\n00:00" % n
	_card_label.modulate.a = 0.0
	_show_only("card")
	Sfx.stop_all()
	Sfx.play("static", -14.0)


func _begin_night() -> void:
	state = "night"
	_show_only("")
	hud.visible = true
	hud.set_night(_card_night)
	nc.hour_len = 10.0 if GameState.has_arg("--fast") else NightController.HOUR_LEN
	nc.start(_card_night, GameState.run_seed)
	monitor_hover_armed = true
	if not GameState.has_arg("--novoice"):
		hud.show_subtitle(StoryData.VOICEMAILS[_card_night])
		Sfx.play("beep", -8.0)
		Sfx.loop("voice_owner", -12.0)
		_voicemail_t = 0.0
	else:
		_voicemail_t = -1.0


func _end_voicemail() -> void:
	hud.hide_subtitle()
	Sfx.stop_loop("voice_owner")
	Sfx.play("beep", -10.0, 0.8)
	_voicemail_t = -1.0


func _on_clue(id: String) -> void:
	var c: Dictionary = StoryData.clue(id)
	hud.toast("KANIT KAYDEDİLDİ: %s  [%s]\n(J ile günlükte incele)" % [c.title, StoryData.TYPE_NAMES[c.type]])


func _on_died(who: String) -> void:
	_last_death = who
	hud.visible = false
	_end_voicemail()
	Sfx.stop_all()
	if who == "golden":
		state = "crash"
		_crash_t = 2.8
		_show_only("crash")
		return
	_show_gameover()


func _show_gameover() -> void:
	state = "gameover"
	var names := {"grayson": "Grayson", "benny": "Benny Beak", "brutus": "Brutus", "rook": "Kaptan Rook", "golden": "???"}
	var tips := {
		"grayson": "Grayson izlendiğinde durur; sağ kapıyı kapalı tutmadan kamerada oyalanma. Elektrik biterse o gelir.",
		"benny": "Benny kameradan kaybolduğunda sol ışığa bak. Ayak seslerini dinle.",
		"brutus": "Mutfaktan gelen tepsi ve tencere seslerine kulak ver. Sağ ışığı kontrol et.",
		"rook": "Korsan Köşesi'ni düzenli kontrol et. Perde açıldığında sol kapıyı kapatmaya hazır ol.",
		"golden": "Onu gördüysen, tableti indirdiğinde yeniden kaldır.",
	}
	_over_title.text = "YAKALANDIN"
	_over_info.text = "Gece %d — %s\n%s seni buldu.\n\n%s\n\nBu gece bulduğun kanıtlar kaydedildi." % [GameState.night, nc.clock_text(), names.get(_last_death, "?"), tips.get(_last_death, "")]
	_show_only("gameover")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.loop("static", -26.0)


func _on_won() -> void:
	state = "win"
	_end_voicemail()
	hud.visible = false
	var n := GameState.night
	GameState.complete_night(n)
	var lines := []
	for id in nc.found_tonight:
		lines.append("• " + StoryData.clue(id).title)
	var found_txt := ("Bu gece bulunan kanıtlar:\n" + "\n".join(PackedStringArray(lines))) if lines.size() > 0 else "Bu gece yeni kanıt bulunmadı.\n(Bulunamayan önemli kanıtlar sonraki gecelerde başka yerlerde yeniden ortaya çıkar.)"
	_win_title.text = "06:00"
	_win_info.text = "GECE %d TAMAMLANDI\n\n%s\n\nToplam kanıt: %d / %d" % [n, found_txt, GameState.found.size(), StoryData.CLUES.size()]
	_win_next.text = "Sonuç raporunu yaz" if n >= 5 else "Gece %d" % (n + 1)
	_show_only("win")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _after_win() -> void:
	if GameState.night >= 6:
		_show_deduction()
	else:
		_start_night(GameState.night, false)


func _resume() -> void:
	get_tree().paused = false
	state = "night"
	_show_only("")


func _open_journal() -> void:
	journal.open_journal()


func _on_journal_closed() -> void:
	pass


# ================================================================ deduction & endings
func _show_deduction() -> void:
	state = "deduction"
	Sfx.stop_all()
	Sfx.loop("amb_drone", -14.0)
	for c in _ded_box.get_children():
		c.queue_free()
	_answers = []
	for i in StoryData.QUESTIONS.size():
		_answers.append(-1)
	_lbl(_ded_box, "SONUÇ RAPORU", 40, Color(0.95, 0.85, 0.6))
	_lbl(_ded_box, "Söküm ekibi sabah geliyor. Elindeki kanıtlarla 14 Mart 2018 gecesini yeniden kur.\nCevaplar hiçbir yerde açıkça yazmıyor; kanıtları birbiriyle karşılaştır. (Günlüğü istediğin zaman açabilirsin.)", 18, Color(0.8, 0.78, 0.7))
	_btn(_ded_box, "Kanıt günlüğünü aç", func(): _open_journal())
	for qi in StoryData.QUESTIONS.size():
		var q: Dictionary = StoryData.QUESTIONS[qi]
		_lbl(_ded_box, "%d. %s" % [qi + 1, q.q], 21, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		_ded_box.add_child(row)
		var group := []
		for oi in q.options.size():
			var b := Button.new()
			b.text = q.options[oi]
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.theme = theme_ui
			row.add_child(b)
			group.append(b)
		for oi in group.size():
			var bb: Button = group[oi]
			bb.pressed.connect(func():
				_answers[qi] = oi
				for g in group:
					g.button_pressed = g == bb)
	_ded_result = _lbl(_ded_box, "", 18, Color(0.9, 0.5, 0.4))
	_btn(_ded_box, "Raporu teslim et", func(): _submit_deduction())
	_btn(_ded_box, "Ana menü", func(): _show_menu())
	_show_only("deduction")


func _submit_deduction() -> void:
	if _answers.has(-1):
		_ded_result.text = "Her soruya bir cevap seçmelisin."
		return
	var score := 0
	for i in StoryData.QUESTIONS.size():
		if _answers[i] == StoryData.QUESTIONS[i].answer:
			score += 1
	var eid := "wrong"
	if score == StoryData.QUESTIONS.size():
		eid = "truth"
	elif score >= 3:
		eid = "partial"
	# the true ending also needs the key evidence to exist in the journal
	if eid == "truth":
		for need in ["c_syslog_delete", "c_tape_hakan_1", "c_postcard"]:
			if not GameState.found.has(need):
				eid = "partial"
	GameState.ending_id = eid
	GameState.deduction_done = true
	GameState.save_game()
	var e: Dictionary = StoryData.ENDINGS[eid]
	_end_title.text = e.title
	var extra := "\n\n[Doğru çıkarım: %d / %d]" % [score, StoryData.QUESTIONS.size()]
	if eid == "truth" and GameState.found.has("m_gold_3"):
		extra += "\n\nSöküm ekibinin raporunda tek bir satır vardı: \"Altın renkli ünitenin bellek modülü yerinde. Kayıt cihazı hâlâ çalışıyor. Son kayıt: bu sabah 05:59.\""
	_end_text.text = e.text + extra
	state = "ending"
	_show_only("ending")
	Sfx.stop_all()
	Sfx.play("chime6", -6.0, 0.8)


# ================================================================ per-frame & input
func _process(delta: float) -> void:
	_menu_t += delta
	match state:
		"menu":
			var mc: Camera3D = world.office.menu_cam
			mc.position = Vector3(1.2 + sin(_menu_t * 0.08) * 0.6, 1.7, -14.0 + sin(_menu_t * 0.05) * 0.5)
			mc.look_at(Vector3(0, 1.7, -21.0), Vector3.UP)
			nc._flick_t = _menu_t
			nc._flicker_lights(delta)
			for c in screens.menu.get_children():
				if c is VBoxContainer:
					var t: Label = c.get_child(0)
					t.modulate.a = 0.25 if fmod(_menu_t * 1.3, 4.0) < 0.07 else 1.0
			if fmod(_menu_t, 23.0) < 0.12 and _menu_t > 5.0:
				# rare glimpse of the golden one on stage
				var sp: Array = world.spot_for("golden_stage", "golden")
				chars.golden.place(sp[0], sp[1])
				chars.golden.set_pose("slump", true)
				chars.golden.visible = true
			elif chars.golden.visible:
				chars.golden.visible = false
		"intro":
			_intro_chars += delta * 38.0
			_intro_label.visible_characters = int(_intro_chars)
		"card":
			_card_t += delta
			_card_label.modulate.a = clamp(_card_t / 0.8, 0.0, 1.0) * clamp((3.2 - _card_t) / 0.6, 0.0, 1.0)
			if _card_t > 3.2:
				_begin_night()
		"crash":
			_crash_t -= delta
			if _crash_t <= 0.0:
				_show_gameover()
		"night":
			_night_frame(delta)


func _night_frame(delta: float) -> void:
	if _voicemail_t >= 0.0:
		_voicemail_t += delta
		if hud.subtitle_done() and _voicemail_t > 4.0 + StoryData.VOICEMAILS[_card_night].length() / 42.0:
			_end_voicemail()
	if journal.visible or not nc.active or nc.dying:
		hud.set_tip("", Vector2.ZERO)
		return
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var mp := vp.get_mouse_position()
	if not nc.monitor_up:
		var look := 0.0
		if GameState.mouse_look and mp.y < size.y - 70:
			var fx := mp.x / size.x
			if fx < 0.2:
				look = (0.2 - fx) / 0.2
			elif fx > 0.8:
				look = -(fx - 0.8) / 0.2
		if Input.is_action_pressed("look_left"):
			look = 1.0
		if Input.is_action_pressed("look_right"):
			look = -1.0
		nc.set_look(nc.yaw + look * delta * 2.2)
	if GameState.has_arg("--autoshot") or GameState.has_arg("--flowtest"):
		return
	# FNAF-style hover bar toggles the tablet
	var bar := Rect2(size.x * 0.5 - 260, size.y - 48, 520, 40)
	if GameState.has_arg("--showcase"):
		bar = Rect2()
	if bar.has_point(mp):
		if monitor_hover_armed and not nc.power_out:
			monitor_hover_armed = false
			nc.set_monitor(not nc.monitor_up)
	else:
		monitor_hover_armed = true
	# hover tips
	var hit := nc.pick_at(mp)
	if nc.monitor_up and not hit.is_empty() and hit.kind == "clue":
		hud.set_tip("◉ İNCELE — tıkla", mp)
	elif nc.monitor_up and not hit.is_empty() and hit.kind == "golden" and nc.golden_state == "cam" and nc.cur_cam == "2B":
		hud.set_tip("▒ ???", mp)
	else:
		hud.set_tip("", mp)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.has_arg("--showcase"):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
		return
	if state == "intro" and event.is_action_pressed("ui_accept"):
		_intro_continue()
		return
	if state != "night":
		if state == "menu" and event is InputEventKey and event.pressed and event.keycode == KEY_F12:
			_take_shot("manual_%d" % Time.get_ticks_msec())
		return
	if journal.visible:
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = true
		_show_only("pause")
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if _voicemail_t >= 0.0:
			_end_voicemail()
		return
	if not nc.active or nc.dying:
		return
	if event.is_action_pressed("door_left"):
		nc.toggle_door("left")
	elif event.is_action_pressed("door_right"):
		nc.toggle_door("right")
	elif event.is_action_pressed("light_left"):
		nc.toggle_light("left")
	elif event.is_action_pressed("light_right"):
		nc.toggle_light("right")
	elif event.is_action_pressed("monitor"):
		nc.set_monitor(not nc.monitor_up)
	elif event.is_action_pressed("journal"):
		_open_journal()
	elif nc.monitor_up and event.is_action_pressed("cam_next"):
		nc.cycle_cam(1)
	elif nc.monitor_up and event.is_action_pressed("cam_prev"):
		nc.cycle_cam(-1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := nc.pick_at(event.position)
		if hit.is_empty():
			return
		match hit.kind:
			"clue":
				nc.try_pick_clue(hit.id)
			"golden":
				nc.try_pick_golden()
			"button":
				var parts: PackedStringArray = String(hit.id).split("_")
				if parts[0] == "door":
					nc.toggle_door(parts[1])
				else:
					nc.toggle_light(parts[1])


func _take_shot(sname: String) -> void:
	var dir := ProjectSettings.globalize_path("res://_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + sname + ".png")
	print("shot: ", sname)


# ================================================================ automated tests
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(sname: String) -> void:
	await RenderingServer.frame_post_draw
	_take_shot(sname)


func _autoshot() -> void:
	await _wait(1.5)
	await _shot("01_menu")
	# character portraits
	state = "test"
	_show_only("")
	var pc := Camera3D.new()
	world.root.add_child(pc)
	var pl := OmniLight3D.new()
	pl.light_energy = 2.5
	pl.omni_range = 8.0
	world.root.add_child(pl)
	var spot_pos := Vector3(0, 0.0, -6.0)
	for k in ["grayson", "benny", "brutus", "rook", "golden"]:
		for other in chars.keys():
			chars[other].visible = other == k
		var m: Animatronic = chars[k]
		m.place(spot_pos, 0.0)
		m.set_pose("perform" if k != "golden" else "slump", true)
		m.anim = "idle"
		m.look_weight = 0.0
		pc.look_at_from_position(spot_pos + Vector3(1.2, 1.6, 3.4), spot_pos + Vector3(0, 1.3 if k != "golden" else 0.7, 0), Vector3.UP)
		pc.current = true
		pl.global_position = spot_pos + Vector3(1.5, 2.5, 2.5)
		await _wait(0.5)
		await _shot("02_char_" + k)
	pl.queue_free()
	pc.queue_free()
	GameState.args.append("--novoice")
	GameState.args.append("--fixed-rt")
	GameState.new_run(424242)
	_start_night(1, true)
	await _wait(1.0)
	await _shot("03_office")
	nc.set_look(1.1)
	nc.toggle_light("left")
	await _wait(1.0)
	await _shot("04_office_left_light")
	nc.toggle_light("left")
	nc.toggle_door("left")
	await _wait(1.0)
	await _shot("05_office_left_door_closed")
	nc.toggle_door("left")
	nc.set_look(-1.1)
	await _wait(1.0)
	await _shot("06_office_right")
	nc.set_look(0.0)
	await _wait(0.6)
	# spawn all clues now so they appear on camera shots
	for e in nc.clue_plan:
		e.reveal_hour = 0.0
	nc._clues_update()
	nc.set_monitor(true)
	for id in ["1A", "1B", "1C", "5", "7", "6", "3", "2A", "2B", "4A", "4B"]:
		nc.select_cam(id)
		nc.cam_glitch = 0.0
		await _wait(0.7)
		nc.cam_glitch = 0.0
		await _shot("10_cam_" + id)
	# mouse picking through the real camera projection
	var ok_picks := 0
	var total_picks := 0
	for id in nc.clue_nodes.keys():
		var node: Node3D = nc.clue_nodes[id]
		nc.select_cam(node.get_meta("cam"))
		await _wait(0.15)
		var cam: Camera3D = world.cams[nc.cur_cam].node
		var sp := cam.unproject_position(node.global_position + Vector3(0, 0.05, 0))
		var hit := nc.pick_at(sp)
		total_picks += 1
		if not hit.is_empty() and hit.kind == "clue" and hit.id == id:
			ok_picks += 1
		else:
			print("PICK FAIL ", id, " on cam ", nc.cur_cam, " at ", sp, " -> ", hit, " behind=", cam.is_position_behind(node.global_position))
	print("clue picking: %d / %d" % [ok_picks, total_picks])
	nc.set_monitor(false)
	for side in ["left", "right"]:
		nc.set_look(1.1 if side == "left" else -1.1)
		await _wait(0.8)
		for kind in ["door", "light"]:
			var area_pos: Vector3 = Vector3(-3.38 if side == "left" else 3.38, 1.35 + (0.13 if kind == "door" else -0.13), 13.8)
			var ocam: Camera3D = world.office.cam
			var p2 := ocam.unproject_position(area_pos)
			var h2 := nc.pick_at(p2)
			print("button %s_%s -> %s" % [kind, side, str(h2)])
	nc.set_look(0.0)
	nc.set_monitor(true)
	# animatronics moved around
	nc._move("benny", "whall")
	nc._move("brutus", "kitchen")
	nc._move("grayson", "dining")
	for id in ["2A", "6", "1B"]:
		nc.select_cam(id)
		await _wait(0.8)
		nc.cam_glitch = 0.0
		await _wait(0.2)
		await _shot("11_moved_" + id)
	nc._move("benny", "wcorner")
	nc._move("brutus", "ecorner")
	nc.select_cam("2B")
	await _wait(0.9)
	nc.cam_glitch = 0.0
	await _shot("12_benny_2B")
	nc.select_cam("4B")
	await _wait(0.9)
	nc.cam_glitch = 0.0
	await _shot("12_brutus_4B")
	nc.set_monitor(false)
	nc._move("benny", "ldoor")
	nc._move("brutus", "rdoor")
	nc.ai.benny.door_t = 999.0
	nc.ai.brutus.door_t = 999.0
	nc.set_look(1.1)
	nc.toggle_light("left")
	await _wait(1.2)
	await _shot("13_benny_at_door")
	nc.toggle_light("left")
	nc.set_look(-1.1)
	nc.toggle_light("right")
	await _wait(1.2)
	await _shot("14_brutus_at_door")
	nc.toggle_light("right")
	nc.set_look(0.0)
	nc._move("benny", "dining")
	nc._move("brutus", "dining")
	# Rook stages and run
	nc.set_monitor(true)
	nc.select_cam("1C")
	for st in [1, 2]:
		nc.ai.rook.stage = st
		nc._place_rook()
		nc._update_cove_visual()
		await _wait(1.5)
		nc.cam_glitch = 0.0
		await _shot("15_rook_stage%d" % st)
	nc.ai.rook.state = "run"
	nc.ai.rook.run_d = 12.0
	nc._place_rook()
	nc.select_cam("2A")
	nc.ai.rook.run_d = 14.0
	await _wait(0.25)
	await _shot("16_rook_run_2A")
	nc.ai.rook.state = "cove"
	nc.ai.rook.stage = 0
	nc._place_rook()
	nc._update_cove_visual(true)
	# Golden
	nc.golden_events = [{"hour": 0.0, "kind": "memory", "memory": "m_gold_1", "done": false}]
	nc.select_cam("2B")
	await _wait(1.2)
	await _shot("17_golden_2B")
	nc.set_monitor(false)
	await _wait(0.8)
	await _shot("18_golden_office")
	nc.set_monitor(true)
	await _wait(0.3)
	nc.set_monitor(false)
	# journal
	for id in ["c_news_2018", "c_tape_selim_orient", "c_form_hakan_1"]:
		GameState.add_clue(id, 1)
	_open_journal()
	await _wait(0.6)
	await _shot("19_journal")
	journal.close_journal()
	# jumpscares
	for who in ["benny", "brutus", "rook", "grayson", "golden"]:
		_start_night(1, true)
		await _wait(0.6)
		nc._jumpscare(who, 0.0)
		await _wait(1.0 if who == "grayson" else 0.25)
		await _shot("20_jumpscare_" + who)
		await _wait(2.5)
	await _wait(3.0)
	await _shot("21_gameover")
	# power out
	_start_night(2, true)
	await _wait(0.5)
	nc.power = 0.0001
	await _wait(0.3)
	nc.po_timer = 0.0
	await _wait(0.4)
	nc.set_look(1.1)
	await _wait(0.6)
	while nc.po_face_light.light_energy <= 0.0:
		await get_tree().process_frame
	await _shot("22_powerout")
	nc.stop()
	_show_deduction()
	await _wait(0.5)
	await _shot("23_deduction")
	GameState.new_run(424242)


# ================================================================ showcase (video demo)
var _cap_panel: PanelContainer
var _cap_label: Label


var _cap_n: int = 0


func _cap_shot() -> void:
	_cap_n += 1
	var n := _cap_n
	await _wait(1.0)
	_take_shot("sc_%02d" % n)


func _caption(text: String, bottom: bool = false) -> void:
	if _cap_panel == null:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		_cap_panel = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.72)
		sb.border_color = Color(0.85, 0.25, 0.15, 0.9)
		sb.border_width_bottom = 3
		sb.set_content_margin_all(14)
		_cap_panel.add_theme_stylebox_override("panel", sb)
		_cap_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_cap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_cap_panel)
		_cap_label = Label.new()
		_cap_label.add_theme_font_size_override("font_size", 26)
		_cap_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
		_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cap_panel.add_child(_cap_label)
	_cap_label.text = text
	_cap_panel.visible = text != ""
	if text != "" and GameState.has_arg("--capshots"):
		_cap_shot.call_deferred()
	_cap_panel.reset_size()
	var vs := get_viewport().get_visible_rect().size
	_cap_panel.position = Vector2((vs.x - _cap_panel.size.x) * 0.5, vs.y - 110.0 if bottom else 64.0)


## Starts a night for the demo with all AI frozen (the script drives everything).
func _demo_night(n: int) -> void:
	_start_night(n, true)
	await get_tree().process_frame
	for w in ["grayson", "benny", "brutus", "rook"]:
		nc.ai[w].level = 0
	nc.golden_events = []
	Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)


func _wait_state(states: Array, timeout: float = 15.0) -> void:
	var t := 0.0
	while not states.has(state) and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _showcase() -> void:
	GameState.mouse_look = false
	GameState.new_run(2026)
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	# 1) title
	_show_menu()
	_caption("GREYFANG: 5 GECE  —  FNAF tarzı, Türkiye'de bir lahmacun salonunda geçen korku oyunu", true)
	await _wait(5.0)
	# 2) story intro
	state = "intro"
	_show_only("intro")
	_intro_label.text = StoryData.INTRO
	_intro_chars = 0.0
	_caption("Hikâye: 8 yıl önce kameralar 11 dakika karardı. Dila kayboldu, Berk'in babası suçlandı.", true)
	Sfx.stop_all()
	Sfx.loop("amb_drone", -12.0)
	await _wait(7.0)
	# 3) the office + voicemail
	_caption("Gece 1 — FNAF 1 tarzı güvenlik ofisi")
	_start_night(1, false)
	await _wait_state(["night"])
	for w in ["grayson", "benny", "brutus", "rook"]:
		nc.ai[w].level = 0
	nc.golden_events = []
	Input.warp_mouse(vp_center)
	await _wait(4.5)
	_end_voicemail()
	GameState.args.append("--novoice")
	# 4) doors & lights
	_caption("Kapılar ve koridor ışıkları — hepsi elektrik harcar (Kullanım göstergesi)")
	nc.set_look(1.1)
	await _wait(1.0)
	nc.toggle_light("left")
	await _wait(1.3)
	nc.toggle_light("left")
	nc.toggle_door("left")
	await _wait(1.5)
	nc.toggle_door("left")
	nc.set_look(-1.1)
	await _wait(1.0)
	nc.toggle_light("right")
	await _wait(1.3)
	nc.toggle_light("right")
	nc.set_look(0.0)
	await _wait(0.8)
	# 5) camera tour
	_caption("11 güvenlik kamerası ve kamera haritası")
	nc.set_monitor(true)
	for id in ["1A", "1B", "1C", "5", "7", "3", "2A", "2B", "4A", "4B"]:
		nc.select_cam(id)
		await _wait(1.1)
	# 6) movement
	_caption("Animatronikler odadan odaya ilerler — izlediğin kamera bozulur")
	nc.select_cam("1A")
	await _wait(1.5)
	nc._move("benny", "dining")
	await _wait(2.2)
	nc.select_cam("1B")
	await _wait(1.8)
	nc._move("benny", "whall")
	nc.select_cam("2A")
	await _wait(2.2)
	# 7) Brutus by sound
	_caption("Mutfak kamerası arızalı: Brutus'u tepsi ve tencere seslerinden takip et")
	nc._move("brutus", "kitchen")
	nc.select_cam("6")
	for i in 3:
		Sfx.play("pots" if i != 1 else "tray", -4.0, 0.9 + i * 0.1)
		await _wait(1.3)
	# 8) evidence
	_caption("Her oyunda seed'e göre farklı yerlere düşen kanıtlar — kamerada tıkla, kaydet")
	for e in nc.clue_plan:
		e.reveal_hour = 0.0
	nc._clues_update()
	var picked := ""
	for id in nc.clue_nodes.keys():
		var node: Node3D = nc.clue_nodes[id]
		nc.select_cam(node.get_meta("cam"))
		await _wait(1.0)
		var cam: Camera3D = world.cams[nc.cur_cam].node
		Input.warp_mouse(cam.unproject_position(node.global_position + Vector3(0, 0.05, 0)))
		await _wait(1.4)
		nc.try_pick_clue(id)
		picked = id
		break
	await _wait(2.0)
	Input.warp_mouse(vp_center)
	# 9) journal
	_caption("Kanıt günlüğü: belgeler, kasetler, kamera ve sistem kayıtları — sonucu sen çıkarırsın")
	for id in ["c_tape_selim_orient", "c_news_2018", "c_form_hakan_1", "c_syslog_delete"]:
		GameState.add_clue(id, 1)
	_open_journal()
	journal._show("c_tape_selim_orient")
	journal._play_tape()
	await _wait(5.5)
	journal._show("c_syslog_delete")
	await _wait(2.5)
	journal.close_journal()
	# 10) Captain Rook
	_caption("Kaptan Rook: Korsan Köşesi'ni kontrol etmezsen perdeden çıkar...")
	nc.select_cam("1C")
	await _wait(1.0)
	for st in [1, 2]:
		nc.ai.rook.stage = st
		nc._place_rook()
		nc._update_cove_visual()
		Sfx.play_at("curtain", world.root, Vector3(-10, 1.5, -9), 0.0)
		await _wait(2.0)
	nc.ai.rook.state = "out"
	nc.ai.rook.wait = 1.0
	nc._place_rook()
	nc._update_cove_visual()
	await _wait(1.2)
	_caption("...ve koşar! Sol kapıyı kapat")
	nc.select_cam("2A")
	await _wait(2.0)
	nc.set_monitor(false)
	nc.set_look(1.1)
	nc.toggle_door("left")
	await _wait(3.5)
	nc.toggle_door("left")
	# 11) Benny at the door
	_caption("Benny kameradan kayboldu — sol ışığa bak!")
	nc._move("benny", "ldoor")
	nc.ai.benny.door_t = 999.0
	await _wait(0.8)
	nc.toggle_light("left")
	await _wait(2.2)
	nc.toggle_door("left")
	nc.toggle_light("left")
	await _wait(2.5)
	nc.toggle_door("left")
	nc._move("benny", "stage")
	# 12) Grayson
	_caption("Grayson: kamerada izlendiği sürece donar, arkanı döndüğünde ilerler")
	nc.set_look(0.0)
	nc._move("grayson", "ecorner")
	nc.set_monitor(true)
	nc.select_cam("4B")
	await _wait(3.5)
	nc._move("grayson", "stage")
	# 13) Golden Grayson
	_caption("Golden Grayson: nadir görülen gizli karakter ve bozuk hafızası")
	nc.golden_events = [{"hour": nc.hours_f(), "kind": "memory", "memory": "m_gold_1", "done": false}]
	nc.select_cam("2B")
	await _wait(2.0)
	var gcam: Camera3D = world.cams["2B"].node
	Input.warp_mouse(gcam.unproject_position(chars.golden.global_position + Vector3(0, 0.6, 0)))
	await _wait(1.0)
	nc.try_pick_golden()
	await _wait(1.5)
	Input.warp_mouse(vp_center)
	_caption("Onu gördüysen... tableti indirdiğinde ofistedir. Hemen tableti kaldır!")
	nc.set_monitor(false)
	await _wait(1.8)
	nc.set_monitor(true)
	await _wait(1.0)
	nc.set_monitor(false)
	# 14) power out
	_caption("Elektrik biterse kapılar açılır, ışıklar söner... ve Grayson şarkısını söyler")
	nc.power = 0.0001
	while not nc.power_out:
		await get_tree().process_frame
	nc.po_timer = 1.5
	nc.set_look(1.1)
	while nc.po_phase < 1:
		await get_tree().process_frame
	nc.po_timer = 6.0
	await _wait_state(["gameover"], 20.0)
	_caption("")
	await _wait(2.0)
	# 15) jumpscare montage
	var names := {"benny": "Benny Beak", "brutus": "Brutus", "rook": "Kaptan Rook", "golden": "Golden Grayson"}
	for who in ["benny", "brutus", "rook", "golden"]:
		await _demo_night(2)
		_caption("Her animatroniğin kendine özgü saldırısı — " + names[who])
		await _wait(1.2)
		nc._jumpscare(who, 0.0)
		await _wait(0.25)
		var heard := []
		for pl in Sfx._pool:
			if pl.playing and pl.stream in [Sfx.streams["scream_" + who], Sfx.streams["scream_grayson"]]:
				heard.append(pl.stream.resource_path.get_file())
		print("jumpscare %s sounds: %s" % [who, heard])
		await _wait_state(["gameover"], 10.0)
		await _wait(0.8)
	# 16) 6 AM
	_caption("06:00'ya kadar dayan — 5 gece, her gece daha zor")
	await _demo_night(1)
	nc.time_s = nc.hour_len * 6.0 - 3.0
	await _wait_state(["win"], 10.0)
	await _wait(4.0)
	# 17) deduction + ending
	_caption("5. gecenin sonunda: Sonuç Raporu — kanıtları birleştir", true)
	for id in StoryData.CLUES.keys():
		GameState.add_clue(id, 5)
	_show_deduction()
	await _wait(1.5)
	for i in StoryData.QUESTIONS.size():
		_answers[i] = StoryData.QUESTIONS[i].answer
	await _wait(2.5)
	_caption("Üç farklı son — gerçeği bulabilecek misin?", true)
	_submit_deduction()
	await _wait(6.0)
	# 18) end card
	_show_only("card")
	state = "test"
	_card_label.text = "GREYFANG: 5 GECE\n\nyoutube.com/@eftelix"
	_card_label.modulate.a = 1.0
	_caption("")
	Sfx.stop_all()
	Sfx.play("laugh_grayson", 0.0)
	await _wait(4.0)


## Plays all five nights end-to-end with a bot through the real UI flow
## (voicemail, night card, win screen, journal, deduction, ending).
func _flowtest() -> void:
	GameState.args.append("--fast")
	Engine.time_scale = 3.0
	await _wait(1.0)
	_seed_edit.text = "777123"
	_new_game()
	await _wait(1.0)
	await _shot("30_intro")
	_intro_continue()
	_intro_continue()
	var bot := {"check": 0.0, "cam": 0.0, "cam_t": 0.0, "react": 0.0}
	var night_results := []
	var guard := 0
	while guard < 40:
		guard += 1
		while state == "card":
			await get_tree().process_frame
		if state != "night":
			break
		var n := GameState.night
		await _wait(0.5)
		await _shot("31_voicemail_n%d" % n)
		while state == "night":
			await get_tree().process_frame
			var dt := get_process_delta_time()
			if not nc.active or nc.dying:
				continue
			_flow_bot(bot, dt)
		if state == "win":
			night_results.append("night %d: WIN (power %.0f%%, clues tonight %d)" % [n, nc.power, nc.found_tonight.size()])
			await _wait(0.3)
			await _shot("32_win_n%d" % n)
			_after_win()
		elif state == "gameover" or state == "crash":
			night_results.append("night %d: died to %s at %s" % [n, _last_death, nc.clock_text()])
			while state == "crash":
				await get_tree().process_frame
			await _shot("33_gameover_n%d_%d" % [n, guard])
			_start_night(n, false)
		if state == "deduction":
			break
	for r in night_results:
		print(r)
	print("found clues: ", GameState.found.size(), " / ", StoryData.CLUES.size(), " -> ", GameState.found)
	if state == "deduction":
		await _wait(0.5)
		for i in StoryData.QUESTIONS.size():
			_answers[i] = StoryData.QUESTIONS[i].answer
		_submit_deduction()
		await _wait(0.5)
		await _shot("34_ending")
		print("ending: ", GameState.ending_id)
	Engine.time_scale = 1.0


func _flow_bot(b: Dictionary, dt: float) -> void:
	# grab evidence and memory like an attentive player would
	if nc.monitor_up:
		if nc.golden_state == "cam" and nc.cur_cam != "2B":
			nc.select_cam("2B")
		elif nc.golden_state == "cam" and nc.cur_cam == "2B":
			nc.try_pick_golden()
		else:
			for id in nc.clue_nodes.keys():
				var node = nc.clue_nodes[id]
				if is_instance_valid(node):
					if nc.cur_cam != node.get_meta("cam"):
						nc.select_cam(node.get_meta("cam"))
					else:
						nc.try_pick_clue(id)
					break
	_bot_step(b, dt)


func _sim_test() -> void:
	print("=== SIM TEST ===")
	nc.sim = true
	GameState.args.append("--fixed-rt")
	var summary := []
	for n in range(1, 6):
		for policy in ["passive", "smart"]:
			var wins := 0
			var causes := {}
			var power_end := 0.0
			var trials := 12
			for t in trials:
				nc.cause_stats = {}
				nc.start(n, 1000 + t)
				nc.rng.seed = hash("sim:%d:%d:%s" % [n, t, policy])
				var bot := {"check": 0.0, "cam": 0.0, "cam_t": 0.0, "react": 0.0}
				var steps := 0
				while nc.active and steps < 200000:
					steps += 1
					if policy == "smart":
						_bot_step(bot, 0.1)
					nc.step(0.1)
					for side in ["left", "right"]:
						if nc.doors[side]:
							causes["t_" + side] = causes.get("t_" + side, 0.0) + 0.1 / trials
					if nc.monitor_up:
						causes["t_mon"] = causes.get("t_mon", 0.0) + 0.1 / trials
					if nc.ai.rook.state != "cove" or int(nc.ai.rook.stage) >= 2:
						causes["t_rook"] = causes.get("t_rook", 0.0) + 0.1 / trials
					if nc.ai.grayson.loc == "ecorner":
						causes["t_gray"] = causes.get("t_gray", 0.0) + 0.1 / trials
				if nc.hour >= 6 and not nc.dying:
					wins += 1
					power_end += nc.power
				for k in nc.cause_stats.keys():
					if k.begins_with("attack"):
						causes[k] = causes.get(k, 0) + nc.cause_stats[k]
				nc.dying = false
			var line := "night %d %-7s wins %2d/%d  avg_power_left %.1f  deaths %s" % [n, policy, wins, trials, power_end / max(wins, 1), str(causes)]
			print(line)
			summary.append(line)
	nc.sim = false
	print("=== END SIM ===")


## a reasonable human-like player used to balance difficulty
func _bot_step(b: Dictionary, dt: float) -> void:
	b.check -= dt
	b.cam -= dt
	# react to golden in office
	if nc.golden_state == "office":
		b.react += dt
		if b.react > 0.8:
			nc.set_monitor(true)
			b.react = 0.0
		return
	if nc.monitor_up:
		b.cam_t -= dt
		if b.cam_t <= 0.0:
			nc.set_monitor(false)
		return
	# hearing Rook's footsteps: slam the left door right away
	if nc.ai.rook.state == "run" and not nc.doors.left:
		b.react += dt
		if b.react > 0.9:
			nc.toggle_door("left")
			b.react = 0.0
	# door checks every ~3 s (a brief light flash)
	if b.check <= 0.0:
		b.check = 2.8 + nc.rng.randf() * 1.5
		for side in ["left", "right"]:
			var who := nc._at_door(side)
			var rook_threat: bool = side == "left" and nc.ai.rook.state != "cove"
			var gray_threat: bool = side == "right" and nc.ai.grayson.loc == "ecorner"
			var want: bool = who != "" or rook_threat or gray_threat
			if want != nc.doors[side]:
				nc.toggle_door(side)
		nc.power -= 0.1 * 0.3 * 2  # cost of the quick light flashes
	# check cameras (cove) every 9-14 s
	if b.cam <= 0.0:
		b.cam = (5.0 if int(nc.ai.rook.stage) >= 2 else 9.0) + nc.rng.randf() * 4.0
		b.cam_t = 1.6
		if nc.ai.grayson.loc == "ecorner" and not nc.doors.right:
			nc.toggle_door("right")
		nc.select_cam("1C")
		nc.set_monitor(true)


func _clue_test() -> void:
	print("=== CLUE TEST ===")
	var problems := 0
	var cores := StoryData.core_ids()
	var orders := {}
	for sd in range(1, 301):
		# determinism
		var a := ClueSystem.plan(sd, 2, [], world.clue_spots)
		var b := ClueSystem.plan(sd, 2, [], world.clue_spots)
		var sa := []
		for e in a:
			sa.append(e.id + "@" + e.spot.id)
		var sb := []
		for e in b:
			sb.append(e.id + "@" + e.spot.id)
		if sa != sb:
			problems += 1
			print("non-deterministic seed ", sd)
		orders[str(sa)] = true
		# a sloppy player who finds only ~40% of what is placed each night
		var found := []
		var r := RandomNumberGenerator.new()
		r.seed = sd
		for n in range(1, 6):
			var plan := ClueSystem.plan(sd, n, found, world.clue_spots)
			var placed := []
			for e in plan:
				placed.append(e.id)
				if StoryData.CLUES[e.id].place.size() > 0 and not StoryData.CLUES[e.id].place.has(e.spot.kind):
					problems += 1
					print("bad spot kind ", e.id, " ", e.spot.kind)
			# every due core clue must be placed
			for cid in cores:
				if int(StoryData.CLUES[cid].night) <= n and not found.has(cid) and not placed.has(cid):
					problems += 1
					print("seed %d night %d missing core %s" % [sd, n, cid])
			for id in placed:
				if n == 5 or r.randf() < 0.4:
					found.append(id)
		for cid in cores:
			if not found.has(cid):
				problems += 1
				print("seed %d: core %s never obtainable" % [sd, cid])
	print("distinct layouts for night 2 over 300 seeds: ", orders.size())
	print("spots: ", world.clue_spots.size(), "  problems: ", problems)
	print("=== END CLUE TEST ===")
