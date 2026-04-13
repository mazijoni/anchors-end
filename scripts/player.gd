extends CharacterBody3D

# Player Nodes
@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/eyes
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var chrouching_collision_shape: CollisionShape3D = $chrouching_collision_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $"Head/eyes/Arms Center/PSX_First_Person_Arms/AnimationPlayer"
@onready var arms_senter: Node3D = $"Head/eyes/Arms Center"
@onready var ledge_check_forward: RayCast3D = $LedgeCheckForward
@onready var ledge_check_top: RayCast3D = $LedgeCheckTop
@onready var legs_node: Node3D = $"Head/eyes/Arms Center/PSX_First_Person_Legs"
@onready var legs_animation_player: AnimationPlayer = $"Head/eyes/Arms Center/PSX_First_Person_Legs/AnimationPlayer"

# Speed Vars
@export var current_speed: float = 5.0
@export var walking_speed: float = 5.0
@export var sprinting_speed: float = 8.0
@export var crouching_speed: float = 2.0
@export var jump_velocity: float = 4.5
@export var mouse_sens: float = 0.5
@export var lerp_spead: float = 10.0
@export var direction: Vector3 = Vector3.ZERO
@export var crouching_depth: float = -0.5

# Health
@export var max_health: int = 100
@export var health: int = 100
@onready var health_bar: ECGHealthBar = $Head/eyes/Camera3D/CanvasLayer/ECGHealthBar

# Stamina
@export var max_stamina: float = 100.0
var stamina: float = max_stamina
@export var stamina_drain: float = 20.0
@export var stamina_regen: float = 10.0
@export var stamina_regen_delay: float = 1.0
@export var stamina_sprint_threshold: float = 50.0  # must reach this to sprint again
var stamina_regen_timer: float = 0.0
var can_sprint: bool = true
@onready var stamina_bar: TextureProgressBar = $Head/eyes/Camera3D/CanvasLayer/StaminaBar

# States
var walking: bool = false
var sprinting: bool = false
var crouching: bool = false

# Punch vars
var is_punching: bool = false
var next_punch_is_right: bool = true
var punch_reset_timer: float = 0.0
@export var punch_reset_delay: float = 1.0

# Head bobbing vars
@export var head_bobbing_sprinting_speed: float = 22.0
@export var head_bobbing_walking_speed: float = 14.0
@export var head_bobbing_crouching_speed: float = 10.0

@export var head_bobbing_sprinting_intensity: float = 0.2
@export var head_bobbing_walking_intensity: float = 0.1
@export var head_bobbing_crouching_intensity: float = 0.05

var head_bobbing_vector: Vector2 = Vector2.ZERO
var head_bobbing_index: float = 0.0
var head_bobbing_current_intensity: float = 0.0

# Extra sway/tilt strengths
@export var head_sway_strength: float = 0.4
@export var head_tilt_strength: float = 0.3

# Crouch arm offset: arms shift up when looking down, down when looking up
@export var crouch_arm_look_strength: float = 0.3
@export var crouch_look_down_limit: float = 50.0  # max degrees looking down while crouched

# Godmode flag
var _godmode := false

# Ledge grab vars
var is_ledge_grabbing: bool = false
var ledge_top_y: float = 0.0
var ledge_grab_yaw: float = 0.0
var ledge_release_timer: float = 0.0
const LEDGE_RELEASE_COOLDOWN: float = 0.4
@export var ledge_grab_look_limit_up: float = 60.0    # max degrees looking up while hanging
@export var ledge_grab_look_limit_down: float = 25.0  # max degrees looking down while hanging
@export var ledge_grab_yaw_limit: float = 45.0        # max degrees turning left/right while hanging
@export var ledge_arm_pitch: float = 35.0             # degrees above horizontal arms aim while hanging
@export var ledge_hang_offset: float = 1.6            # distance below ledge top the player origin sits

