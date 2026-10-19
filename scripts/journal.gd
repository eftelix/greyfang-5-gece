class_name Journal
extends Control
## Berk's evidence journal. Lists found evidence, filters by person/topic tags,
## shows linked evidence (shared tags) and replays tapes with garbled audio.
## It never states the answer; the player connects the pieces.

signal closed

var list_box: VBoxContainer
var detail_title: Label
var detail_meta: Label
var detail_text: RichTextLabel
var detail_links: Label
var play_btn: Button
var tag_filter: String = ""
var counter: Label
var selected: String = ""
var tag_buttons: Dictionary = {}
var _reveal: float = -1.0
var _voice: AudioStreamPlayer = null


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "BERK'İN KANIT GÜNLÜĞÜ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	top.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	counter = Label.new()
	counter.add_theme_font_size_override("font_size", 18)
	counter.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	top.add_child(counter)
	var close := Button.new()
	close.text = "  KAPAT [J / ESC]  "
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): close_journal())
	top.add_child(close)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	v.add_child(tags)
	var tl := Label.new()
	tl.text = "Süz: "
	tl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	tags.add_child(tl)
	for t in [""] + StoryData.TAGS:
		var b := Button.new()
		b.text = t if t != "" else "Tümü"
		b.toggle_mode = true
		b.button_pressed = t == ""
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _set_filter(t))
		tags.add_child(b)
		tag_buttons[t] = b
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(380, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 24)
	detail_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_title)
	detail_meta = Label.new()
	detail_meta.add_theme_font_size_override("font_size", 15)
	detail_meta.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
	right.add_child(detail_meta)
	play_btn = Button.new()
	play_btn.text = "▶  Kaydı oynat"
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.visible = false
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play_btn.pressed.connect(_play_tape)
	right.add_child(play_btn)
	detail_text = RichTextLabel.new()
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_text.add_theme_font_size_override("normal_font_size", 18)
	detail_text.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	detail_text.scroll_active = true
	right.add_child(detail_text)
	detail_links = Label.new()
	detail_links.add_theme_font_size_override("font_size", 15)
	detail_links.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
	detail_links.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_links)
	visible = false


func open_journal() -> void:
	visible = true
	refresh()


func close_journal() -> void:
	visible = false
	_stop_voice()
	closed.emit()


func _set_filter(t: String) -> void:
	tag_filter = t
	for k in tag_buttons.keys():
		tag_buttons[k].button_pressed = k == t
	refresh()


func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var total := StoryData.CLUES.size()
	counter.text = "Bulunan kanıt: %d / %d    Seed: %d    " % [GameState.found.size(), total, GameState.run_seed]
	if GameState.found.is_empty():
		var l := Label.new()
		l.text = "Henüz bir şey bulmadın.\n\nKameralarda yerinde durmayan nesnelere\n(kâğıtlar, kasetler, ekranlar, duvardaki izler)\ntıklayarak onları kaydet."
		l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
		list_box.add_child(l)
		_show("")
		return
	var by_night := {}
	for id in GameState.found:
		var c: Dictionary = StoryData.clue(id)
		if c.is_empty():
			continue
		if tag_filter != "" and not c.tags.has(tag_filter):
			continue
		var n: int = int(GameState.found_night.get(id, 1))
		if not by_night.has(n):
			by_night[n] = []
		by_night[n].append(id)
	var nights := by_night.keys()
	nights.sort()
	for n in nights:
		var h := Label.new()
		h.text = "— GECE %d —" % n
		h.add_theme_color_override("font_color", Color(0.75, 0.5, 0.35))
		list_box.add_child(h)
		for id in by_night[n]:
			var c: Dictionary = StoryData.clue(id)
			var b := Button.new()
			b.text = "[%s]  %s" % [StoryData.TYPE_NAMES[c.type], c.title]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = true
			b.custom_minimum_size = Vector2(360, 30)
			b.pressed.connect(func(): _show(id))
			list_box.add_child(b)
	if selected == "" or not GameState.found.has(selected):
		selected = GameState.found[GameState.found.size() - 1]
	_show(selected)


func _show(id: String) -> void:
	_stop_voice()
	selected = id
	if id == "":
		detail_title.text = ""
		detail_meta.text = ""
		detail_text.text = ""
		detail_links.text = ""
		play_btn.visible = false
		return
	var c: Dictionary = StoryData.clue(id)
	detail_title.text = c.title
	detail_meta.text = "%s   •   Tarih: %s   •   Etiketler: %s" % [StoryData.TYPE_NAMES[c.type], c.date, ", ".join(PackedStringArray(c.tags))]
	detail_text.text = c.text
	detail_text.visible_characters = -1
	play_btn.visible = c.type == "tape" or c.type == "memory"
	play_btn.text = "▶  Kaydı oynat" if c.type == "tape" else "▶  Belleği oku"
	# linked evidence by shared tags (no conclusions given)
	var links := []
	for other in GameState.found:
		if other == id:
			continue
		var oc: Dictionary = StoryData.clue(other)
		var shared := 0
		for t in c.tags:
			if oc.tags.has(t):
				shared += 1
		if shared >= 2:
			links.append(oc.title)
	detail_links.text = ("İlişkili olabilecek kanıtlar: " + "; ".join(PackedStringArray(links))) if links.size() > 0 else ""


func _play_tape() -> void:
	var c: Dictionary = StoryData.clue(selected)
	_stop_voice()
	Sfx.play("tape_click", -6.0)
	var voice: String = c.get("voice", "golden_whisper")
	if c.type == "memory":
		voice = "golden_whisper"
	_voice = Sfx.loop(voice, -10.0, 1.0 if c.type == "tape" else 0.8)
	detail_text.visible_characters = 0
	_reveal = 0.0


func _stop_voice() -> void:
	_reveal = -1.0
	for v in ["voice_selim", "voice_hakan", "voice_dila", "voice_owner", "golden_whisper"]:
		Sfx.stop_loop(v)
	_voice = null


func _process(delta: float) -> void:
	if _reveal >= 0.0 and visible:
		_reveal += delta * 30.0
		detail_text.visible_characters = int(_reveal)
		if _reveal >= detail_text.get_total_character_count():
			detail_text.visible_characters = -1
			_stop_voice()
			Sfx.play("tape_click", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("pause"):
		close_journal()
		get_viewport().set_input_as_handled()
