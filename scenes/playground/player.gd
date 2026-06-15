extends CharacterBody3D

@export var move_speed_meters_per_second: float = 18.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.0025
@export var capture_mouse_on_ready: bool = false

@export var gravity_meters_per_second_squared: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D

var pitch_radians: float = -0.35
var yaw_radians: float = 0.0


func _ready() -> void:
	if camera != null:
		camera.current = true

	if capture_mouse_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion

		yaw_radians -= motion.relative.x * mouse_sensitivity
		pitch_radians = clampf(
			pitch_radians - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0),
			deg_to_rad(85.0)
		)

		_apply_rotation()


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x

	direction.y = 0.0
	direction = direction.normalized()

	var speed := move_speed_meters_per_second
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= gravity_meters_per_second_squared * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	move_and_slide()


func _apply_rotation() -> void:
	rotation = Vector3(0.0, yaw_radians, 0.0)

	if camera != null:
		camera.rotation = Vector3(pitch_radians, 0.0, 0.0)
