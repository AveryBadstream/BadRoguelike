extends Node2D

var FCT = preload("res://FCT.tscn")

export var travel = Vector2(0, -80)
export var duration = 2
export var spread = PI/2

func show_value(value, start_pos, color):
	var fct = FCT.instance()
	add_child(fct)
	fct.show_value(str(value), start_pos*16, travel, duration, spread, color)
