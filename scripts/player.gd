extends CharacterBody3D

# Player Nodes
@onready var head = $Head
@onready var eyes = $Head/eyes
@onready var standing_collision_shape = $standing_collision_shape
@onready var crouching_collision_shape = $chrouching_collision_shape
@onready var ray_cast_3d = $RayCast3D
@onready var animation_player = $"Head/eyes/Arms Senter/PSX_First_Person_Arms/AnimationPlayer"
@onready var arms_senter = $"Head/eyes/Arms Senter"

# Speed Vars
@export var current_speed := 5.0
@export var walking_speed := 5.0
@export var sprinting_speed := 8.0
@export var crouching_speed := 2.0
@export var jump_velocity := 4.5
@export var mouse_sens := 0.5
@export var lerp_speed := 10.0
@export var direction := Vector3.ZERO
@export var crouching_depth := -0.5

# States
var walking := false
var sprinting := false
var crouching := false
var is_moving_backward := false

# Punch vars
var is_punching := false
var next_punch_is_right := true
var punch_reset_timer := 0.0
@export var punch_reset_delay := 1.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	animation_player.animation_finished.connect(_on_animation_finished)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("punch") and not is_punching:
		_play_punch()

	if not is_punching:
		punch_reset_timer += delta
		if punch_reset_timer >= punch_reset_delay:
			next_punch_is_right = true

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	is_moving_backward = input_dir.y > 0.0

	direction = direction.lerp(
		(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),
		delta * lerp_speed
	)

	if direction.length() > 0.01:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

	if not is_punching:
		_handle_animations()

func _play_punch() -> void:
	is_punching = true
	punch_reset_timer = 0.0
	animation_player.speed_scale = 1.0
	animation_player.play("punch_right" if next_punch_is_right else "punch_left")
	next_punch_is_right = not next_punch_is_right


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "punch_right" or anim_name == "punch_left":
		is_punching = false

func _handle_animations() -> void:
	if not is_on_floor():
		animation_player.speed_scale = 1.0
		if velocity.y < 0.0:
			if animation_player.current_animation != "falling":
				animation_player.play("falling")
		else:
			if animation_player.current_animation != "jump":
				animation_player.play("jump")

	elif direction.length() > 0.1:
		animation_player.speed_scale = -1.0 if is_moving_backward else 1.0

		if sprinting:
			if animation_player.current_animation != "sprint":
				animation_player.play("sprint")
		elif crouching:
			if animation_player.current_animation != "crouch_walk":
				animation_player.play("crouch_walk")
		else:
			if animation_player.current_animation != "walk":
				animation_player.play("walk")

	else:
		animation_player.speed_scale = 1.0
		if crouching:
			if animation_player.current_animation != "crouch_idle":
				animation_player.play("crouch_idle")
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
