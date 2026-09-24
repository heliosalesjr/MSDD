extends Control

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "MSDD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Minesweeper × D&D"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	_add_option(
		vbox,
		"1 — Caça às chaves",
		"Ache 5 chaves escondidas no campo antes do tempo acabar.\nUm passo em falso numa bomba encerra a corrida.",
		_on_play_pressed
	)

	_add_option(
		vbox,
		"2 — Exploração (proto)",
		"Mova o cavaleiro por um mapa infinito de setores.\nCada portal abre um novo campo para revelar.",
		_on_explore_pressed
	)

	_add_option(
		vbox,
		"3 — Cripta",
		"Campo minado com regras de RPG: role os dados para desarmar armadilhas.\nJunte ouro e sobreviva com seus 5 pontos de vida.",
		_on_classic_pressed
	)

func _add_option(parent: VBoxContainer, label: String, description: String, callback: Callable) -> void:
	var option := VBoxContainer.new()
	option.add_theme_constant_override("separation", 6)
	parent.add_child(option)

	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(320, 60)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(callback)
	option.add_child(btn)

	var desc := Label.new()
	desc.text = description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 15)
	desc.modulate = Color(0.65, 0.65, 0.7)
	option.add_child(desc)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://explore.tscn")

func _on_classic_pressed() -> void:
	get_tree().change_scene_to_file("res://classic.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_play_pressed()
		elif event.keycode == KEY_2:
			_on_explore_pressed()
		elif event.keycode == KEY_3:
			_on_classic_pressed()
