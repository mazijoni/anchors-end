extends Control

# ── Static node refs ──────────────────────────────────────────────
@onready var output_vbox    : VBoxContainer   = $CenterContainer/Monitor/MarginContainer/VBox/OutputBg/OutputScroll/OutputVBox
@onready var output_scroll  : ScrollContainer = $CenterContainer/Monitor/MarginContainer/VBox/OutputBg/OutputScroll
@onready var clock_label    : Label           = $CenterContainer/Monitor/MarginContainer/VBox/StatusBar/ClockLabel
@onready var ready_label    : Label           = $CenterContainer/Monitor/MarginContainer/VBox/TitleBar/ReadyLabel
@onready var launch_overlay : ColorRect       = $LaunchOverlay
@onready var launch_text    : Label           = $LaunchOverlay/LaunchCenter/LaunchVBox/LaunchText
@onready var loading_bar    : ProgressBar     = $LaunchOverlay/LaunchCenter/LaunchVBox/BarBg/LoadingBar
@onready var launch_sub     : Label           = $LaunchOverlay/LaunchCenter/LaunchVBox/LaunchSub

# ── Fonts ─────────────────────────────────────────────────────────
var font_regular : FontFile
var font_bold    : FontFile

# ── Colors ────────────────────────────────────────────────────────
const C_GREEN     := Color(0.224, 1.0,   0.082, 1.0)
const C_GREEN_DIM := Color(0.102, 0.475, 0.031, 1.0)
const C_AMBER     := Color(1.0,   0.702, 0.0,   1.0)
const C_RED       := Color(1.0,   0.235, 0.235, 1.0)
const C_WHITE     := Color(0.910, 1.0,   0.910, 1.0)
const C_TRACK     := Color(0.039, 0.078, 0.039, 1.0)
const C_BORDER    := Color(0.102, 0.475, 0.031, 0.8)

# ── Block-bar settings ────────────────────────────────────────────
const BAR_BLOCKS  : int    = 10      # total block characters
const BLOCK_FULL  : String = "█"
const BLOCK_EMPTY : String = "░"

# ── Audio buses ───────────────────────────────────────────────────
const BUS_MASTER    := "Master"
const BUS_MUSIC     := "Music"
const BUS_SFX       := "SFX"
const SETTINGS_PATH := "user://settings.cfg"

# ── Typing state ──────────────────────────────────────────────────
const CHAR_DELAY : float = 0.018
const LINE_DELAY : float = 0.07

# Queue entry types:
#   { "type":"text",   "text":String, "color":Color }
#   { "type":"slider", "label":String, "key":String, "value":float }
#   { "type":"toggle", "label":String, "key":String, "value":bool }
#   { "type":"button", "label":String, "key":String }
var _queue      : Array = []
var _cur_text   : String = ""
var _cur_color  : Color  = C_WHITE
var _char_idx   : int    = 0
var _char_timer : float  = 0.0
var _line_pause : float  = 0.0
var _typing     : bool   = false
var _cur_label  : Label  = null

# ── Runtime state ─────────────────────────────────────────────────
var _clock_timer   : float = 0.0
var _blink_timer   : float = 0.0
var _blink_state   : bool  = true
var _loading       : bool  = false
var _load_progress : float = 0.0
var _in_settings   : bool  = false

# Settings values
var _vol_master  : float = 80.0
var _vol_music   : float = 70.0
var _vol_sfx     : float = 90.0
var _brightness  : float = 60.0
var _fullscreen  : bool  = false


