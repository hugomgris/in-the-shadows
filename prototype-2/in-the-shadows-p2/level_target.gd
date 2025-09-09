extends Resource
class_name LevelTarget

@export var pose_data: PoseTarget
@export var level_name: String = ""
@export var description: String = ""
@export var unlock_requirements: Array[String] = []

func _init(level_name: String = "", pose: PoseTarget = null):
	self.level_name = level_name
	self.pose_data = pose
