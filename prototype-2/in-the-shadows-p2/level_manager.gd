extends Node

signal pose_recorded(pose: PoseTarget)
signal poses_saved(file_path: String)
signal pose_match_found(pose_name: String, accuracy: float)

@export var poses_directory: String = "res://poses/"
@export var auto_save_on_record: bool = false

var recorded_poses: Array[PoseTarget] = []
var loaded_poses: Array[PoseTarget] = []
var skeleton_controller: Skeleton3D

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(poses_directory):
		DirAccess.open("res://").make_dir_recursive_absolute(poses_directory)

func set_skeleton_controller(controller: Skeleton3D):
	skeleton_controller = controller

func record_current_pose(pose_name: String = "") -> PoseTarget:
	"""Record current pose from connected skeleton controller"""
	if not skeleton_controller:
		push_error("No skeleton controller connected!")
		return null
	
	if pose_name.is_empty():
		pose_name = "pose_" + str(Time.get_unix_time_from_system())
	
	var target = create_pose_target(pose_name)
	recorded_poses.append(target)

	pose_recorded.emit(target)
	print("Recorded pose: ", pose_name)

	if auto_save_on_record:
		save_recorded_poses()

	return target

func create_pose_target(pose_name: String) -> PoseTarget:
	"""Create a PoseTarget from current skeleton state"""
	var target = PoseTarget.new(pose_name)

	for bone_id in skeleton_controller.bone_data.keys():
		var bone_name = skeleton_controller.get_bone_name(bone_id)
		var state = skeleton_controller.bone_data[bone_id]
		target.bone_rotations[bone_name] = state.current_rotation
		target.required_bones.append(bone_name)

	target.tolerance = 15.0
	target.difficulty = 1

	return target

func save_recorded_poses(custom_filename: String = "") -> String:
	"Save all recorded poses to JSON file"
	if recorded_poses.is_empty():
		print("No poses recorded yet!")
		return ""

	var poses_data = []
	for pose in recorded_poses:
		poses_data.append(pose_to_dict(pose))
	
	var json_data = {
		"version": "1.0",
		"created_at": Time.get_datetime_string_from_system(),
		"poses": poses_data
	}

	var json_string = JSON.stringify(json_data, "\t")

	var filename: String
	if custom_filename.is_empty():
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		filename = poses_directory + "poses_" + timestamp + ".json"
	else:
		filename = poses_directory + custom_filename + ".json"
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Saved ", recorded_poses.size(), " poses to: ", filename)
		poses_saved.emit(filename)
		recorded_poses.clear()
		return filename
	else:
		push_error("Failed to save poses to file!")
		return ""

func load_poses_from_json(file_path: String) -> Array[PoseTarget]:
	"""Load poses from JSON file"""
	var poses: Array[PoseTarget] = []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open file " + file_path)
		return poses

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Error parsin JSON: " + json.get_error_message())
		return poses

	var data = json.get_data()
	if not data.has("poses"):
		push_error("Invalid JSON format - missing 'poses' array")
		return poses
	
	for pose_data in data.poses:
		var pose = dict_to_pose(pose_data)
		if pose:
			poses.append(pose)

	print ("Loaded ", poses.size(), " poses from ", file_path)
	return poses

func load_all_poses() -> Array[PoseTarget]:
	"""Load ALL JSON pose files from the poses directory"""
	loaded_poses.clear()

	var dir = DirAccess.open(poses_directory)
	if not dir:
		push_error("Could not access poses directory: " + poses_directory)
		return loaded_poses

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			print("Loading poses from: ", file_name)
			var poses = load_poses_from_json(poses_directory + file_name)
			loaded_poses.append_array(poses)
		file_name = dir.get_next()

	return loaded_poses

