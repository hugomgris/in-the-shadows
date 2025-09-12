extends Node
class_name AnimationController

signal intro_finished
signal animation_state_changed(new_state: String)

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback

# Animation state
var current_state: String = ""
var is_intro_playing: bool = false
var _pending_intro_start: bool = false

func _ready() -> void:
	setup_animation_system()

	if _pending_intro_start:
		_start_intro_now()

func setup_animation_system() -> void:
	"""Initialize the animation tree & state machine"""
	print("Setting up animation system...")
	
	if not animation_tree:
		push_error("Animation tree not found!")
		return

	print("Animation tree found, activating...")
	animation_tree.active = true
	
	# Get the state machine playback
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	if not state_machine:
		push_error("StateMachine playback not found!")
		return

	print("Animation system initialized successfully")

func play_intro() -> void:
	"""Start the intro animation (can be called before _ready)"""
	print("play_intro() called")
	
	if not state_machine:
		print("State machine not ready yet, marking intro as pending...")
		_pending_intro_start = true
		return
	
	_start_intro_now()

func _start_intro_now() -> void:
	"""Actually start the intro animation"""
	if not state_machine:
		push_error("StateMachine not available!")
		return

	is_intro_playing = true
	current_state = "intro"
	_pending_intro_start = false
		
	print("Starting intro animation...")
	state_machine.start("intro")
	animation_state_changed.emit("intro")
	print("Intro animation started, signal emitted")

func _process(delta):
	"""Monitor animation state changes"""
	if not state_machine:
		return

	var current_node = state_machine.get_current_node()
	var is_playing = state_machine.is_playing()

	# Check for state changes
	if current_node != current_state:
		print("State transition detected: ", current_state, " → ", current_node)
		
		# Handle intro finishing
		if current_state == "intro" and current_node == "idle":
			_on_intro_finished()
		
		# Update current state
		current_state = current_node
		animation_state_changed.emit(current_state)

	# Debug output (commented out for production)
	# if Engine.get_process_frames() % 120 == 0:  # Every 2 seconds
	#	print("Animation status - Current: ", current_node, " Playing: ", is_playing)

func _on_intro_finished():
	"""Handle intro completion"""
	print("Intro animation finished")
	is_intro_playing = false
	current_state = "idle"

	#Transition to idle
	state_machine.travel("idle")
	intro_finished.emit()

# Debug
func debug_state():
	"""Print current animation state info"""
	if state_machine:
		var current_node = state_machine.get_current_node()
		var is_playing = state_machine.is_playing()
		print("Animation State - Current: ", current_node, " Playing: ", is_playing)
