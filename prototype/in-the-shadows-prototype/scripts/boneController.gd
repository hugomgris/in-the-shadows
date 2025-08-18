extends Area3D

# Bone Configuration
@export var bone_name: String = "Bone.014"  # Set this in the inspector for each bone
@export var skeleton_path: NodePath = "../.."  # Path to skeleton from this node

# Movement Parameters
@export var rotation_speed: float = 0.005   # Drag sensitivity
@export var spring_factor: float = 0.15     # Soft spring interpolation
@export var damping_factor: float = 0.95    # Damping for organic feel

# Rotation Limits (radians)
@export var max_rotation_x: float = 1.0
@export var min_rotation_x: float = -1.0
@export var max_rotation_y: float = 0.5
@export var min_rotation_y: float = -0.5

# Curl Parameters
@export var max_curl: float = 1.0
@export var min_curl: float = -0.2
@export var curl_step: float = 0.1          # Wheel sensitivity

var dragging = false
var last_mouse_pos: Vector2
var skeleton: Skeleton3D
var bone_idx: int

# Stored target rotations
var target_rot: Vector3 = Vector3.ZERO
var current_rot: Vector3 = Vector3.ZERO
var velocity_rot: Vector3 = Vector3.ZERO    # For organic movement
var curl_angle: float = 0.0
var target_curl: float = 0.0
var curl_velocity: float = 0.0

func _ready():
	# Find the skeleton using the exported path
	skeleton = get_node(skeleton_path)
	if not skeleton:
		push_error("Skeleton not found at path: " + str(skeleton_path))
		return
	
	# Find the bone index by name
	bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		push_error("Bone '" + bone_name + "' not found in skeleton")
		return
	
	print("Bone controller initialized for: " + bone_name + " (index: " + str(bone_idx) + ")")
	
	# Connect to the main scene's input handling
	set_process_unhandled_input(true)

# Handles clicks + scroll wheel while hovering the collider
func _input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging = true
			last_mouse_pos = event.position
			# Reset velocity for smooth start
			velocity_rot = Vector3.ZERO
			print("Started dragging: " + bone_name)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_curl = clamp(target_curl + curl_step, min_curl, max_curl)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_curl = clamp(target_curl - curl_step, min_curl, max_curl)

# Handle all mouse input globally to maintain dragging outside collider
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			print("Stopped dragging: " + bone_name)
		dragging = false
	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		# Apply drag movement to target rotation
		var new_target_x = clamp(target_rot.x + delta.y * rotation_speed, min_rotation_x, max_rotation_x)
		var new_target_y = clamp(target_rot.y + delta.x * rotation_speed, min_rotation_y, max_rotation_y)
		
		target_rot.x = new_target_x
		target_rot.y = new_target_y

# Apply smoothed rotations + curl to the bone with organic movement
func _process(delta: float) -> void:
	# Skip if skeleton or bone is invalid
	if not skeleton or bone_idx == -1:
		return
	
	# Organic rotation interpolation with velocity and damping
	if dragging:
		# Calculate spring force towards target
		var force = (target_rot - current_rot) * spring_factor
		velocity_rot += force
		velocity_rot *= damping_factor  # Apply damping
		current_rot += velocity_rot * delta * 60.0  # Frame-rate independent
	else:
		# When not dragging, gradually return to rest position
		var rest_force = (Vector3.ZERO - current_rot) * spring_factor * 0.5
		velocity_rot += rest_force
		velocity_rot *= damping_factor
		current_rot += velocity_rot * delta * 60.0
	
	# Organic curl interpolation
	var curl_force = (target_curl - curl_angle) * spring_factor * 2.0
	curl_velocity += curl_force
	curl_velocity *= damping_factor
	curl_angle += curl_velocity * delta * 60.0
	
	# Apply to skeleton
	var rest_transform = skeleton.get_bone_rest(bone_idx)
	
	# Create rotation matrices
	var drag_basis = Basis()
	drag_basis = drag_basis.rotated(Vector3.RIGHT, current_rot.x)
	drag_basis = drag_basis.rotated(Vector3.UP, current_rot.y)
	
	# Curl around the bone's local forward axis (adjust if needed)
	var curl_basis = Basis()
	curl_basis = curl_basis.rotated(Vector3.FORWARD, curl_angle)
	
	var new_transform = rest_transform
	new_transform.basis = rest_transform.basis * drag_basis * curl_basis
	
	skeleton.set_bone_pose(bone_idx, new_transform)

# Utility function to reset bone to rest position
func reset_bone():
	target_rot = Vector3.ZERO
	current_rot = Vector3.ZERO
	velocity_rot = Vector3.ZERO
	curl_angle = 0.0
	target_curl = 0.0
	curl_velocity = 0.0
	
	if skeleton and bone_idx != -1:
		skeleton.set_bone_pose(bone_idx, skeleton.get_bone_rest(bone_idx))

# Function to set bone name programmatically (useful for dynamic setup)
func set_bone_name(new_bone_name: String):
	bone_name = new_bone_name
	if skeleton:
		bone_idx = skeleton.find_bone(bone_name)
		if bone_idx == -1:
			push_error("Bone '" + bone_name + "' not found in skeleton")
		else:
			print("Bone controller updated for: " + bone_name + " (index: " + str(bone_idx) + ")")
			reset_bone()