# ════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Load fonts
	font_regular = load("res://fonts/HomeVideo-Regular.ttf")
	font_bold    = load("res://fonts/HomeVideo-Bold.ttf")

	# Apply font to every existing Label/Button in the tree
	_apply_fonts_recursive(self)

	# Connect menu buttons
	$CenterContainer/Monitor/MarginContainer/VBox/MenuList/BtnNewGame.pressed.connect(_on_new_game)
	$CenterContainer/Monitor/MarginContainer/VBox/MenuList/BtnLoadGame.pressed.connect(_on_load_game)
	$CenterContainer/Monitor/MarginContainer/VBox/MenuList/BtnSettings.pressed.connect(_on_open_settings)
	$CenterContainer/Monitor/MarginContainer/VBox/MenuList/BtnCredits.pressed.connect(_on_credits)
	$CenterContainer/Monitor/MarginContainer/VBox/MenuList/BtnQuit.pressed.connect(_on_quit)

	launch_overlay.visible = false
	_load_settings()

	_show([
		_t("[ SYS ] Initializing game engine... ", C_GREEN_DIM),
		_t("OK",                                    C_GREEN),
		_t("\n[ SYS ] Loading player data... ",     C_GREEN_DIM),
		_t("OK",                                    C_GREEN),
		_t("\n> Welcome back, Player. What would you like to do?", C_WHITE),
	])


# Apply HomeVideo font to all Labels and Buttons already in the scene tree
func _apply_fonts_recursive(node: Node) -> void:
	if font_regular == null:
		return
	if node is Label:
		node.add_theme_font_override("font", font_regular)
	elif node is Button or node is CheckButton:
		node.add_theme_font_override("font", font_regular)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font_regular)
		node.add_theme_font_override("bold_font", font_bold if font_bold else font_regular)
	for child in node.get_children():
		_apply_fonts_recursive(child)


# Apply font to a single newly-created node
func _apply_font(node: Control) -> void:
	if font_regular == null:
		return
	if node is Label:
		node.add_theme_font_override("font", font_regular)
	elif node is Button or node is CheckButton:
		node.add_theme_font_override("font", font_regular)


# ════════════════════════════════════════════════════════════════
#  QUEUE HELPERS
# ════════════════════════════════════════════════════════════════

func _t(text: String, color: Color) -> Dictionary:
	return { "type": "text", "text": text, "color": color }

func _s(label: String, key: String, value: float) -> Dictionary:
	return { "type": "slider", "label": label, "key": key, "value": value }

func _tog(label: String, key: String, value: bool) -> Dictionary:
	return { "type": "toggle", "label": label, "key": key, "value": value }

func _btn(label: String, key: String) -> Dictionary:
	return { "type": "button", "label": label, "key": key }


# ════════════════════════════════════════════════════════════════
#  SHOW — clears output and types new content
# ════════════════════════════════════════════════════════════════

func _show(entries: Array) -> void:
	_typing    = false
	_queue     = []
	_cur_label = null
	for child in output_vbox.get_children():
		child.queue_free()
	_queue  = entries.duplicate()
	_typing = true
	_next()


func _next() -> void:
	if _queue.is_empty():
		_typing = false
		_scroll_bottom()
		return

	var e : Dictionary = _queue.pop_front()

	match e["type"]:
		"text":
			_cur_text   = e["text"]
			_cur_color  = e["color"]
			_char_idx   = 0
			_char_timer = 0.0
			_line_pause = 0.0
			if _cur_text.begins_with("\n"):
				_cur_text  = _cur_text.substr(1)
				_cur_label = _new_label("")
				output_vbox.add_child(_cur_label)
			elif _cur_label == null:
				_cur_label = _new_label("")
				output_vbox.add_child(_cur_label)

		"slider":
			_add_slider_row(e["label"], e["key"], e["value"])
			_line_pause = LINE_DELAY

		"toggle":
			_add_toggle_row(e["label"], e["key"], e["value"])
			_line_pause = LINE_DELAY

		"button":
			_add_output_btn(e["label"], e["key"])
			_line_pause = LINE_DELAY


# ════════════════════════════════════════════════════════════════
#  NODE FACTORIES
# ════════════════════════════════════════════════════════════════

func _new_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", C_WHITE)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(lbl)
	return lbl


