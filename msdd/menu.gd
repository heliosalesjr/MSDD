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

	var btn1 := Button.new()
	btn1.text = "1 — Jogar"
	btn1.custom_minimum_size = Vector2(320, 60)
	btn1.add_theme_font_size_override("font_size", 26)
	btn1.pressed.connect(_on_play_pressed)
	vbox.add_child(btn1)

	var btn2 := Button.new()
	btn2.text = "2 — Exploração (proto)"
	btn2.custom_minimum_size = Vector2(320, 60)
	btn2.add_theme_font_size_override("font_size", 26)
	btn2.pressed.connect(_on_explore_pressed)
	vbox.add_child(btn2)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://explore.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_play_pressed()
		elif event.keycode == KEY_2:
			_on_explore_pressed()
