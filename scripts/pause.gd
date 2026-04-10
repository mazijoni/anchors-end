extends Control

@onready var normal_font = preload("res://fonts/HomeVideo-Regular.ttf")
@onready var bold_font   = preload("res://fonts/HomeVideo-Bold.ttf")

const ARROW_INDICATOR := "▶ "

func _ready() -> void:
	_connect_hover_signals(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # UI works when paused

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func toggle_pause() -> void:
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_game() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- Hover Effects ---
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

# --- Button Callbacks ---
func _on_resume_pressed() -> void:
	_resume_game()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
