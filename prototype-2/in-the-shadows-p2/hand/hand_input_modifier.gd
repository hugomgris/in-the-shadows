@tool
class_name HandInputModifier
extends SkeletonModifier3D

signal bone_hovered(bone_id: int)
signal bone_unhovered(bone_id: int)

# Spring-based movement parameters for organic feel
@export var rotation_speed: float = 0.8        # Drag sensitivity
@export var spring_factor: float = 0.08        # Spring elasticity
@export var damping_factor: float = 0.88       # Damping to prevent infinite bouncing
@export var click_curl_step: float = 30.0      # Degrees per click
@export var drag_sensitivity: float = 3.0      # Z-axis drag sensitivity

# Rotation limits (degrees)
@export var max_rotation_x: float = 90.0       # Max finger curl
@export var min_rotation_x: float = -10.0      # Max finger extension
@export var max_rotation_z: float = 30.0       # Max sideways bend
@export var min_rotation_z: float = -30.0      # Max sideways bend

# Input state
var _input_enabled := false
var _is_dragging := false
var _has_dragged := false
var _mouse_pressed_time := 0
var _click_threshold := 1.0  # Maximum time for a click (seconds) - very lenient for natural clicking
var _drag_threshold := 20.0    # Minimum distance to register as drag - much higher threshold

var current_bone_id := -1
var hovered_bone_id := -1
var last_mouse_pos: Vector2

var draggable_bones = ["Bone.001", "Bone.012", "Bone.014", "Bone.017", "Bone.020", "Bone.023"]

# Bone modification data
var bone_modifications := {}

class BoneModification:
	var bone_id: int
	var target_rotation: Vector3 = Vector3.ZERO
	var current_rotation: Vector3 = Vector3.ZERO
	var velocity_rotation: Vector3 = Vector3.ZERO
	var rest_pose: Transform3D

func _ready():
	if not Engine.is_editor_hint():
		setup_input_handling()

func setup_input_handling():
	"""Initialize input handling and bone modification data"""
	var skeleton = get_skeleton()
	if not skeleton:
		return
	
	# Initialize bone modifications for draggable bones
	for bone_name in draggable_bones:
		var bone_id = skeleton.find_bone(bone_name)
		if bone_id != -1:
			_create_bone_modification(bone_id)

func _create_bone_modification(bone_id: int):
	"""Create a bone modification entry for the given bone ID"""
	var mod = BoneModification.new()
	mod.bone_id = bone_id
	bone_modifications[bone_id] = mod

func enable_input():
	"""Enable input handling (called after intro finishes)"""
	_input_enabled = true

func disable_input():
	"""Disable input handling"""
	_input_enabled = false
	current_bone_id = -1
	hovered_bone_id = -1
	_is_dragging = false

func capture_rest_poses():
	"""Capture current bone poses as rest poses (called after intro)"""
	var skeleton = get_skeleton()
	if not skeleton:
		return
		
	for bone_id in bone_modifications.keys():
		var mod = bone_modifications[bone_id]
		mod.rest_pose = skeleton.get_bone_global_pose(bone_id)
		# Reset rotations to zero relative to new rest pose
		mod.target_rotation = Vector3.ZERO
		mod.current_rotation = Vector3.ZERO
		mod.velocity_rotation = Vector3.ZERO

func _process_modification():
	"""Apply bone modifications (runs after AnimationTree)"""
	if not _input_enabled:
		return
		
	var skeleton = get_skeleton()
	if not skeleton:
		return
	
	var delta = get_process_delta_time()
	
	# Update spring physics for all modified bones
	for bone_id in bone_modifications.keys():
		var mod = bone_modifications[bone_id]
		_update_bone_spring_physics(mod, delta)
		_apply_bone_modification(skeleton, mod)

func _update_bone_spring_physics(mod: BoneModification, delta: float):
	"""Calculate spring physics for bone movement"""
	# Calculate the target rotation using spring physics
	var force = (mod.target_rotation - mod.current_rotation) * spring_factor
	mod.velocity_rotation += force
	mod.velocity_rotation *= damping_factor
	mod.current_rotation += mod.velocity_rotation * delta * 60.0

func _apply_bone_modification(skeleton: Skeleton3D, mod: BoneModification):
	"""Apply the calculated rotation to the bone"""
	if mod.current_rotation.length() < 0.001:
		return  # No meaningful rotation to apply
	
	# Get current pose from animation
	var current_pose = skeleton.get_bone_global_pose(mod.bone_id)
	
	# Apply our rotation on top of the animated pose
	var rotation_quat = Quaternion.from_euler(mod.current_rotation)
	var modified_pose = Transform3D(current_pose.basis * Basis(rotation_quat), current_pose.origin)
	
	# Set the modified pose
	skeleton.set_bone_global_pose(mod.bone_id, modified_pose)

