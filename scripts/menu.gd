extends Control

@onready var normal_font = preload("res://fonts/HomeVideo-Regular.ttf")
@onready var bold_font   = preload("res://fonts/HomeVideo-Bold.ttf")

const ARROW_INDICATOR := "▶ "

func _ready() -> void:
	_connect_hover_signals(self)

func _connect_hover_signals(node):
	for child in node.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_button_hover.bind(child))
			child.mouse_exited.connect(_on_button_exit.bind(child))
		elif child.get_child_count() > 0:
			_connect_hover_signals(child)

func _on_button_hover(button: Button) -> void:
	button.add_theme_font_override("font", bold_font)
	if not button.text.begins_with(ARROW_INDICATOR):
		button.text = ARROW_INDICATOR + button.text

func _on_button_exit(button: Button) -> void:
	button.add_theme_font_override("font", normal_font)
	button.text = button.text.replace(ARROW_INDICATOR, "")

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