# Vault vars
var is_vaulting: bool = false
var vault_onto: bool = false        # true = hop onto obstacle, false = vault completely over
var vault_timer: float = 0.0
var vault_start_pos: Vector3 = Vector3.ZERO
var vault_end_pos: Vector3 = Vector3.ZERO
var arms_base_pos_y: float = 0.0
@export var vault_duration: float = 0.5
@export var vault_check_distance: float = 1.2   # how far forward to detect obstacle
@export var vault_low_height: float = 0.15      # min relative obstacle height to trigger vault
@export var vault_over_height: float = 0.9      # relative height threshold: above → vault onto, below → vault over
@export var vault_onto_height: float = 1.35     # max relative height that can be vaulted onto
@export var vault_arms_down: float = -0.25      # how far arms lower during vault (negative = down)
var vault_exit_speed: float = 0.0               # sprint speed captured at vault start

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	animation_player.animation_finished.connect(_on_animation_finished)
	legs_animation_player.animation_finished.connect(_on_legs_animation_finished)
	legs_node.visible = false
	arms_base_pos_y = arms_senter.position.y

	# ── Debug console commands ──────────────────────────────────────────
	DebugConsole.register_command("health",      _cmd_sethealth,   "Set/show player health: health <amount> / <empty>")
	DebugConsole.register_command("hp",          _cmd_sethealth,   "Alias for health")
	DebugConsole.register_command("damage",      _cmd_damage,      "Damage player: damage <amount>")
	DebugConsole.register_command("dmg",         _cmd_damage,      "Alias for damage")
	DebugConsole.register_command("heal",        _cmd_heal,        "Heal player: heal <amount>")
	DebugConsole.register_command("kill",        _cmd_kill,        "Kill player instantly")
	DebugConsole.register_command("godmode",     _cmd_godmode,     "Toggle invincibility")
	DebugConsole.register_command("setspeed",    _cmd_setspeed,    "Set walk speed: setspeed <amount>")
	DebugConsole.register_command("setjump",     _cmd_setjump,     "Set jump height: setjump <amount>")
	DebugConsole.register_command("noclip",      _cmd_noclip,      "Toggle noclip (fly through walls)")
	DebugConsole.register_command("teleport",    _cmd_teleport,    "Teleport: teleport <x> <y> <z>")
	DebugConsole.register_command("stats",       _cmd_stats,       "Show all player stats")

# ── Debug command implementations ──────────────────────────────────────────────

func _cmd_sethealth(args: Array) -> String:
	if args.is_empty():
		return "health = %d / %d" % [health, max_health]
	health = clamp(int(args[0]), 0, max_health)
	return "Health set to %d" % health

func _cmd_damage(args: Array) -> String:
	if args.is_empty():
		return "[error] Usage: damage <amount>"
	var amt := int(args[0])
	if _godmode:
		return "[godmode] Damage blocked."
	health = clamp(health - amt, 0, max_health)
	return "Dealt %d damage. Health = %d" % [amt, health]

func _cmd_heal(args: Array) -> String:
	if args.is_empty():
		return "[error] Usage: heal <amount>"
	var amt := int(args[0])
	health = clamp(health + amt, 0, max_health)
	return "Healed %d. Health = %d" % [amt, health]

func _cmd_kill(_args: Array) -> String:
	health = 0
	return "Player killed."

func _cmd_godmode(_args: Array) -> String:
	_godmode = !_godmode
	return "Godmode: %s" % ("ON" if _godmode else "OFF")

func _cmd_setspeed(args: Array) -> String:
	if args.is_empty():
		return "walk=%s  sprint=%s  crouch=%s" % [walking_speed, sprinting_speed, crouching_speed]
	var val := float(args[0])
	walking_speed  = val
	sprinting_speed = val * 1.6
	crouching_speed = val * 0.4
	return "Walk speed set to %.1f  (sprint=%.1f  crouch=%.1f)" % [walking_speed, sprinting_speed, crouching_speed]

func _cmd_setjump(args: Array) -> String:
	if args.is_empty():
		return "jump_velocity = %s" % jump_velocity
	jump_velocity = float(args[0])
	return "Jump velocity set to %.1f" % jump_velocity

var _noclip: bool = false
func _cmd_noclip(_args: Array) -> String:
	_noclip = !_noclip
	if _noclip:
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = true
		motion_mode = MOTION_MODE_FLOATING
	else:
		standing_collision_shape.disabled = false
		chrouching_collision_shape.disabled = false
		motion_mode = MOTION_MODE_GROUNDED
	return "Noclip: %s" % ("ON" if _noclip else "OFF")

func _cmd_teleport(args: Array) -> String:
	if args.size() < 3:
		return "[error] Usage: teleport <x> <y> <z>"
	global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
	return "Teleported to %s" % global_position

func _cmd_stats(_args: Array) -> String:
	return """[b]Player Stats[/b]
  health       = %d / %d
  stamina      = %.1f / %.1f
  godmode      = %s
  noclip       = %s
  walk speed   = %.1f
  sprint speed = %.1f
  crouch speed = %.1f
  jump vel     = %.1f
  position     = %s""" % [
		health, max_health,
		stamina, max_stamina,
		"ON" if _godmode else "OFF",
		"ON" if _noclip else "OFF",
		walking_speed, sprinting_speed, crouching_speed,
		jump_velocity,
		global_position
	]

