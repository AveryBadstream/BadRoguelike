extends Position2D

onready var tween = get_node("Tween")
onready var FCT = get_node("FCT")


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func show_value(value, start_pos, travel, duration, spread, color=Color(255,255,255)):
	FCT.text = str(value)
	FCT.modulate = color
	var movement = travel.rotated(rand_range(-spread/2, spread/2))
	position =  Vector2(start_pos.x+8, start_pos.y+4)
	
	tween.interpolate_property(self, "scale", scale,  Vector2(1,1), 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(self, "scale", Vector2(1,1), Vector2(0.1, 0.1), 0.7, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.3)
	tween.start()
	
#func _process(delta):
#	pass


func _on_Tween_tween_all_completed():
	self.queue_free() # Replace with function body.
