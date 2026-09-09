extends Node2D

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _base_sprite_pos := Vector2()


func _ready():
	_base_sprite_pos = _animated_sprite.position
	_animated_sprite.play("idle")


func walk(direction: int) -> void:
	_animated_sprite.play("walk")
	_animated_sprite.flip_h = direction == -1


func idle() -> void:
	_animated_sprite.play("idle")


func surprised() -> void:
	_animated_sprite.play("surprised")


func gaming() -> void:
	_animated_sprite.play("gaming")


func set_seated(seated: bool, offset: float) -> void:
	if seated:
		_animated_sprite.position = _base_sprite_pos + Vector2(0, -offset)
	else:
		_animated_sprite.position = _base_sprite_pos