# ── Take damage helper ────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _godmode:
		return
	health = clamp(health - amount, 0, max_health)

# ── Stamina ───────────────────────────────────────────────────────────────────

func _handle_stamina(delta: float) -> void:
	if sprinting and velocity.length() > 0.1:
		stamina -= stamina_drain * delta
		stamina = max(stamina, 0.0)
		stamina_regen_timer = stamina_regen_delay
		if stamina <= 0.0:
			can_sprint = false
	else:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			stamina += stamina_regen * delta
			stamina = min(stamina, max_stamina)
			if stamina >= stamina_sprint_threshold:
				can_sprint = true

	stamina_bar.value = stamina

# ─────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		if is_ledge_grabbing:
			# Clamp yaw left/right from the grab direction
			var yaw_diff = rotation.y - ledge_grab_yaw
			yaw_diff = clamp(yaw_diff, deg_to_rad(-ledge_grab_yaw_limit), deg_to_rad(ledge_grab_yaw_limit))
			rotation.y = ledge_grab_yaw + yaw_diff
			# Clamp pitch up/down
			head.rotation.x = clamp(head.rotation.x,
				deg_to_rad(-ledge_grab_look_limit_up),
				deg_to_rad(ledge_grab_look_limit_down))
		else:
			if crouching:
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-crouch_look_down_limit), deg_to_rad(89))
			else:
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	health_bar.set_health(health)
	_handle_stamina(delta)

	if ledge_release_timer > 0:
		ledge_release_timer -= delta

	# Noclip: full 6DOF fly mode — skip all grounded movement
	if _noclip:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var fly_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
		if Input.is_action_pressed("jump"):
			fly_dir.y += 1.0
		if Input.is_action_pressed("crouch"):
			fly_dir.y -= 1.0
		velocity = fly_dir.normalized() * sprinting_speed
		move_and_slide()
		return

	# Handle vault state — skip all normal movement while vaulting
	if is_vaulting:
		_handle_vault(delta)
		return

	# Handle ledge grab state — skip all normal movement when hanging
	if is_ledge_grabbing:
		_handle_ledge_hang(delta)
		move_and_slide()
		if !is_punching:
			_handle_animations()
		return

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

	elif Input.is_action_pressed("sprint") and !ray_cast_3d.is_colliding() and stamina > 0 and can_sprint:
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

	# Try to grab ledge while airborne
	if not is_on_floor() and ledge_release_timer <= 0:
		_try_ledge_grab()

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
		arms_senter.rotation.y = lerp(arms_senter.rotation.y, 0.0, delta * lerp_spead)
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	move_and_slide()

	# Detect vaultable obstacles — sprint only
	if is_on_floor() and sprinting and not is_punching and ledge_release_timer <= 0 and direction.length() > 0.1:
		_try_vault()

	if !is_punching:
		_handle_animations()

func _try_vault() -> void:
	var move_dir = direction.normalized()
	var space = get_world_3d().direct_space_state

	# Ray at lower-body height to detect an obstacle face
	var ray_origin = global_position + Vector3(0, 0.7, 0)
	var ray_end = ray_origin + move_dir * vault_check_distance
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return

	# Sample slightly past the face to find the obstacle's top surface
	var sample = hit["position"] + move_dir * 0.2
	var top_origin = Vector3(sample.x, global_position.y + 2.2, sample.z)
	var top_end   = Vector3(sample.x, global_position.y - 0.3, sample.z)
	var top_query = PhysicsRayQueryParameters3D.create(top_origin, top_end)
	top_query.exclude = [self]
	var top_hit = space.intersect_ray(top_query)
	if top_hit.is_empty():
		return

	var obstacle_top_y = top_hit["position"].y
	var obstacle_height = obstacle_top_y - global_position.y

	if obstacle_height < vault_low_height or obstacle_height > vault_onto_height:
		return

	vault_onto = obstacle_height > vault_over_height

	vault_start_pos = global_position
	var travel = vault_check_distance + (0.4 if vault_onto else 0.9)
	vault_end_pos = global_position + move_dir * travel
	if vault_onto:
		vault_end_pos.y = obstacle_top_y + 0.05

	# Duration matches sprint speed; animation is scaled to finish at the same time
	vault_duration = travel / current_speed
	vault_exit_speed = current_speed

	var anim: Animation = legs_animation_player.get_animation("legs_up")
	var anim_speed: float = anim.length if anim != null else 1.0

	is_vaulting = true
	vault_timer = 0.0
	velocity = Vector3.ZERO
	legs_node.visible = true
	legs_animation_player.play("legs_up", 0.05, anim_speed)
	animation_player.play("idle", 0.1)

