extends Node3D

@onready var shaded = $linkPosed001
@onready var unshaded = $link_nonshaded
@onready var toggle_button = $CameraRoot/Camera3D/ToggleButton
@onready var camera = $CameraRoot/Camera3D

func _physics_process(delta):
	if Input.is_action_just_released("wheel_up"):
		camera.position.z -= delta * 5.0
		camera.position.z = clamp(camera.position.z, 0.0, 50.0)
	elif Input.is_action_just_released("wheel_down"):
		camera.position.z += delta * 5.0
		camera.position.z = clamp(camera.position.z, 0.0, 50.0)



func _on_ToggleButton_toggled(button_pressed):
	if button_pressed:
		shaded.visible = true
		unshaded.visible = false
	else:
		shaded.visible = false
		unshaded.visible = true
