extends CharacterBody3D

# Player Nodes
@onready var head = $Head
@onready var eyes = $Head/eyes
@onready var standing_collision_shape = $standing_collision_shape
@onready var chrouching_collision_shape = $chrouching_collision_shape
@onready var ray_cast_3d = $RayCast3D
@onready var animation_player = $"Head/eyes/Arms Center/PSX_First_Person_Arms/AnimationPlayer"
@onready var arms_senter = $"Head/eyes/Arms Center"

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

# Health
@export var max_health: int = 100
@export var health: int = 100
@onready var health_bar = $Head/eyes/Camera3D/CanvasLayer/ECGHealthBar

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

# Godmode flag
var _godmode := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	animation_player.animation_finished.connect(_on_animation_finished)

	# ── Debug console commands ──────────────────────────────────────────
	DebugConsole.register_command("sethealth",   _cmd_sethealth,   "Set player health: sethealth <amount>")
	DebugConsole.register_command("damage",      _cmd_damage,      "Damage player: damage <amount>")
	DebugConsole.register_command("heal",        _cmd_heal,        "Heal player: heal <amount>")
	DebugConsole.register_command("kill",        _cmd_kill,        "Kill player instantly")
	DebugConsole.register_command("godmode",     _cmd_godmode,     "Toggle invincibility")
	DebugConsole.register_command("setspeed",    _cmd_setspeed,    "Set walk speed: setspeed <amount>")
	DebugConsole.register_command("setjump",     _cmd_setjump,     "Set jump height: setjump <amount>")
	DebugConsole.register_command("noclip",      _cmd_noclip,      "Toggle noclip (fly through walls)")
	DebugConsole.register_command("teleport",    _cmd_teleport,    "Teleport: teleport <x> <y> <z>")
	DebugConsole.register_command("stats",       _cmd_stats,       "Show all player stats")

# ── Debug command implementations ──────────────────────────────────────────────

func _cmd_sethealth(args) -> String:
	if args.is_empty():
		return "health = %d / %d" % [health, max_health]
	health = clamp(int(args[0]), 0, max_health)
	return "Health set to %d" % health

func _cmd_damage(args) -> String:
	if args.is_empty():
		return "[error] Usage: damage <amount>"
	var amt := int(args[0])
	if _godmode:
		return "[godmode] Damage blocked."
	health = clamp(health - amt, 0, max_health)
	return "Dealt %d damage. Health = %d" % [amt, health]

func _cmd_heal(args) -> String:
	if args.is_empty():
		return "[error] Usage: heal <amount>"
	var amt := int(args[0])
	health = clamp(health + amt, 0, max_health)
	return "Healed %d. Health = %d" % [amt, health]

func _cmd_kill(_args) -> String:
	health = 0
	return "Player killed."

func _cmd_godmode(_args) -> String:
	_godmode = !_godmode
	return "Godmode: %s" % ("ON" if _godmode else "OFF")

func _cmd_setspeed(args) -> String:
	if args.is_empty():
		return "walk=%s  sprint=%s  crouch=%s" % [walking_speed, sprinting_speed, crouching_speed]
	var val := float(args[0])
	walking_speed  = val
	sprinting_speed = val * 1.6
	crouching_speed = val * 0.4
	return "Walk speed set to %.1f  (sprint=%.1f  crouch=%.1f)" % [walking_speed, sprinting_speed, crouching_speed]

func _cmd_setjump(args) -> String:
	if args.is_empty():
		return "jump_velocity = %s" % jump_velocity
	jump_velocity = float(args[0])
	return "Jump velocity set to %.1f" % jump_velocity

var _noclip := false
func _cmd_noclip(_args) -> String:
	_noclip = !_noclip
	if _noclip:
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = true
	else:
		standing_collision_shape.disabled = false
	return "Noclip: %s" % ("ON" if _noclip else "OFF")

func _cmd_teleport(args) -> String:
	if args.size() < 3:
		return "[error] Usage: teleport <x> <y> <z>"
	global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
	return "Teleported to %s" % global_position

func _cmd_stats(_args) -> String:
	return """[b]Player Stats[/b]
  health       = %d / %d
  godmode      = %s
  noclip       = %s
  walk speed   = %.1f
  sprint speed = %.1f
  crouch speed = %.1f
  jump vel     = %.1f
  position     = %s""" % [
		health, max_health,
		"ON" if _godmode else "OFF",
		"ON" if _noclip else "OFF",
		walking_speed, sprinting_speed, crouching_speed,
		jump_velocity,
		global_position
	]

# ── Take damage helper (use this from other scripts to deal damage) ────────────

func take_damage(amount: int) -> void:
	if _godmode:
		return
	health = clamp(health - amount, 0, max_health)

# ─────────────────────────────────────────────────────────────────────────────

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	health_bar.set_health(health)
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

		var target_rot_x = 0.0
		if crouching:
			target_rot_x = -head.rotation.x * crouch_arm_look_strength
		arms_senter.rotation.x = lerp(arms_senter.rotation.x, target_rot_x, delta * lerp_spead)
	else:
		var target_rot_x = 0.0
		if crouching:
			target_rot_x = -head.rotation.x * crouch_arm_look_strength

		arms_senter.rotation.x = lerp(arms_senter.rotation.x, target_rot_x, delta * lerp_spead)
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	move_and_slide()
	
	if !is_punching:
		_handle_animations()

func _play_punch():
	is_punching = true
	punch_reset_timer = 0.0
	if next_punch_is_right:
		animation_player.play("punch_right")
	else:
		animation_player.play("punch_left")
	next_punch_is_right = !next_punch_is_right

func _on_animation_finished(anim_name: String):
	if anim_name == "punch_right" or anim_name == "punch_left":
		is_punching = false

func _handle_animations():
	if !is_on_floor():
		if velocity.y < 0:
			if animation_player.current_animation != "falling":
				animation_player.play("falling")
		else:
			if animation_player.current_animation != "jump":
				animation_player.play("jump")
	elif direction.length() > 0.1:
		if sprinting:
			if animation_player.current_animation != "sprint":
				animation_player.play("sprint")
		elif crouching:
			if animation_player.current_animation != "crouch_walk":
				animation_player.play("crouch_walk")
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
	else:
		if crouching:
			if animation_player.current_animation != "crouch_idle":
				animation_player.play("crouch_idle")
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
