extends Skeleton3D

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

@onready var area_3d: Area3D = %Area3D
@onready var skeleton_3d: Skeleton3D = %Skeleton3D
@onready var animation_controller: AnimationController = %AnimationController

var bone_data := {}
var current_bone_id := -1
var hovered_bone_id := -1
var last_mouse_pos: Vector2

var _input_enabled := false
var _is_dragging := false
var _has_dragged := false
var _mouse_pressed_time := 0
var _click_threshold := 0.15  # Maximum time for a click (seconds)
var _drag_threshold := 5.0    # Minimum distance to register as drag

var draggable_bones = ["Bone.001", "Bone.007", "Bone.009", "Bone.012", "Bone.015", "Bone.018"]

class BoneState:
	var bone_id: int
	var attachment: BoneAttachment3D
	var initial_rotation: Quaternion
	var target_rotation: Vector3 = Vector3.ZERO
	var current_rotation: Vector3 = Vector3.ZERO
	var velocity_rotation: Vector3 = Vector3.ZERO
	var accumulated_rotation: Vector3 = Vector3.ZERO

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	setup_bone_attachments()
	
	setup_animation_connection()
	_input_enabled = false

	set_process_unhandled_input(true)

	# Level manager connection
	if LevelManager:
		LevelManager.set_skeleton_controller(self)
		print("Connected to global LevelManager")

# Animation related management
func setup_animation_connection():
	"""Connect to the animation controller"""
	if animation_controller:
		# Make animation event connections
		animation_controller.intro_finished.connect(_on_intro_finished)
		animation_controller.animation_state_changed.connect(_on_animation_state_changed)

		animation_controller.play_intro()
		print("Connected to Animation Controller and started intro")
	else:
		push_error("Animation Controller not found!")

func _on_intro_finished():
	"""Called when intro animation completes (connected to signal)"""
	print("Intro finished - enabling input")

	# Capture final bone states frm intro
	capture_intro_final_states()

	_input_enabled = true
	set_process_unhandled_input(true)

	print("Hand ready for interaction")

func _on_animation_state_changed(new_state: String):
	"""Called when animation state changes (connected to signal)"""
	print("Animation state changed to: ", new_state)

func capture_intro_final_states():
	"""Capture the final bone states from intro animation"""
	print("Capturing final intro states...")

	for bone_id in bone_data.keys():
		var state = bone_data[bone_id]

		# Reset internal rotations to zero (relative to current pose)
		state.target_rotation = Vector3.ZERO
		state.current_rotation = Vector3.ZERO
		state.velocity_rotation = Vector3.ZERO

		# Store the current animated pose as the new "rest" pose
		state.initial_rotation = get_bone_pose_rotation(bone_id)

# Input/Bone related management
func setup_bone_attachments():
	var bone_attachments = find_children("*", "BoneAttachment3D")

	for attachment in bone_attachments:
		var bone_name = attachment.bone_name
		var bone_id = find_bone(bone_name)

		if bone_id != -1:
			var state = BoneState.new()
			state.bone_id = bone_id
			state.attachment = attachment
			state.initial_rotation = get_bone_pose_rotation(bone_id)
			bone_data[bone_id] = state

			var area = attachment.get_node("Area3D") as Area3D
			if area:
				area.set_meta("bone_name", bone_name)
				area.mouse_entered.connect(_on_bone_area_mouse_entered.bind(bone_id))
				area.mouse_exited.connect(_on_bone_area_mouse_exited.bind(bone_id))
				area.input_ray_pickable = true
				area.monitoring = true
			
			print("Setup bone: ", bone_name, " (ID: ", bone_id, ")")

func _on_bone_area_mouse_entered(bone_id: int):
	hovered_bone_id = bone_id
	print("Mouse entered bone: ", get_bone_name(bone_id))

func _on_bone_area_mouse_exited(bone_id: int):
	if hovered_bone_id == bone_id:
		hovered_bone_id = -1
	print("Mouse exited bone: ", get_bone_name(bone_id))

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or (animation_controller and animation_controller.is_intro_playing):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and hovered_bone_id != -1:
				current_bone_id = hovered_bone_id
				_is_dragging = true
				_has_dragged = false
				_mouse_pressed_time = Time.get_ticks_msec()
				last_mouse_pos = event.position
				
				if bone_data.has(current_bone_id):
					bone_data[current_bone_id].velocity_rotation = Vector3.ZERO
				
				print("Started interaction with bone: ", get_bone_name(current_bone_id))

			elif not event.pressed and current_bone_id != -1:
				var interaction_time = (Time.get_ticks_msec() - _mouse_pressed_time) / 1000.0
				
				if _is_dragging:
					_is_dragging = false
					
					if not _has_dragged and interaction_time < _click_threshold:
						_handle_bone_click()
				
				if _has_dragged:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

				current_bone_id = -1
				_has_dragged = false
	
	elif event is InputEventMouseMotion and _is_dragging and current_bone_id != -1:
		var delta_mouse = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		if delta_mouse.length() > _drag_threshold:
			_has_dragged = true

			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		
		if _has_dragged:
			_handle_bone_drag(delta_mouse)

	#Level creation key binds
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			LevelManager.record_current_pose()
		elif event.keycode == KEY_L:
			LevelManager.load_all_poses()
		elif event.keycode == KEY_S:
			LevelManager.save_recorded_poses()
		elif event.keycode == KEY_T:
			LevelManager.test_current_pose()
		elif event.keycode == KEY_R:
			reset_all_bones()