# ── Builds: > Label: ██████░░░░ 60%
#    with an invisible HSlider on top for interaction
func _add_slider_row(label_text: String, key: String, initial: float) -> void:
	# Outer container — stack (Control) so slider overlays the label
	var container := Control.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 22)

	# The text label showing the bar
	var lbl := Label.new()
	lbl.text = _bar_text(label_text, initial)
	lbl.add_theme_color_override("font_color", C_WHITE)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.anchor_right  = 1.0
	lbl.anchor_bottom = 1.0
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(lbl)
	container.add_child(lbl)

	# Invisible HSlider on top — same size, handles drag input
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = initial
	slider.step = 1.0
	slider.anchor_right  = 1.0
	slider.anchor_bottom = 1.0
	slider.modulate = Color(1, 1, 1, 0)   # fully transparent — invisible
	slider.focus_mode = Control.FOCUS_NONE
	container.add_child(slider)

	slider.value_changed.connect(func(v: float) -> void:
		lbl.text = _bar_text(label_text, v)
		_on_slider_changed(key, v)
	)

	output_vbox.add_child(container)
	_cur_label = null


# ── Builds: > Fullscreen: ON/OFF  with a clickable toggle
func _add_toggle_row(label_text: String, key: String, initial: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Prefix label
	var prefix := Label.new()
	prefix.text = "> " + label_text + ":"
	prefix.add_theme_color_override("font_color", C_WHITE)
	prefix.add_theme_font_size_override("font_size", 13)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(prefix)
	row.add_child(prefix)

	# Status label (ON / OFF) — acts as the button
	var status := Label.new()
	status.text = "ON" if initial else "OFF"
	status.add_theme_color_override("font_color", C_GREEN if initial else C_GREEN_DIM)
	status.add_theme_font_size_override("font_size", 13)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(status)
	row.add_child(status)

	# Hint
	var hint := Label.new()
	hint.text = "  [click to toggle]"
	hint.add_theme_color_override("font_color", C_GREEN_DIM)
	hint.add_theme_font_size_override("font_size", 11)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(hint)
	row.add_child(hint)

	# Make the row clickable via a Button overlaid
	var click_btn := Button.new()
	click_btn.anchor_right  = 1.0
	click_btn.anchor_bottom = 1.0
	click_btn.modulate = Color(1, 1, 1, 0)
	click_btn.flat = true

	var _state := [initial]
	click_btn.pressed.connect(func() -> void:
		_state[0] = !_state[0]
		status.text = "ON" if _state[0] else "OFF"
		status.add_theme_color_override("font_color", C_GREEN if _state[0] else C_GREEN_DIM)
		_on_toggle_changed(key, _state[0])
	)

	# Wrap row in a Control so we can overlay the button
	var wrap := Control.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 22)

	row.anchor_right  = 1.0
	row.anchor_bottom = 1.0
	wrap.add_child(row)
	wrap.add_child(click_btn)

	output_vbox.add_child(wrap)
	_cur_label = null


