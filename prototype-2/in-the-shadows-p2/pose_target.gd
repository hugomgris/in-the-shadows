extends Resource
class_name PoseTarget

@export var name: String = ""
@export var bone_rotations: Dictionary = {} #bone_name -> Vector3
@export var tolerance: float = 15.0
@export var required_bones: Array = []
@export var difficulty: int = 1
@export var hints: Array[String] = []
@export var img_reference: Texture2D

func _init(pose_name: String = ""):
	name = pose_name
