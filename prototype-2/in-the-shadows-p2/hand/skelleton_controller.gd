extends Skeleton3D

@export var mouse_sensitivity = 12.0
@export var rotation_speed = 6.0
@export var curl_speed = 0.5
@export var lerp_speed = 5.0

@onready var area_3d: Area3D = %Area3D
@onready var skeleton_3d: Skeleton3D = %Skeleton3D

var bone_data := {}
var current_bone_id := -1
var hovered_bone_id := -1

var _mouse_input_direction := Vector2.ZERO
var _is_dragging := false
var _has_dragged := false
var _target_rotation: Quaternion
var _is_rotating := false

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	setup_bone_attachments()

func setup_bone_attachments():
	var bone_attachments = find_children("*", "BoneAttachment3D")

	for attachment in bone_attachments:
		var bone_name = attachment.bone_name
		var bone_id = find_bone(bone_name)

		if bone_id != -1:
			bone_data[bone_id] = { 
				"attachment": attachment,
				"initial_rotation": get_bone_pose_rotation(bone_id),
				"accumulated_rotation": Vector3.ZERO
			}

			var area = attachment.get_node("Area3D") as Area3D
			if area:
				area.mouse_entered.connect(_on_bone_area_mouse_entered.bind(bone_id))
				area.mouse_exited.connect(_on_bone_area_mouse_exited.bind(bone_id))
			
			print("Setup bone: ", bone_name, " (ID: ", bone_id, ")")

func _on_bone_area_mouse_entered(bone_id: int):
	hovered_bone_id = bone_id
	print("Mouse entered bone: ", get_bone_name(bone_id))

func _on_bone_area_mouse_exited(bone_id: int):
	if hovered_bone_id == bone_id:
		hovered_bone_id = -1
	print("Mouse exited bone: ", get_bone_name(bone_id))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _is_rotating and hovered_bone_id != -1:
				current_bone_id = hovered_bone_id
				_is_dragging = true
				_has_dragged = false
				print("Selected bone: ", get_bone_name(current_bone_id))

			elif not event.pressed and current_bone_id != -1:
				if _is_dragging:
					_is_dragging = false

					if not _has_dragged and not _is_rotating:
						var bone_rotation = bone_data[current_bone_id]["accumulated_rotation"]

						if bone_rotation.x >= deg_to_rad(90):
							bone_rotation.x = 0.0
						else:
							bone_rotation.x += deg_to_rad(30.0)
							bone_rotation.x = clamp(bone_rotation.x, deg_to_rad(-10), deg_to_rad(90))

						bone_data[current_bone_id]["accumulated_rotation"] = bone_rotation
						var delta_rotation = Quaternion.from_euler(bone_rotation)
						_target_rotation = bone_data[current_bone_id]["initial_rotation"] * delta_rotation
						_is_rotating = true
	
	elif event is InputEventMouseMotion and _is_dragging and current_bone_id != -1:
		_mouse_input_direction = event.relative * mouse_sensitivity * 0.01


func _physics_process(delta: float) -> void:
	if _is_dragging and _mouse_input_direction.length() > 0 and current_bone_id != -1:
		_has_dragged = true
	
		var rotation_input = Vector3(
			0.0,
			0.0,
			_mouse_input_direction.y * rotation_speed * delta
		)

		var bone_rotation = bone_data[current_bone_id]["accumulated_rotation"]
		bone_rotation += rotation_input
		bone_rotation.z = clamp(bone_rotation.z, deg_to_rad(-10), deg_to_rad(10))
		bone_data[current_bone_id]["accumulated_rotation"] = bone_rotation

		var delta_rotation = Quaternion.from_euler(bone_rotation)
		_target_rotation = bone_data[current_bone_id]["initial_rotation"] * delta_rotation
		
		_mouse_input_direction = Vector2.ZERO
		_is_rotating = true

	if _is_rotating and current_bone_id != -1:
		var current_rotation = get_bone_pose_rotation(current_bone_id)
		var smooth_rotation = current_rotation.slerp(_target_rotation, lerp_speed * delta)
		set_bone_pose_rotation(current_bone_id, smooth_rotation)

		var angle_diff = current_rotation.angle_to(_target_rotation)
		if angle_diff < deg_to_rad(1.0):
			set_bone_pose_rotation(current_bone_id, _target_rotation)
			_is_rotating = false
