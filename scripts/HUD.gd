extends CanvasLayer
## Responsive touch HUD: landscape phones + keyboard/desktop.
var game: Node3D
var screen_root: Control
var match_ui: Control
var menu: Control
var touch: Dictionary = {"left": false, "right": false, "guard": false}
var left_hp: ColorRect
var right_hp: ColorRect
var left_energy: ColorRect
var right_energy: ColorRect
var name_left: Label
var name_right: Label
var clock_label: Label
var round_label: Label
var note_label: Label
var flash: ColorRect
var touch_buttons: Array[Button] = []
var hp_tracks: Array[ColorRect] = []
var energy_tracks: Array[ColorRect] = []
var screen_size := Vector2(1280, 720)

func setup(owner_game: Node3D) -> void:
	game = owner_game
	screen_root = Control.new()
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)
	match_ui = Control.new()
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(match_ui)
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_root.add_child(menu)
	for _i in range(2):
		var hp := _rect(match_ui, Color("#161923"))
		hp_tracks.append(hp)
		var energy := _rect(match_ui, Color("#131924"))
		energy_tracks.append(energy)
	left_hp = _rect(match_ui, Color("#dd5148"))
	right_hp = _rect(match_ui, Color("#e0b24f"))
	left_energy = _rect(match_ui, Color("#74dee1"))
	right_energy = _rect(match_ui, Color("#74dee1"))
	name_left = _label(match_ui, "БОМЖ", 29, Color("#f3f0e9"), HORIZONTAL_ALIGNMENT_LEFT)
	name_right = _label(match_ui, "ГОПНИК", 29, Color("#f3f0e9"), HORIZONTAL_ALIGNMENT_RIGHT)
	clock_label = _label(match_ui, "90", 50, Color("#ffdc8e"), HORIZONTAL_ALIGNMENT_CENTER)
	round_label = _label(match_ui, "РАУНД 1", 20, Color("#ded5cf"), HORIZONTAL_ALIGNMENT_CENTER)
	note_label = _label(match_ui, "", 31, Color("#faf6ed"), HORIZONTAL_ALIGNMENT_CENTER)
	var controls = [
		["left", "◀", Color("#283646")],
		["right", "▶", Color("#283646")],
		["guard", "БЛОК", Color("#303f52")],
		["punch", "УДАР", Color("#783c44")],
		["kick", "НОГА", Color("#824e31")],
		["special1", "СУПЕР 1", Color("#375968")],
		["special2", "СУПЕР 2", Color("#625070")]
	]
	for entry in controls:
		var key: String = entry[0]
		var button := _button(match_ui, entry[1], entry[2], 19)
		button.set_meta("control", key)
		touch_buttons.append(button)
		if key in ["left", "right", "guard"]:
			button.button_down.connect(func(): touch[key] = true)
			button.button_up.connect(func(): touch[key] = false)
		else:
			button.pressed.connect(func(): game.player_action(key))
	flash = _rect(screen_root, Color(1, 0.12, 0.07, 0.0))
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_match_visible(false)
	show_menu("start")

