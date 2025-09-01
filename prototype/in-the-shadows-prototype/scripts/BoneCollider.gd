extends Area3D

# Simple bone collider - just stores the bone name
# The actual logic is handled by SkeletonController.gd on the parent Skeleton3D

@export var bone_name: String = "Bone.000"  # Set this in the inspector

func _ready():
	# Store bone name as metadata for the skeleton controller to find
	set_meta("bone_name", bone_name)
	print("Bone collider ready: " + bone_name)