func _add_output_btn(label_text: String, key: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_color_override("font_color", C_GREEN_DIM)
	btn.add_theme_color_override("font_hover_color", C_GREEN)
	btn.add_theme_color_override("font_pressed_color", C_GREEN)
	btn.add_theme_font_size_override("font_size", 13)
	_apply_font(btn)
	_style_output_btn(btn)
	btn.pressed.connect(func() -> void: _on_output_button(key))
	output_vbox.add_child(btn)
	_cur_label = null


# ── Generates the bar string: > Master Volume: ████████░░ 80%
func _bar_text(label: String, value: float) -> String:
	var filled : int = int(round((value / 100.0) * BAR_BLOCKS))
	var empty  : int = BAR_BLOCKS - filled
	var bar    : String = BLOCK_FULL.repeat(filled) + BLOCK_EMPTY.repeat(empty)
	return "> " + label + ": " + bar + " " + "%d%%" % int(value)


# ════════════════════════════════════════════════════════════════
#  STYLES
# ════════════════════════════════════════════════════════════════

func _style_output_btn(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("focus",  normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.224, 1.0, 0.082, 0.07)
	hover.border_color = C_BORDER
	hover.set_border_width_all(1)
	hover.set_content_margin_all(2)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)


# ════════════════════════════════════════════════════════════════
#  _process — typing animation + clock + loading
# ════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	# Clock
	_clock_timer += delta
	if _clock_timer >= 1.0:
		_clock_timer = 0.0
		var t := Time.get_time_dict_from_system()
		clock_label.text = "%02d:%02d:%02d" % [t["hour"], t["minute"], t["second"]]

	# Blink
	_blink_timer += delta
	if _blink_timer >= 0.8:
		_blink_timer = 0.0
		_blink_state = !_blink_state
		ready_label.visible = _blink_state

	# Launch bar
	if _loading:
		_load_progress += delta / 2.5
		loading_bar.value = clamp(_load_progress * 100.0, 0.0, 100.0)
		if _load_progress >= 1.0:
			_loading = false
			launch_overlay.visible = false
			_load_progress = 0.0

	if not _typing:
		return

	# Inter-item pause
	if _line_pause > 0.0:
		_line_pause -= delta
		if _line_pause <= 0.0:
			_next()
		return

	if _cur_label == null:
		return

	# Type characters
	_char_timer += delta
	while _char_timer >= CHAR_DELAY and _char_idx < _cur_text.length():
		_char_timer -= CHAR_DELAY
		_cur_label.text += _cur_text[_char_idx]
		_cur_label.add_theme_color_override("font_color", _cur_color)
		_char_idx += 1

	if _char_idx >= _cur_text.length():
		_cur_label  = null
		_line_pause = LINE_DELAY


func _scroll_bottom() -> void:
	await get_tree().process_frame
	output_scroll.scroll_vertical = output_scroll.get_v_scroll_bar().max_value


# ════════════════════════════════════════════════════════════════
#  KEYBOARD
# ════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE and _in_settings:
		_on_close_settings()
		return
	if _in_settings:
		return
	match event.keycode:
		KEY_1: _on_new_game()
		KEY_2: _on_load_game()
		KEY_3: _on_open_settings()
		KEY_4: _on_credits()
		KEY_Q: _on_quit()


# ════════════════════════════════════════════════════════════════
#  MENU ACTIONS
# ════════════════════════════════════════════════════════════════

func _on_new_game() -> void:
	_show([
		_t("[ NEW GAME ]", C_AMBER),
		_t(" Starting fresh adventure...", C_WHITE),
		_t("	done", C_GREEN_DIM),
		_t("\n> Loading world generator...", C_WHITE),
		_t("	done", C_GREEN_DIM),
	])
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_load_game() -> void:
	_show([
		_t("[ LOAD GAME ]", C_AMBER),
		_t(" Save files found: 3", C_WHITE),
		_t("\n> SLOT 1 — Chapter 3, Village of Arden   ", C_WHITE),
		_t("(2h 34m)", C_GREEN_DIM),
		_t("\n> SLOT 2 — Chapter 1, Tutorial Complete  ", C_WHITE),
		_t("(0h 18m)", C_GREEN_DIM),
		_t("\n> SLOT 3 — Chapter 5, The Dark Tower     ", C_WHITE),
		_t("(8h 02m)", C_GREEN_DIM),
		_t("\n> Click a slot above to load it.", C_GREEN_DIM),
	])


func _on_open_settings() -> void:
	_in_settings = true
	_show([
		_t("[ SETTINGS ]", C_AMBER),
		_t(" Drag the bars to adjust. ESC or Back to return.", C_GREEN_DIM),
		_t("\n── AUDIO ──────────────────────────────────", C_GREEN_DIM),
		_s("Master Volume", "master",     _vol_master),
		_s("Music Volume",  "music",      _vol_music),
		_s("SFX Volume",    "sfx",        _vol_sfx),
		_t("── VIDEO ──────────────────────────────────", C_GREEN_DIM),
		_s("Brightness",    "brightness", _brightness),
		_tog("Fullscreen",  "fullscreen", _fullscreen),
		_t("\n", C_GREEN_DIM),
		_btn("> [ ESC ]  Back to Main Menu", "back"),
	])


func _on_close_settings() -> void:
	_in_settings = false
	_save_settings()
	_show([
		_t("[ SETTINGS ]", C_AMBER),
		_t(" All settings saved.", C_GREEN),
		_t("\n> What would you like to do next?", C_WHITE),
	])


func _on_credits() -> void:
	_show([
		_t("[ Game name ]", C_AMBER),
		_t("\nA game by", C_WHITE),
		_t("\nMaze_development", C_RED),

		_t("\n\n--- LEAD DESIGN & PROGRAMMING ---", C_AMBER),
		_t("\nJonatan Lund Ermesjø", C_WHITE),

		_t("\n\n--- PRODUCTION ---", C_AMBER),
		_t("\nProducer ...................... Maze_development", C_WHITE),
		_t("\nAssociate Producer ............ [Your Name/Studio Here]", C_WHITE),

		_t("\n\n--- ART & VISUALS ---", C_AMBER),
		_t("\nLead Artist ................... Jonatan Lund Ermesjø", C_WHITE),
		_t("\nCharacter designer ............ Jonatan Lund Ermesjø", C_WHITE),
		_t("\nEnvironment Art ............... Jonatan Lund Ermesjø", C_WHITE),
		_t("\nVFX ........................... Jonatan Lund Ermesjø", C_WHITE),

		_t("\n\n--- AUDIO ---", C_AMBER),
		_t("\nMusic Composition ............. [Your Name/Studio Here]", C_WHITE),
		_t("\nSound Effects ................. [Your Name/Studio Here]", C_WHITE),

		_t("\n\n--- QUALITY ASSURANCE ---", C_AMBER),
		_t("\nLead QA Tester ................ Maze_development", C_WHITE),
		_t("\nQA Team ....................... Jonatan lund ermesjø", C_WHITE),

		_t("\n\n--- SPECIAL THANKS ---", C_AMBER),
		_t("\nThe Godot Engine Community", C_WHITE),
		_t("\nOur Families & Friends", C_WHITE),
		_t("\nYou, for supporting this project!", C_WHITE),

		_t("\n\nThis game was crafted with care by maze_development", C_WHITE),
		_t("\nFind more projects:", C_WHITE),
		_t("\nmaze-dev.itch.io", C_RED),

		_t("\n\nThank you for playing!", C_WHITE),
		_t("\nPLEASE play again", C_AMBER),
	])

func _on_quit() -> void:
	_show([
		_t("[ QUIT ]", C_AMBER),
		_t(" Saving and shutting down...", C_WHITE),
		_t("\n> Your progress has been saved automatically.", C_WHITE),
		_t("\n> Thanks for playing. See you next time!", C_WHITE),
	])
	await get_tree().create_timer(2.5).timeout
	get_tree().quit()


func _on_output_button(key: String) -> void:
	if key == "back":
		_on_close_settings()


# ════════════════════════════════════════════════════════════════
#  SETTINGS CALLBACKS
# ════════════════════════════════════════════════════════════════

func _on_slider_changed(key: String, value: float) -> void:
	match key:
		"master":
			_vol_master = value
			_set_bus_volume(BUS_MASTER, value)
		"music":
			_vol_music = value
			_set_bus_volume(BUS_MUSIC, value)
		"sfx":
			_vol_sfx = value
			_set_bus_volume(BUS_SFX, value)
		"brightness":
			_brightness = value
			var t : float = value / 100.0
			$Background.color = Color(0.039 * t, 0.059 * t, 0.039 * t, 1.0)


func _on_toggle_changed(key: String, pressed: bool) -> void:
	if key == "fullscreen":
		_fullscreen = pressed
		if pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = 0
	if percent <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))


# ════════════════════════════════════════════════════════════════
#  SAVE / LOAD
# ════════════════════════════════════════════════════════════════

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master",     _vol_master)
	cfg.set_value("audio", "music",      _vol_music)
	cfg.set_value("audio", "sfx",        _vol_sfx)
	cfg.set_value("video", "brightness", _brightness)
	cfg.set_value("video", "fullscreen", _fullscreen)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_vol_master = cfg.get_value("audio", "master",     80.0)
	_vol_music  = cfg.get_value("audio", "music",      70.0)
	_vol_sfx    = cfg.get_value("audio", "sfx",        90.0)
	_brightness = cfg.get_value("video", "brightness", 60.0)
	_fullscreen = cfg.get_value("video", "fullscreen", false)
	_set_bus_volume(BUS_MASTER, _vol_master)
	_set_bus_volume(BUS_MUSIC,  _vol_music)
	_set_bus_volume(BUS_SFX,    _vol_sfx)
	var t : float = _brightness / 100.0
	$Background.color = Color(0.039 * t, 0.059 * t, 0.039 * t, 1.0)
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