func _rect(parent: Control, color: Color) -> ColorRect:
	var n := ColorRect.new()
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func _label(parent: Control, txt: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var n := Label.new()
	n.text = txt
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", col)
	n.horizontal_alignment = align
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func _button(parent: Control, txt: String, col: Color, font_size: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color("#fdf4e9"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = col
	normal.border_color = Color("#b1a9a1")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(9)
	var down := normal.duplicate() as StyleBoxFlat
	down.bg_color = col.lightened(0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", down)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b

func _layout() -> void:
	screen_size = get_viewport().get_visible_rect().size
	if screen_root == null:
		return
	screen_root.position = Vector2.ZERO
	screen_root.size = screen_size
	match_ui.size = screen_size
	menu.size = screen_size
	flash.position = Vector2.ZERO
	flash.size = screen_size
	var w := screen_size.x
	var h := screen_size.y
	var margin := w * 0.037
	var bar_width := w * 0.346
	var bar_height := maxf(15, h * 0.034)
	hp_tracks[0].position = Vector2(margin, h * 0.093)
	hp_tracks[1].position = Vector2(w - margin - bar_width, h * 0.093)
	for b in hp_tracks:
		b.size = Vector2(bar_width, bar_height)
	energy_tracks[0].position = Vector2(margin, h * 0.135)
	energy_tracks[1].position = Vector2(w - margin - bar_width, h * 0.135)
	for b in energy_tracks:
		b.size = Vector2(bar_width, h * 0.013)
	name_left.position = Vector2(margin, h * 0.025)
	name_right.position = Vector2(w - margin - bar_width, h * 0.025)
	for n in [name_left, name_right]:
		n.size = Vector2(bar_width, h * 0.066)
	clock_label.position = Vector2(w * 0.448, h * 0.039)
	clock_label.size = Vector2(w * 0.104, h * 0.077)
	round_label.position = Vector2(w * 0.423, h * 0.133)
	round_label.size = Vector2(w * 0.154, h * 0.043)
	note_label.position = Vector2(w * 0.25, h * 0.24)
	note_label.size = Vector2(w * 0.50, h * 0.12)
	var unit := minf(w * 0.115, h * 0.145)
	var base := h - unit - h * 0.055
	var spots := [
		Vector2(w * 0.04, base),
		Vector2(w * 0.04 + unit * 1.1, base),
		Vector2(w * 0.04 + unit * 2.2, base),
		Vector2(w - w * 0.04 - unit * 4.4, base),
		Vector2(w - w * 0.04 - unit * 3.3, base),
		Vector2(w - w * 0.04 - unit * 2.2, base),
		Vector2(w - w * 0.04 - unit * 1.1, base)
	]
	for i in range(touch_buttons.size()):
		touch_buttons[i].position = spots[i]
		touch_buttons[i].size = Vector2(unit * 1.0, unit * 0.96)
	_layout_menu()

func set_match_visible(yes: bool) -> void:
	match_ui.visible = yes
	for key in touch.keys():
		touch[key] = false

func set_note(note: String) -> void:
	note_label.text = note

func set_flash(intensity: float) -> void:
	flash.visible = intensity > 0.001
	flash.color = Color(0.97, 0.18, 0.12, intensity * 0.32)

func update_bars(player, opponent, seconds: int, round_num: int, victories_player: int, victories_cpu: int) -> void:
	var w := hp_tracks[0].size.x
	var ew := energy_tracks[0].size.x
	left_hp.position = hp_tracks[0].position
	left_hp.size = Vector2(maxf(0, w * player.hp / 100.0), hp_tracks[0].size.y)
	right_hp.size = Vector2(maxf(0, w * opponent.hp / 100.0), hp_tracks[1].size.y)
	right_hp.position = Vector2(hp_tracks[1].position.x + w - right_hp.size.x, hp_tracks[1].position.y)
	left_energy.position = energy_tracks[0].position
	left_energy.size = Vector2(ew * player.energy / 100.0, energy_tracks[0].size.y)
	right_energy.size = Vector2(ew * opponent.energy / 100.0, energy_tracks[1].size.y)
	right_energy.position = Vector2(energy_tracks[1].position.x + ew - right_energy.size.x, energy_tracks[1].position.y)
	name_left.text = "БОМЖ" if player.kind == 0 else "ГОПНИК"
	name_right.text = "БОТ: БОМЖ" if opponent.kind == 0 else "БОТ: ГОПНИК"
	clock_label.text = str(seconds)
	round_label.text = "РАУНД %d   %d : %d" % [round_num, victories_player, victories_cpu]
	for i in range(5, 7):
		touch_buttons[i].modulate.a = 1.0 if player.energy >= (40.0 if i == 5 else 65.0) else 0.45

func show_menu(mode: String) -> void:
	menu.visible = true
	for n in menu.get_children():
		n.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.035, 0.044, 0.07, 0.86)
	menu.add_child(background)
	background.set_meta("menu_background", true)
	var title := _label(menu, "БОМЖ  ПРОТИВ  ГОПНИКА", 52, Color("#f0deba"))
	title.set_meta("menu_title", true)
	var subtitle := _label(menu, "ПРОВИНЦИЯ • 1997  |  ОДИН ПРОТИВ КОМПЬЮТЕРА", 23, Color("#c8a077"))
	subtitle.set_meta("menu_subtitle", true)
	var info := _label(menu, "Выбери бойца", 30, Color("#eae9e8"))
	info.set_meta("menu_info", true)
	if mode == "final":
		info.text = "ПОБЕДА!" if game.player_won() else "ПОРАЖЕНИЕ"
	elif mode == "start":
		info.text = "ВЫБЕРИ СВОЕГО БОЙЦА"
	var bomj := _button(menu, "БОМЖ\n\nБорода • лохмотья • уличная закалка\n\n40 энергии: ОГНЕННАЯ ОТРЫЖКА\n65 энергии: КОШАЧИЙ ДЕСАНТ", Color("#3b473c"), 22)
	bomj.set_meta("choice", 0)
	bomj.pressed.connect(func(): game.start_match(0))
	var gopnik := _button(menu, "ГОПНИК\n\nКожанка • спортивки • дерзкий взгляд\n\n40 энергии: СЕМЕЧКИ В ГЛАЗ\n65 энергии: ТЕЛЕФОН-КИРПИЧ", Color("#393b4a"), 22)
	gopnik.set_meta("choice", 1)
	gopnik.pressed.connect(func(): game.start_match(1))
	var help := _label(menu, "Управление: A / D — ходить, J — удар, K — нога, L — блок, U / I — суперудары", 18, Color("#aab4be"))
	help.set_meta("menu_help", true)
	_layout_menu()

func _layout_menu() -> void:
	if menu == null:
		return
	var w := screen_size.x
	var h := screen_size.y
	for n in menu.get_children():
		if n.has_meta("menu_background"):
			n.position = Vector2.ZERO
			n.size = screen_size
		elif n.has_meta("menu_title"):
			n.position = Vector2(w * 0.06, h * 0.065)
			n.size = Vector2(w * 0.88, h * 0.12)
		elif n.has_meta("menu_subtitle"):
			n.position = Vector2(w * 0.06, h * 0.19)
			n.size = Vector2(w * 0.88, h * 0.06)
		elif n.has_meta("menu_info"):
			n.position = Vector2(w * 0.1, h * 0.285)
			n.size = Vector2(w * 0.8, h * 0.075)
		elif n.has_meta("choice"):
			var i: int = n.get_meta("choice")
			n.position = Vector2(w * (0.12 if i == 0 else 0.515), h * 0.39)
			n.size = Vector2(w * 0.365, h * 0.40)
		elif n.has_meta("menu_help"):
			n.position = Vector2(w * 0.07, h * 0.84)
			n.size = Vector2(w * 0.86, h * 0.075)

func hide_menu() -> void:
	menu.visible = false
