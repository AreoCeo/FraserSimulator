extends CharacterBody3D

# Movement parameters
@export var roll_speed := 5.0
@export var sprint_speed := 10.0
@export var jump_force := 10.0
@export var gravity := -25.0
@export var mouse_sensitivity := 0.003
@export var max_pitch := 1.2  # ~70 degrees
@export var slide_angle := 30.0 # degrees
@export var slide_speed := 8.0

# Stamina parameters
@export var stamina_max := 100.0
@export var stamina_regen := 20.0      # per second
@export var stamina_sprint_use := 30.0 # per second
@export var stamina_sprint_min := 3.0  # Minimum stamina to keep sprinting

# FOV Sprint effect
@export var normal_fov := 75.0
@export var sprint_fov := 85.0
@export var fov_lerp_speed := 7.0

var stamina := stamina_max
var is_sprinting := false

# Camera and movement
var yaw := 0.0
var pitch := 0.0

signal stamina_changed(stamina_value: float, stamina_maximum: float)

var debug_timer := 0.0  # Tracks time for debug prints

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("stamina_changed", stamina, stamina_max) # initial signal
	# Set initial FOV
	if $SpringArm3D/Camera3D:
		$SpringArm3D/Camera3D.fov = normal_fov

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -max_pitch, max_pitch)
		$SpringArm3D.rotation.x = pitch
		rotation.y = yaw
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	debug_timer += delta

	var input_direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_direction.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_direction.z += 1
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1

	var sprint_input = Input.is_action_pressed("sprint")
	# Only allow sprinting if stamina is above the minimum threshold
	is_sprinting = sprint_input and stamina > stamina_sprint_min and input_direction != Vector3.ZERO

	var move_speed = roll_speed
	if is_sprinting:
		move_speed = sprint_speed
		stamina -= stamina_sprint_use * delta
		stamina = max(stamina, 0.0)
		# Stop sprinting if stamina crosses below threshold mid-frame
		if stamina <= stamina_sprint_min:
			is_sprinting = false
			move_speed = roll_speed
	else:
		stamina += stamina_regen * delta
		stamina = min(stamina, stamina_max)

	# Debug print only once per second
	if debug_timer >= 1.0:
		print("move_forward:", Input.is_action_pressed("move_forward"),
			  " move_backward:", Input.is_action_pressed("move_backward"),
			  " move_left:", Input.is_action_pressed("move_left"),
			  " move_right:", Input.is_action_pressed("move_right"),
			  " sprint:", sprint_input)
		print("input_direction:", input_direction)
		print("is_sprinting:", is_sprinting, " | stamina:", stamina)
		debug_timer = 0.0

	emit_signal("stamina_changed", stamina, stamina_max)

	# Movement (relative to camera)
	if input_direction != Vector3.ZERO:
		input_direction = input_direction.normalized()
		var move_basis = Basis(Vector3.UP, yaw)
		var direction = move_basis * input_direction
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, roll_speed)
		velocity.z = move_toward(velocity.z, 0, roll_speed)

	# Clamp velocity to walk speed if not sprinting, to avoid lingering speed boost
	if not is_sprinting:
		var horizontal_speed = Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > roll_speed:
			var factor = roll_speed / horizontal_speed
			velocity.x *= factor
			velocity.z *= factor

	velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	move_and_slide()

	# Slope sliding logic
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var floor_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		if floor_angle > slide_angle:
			var slide_dir = Vector3(floor_normal.x, 0, floor_normal.z).normalized()
			velocity.x += slide_dir.x * slide_speed * delta
			velocity.z += slide_dir.z * slide_speed * delta

	# Optional: rolling mesh effect
	if $MeshInstance3D and velocity.length() > 0:
		$MeshInstance3D.rotate_x(velocity.z * delta)
		$MeshInstance3D.rotate_z(-velocity.x * delta)

	# --- FOV Sprint effect ---
	if $SpringArm3D/Camera3D:
		var target_fov = sprint_fov if is_sprinting else normal_fov
		$SpringArm3D/Camera3D.fov = lerp($SpringArm3D/Camera3D.fov, target_fov, delta * fov_lerp_speed)