func _handle_bone_click():
	"""Handle click-based finger curling (X-axis rotation)"""
	if not bone_data.has(current_bone_id):
		return
		
	var state = bone_data[current_bone_id]
	
	if state.target_rotation.x >= deg_to_rad(max_rotation_x - 5.0):  # Near max curl
		state.target_rotation.x = deg_to_rad(min_rotation_x)  # Reset to extended
	else:
		state.target_rotation.x += deg_to_rad(click_curl_step)  # Curl more
		state.target_rotation.x = clamp(state.target_rotation.x, 
			deg_to_rad(min_rotation_x), deg_to_rad(max_rotation_x))
	
	print("Curling bone ", get_bone_name(current_bone_id), " to ", rad_to_deg(state.target_rotation.x), " degrees")
	print("Target rotation set to: ", state.target_rotation)

func _handle_bone_drag(delta_mouse: Vector2):
	"""Handle drag-based sideways movement (Z-axis rotation)"""
	if not bone_data.has(current_bone_id):
		return
		
	var bone_name = get_bone_name(current_bone_id)
	
	if bone_name in draggable_bones:
		var state = bone_data[current_bone_id]
		
		var rotation_delta = delta_mouse.y * rotation_speed * 0.01
		state.target_rotation.z = clamp(state.target_rotation.z + rotation_delta,
			deg_to_rad(min_rotation_z), deg_to_rad(max_rotation_z))
		
		state.velocity_rotation.z *= 0.5
		
		print("Dragging bone ", bone_name, " - Z rotation: ", rad_to_deg(state.target_rotation.z), " degrees")
	else:
		print("Bone ", bone_name, " is not draggable")

func _physics_process(delta: float) -> void:
	# Update spring physics for all bones
	for bone_id in bone_data.keys():
		_update_bone_with_springs(bone_id, delta)

func _process(delta: float) -> void:
	"""Force manual bone control AFTER animation system updates"""
	if _input_enabled and animation_controller and not animation_controller.is_intro_playing:
		# Apply manual control AFTER animation tree has updated
		_apply_manual_bone_control()

func _update_bone_with_springs(bone_id: int, delta: float):
	"""Calculate spring physics for bone movement (doesn't apply yet)"""
	var state = bone_data[bone_id]

	# During intro, let animation handle everything
	if animation_controller and animation_controller.is_intro_playing:
		return
	
	# Calculate the target rotation using spring physics
	var force = (state.target_rotation - state.current_rotation) * spring_factor
	state.velocity_rotation += force
	state.velocity_rotation *= damping_factor
	state.current_rotation += state.velocity_rotation * delta * 60.0

func _apply_manual_bone_control():
	"""Force apply manual bone rotations, overriding animation system"""
	var applied_count = 0
	
	# Check if AnimationTree is still active
	var animation_tree_active = animation_controller and animation_controller.animation_tree and animation_controller.animation_tree.active
	
	for bone_id in bone_data.keys():
		var bone_name = get_bone_name(bone_id)
		var state = bone_data[bone_id]
		
		# If AnimationTree is disabled, apply manual control to ALL bones
		# If AnimationTree is active, only apply to interactive bones with non-zero rotations
		var should_apply = false
		if not animation_tree_active:
			# AnimationTree disabled - apply all manual rotations
			should_apply = state.current_rotation.length() > 0.001
		else:
			# AnimationTree active - only override interactive bones
			should_apply = bone_name in draggable_bones and state.current_rotation.length() > 0.01
		
		if should_apply:
			var rotation_quat = Quaternion.from_euler(state.current_rotation)
			var final_rotation = state.initial_rotation * rotation_quat
			
			# FORCE set the bone rotation
			set_bone_pose_rotation(bone_id, final_rotation)
			applied_count += 1
	
	# Debug output every 60 frames if we're applying manual control
	if applied_count > 0 and Engine.get_process_frames() % 60 == 0:
		var tree_status = "active" if animation_tree_active else "disabled"
		print("Applying manual control to ", applied_count, " bones (AnimationTree: ", tree_status, ")")

func reset_bone(bone_id: int):
	"""Reset a specific bone to its initial state"""
	if not bone_data.has(bone_id):
		return
		
	var state = bone_data[bone_id]
	state.target_rotation = Vector3.ZERO
	state.current_rotation = Vector3.ZERO
	state.velocity_rotation = Vector3.ZERO
	state.accumulated_rotation = Vector3.ZERO
	
	set_bone_pose_rotation(bone_id, state.initial_rotation)

func reset_all_bones():
	"""Reset all bones to their initial state"""
	for bone_id in bone_data.keys():
		reset_bone(bone_id)
