extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var Enemy_Sprite = $Enemy_Sprite
var mod_color = Color.white
var sprite_frame = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	Enemy_Sprite.frame = sprite_frame
	Enemy_Sprite.modulate = mod_color # Replace with function body.

func modulate_sprite(color):
	mod_color = color
	Enemy_Sprite.modulate = color

func set_sprite(frame):
	sprite_frame = frame
	Enemy_Sprite.frame = frame
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
