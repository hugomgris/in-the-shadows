extends Node3D

var skeleton: Skeleton3D
var base_bone_id: int
var mid_bone_id: int
var tip_bone_id: int

var base_to_mid_ratio: float = 0.6
var mid_to_tip_ratio: float = 0.8

func setup_skeleton():
	skeleton = get_node("BasiscHand_02/Armature_001/Skeleton3D")
	if skeleton:
		print("Found skeleton with ", skeleton.get_bone_count(), " bones")
	else:
		print("No skeleton found!")

func handle_input(event):
	if event is InputEventKey:
		_select_finger(event.keycode)
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			#curl_finger(-0.1)
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			#curl_finger(0.1)

func _select_finger(keycode: int):
	match keycode:
			KEY_1:
				base_bone_id = skeleton.find_bone("Bone.007")
				mid_bone_id = skeleton.find_bone("Bone.008")
				tip_bone_id = -1
			KEY_2:
				base_bone_id = skeleton.find_bone("Bone.009")
				mid_bone_id = skeleton.find_bone("Bone.010")
				tip_bone_id = skeleton.find_bone("Bone.011")
			KEY_3:
				base_bone_id = skeleton.find_bone("Bone.012")
				mid_bone_id = skeleton.find_bone("Bone.013")
				tip_bone_id = skeleton.find_bone("Bone.014")
			KEY_4:
				base_bone_id = skeleton.find_bone("Bone.015")
				mid_bone_id = skeleton.find_bone("Bone.016")
				tip_bone_id = skeleton.find_bone("Bone.017")
			KEY_5:
				base_bone_id = skeleton.find_bone("Bone.018")
				mid_bone_id = skeleton.find_bone("Bone.019")
				tip_bone_id = skeleton.find_bone("Bone.0201")
			KEY_6:
				base_bone_id = skeleton.find_bone("Bone.001")
				mid_bone_id = -1
				tip_bone_id = -1

func curl_finger(base_rotation_amount: float):
	if not skeleton or base_bone_id == -1:
		return

	var current_base_rotation = skeleton.get_bone_pose_rotation(base_bone_id)
	var x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount)
	skeleton.set_bone_pose_rotation(base_bone_id, current_base_rotation * x_rotation)

	if mid_bone_id != -1:
		var current_mid_rotation = skeleton.get_bone_pose_rotation(mid_bone_id)
		var mid_x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount * base_to_mid_ratio)
		skeleton.set_bone_pose_rotation(mid_bone_id, current_mid_rotation * mid_x_rotation)

	if tip_bone_id != -1:
		var current_tip_rotation = skeleton.get_bone_pose_rotation(tip_bone_id)
		var tip_x_rotation = Quaternion(Vector3.RIGHT, base_rotation_amount * base_to_mid_ratio * mid_to_tip_ratio)
		skeleton.set_bone_pose_rotation(tip_bone_id, current_tip_rotation * tip_x_rotation)
