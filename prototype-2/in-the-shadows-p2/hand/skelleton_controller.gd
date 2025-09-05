extends Skeleton3D

@export var mouse_sensitivity = 12.0
@export var rotation_speed = 6.0
@export var curl_speed = 0.5
@export var lerp_speed = 5.0

@onready var area_3d: Area3D = %Area3D
@onready var bone := find_bone("Bone.009")
@onready var skeleton_3d: Skeleton3D = %Skeleton3D

var _mouse_input_direction := Vector2.ZERO
var _is_dragging := false
var _has_dragged := false
var _initial_bone_rotation: Quaternion
var _target_rotation: Quaternion
var _accumulated_rotation := Vector3.ZERO
var _is_rotating := false

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	_initial_bone_rotation = get_bone_pose_rotation(bone)
	_target_rotation = _initial_bone_rotation

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_1:
			bone = find_bone("Bone.009")
		elif event.keycode == KEY_2:
			bone = find_bone("Bone.010")
		elif event.keycode == KEY_3:
			bone = find_bone("Bone.011")
		elif event.keycode == KEY_4:
			bone = find_bone("Bone.012")
		elif event.keycode == KEY_5:
			bone = find_bone("Bone.007")
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _is_rotating:
				_is_dragging = true
				_has_dragged = false
			elif not event.pressed:
				if _is_dragging:
					_is_dragging = false

					if not _has_dragged and not _is_rotating:
						if _accumulated_rotation.x >= deg_to_rad(90):
							_accumulated_rotation.x = 0.0
						else:
							_accumulated_rotation.x += deg_to_rad(30.0)
							_accumulated_rotation.x = clamp(_accumulated_rotation.x, deg_to_rad(-10), deg_to_rad(90))

						var delta_rotation = Quaternion.from_euler(_accumulated_rotation)
						_target_rotation = _initial_bone_rotation * delta_rotation
						_is_rotating = true
						
	elif event is InputEventMouseMotion and _is_dragging:
		_mouse_input_direction = event.relative * mouse_sensitivity * 0.01


func _physics_process(delta: float) -> void:
	if _is_dragging and _mouse_input_direction.length() > 0:
		_has_dragged = true
		
		var rotation_input = Vector3(
			0.0,
			0.0,
			_mouse_input_direction.y * rotation_speed * delta
		)

		_accumulated_rotation += rotation_input
		_accumulated_rotation.z = clamp(_accumulated_rotation.z, deg_to_rad(-10), deg_to_rad(10))

		var delta_rotation = Quaternion.from_euler(_accumulated_rotation)
		_target_rotation = _initial_bone_rotation * delta_rotation

		_mouse_input_direction = Vector2.ZERO
		_is_rotating = true


	if _is_rotating:
		var current_rotation = get_bone_pose_rotation(bone)
		var smooth_rotation = current_rotation.slerp(_target_rotation, lerp_speed * delta)
		set_bone_pose_rotation(bone, smooth_rotation)

		var angle_diff = current_rotation.angle_to(_target_rotation)
		if angle_diff < deg_to_rad(1.0):
			set_bone_pose_rotation(bone, _target_rotation)
			_is_rotating = false
