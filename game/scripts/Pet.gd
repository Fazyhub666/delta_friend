extends Node2D

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _base_sprite_pos := Vector2()


func _ready():
	_base_sprite_pos = _animated_sprite.position
	_animated_sprite.play("idle")


func walk(direction: int) -> void:
	_animated_sprite.play("walk")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == -1


func idle() -> void:
	_animated_sprite.play("idle")
	_animated_sprite.speed_scale = 1.0


func surprised() -> void:
	_animated_sprite.play("surprised")
	_animated_sprite.speed_scale = 1.0


func gaming() -> void:
	_animated_sprite.play("gaming")
	_animated_sprite.speed_scale = 1.0


func sit_call() -> void:
	_animated_sprite.play("sit_call")
	_animated_sprite.speed_scale = 1.0


func sit_call_end() -> void:
	_animated_sprite.play("sit_call_end")
	_animated_sprite.speed_scale = 1.0


func sit_book() -> void:
	_animated_sprite.play("sit_book")
	_animated_sprite.speed_scale = 1.0


func walk_book(direction: int) -> void:
	_animated_sprite.play("walk_book")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == -1


func idle_book() -> void:
	_animated_sprite.play("idle_book")
	_animated_sprite.speed_scale = 1.0


func maus_walk1() -> void:
	_animated_sprite.play("maus_walk1")
	_animated_sprite.speed_scale = 1.0


func maus_walk2(direction: int) -> void:
	_animated_sprite.play("maus_walk2")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == -1


func maus_walk3(direction: int) -> void:
	_animated_sprite.play("maus_walk3")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == 1


func maus_catch(direction: int) -> void:
	_animated_sprite.play("maus_catch")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == 1


func maus_catch2(direction: int) -> void:
	_animated_sprite.play("maus_catch2")
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = direction == -1


func animation_duration(anim: StringName) -> float:
	var frames: SpriteFrames = _animated_sprite.sprite_frames
	var base := 0.0
	for i in frames.get_frame_count(anim):
		base += frames.get_frame_duration(anim, i)
	return base / frames.get_animation_speed(anim)


func last_frame_start(anim: StringName) -> float:
	var frames: SpriteFrames = _animated_sprite.sprite_frames
	var n := frames.get_frame_count(anim)
	if n <= 0:
		return 0.0
	var speed := frames.get_animation_speed(anim)
	if speed <= 0.0:
		return 0.0
	return animation_duration(anim) - frames.get_frame_duration(anim, n - 1) / speed


func scared() -> void:
	_animated_sprite.play("scared")
	_animated_sprite.speed_scale = 1.0


func face(direction: int) -> void:
	_animated_sprite.flip_h = direction == -1


func jump(direction: int, duration: float = 0.0) -> void:
	_animated_sprite.play("jump")
	_animated_sprite.flip_h = direction == -1
	if duration > 0.0:
		var base := 0.0
		for i in _animated_sprite.sprite_frames.get_frame_count("jump"):
			base += _animated_sprite.sprite_frames.get_frame_duration("jump", i)
		base /= _animated_sprite.sprite_frames.get_animation_speed("jump")
		_animated_sprite.speed_scale = base / duration
	else:
		_animated_sprite.speed_scale = 1.0


func set_seated(seated: bool, offset: float) -> void:
	if seated:
		_animated_sprite.position = _base_sprite_pos + Vector2(0, -offset)
	else:
		_animated_sprite.position = _base_sprite_pos


func set_sit_call_offset(enabled: bool, offset: float) -> void:
	if enabled:
		_animated_sprite.position = _base_sprite_pos + Vector2(0, -offset)
	else:
		_animated_sprite.position = _base_sprite_pos


func set_sit_book_offset(enabled: bool, offset: float) -> void:
	if enabled:
		_animated_sprite.position = _base_sprite_pos + Vector2(0, -offset)
	else:
		_animated_sprite.position = _base_sprite_pos


func set_scared_offset(enabled: bool, offset: float) -> void:
	if enabled:
		_animated_sprite.position = _base_sprite_pos + Vector2(0, -offset)
	else:
		_animated_sprite.position = _base_sprite_pos
