extends Skeleton3D

@onready var area_3d: Area3D = %Area3D
@onready var skeleton_3d: Skeleton3D = %Skeleton3D
@onready var animation_controller: AnimationController = %AnimationController
@onready var hand_input_modifier: HandInputModifier

var bone_data := {}
var _input_enabled := false

class BoneState:
	var bone_id: int
	var attachment: BoneAttachment3D

func _ready():
	print("Skeleton controller initialized with ", get_bone_count(), " bones")
	setup_bone_attachments()
	setup_hand_input_modifier()
	setup_animation_connection()
	_input_enabled = false

	set_process_unhandled_input(true)

	# Level manager connection
	if LevelManager:
		LevelManager.set_skeleton_controller(self)
		print("Connected to global LevelManager")

func setup_hand_input_modifier():
	"""Find and setup the HandInputModifier"""
	hand_input_modifier = get_node("HandInputModifier") as HandInputModifier
	if hand_input_modifier:
		# Connect signals
		hand_input_modifier.bone_hovered.connect(_on_bone_hovered)
		hand_input_modifier.bone_unhovered.connect(_on_bone_unhovered)
		print("Connected to HandInputModifier")
	else:
		push_error("HandInputModifier not found! Make sure it's added as a child of the Skeleton3D")

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

	# Enable input on the modifier and capture final poses
	if hand_input_modifier:
		hand_input_modifier.capture_rest_poses()
		hand_input_modifier.enable_input()

	_input_enabled = true
	set_process_unhandled_input(true)

	print("Hand ready for interaction")

func _on_animation_state_changed(new_state: String):
	"""Called when animation state changes (connected to signal)"""
	print("Animation state changed to: ", new_state)

func reset_all_bones():
	"""Reset all bones to their initial state"""
	if hand_input_modifier:
		hand_input_modifier.reset_all_bones()
		print("All bones reset via HandInputModifier")

# Methods for LevelManager integration
func get_bone_data():
	"""Get bone data for LevelManager compatibility"""
	if hand_input_modifier:
		return hand_input_modifier.get_bone_data()
	return {}

func set_bone_data(data: Dictionary):
	"""Set bone data for LevelManager compatibility"""
	if hand_input_modifier:
		hand_input_modifier.set_bone_data(data)
func setup_bone_attachments():
	var bone_attachments = find_children("*", "BoneAttachment3D")

	for attachment in bone_attachments:
		var bone_name = attachment.bone_name
		var bone_id = find_bone(bone_name)

		if bone_id != -1:
			var state = BoneState.new()
			state.bone_id = bone_id
			state.attachment = attachment
			bone_data[bone_id] = state

			var area = attachment.get_node("Area3D") as Area3D
			if area:
				area.set_meta("bone_name", bone_name)
				# Connect area signals for hover detection
				area.mouse_entered.connect(_on_bone_area_mouse_entered.bind(bone_id))
				area.mouse_exited.connect(_on_bone_area_mouse_exited.bind(bone_id))
			
			print("Setup bone: ", bone_name, " (ID: ", bone_id, ")")

func _on_bone_hovered(bone_id: int):
	"""Called when HandInputModifier detects bone hover"""
	# Could add visual feedback here if needed
	pass

func _on_bone_unhovered(bone_id: int):
	"""Called when HandInputModifier detects bone unhover"""  
	# Could add visual feedback here if needed
	pass

func _on_bone_area_mouse_entered(bone_id: int):
	"""Handle bone area mouse enter events"""
	if hand_input_modifier:
		hand_input_modifier.set_bone_hovered(bone_id)

func _on_bone_area_mouse_exited(bone_id: int):
	"""Handle bone area mouse exit events"""
	if hand_input_modifier:
		hand_input_modifier.set_bone_hovered(-1)

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or (animation_controller and animation_controller.is_intro_playing):
		return
	
	# Let the HandInputModifier handle mouse input
	if hand_input_modifier and hand_input_modifier.handle_mouse_input(event):
		get_viewport().set_input_as_handled()
		return

	# Level creation key binds
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