func _handle_vault(delta: float) -> void:
	vault_timer += delta
	var t = clamp(vault_timer / vault_duration, 0.0, 1.0)
	var smooth_t = smoothstep(0.0, 1.0, t)

	# Arc: peak in the middle of the motion
	var arc_peak = 0.55 if not vault_onto else 0.25
	var target = vault_start_pos.lerp(vault_end_pos, smooth_t)
	target.y += sin(t * PI) * arc_peak

	global_position = target
	velocity = Vector3.ZERO

	# Arms lower mid-vault then rise back
	arms_senter.position.y = arms_base_pos_y + sin(t * PI) * vault_arms_down

	# Keep eyes steady
	eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
	eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
	eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	if t >= 1.0:
		_end_vault()

func _end_vault() -> void:
	is_vaulting = false
	arms_senter.position.y = arms_base_pos_y
	# Legs stay visible until the animation finishes naturally
	var forward = (vault_end_pos - vault_start_pos)
	forward.y = 0.0
	velocity = forward.normalized() * vault_exit_speed

func _on_legs_animation_finished(anim_name: String) -> void:
	if anim_name == "legs_up":
		legs_node.visible = false

func _try_ledge_grab() -> void:
	if not ledge_check_forward.is_colliding():
		return
	if not ledge_check_top.is_colliding():
		return
	ledge_top_y = ledge_check_top.get_collision_point().y
	ledge_grab_yaw = rotation.y
	is_ledge_grabbing = true
	velocity = Vector3.ZERO
	# Restore standard collision setup while hanging
	standing_collision_shape.disabled = false
	chrouching_collision_shape.disabled = true
	walking = false
	sprinting = false
	crouching = false

func _handle_ledge_hang(delta: float) -> void:
	# Snap vertical position so player hangs at the correct height
	var target_y = ledge_top_y - ledge_hang_offset
	global_position.y = lerp(global_position.y, target_y, delta * lerp_spead)

	# Kill all velocity while hanging
	velocity = Vector3.ZERO

	# Arms pitch upward toward ledge, counter yaw so arms don't follow camera left/right
	var target_arm_pitch = -head.rotation.x - deg_to_rad(ledge_arm_pitch)
	var yaw_diff = rotation.y - ledge_grab_yaw
	arms_senter.rotation.x = lerp(arms_senter.rotation.x, target_arm_pitch, delta * lerp_spead)
	arms_senter.rotation.y = lerp(arms_senter.rotation.y, -yaw_diff, delta * lerp_spead)

	# Eyes stay centred
	eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
	eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
	eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	# Head height while hanging
	head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	# Jump → climb up onto the ledge
	if Input.is_action_just_pressed("jump"):
		is_ledge_grabbing = false
		ledge_release_timer = LEDGE_RELEASE_COOLDOWN
		# Place player on top of ledge and push forward so they always land on it
		global_position.y = ledge_top_y + 0.05
		global_position += -transform.basis.z * 0.6
		velocity = -transform.basis.z * 3.5
		arms_senter.rotation.y = 0.0
		return

	# Crouch → let go
	if Input.is_action_just_pressed("crouch"):
		is_ledge_grabbing = false
		ledge_release_timer = LEDGE_RELEASE_COOLDOWN
		arms_senter.rotation.y = 0.0

func _play_punch():
	is_punching = true
	punch_reset_timer = 0.0
	if next_punch_is_right:
		animation_player.play("punch_right")
	else:
		animation_player.play("punch_left")
	next_punch_is_right = !next_punch_is_right

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "punch_right" or anim_name == "punch_left":
		is_punching = false

func _handle_animations():
	if is_ledge_grabbing:
		if animation_player.current_animation != "hold_edge":
			animation_player.play("hold_edge", 0.2)
		return

	if !is_on_floor():
		if velocity.y < 0:
			if animation_player.current_animation != "falling":
				animation_player.play("falling", 0.2)
		else:
			if animation_player.current_animation != "falling":
				animation_player.play("falling", 0.2)

	elif direction.length() > 0.1:
		if sprinting:
			if animation_player.current_animation != "sprint":
				animation_player.play("sprint", 0.2)
		elif crouching:
			if animation_player.current_animation != "crouch_walk":
				animation_player.play("crouch_walk", 0.2)
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle", 0.2)

	else:
		if crouching:
			if animation_player.current_animation != "crouch_idle":
				animation_player.play("crouch_idle", 0.2)
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle", 0.2)
