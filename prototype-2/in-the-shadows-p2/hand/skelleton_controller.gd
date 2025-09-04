extends Skeleton3D

@export var mouse_sensitivity = 12.0
@export var rotation_speed = 6.0
@export var curl_speed = 0.5
@export var lerp_speed = 5.0

@onready var area_3d: Area3D = %Area3D
@onready var bone := find_bone("Bone.009")
@onready var skeleton_3d: Skeleton3D = %Skeleton3D

var _mouse_input_direction := Vector2.ZERO
var is_dragging := false
var initial_bone_rotation: Quaternion
var target_rotation: Quaternion
var accumulated_rotation := Vector3.ZERO

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	initial_bone_rotation = get_bone_pose_rotation(bone)
	target_rotation = initial_bone_rotation

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		is_dragging = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("left_click"):
		is_dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and is_dragging):
		_mouse_input_direction = event.screen_relative * mouse_sensitivity

func _physics_process(delta: float) -> void:
	if _mouse_input_direction.length() > 0:
		# Update accumulated rotation based on mouse input
		var rotation_input = Vector3(
			_mouse_input_direction.x * rotation_speed * delta,
			0.0,
			_mouse_input_direction.y * curl_speed * delta
		)
		
		accumulated_rotation += rotation_input
		
		# Apply clamping
		accumulated_rotation.x = clamp(accumulated_rotation.x, -deg_to_rad(10), deg_to_rad(90))
		accumulated_rotation.z = clamp(accumulated_rotation.z, -deg_to_rad(10), deg_to_rad(10))  # ±5 degrees = 10 degree span
		
		# Calculate target rotation from initial position
		var delta_rotation = Quaternion.from_euler(accumulated_rotation)
		target_rotation = initial_bone_rotation * delta_rotation
		
		_mouse_input_direction = Vector2.ZERO
	
	# Smoothly lerp current rotation towards target
	var current_rotation = get_bone_pose_rotation(bone)
	var smooth_rotation = current_rotation.slerp(target_rotation, lerp_speed * delta)
	set_bone_pose_rotation(bone, smooth_rotation)

	"""
	func _physics_process(delta: float) -> void:
	if _mouse_input_direction.length() > 0:
		var abs_x = abs(_mouse_input_direction.x)
		var abs_y = abs(_mouse_input_direction.y)

		var rotation_input = Vector3.ZERO

		if abs_x > abs_y:
			rotation_input.z = _mouse_input_direction.x * rotation_speed * delta
		else:
			rotation_input.x = _mouse_input_direction.y * curl_speed * delta

		accumulated_rotation += rotation_input

		accumulated_rotation.x = clamp(accumulated_rotation.x, -deg_to_rad(90), deg_to_rad(10))
		accumulated_rotation.y = clamp(accumulated_rotation.z, -deg_to_rad(5), deg_to_rad(5))

		var delta_rotation = Quaternion.from_euler(accumulated_rotation)
		target_rotation = initial_bone_rotation * delta_rotation

		_mouse_input_direction = Vector2.ZERO
	
	var current_rotation = get_bone_pose_rotation(bone);
	var smooth_rotation = current_rotation.slerp(target_rotation, lerp_speed * delta)
	set_bone_pose_rotation(bone, smooth_rotation)
	"""