func handle_mouse_input(event: InputEvent):
	"""Handle mouse input from the skeleton controller"""
	if not _input_enabled:
		return false
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and hovered_bone_id != -1:
				return _start_bone_interaction()
			elif not event.pressed and current_bone_id != -1:
				return _end_bone_interaction()
	
	elif event is InputEventMouseMotion and _is_dragging and current_bone_id != -1:
		var delta_mouse = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		# Only consider it dragging if we've moved enough
		if delta_mouse.length() > _drag_threshold and not _has_dragged:
			_has_dragged = true
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		
		# Only handle drag if we've confirmed we're dragging
		if _has_dragged:
			_handle_bone_drag(delta_mouse)
			return true
	
	return false

func _start_bone_interaction() -> bool:
	"""Start interacting with a bone"""
	if hovered_bone_id == -1:
		return false
	
	# Create bone modification data if it doesn't exist (for click-only bones)
	if not bone_modifications.has(hovered_bone_id):
		_create_bone_modification(hovered_bone_id)
		
	current_bone_id = hovered_bone_id
	_is_dragging = true
	_has_dragged = false
	_mouse_pressed_time = Time.get_unix_time_from_system()
	
	# Get mouse position from the viewport
	var viewport = get_viewport()
	if viewport:
		last_mouse_pos = viewport.get_mouse_position()
	else:
		last_mouse_pos = Vector2.ZERO
		
	return true

func _end_bone_interaction() -> bool:
	"""End bone interaction"""
	var was_dragging = _is_dragging
	var click_time = Time.get_unix_time_from_system() - _mouse_pressed_time
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Handle click if it was quick and no significant drag occurred
	if click_time < _click_threshold and not _has_dragged:
		_handle_bone_click()
	
	current_bone_id = -1
	_is_dragging = false
	_has_dragged = false
	
	return was_dragging

func _handle_bone_click():
	"""Handle click-based finger curling (X-axis rotation)"""
	if not bone_modifications.has(current_bone_id):
		return
		
	var mod = bone_modifications[current_bone_id]
	
	if mod.target_rotation.x >= deg_to_rad(max_rotation_x - 5.0):  # Near max curl
		mod.target_rotation.x = deg_to_rad(min_rotation_x)  # Reset to extended
	else:
		mod.target_rotation.x += deg_to_rad(click_curl_step)  # Curl more
		mod.target_rotation.x = clamp(mod.target_rotation.x, 
			deg_to_rad(min_rotation_x), deg_to_rad(max_rotation_x))

func _handle_bone_drag(delta_mouse: Vector2):
	"""Handle drag-based sideways movement (Z-axis rotation)"""
	if not bone_modifications.has(current_bone_id):
		return
		
	var skeleton = get_skeleton()
	if not skeleton:
		return
		
	var bone_name = skeleton.get_bone_name(current_bone_id)
	
	# Only allow dragging for bones in the draggable_bones list
	if bone_name in draggable_bones:
		var mod = bone_modifications[current_bone_id]
		
		var rotation_delta = delta_mouse.y * rotation_speed * 0.01
		mod.target_rotation.z = clamp(mod.target_rotation.z + rotation_delta,
			deg_to_rad(min_rotation_z), deg_to_rad(max_rotation_z))
		
		mod.velocity_rotation.z *= 0.5

func set_bone_hovered(bone_id: int):
	"""Set which bone is currently hovered"""
	if hovered_bone_id != bone_id:
		if hovered_bone_id != -1:
			bone_unhovered.emit(hovered_bone_id)
		hovered_bone_id = bone_id
		if bone_id != -1:
			bone_hovered.emit(bone_id)

func reset_bone(bone_id: int):
	"""Reset a specific bone to its rest state"""
	if not bone_modifications.has(bone_id):
		return
		
	var mod = bone_modifications[bone_id]
	mod.target_rotation = Vector3.ZERO
	mod.current_rotation = Vector3.ZERO
	mod.velocity_rotation = Vector3.ZERO

func reset_all_bones():
	"""Reset all bones to their rest state"""
	for bone_id in bone_modifications.keys():
		reset_bone(bone_id)

# Methods for LevelManager integration
func get_bone_data():
	"""Get bone modification data for saving poses"""
	var data = {}
	for bone_id in bone_modifications.keys():
		var mod = bone_modifications[bone_id]
		data[bone_id] = {
			"target_rotation": mod.target_rotation,
			"current_rotation": mod.current_rotation
		}
	return data

func set_bone_data(data: Dictionary):
	"""Set bone modification data for loading poses"""
	for bone_id in data.keys():
		if bone_modifications.has(bone_id):
			var mod = bone_modifications[bone_id]
			mod.target_rotation = data[bone_id].get("target_rotation", Vector3.ZERO)
			mod.current_rotation = data[bone_id].get("current_rotation", Vector3.ZERO)
			mod.velocity_rotation = Vector3.ZERO  # Reset velocity when loading
