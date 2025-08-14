extends Node3D

var skeleton: Skeleton3D
var index_base_bone_id: int
var index_mid_bone_id: int
var index_tip_bone_id: int

# Constraint multipliers (adjust these to get natural finger curl)
var base_to_mid_ratio: float = 0.6  # Middle phalange rotates 60% of base rotation
var mid_to_tip_ratio: float = 0.8   # Tip phalange rotates 80% of middle rotation

# Camera variables
var camera: Camera3D
var camera_pivot: Node3D
var camera_distance: float = 5.0
var camera_height: float = 7.0
var rotation_speed: float = 2.0
var zoom_speed: float = 0.5
var pan_speed: float = 0.01

# Camera state
var is_rotating: bool = false
var is_panning: bool = false
var last_mouse_position: Vector2

func _ready():
	print("Main scene started!")
	setup_camera()
	setup_skeleton()

func setup_camera():
	# Create camera pivot point (this will be our orbit center)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	
	# Create camera and attach to pivot
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera_pivot.add_child(camera)
	
	# Position camera for axonometric-style view (elevated and angled)
	camera.position = Vector3(0, camera_height, camera_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# Optional: Adjust FOV for more orthographic-like feel
	camera.fov = 45  # Lower values feel more orthographic
	
	print("Camera setup complete")

func setup_skeleton():
	skeleton = get_node("Hand/Armature_001/Skeleton3D")
	if skeleton:
		print("Found skeleton with ", skeleton.get_bone_count(), " bones")
		
		# Find all index finger bones
		index_base_bone_id = -1
		index_mid_bone_id = -1
		index_tip_bone_id = -1
		
		if index_base_bone_id != -1:
			print("Found index base bone at ID: ", index_base_bone_id)
		if index_mid_bone_id != -1:
			print("Found index mid bone at ID: ", index_mid_bone_id)
		if index_tip_bone_id != -1:
			print("Found index tip bone at ID: ", index_tip_bone_id)
			
		# If bones not found, print all available names
		if index_base_bone_id == -1 or index_mid_bone_id == -1 or index_tip_bone_id == -1:
			print("Some bones not found! Available bones:")
			for i in range(skeleton.get_bone_count()):
				print("Bone ", i, ": ", skeleton.get_bone_name(i))
		
		# Position camera pivot at hand center for better orbiting
		if skeleton.get_parent():
			camera_pivot.global_position = skeleton.get_parent().global_position
	else:
		print("No skeleton found!")

func _input(event):
	handle_finger_controls(event)
	handle_camera_controls(event)

func handle_finger_controls(event):
	if event is InputEventKey:
		if event.keycode == KEY_1:
			index_base_bone_id = skeleton.find_bone("Bone.007")
			index_mid_bone_id = skeleton.find_bone("Bone.008")
			index_tip_bone_id = -1
		elif event.keycode == KEY_2:
			index_base_bone_id = skeleton.find_bone("Bone.009")
			index_mid_bone_id = skeleton.find_bone("Bone.010")
			index_tip_bone_id = skeleton.find_bone("Bone.011")
		elif event.keycode == KEY_3:
			index_base_bone_id = skeleton.find_bone("Bone.012")
			index_mid_bone_id = skeleton.find_bone("Bone.013")
			index_tip_bone_id = skeleton.find_bone("Bone.014")
		elif event.keycode == KEY_4:
			index_base_bone_id = skeleton.find_bone("Bone.015")
			index_mid_bone_id = skeleton.find_bone("Bone.016")
			index_tip_bone_id = skeleton.find_bone("Bone.017")
		elif event.keycode == KEY_5:
			index_base_bone_id = skeleton.find_bone("Bone.018")
			index_mid_bone_id = skeleton.find_bone("Bone.019")
			index_tip_bone_id = skeleton.find_bone("Bone.0201")
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			curl_finger(-0.1)  # Curl finger
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			curl_finger(0.1)  # Uncurl finger

func handle_camera_controls(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_rotating = event.pressed
			last_mouse_position = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			last_mouse_position = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.ctrl_pressed:
			zoom_camera(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.ctrl_pressed:
			zoom_camera(zoom_speed)
	
	elif event is InputEventMouseMotion:
		var mouse_delta = event.position - last_mouse_position
		
		if is_rotating:
			orbit_camera(mouse_delta)
		elif is_panning:
			pan_camera(mouse_delta)
		
		last_mouse_position = event.position

func orbit_camera(mouse_delta: Vector2):
	# Rotate around Y axis (horizontal mouse movement)
	camera_pivot.rotate_y(-mouse_delta.x * rotation_speed * 0.01)
	
	# Rotate around local X axis (vertical mouse movement) with limits
	var x_rotation = -mouse_delta.y * rotation_speed * 0.01
	var current_x_rotation = camera_pivot.rotation.x
	
	# Clamp vertical rotation to prevent flipping
	var new_x_rotation = clamp(current_x_rotation + x_rotation, -PI/2 + 0.1, PI/2 - 0.1)
	camera_pivot.rotation.x = new_x_rotation

func pan_camera(mouse_delta: Vector2):
	# Pan the camera pivot point
	var camera_basis = camera.global_transform.basis
	var right = camera_basis.x
	var up = camera_basis.y
	
	var pan_vector = (-right * mouse_delta.x + up * mouse_delta.y) * pan_speed
	camera_pivot.global_position += pan_vector

func zoom_camera(zoom_amount: float):
	camera_distance += zoom_amount
	camera_distance = clamp(camera_distance, 1.0, 20.0)  # Limit zoom range
	
	# Update camera position relative to pivot
	var direction = camera.position.normalized()
	camera.position = direction * camera_distance

# Reset camera to default axonometric view
func reset_camera():
	camera_pivot.rotation = Vector3.ZERO
	camera_distance = 5.0
	camera_height = 4.0
	camera.position = Vector3(0, camera_height, camera_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# Reset pivot position to hand center if skeleton exists
	if skeleton and skeleton.get_parent():
		camera_pivot.global_position = skeleton.get_parent().global_position

func curl_finger(base_rotation_amount: float):
	if skeleton and index_base_bone_id != -1:
		# Rotate base phalange
		var current_base_rotation = skeleton.get_bone_pose_rotation(index_base_bone_id)
		var x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount)
		skeleton.set_bone_pose_rotation(index_base_bone_id, current_base_rotation * x_rotation)
		
		# Rotate middle phalange (constrained to base)
		if index_mid_bone_id != -1:
			var current_mid_rotation = skeleton.get_bone_pose_rotation(index_mid_bone_id)
			var mid_x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount * base_to_mid_ratio)
			skeleton.set_bone_pose_rotation(index_mid_bone_id, current_mid_rotation * mid_x_rotation)
		
		# Rotate tip phalange (constrained to middle)
		if index_tip_bone_id != -1:
			var current_tip_rotation = skeleton.get_bone_pose_rotation(index_tip_bone_id)
			var tip_x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount * base_to_mid_ratio * mid_to_tip_ratio)
			skeleton.set_bone_pose_rotation(index_tip_bone_id, current_tip_rotation * tip_x_rotation)
		
		print("Curled finger by: ", base_rotation_amount)

# Add keyboard shortcut to reset camera
func _unhandled_key_input(event):
	if event.keycode == KEY_R and event.pressed:
		reset_camera()
		print("Camera reset to default position")
