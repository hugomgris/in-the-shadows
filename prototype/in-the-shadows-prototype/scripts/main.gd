extends Node3D

func _ready():
	print("Main scene started!")
	var game_manager = $GameManager
	game_manager.initialize()
