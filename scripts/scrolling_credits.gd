# ============================================================================
#                           scrolling_credits.gd
#
# Purpose:
#   Creates a professional, smooth-scrolling credits screen. The text auto-
#   scrolls upwards, but the user can seamlessly take over by clicking and
#   dragging. After a drag, the auto-scroll will pause briefly before
#   resuming. Once the credits have finished, it will pause and then
#   transition to another scene.
#
# [!] HOW TO USE THIS SCRIPT:
#   1. Attach this script to a RichTextLabel node.
#   2. The RichTextLabel MUST be a child of a Control node (like a Panel or
#      MarginContainer) that defines the visible screen area.
#   3. In the Inspector, tweak the exported variables and drag your end logo
#      node into the "End Logo" slot.
# ============================================================================
extends RichTextLabel

# --- EXPORTS ---
@export_group("Scrolling")
@export var auto_scroll_speed: float = 100.0   # Speed in pixels per second.
@export_range(0.01, 1.0) var scroll_easing: float = 0.05 # How smoothly it moves. Lower is smoother.

@export_group("Dragging")
@export var drag_sensitivity: float = 1.5      # Multiplier for mouse drag speed.
@export var pause_after_drag: float = 1.5      # Seconds to wait before resuming auto-scroll.

@export_group("End Behavior")
@export var end_logo: TextureRect              # The logo that should be centered at the end.
@export var pause_at_end: float = 3.0          # Seconds to wait after credits finish.


# --- STATE ---
var _is_dragging := false
var _drag_pause_timer := 0.0
var _target_y: float

var _start_position_y: float
var _end_position_y: float
var _has_finished := false
var _end_timer: Timer


func _ready() -> void:
	var parent_container = get_parent() as Control
	if not parent_container:
		push_error("This node's parent must be a Control node.")
		set_process(false)
		return

	if not is_instance_valid(end_logo):
		push_error("'End Logo' must be assigned in the Inspector.")
		set_process(false)
		return

	var view_height = parent_container.size.y

	_start_position_y = view_height

	var parent_center_y = view_height / 2.0
	var logo_center_offset = end_logo.position.y + (end_logo.size.y / 2.0)
	_end_position_y = parent_center_y - logo_center_offset

	_target_y = _start_position_y
	position.y = _start_position_y


func _process(delta: float) -> void:
	if _is_dragging:
		return

	if _drag_pause_timer > 0:
		_drag_pause_timer -= delta
	elif not _has_finished:
		_target_y -= auto_scroll_speed * delta

	_target_y = max(_target_y, _end_position_y)

	position.y = lerp(position.y, _target_y, scroll_easing)

	if not _has_finished and abs(position.y - _end_position_y) <= 0.5:
		_has_finished = true
		position.y = _end_position_y

		_end_timer = Timer.new()
		add_child(_end_timer)
		_end_timer.wait_time = pause_at_end
		_end_timer.one_shot = true
		_end_timer.timeout.connect(_on_end_timer_timeout)
		_end_timer.start()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			if is_instance_valid(_end_timer):
				_end_timer.queue_free()
				_end_timer = null
			_has_finished = false
		else:
			_is_dragging = false
			_drag_pause_timer = pause_after_drag
			_target_y = position.y
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_dragging:
		position.y += event.relative.y * drag_sensitivity
		position.y = clamp(position.y, _end_position_y, _start_position_y)
		get_viewport().set_input_as_handled()


func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