func check_pose_match(target: PoseTarget) -> float:
	"""Check how well current skeleton poses matches target"""
	if not skeleton_controller:
		push_error("No skeletton controller connected!")
		return 0.0

	var total_bones = target.required_bones.size();
	var matched_bones = 0

	for bone_name in target.required_bones:
		var bone_id = skeleton_controller.find_bone(bone_name)
		if bone_id == -1 or not skeleton_controller.bone_data.has(bone_id):
			continue
		
		var current_rot = skeleton_controller.bone_data[bone_id].current_rotation
		var target_rot = target.bone_rotations.get(bone_name, Vector3.ZERO)

		#Check within tolerance (degrees)
		var diff_x = abs(rad_to_deg(current_rot.x - target_rot.x))
		var diff_z = abs(rad_to_deg(current_rot.z - target_rot.z))

		if diff_x <= target.tolerance and diff_z <= target.tolerance:
			matched_bones += 1

	return float(matched_bones) / float(total_bones) if total_bones > 0 else 0.0

func test_current_pose() -> Array[Dictionary]:
	"""Test current pose against all loaded poses"""
	if not skeleton_controller:
		push_error("No skeleton controller connected!")
		return []

	if loaded_poses.is_empty():
		print("No poses loaded to test against!")
		return []

	var results: Array[Dictionary] = []
	print("Testing current pose against ", loaded_poses. size(), "loaded poses:")

	for pose in loaded_poses:
		var match_percentage = check_pose_match(pose)
		var status = "NOT matched"
		if match_percentage >= 0.85:
			status = "MATCHED"
			pose_match_found.emit(pose.name, match_percentage)
		elif match_percentage >= 0.5:
			status = "CLOSE but NOT matched"

		var result = {
			"pose_name": pose.name,
			"accuracy": match_percentage,
			"status": status,
			"pose": pose
		}

		results.append(result)
		print("%s %s: %.1f%% match" % [status, pose.name, match_percentage * 100])
	
	return results
	

# Utils
func pose_to_dict(pose: PoseTarget) -> Dictionary:
	"""Convert PoseTarget to dictionary for JSON serialization"""
	return {
		"name": pose.name,
		"bone_rotations": serialize_bone_rotations(pose.bone_rotations),
		"tolerance": pose.tolerance,
		"required_bones": pose.required_bones,
		"difficulty": pose.difficulty,
		"hints": pose.hints
	}

func serialize_bone_rotations(bone_rotations: Dictionary) -> Dictionary:
	"""Convert Vector3 rotations to serializable format"""
	var serialized = {}
	for bone_name in bone_rotations:
		var rot = bone_rotations[bone_name] as Vector3
		serialized[bone_name] = {
			"x": rot.x,
			"y": rot.y,
			"z": rot.z
		}
	
	return serialized

func dict_to_pose(data: Dictionary) -> PoseTarget:
	"""Convert dictionary back to PoseTarget"""
	var pose = PoseTarget.new(data.get("name", "unnamed"))
	pose.tolerance = data.get("tolerance", 15.0)
	pose.difficulty = data.get("difficulty", 1)
	pose.required_bones = data.get("required_bones", [])

	var hints_data = data.get("hints", [])
	pose.hints.clear()
	for hint in hints_data:
		pose.hints.append(str(hint))

	# Deserialization
	var bone_rotations_data = data.get("bone_rotations", {})
	for bone_name in bone_rotations_data:
		var rot_data = bone_rotations_data[bone_name]

		if rot_data is Vector3:
			pose.bone_rotations[bone_name] = rot_data
		elif rot_data is Dictionary:
			pose.bone_rotations[bone_name] = Vector3(
				rot_data.get("x", 0.0),
				rot_data.get("y", 0.0),
				rot_data.get("z", 0.0)
			)
		else:
			print("Warning: Unexpected rotation data type for bone ", bone_name, ": ", typeof(rot_data))
			pose.bone_rotations[bone_name] = Vector3.ZERO

	return pose

func get_poses_by_difficulty(difficulty: int) -> Array[PoseTarget]:
	"""Filter loaded poses by difficulty level"""
	var filtered: Array[PoseTarget] = []

	for pose in loaded_poses:
		if pose.difficulty == difficulty:
			filtered.append(pose)

	return filtered

func get_pose_by_name(pose_name: String) -> PoseTarget:
	for pose in loaded_poses:
		if pose.name == pose_name:
			return pose
	
	return null
