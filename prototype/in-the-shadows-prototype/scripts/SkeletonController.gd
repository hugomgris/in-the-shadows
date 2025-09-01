extends Skeleton3D

# Movement Parameters
@export var rotation_speed: float = 0.001   # Drag sensitivity
@export var spring_factor: float = 0.08     # Reduced elasticity for less bounce
@export var damping_factor: float = 0.85     # More damping to reduce bounce

# Rotation Limits (radians) - Inverted for natural finger curl
@export var max_rotation_x: float = 0.2     # Fingers curl toward palm (positive = inward)
@export var min_rotation_x: float = -1.2    # Fingers extend away from palm (negative = outward)

# Curl Parameters - Reduced range for less deformation
@export var max_curl: float = 0.3           # Reduced sideways movement
@export var min_curl: float = -0.3
@export var curl_step: float = 0.1          # Wheel sensitivity

# Base bone names that can be dragged sideways
var draggable_bones = ["Bone.001", "Bone.007", "Bone.009", "Bone.012", "Bone.015", "Bone.018"]

# Global state
var dragging_bone: String = ""
var last_mouse_pos: Vector2

# Per-bone data storage
var bone_data: Dictionary = {}

# Bone data structure
class BoneState:
	var bone_idx: int
	var target_rot: Vector3 = Vector3.ZERO
	var current_rot: Vector3 = Vector3.ZERO
	var velocity_rot: Vector3 = Vector3.ZERO
	var curl_angle: float = 0.0
	var target_curl: float = 0.0
	var curl_velocity: float = 0.0

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	
	# Find all Area3D children and set up their input handling
	_setup_bone_colliders(self)
	set_process_unhandled_input(true)

func _setup_bone_colliders(node: Node):
	for child in node.get_children():
		if child is Area3D:
			# Check if this Area3D has a bone_name property or is named after a bone
			var bone_name = ""
			if child.has_method("get") and child.has_meta("bone_name"):
				bone_name = child.get_meta("bone_name")
			elif child.name.begins_with("Bone"):
				bone_name = child.name
			
			if bone_name != "":
				var bone_idx = find_bone(bone_name)
				if bone_idx != -1:
					# Initialize bone data
					var state = BoneState.new()
					state.bone_idx = bone_idx
					bone_data[bone_name] = state
					
					# Connect the Area3D input signal
					child.input_event.connect(_on_bone_input_event.bind(child))
					print("Connected bone collider: " + bone_name + " (index: " + str(bone_idx) + ")")
		
		# Recursively check children
		_setup_bone_colliders(child)

func _on_bone_input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int, area3d: Area3D):
	# Get the bone name from the Area3D 
	if not area3d or not area3d.has_meta("bone_name"):
		return
		
	var bone_name = area3d.get_meta("bone_name")
	if not bone_data.has(bone_name):
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging_bone = bone_name
			last_mouse_pos = event.position
			# Reset velocity for smooth start
			bone_data[bone_name].velocity_rot = Vector3.ZERO
			print("Started dragging: " + bone_name)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_bone != "":
			print("Stopped dragging: " + dragging_bone)
		dragging_bone = ""
	elif event is InputEventMouseMotion and dragging_bone != "":
		# Only allow sideways dragging for base bones
		if dragging_bone in draggable_bones:
			var delta = event.position - last_mouse_pos
			last_mouse_pos = event.position
			
			# Apply drag movement to target curl (perpendicular to bone's main axis)
			var state = bone_data[dragging_bone]
			state.target_curl = clamp(state.target_curl - delta.y * rotation_speed * 10.0, min_curl, max_curl)
	elif event is InputEventMouseButton and dragging_bone != "":
		# Allow scrolling while dragging any bone
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var state = bone_data[dragging_bone]
			state.target_rot.x = clamp(state.target_rot.x + curl_step, min_rotation_x, max_rotation_x)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var state = bone_data[dragging_bone]
			state.target_rot.x = clamp(state.target_rot.x - curl_step, min_rotation_x, max_rotation_x)

func _process(delta: float) -> void:
	# Update all bones
	for bone_name in bone_data.keys():
		var state = bone_data[bone_name]
		_update_bone(bone_name, state, delta)

func _update_bone(bone_name: String, state: BoneState, delta: float):
	# Organic rotation interpolation with velocity and damping
	# Note: We always interpolate toward target_rot, regardless of dragging state
	# This allows scroll wheel curls to persist when dragging stops
	var force = (state.target_rot - state.current_rot) * spring_factor
	state.velocity_rot += force
	state.velocity_rot *= damping_factor
	state.current_rot += state.velocity_rot * delta * 60.0
	
	# Organic curl interpolation - reduced spring factor for less bounce
	var curl_force = (state.target_curl - state.curl_angle) * spring_factor
	state.curl_velocity += curl_force
	state.curl_velocity *= damping_factor
	state.curl_angle += state.curl_velocity * delta * 60.0
	
	# Apply to skeleton
	var rest_transform = get_bone_rest(state.bone_idx)
	
	# Create rotation matrices
	var scroll_basis = Basis()
	scroll_basis = scroll_basis.rotated(Vector3.RIGHT, state.current_rot.x)
	
	var curl_basis = Basis()
	curl_basis = curl_basis.rotated(Vector3.FORWARD, state.curl_angle)
	
	var new_transform = rest_transform
	new_transform.basis = rest_transform.basis * scroll_basis * curl_basis
	
	set_bone_pose(state.bone_idx, new_transform)

# Utility functions
func reset_bone(bone_name: String):
	if not bone_data.has(bone_name):
		return
		
	var state = bone_data[bone_name]
	state.target_rot = Vector3.ZERO
	state.current_rot = Vector3.ZERO
	state.velocity_rot = Vector3.ZERO
	state.curl_angle = 0.0
	state.target_curl = 0.0
	state.curl_velocity = 0.0
	
	set_bone_pose(state.bone_idx, get_bone_rest(state.bone_idx))

func reset_all_bones():
	for bone_name in bone_data.keys():
		reset_bone(bone_name)
