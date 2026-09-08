extends Node2D

@export var speed := 100.0
@export var left_limit := 100.0
@export var right_limit := 1000.0

var direction := 1

func _ready():
	$AnimatedSprite2D.play("walk")


func _process(delta):
	position.x += speed * direction * delta

	if position.x >= right_limit:
		direction = -1

	if position.x <= left_limit:
		direction = 1

	$AnimatedSprite2D.flip_h = direction == -1
	
