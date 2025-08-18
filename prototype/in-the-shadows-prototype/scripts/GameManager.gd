extends Node

@onready var hand = $"../Hand"

func initialize():
	print("GameManager initialized")
	hand.setup_skeleton()

func _input(event):
	hand.handle_input(event)
