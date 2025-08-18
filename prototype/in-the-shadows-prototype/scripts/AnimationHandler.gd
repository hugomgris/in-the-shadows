extends  Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready():
	print("Animations in AnimationPlayer:")
	for anim_name in anim_player.get_animation_list():
		print("- ", anim_name)
	
	var anim_name = "Hand_Idle"  # replace with your actual animation name
	var anim = anim_player.get_animation(anim_name)
	if anim:
		print("found")
		anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play(anim_name)
