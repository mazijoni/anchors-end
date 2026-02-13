extends CharacterBody3D

# Player Nodes
@onready var head = $Head
@onready var eyes = $Head/eyes
@onready var standing_collision_shape = $standing_collision_shape
@onready var chrouching_collision_shape = $chrouching_collision_shape
@onready var ray_cast_3d = $RayCast3D
@onready var animation_player = $"Head/eyes/Arms Senter/PSX_First_Person_Arms/AnimationPlayer"
@onready var arms_senter = $"Head/eyes/Arms Senter"

# Speed Vars
@export var current_speed = 5.0
@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 2.0
@export var jump_velocity = 4.5
@export var mouse_sens = 0.5
@export var lerp_spead = 10.0
@export var direction = Vector3.ZERO
@export var crouching_depth = -0.5

# States
var walking = false
var sprinting = false
var crouching = false

# Punch vars
var is_punching = false
var next_punch_is_right = true
var punch_reset_timer = 0.0
@export var punch_reset_delay = 1.0

# Head bobbing vars
@export var head_bobbing_sprinting_speed = 22.0
@export var head_bobbing_walking_speed = 14.0
@export var head_bobbing_crouching_speed = 10.0

@export var head_bobbing_sprinting_intensity = 0.2
@export var head_bobbing_walking_intensity = 0.1
@export var head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Extra sway/tilt strengths
@export var head_sway_strength: float = 0.4
@export var head_tilt_strength: float = 0.3

# Crouch arm offset: arms shift up when looking down, down when looking up
@export var crouch_arm_look_strength: float = 0.3

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Connect to animation finished signal
	animation_player.animation_finished.connect(_on_animation_finished)

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	# Handle punch input
	if Input.is_action_just_pressed("punch") and !is_punching:
		_play_punch()
	
	# Update punch reset timer
	if !is_punching:
		punch_reset_timer += delta
		if punch_reset_timer >= punch_reset_delay:
			next_punch_is_right = true
	
	# Handle Movement State
	if Input.is_action_pressed("crouch"):
		walking = false
		sprinting = false
		crouching = true
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1 + crouching_depth, delta * lerp_spead)
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = false

	elif Input.is_action_pressed("sprint") and !ray_cast_3d.is_colliding():
		walking = false
		sprinting = true
		crouching = false
		current_speed = sprinting_speed
		standing_collision_shape.disabled = false
		chrouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	elif !ray_cast_3d.is_colliding():
		walking = true
		sprinting = false
		crouching = false
		current_speed = walking_speed
		standing_collision_shape.disabled = false
		chrouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	else:
		walking = false
		sprinting = false
		crouching = true
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta * lerp_spead)
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = false

	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input and handle movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_spead)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
	# Handle Headbob
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta

	if is_on_floor() and input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		eyes.position.y = lerp(
			eyes.position.y,
			head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0),
			delta * lerp_spead
		)

		var sway_x = sin(head_bobbing_index * 0.5) * head_bobbing_current_intensity * head_sway_strength
		var tilt_z = sin(head_bobbing_index * 0.5) * head_bobbing_current_intensity * head_tilt_strength

		eyes.position.x = lerp(eyes.position.x, sway_x, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, tilt_z, delta * lerp_spead)

		# Also rotate Arms Senter when crouch walking
		var target_rot_x = 0.0
		if crouching:
			target_rot_x = -head.rotation.x * crouch_arm_look_strength
		arms_senter.rotation.x = lerp(arms_senter.rotation.x, target_rot_x, delta * lerp_spead)
	else:
		# When crouching, rotate Arms Senter to follow the vertical look angle,
		# making arms rise when looking down and lower when looking up.
		var target_rot_x = 0.0
		if crouching:
			target_rot_x = -head.rotation.x * crouch_arm_look_strength

		arms_senter.rotation.x = lerp(arms_senter.rotation.x, target_rot_x, delta * lerp_spead)
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	move_and_slide()
	
	# Only handle animations if not punching
	if !is_punching:
		_handle_animations()

func _play_punch():
	is_punching = true
	punch_reset_timer = 0.0  # Reset the timer when punching
	if next_punch_is_right:
		animation_player.play("punch_right")
	else:
		animation_player.play("punch_left")
	next_punch_is_right = !next_punch_is_right

func _on_animation_finished(anim_name: String):
	if anim_name == "punch_right" or anim_name == "punch_left":
		is_punching = false

func _handle_animations():
	# Check if player is in the air
	if !is_on_floor():
		# Falling animation (when moving downward)
		if velocity.y < 0:
			if animation_player.current_animation != "falling":
				animation_player.play("falling")
		# Jumping animation (when moving upward)
		else:
			if animation_player.current_animation != "jump":
				animation_player.play("jump")
	# Check if player is moving on the ground
	elif direction.length() > 0.1:
		# Sprinting animation
		if sprinting:
			if animation_player.current_animation != "sprint":
				animation_player.play("sprint")
		# Crouching walk animation
		elif crouching:
			if animation_player.current_animation != "crouch_walk":
				animation_player.play("crouch_walk")
		# Normal walking animation
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
	# Standing still
	else:
		# Crouching idle
		if crouching:
			if animation_player.current_animation != "crouch_idle":
				animation_player.play("crouch_idle")
		# Normal idle
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
