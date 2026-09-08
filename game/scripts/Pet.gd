extends Node2D

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	_animated_sprite.play("idle")


func walk(direction: int) -> void:
	_animated_sprite.play("walk")
	_animated_sprite.flip_h = direction == -1


func idle() -> void:
	_animated_sprite.play("idle")
