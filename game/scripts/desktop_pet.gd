extends Node2D

enum State { REST, WALK, SIT, GAMING, DRAG, FALLING }

@export var walk_speed := 60.0
@export_range(0.2, 3.0, 0.1) var min_walk_time := 1.0
@export_range(0.5, 8.0, 0.1) var max_walk_time := 3.0
@export_range(0.5, 5.0, 0.1) var min_rest_time := 1.0
@export_range(1.0, 15.0, 0.1) var max_rest_time := 6.0
@export var gravity := 3000.0
@export_range(0.1, 1.0, 0.05) var throw_scale := 0.5
@export_range(0.0, 1.0, 0.05) var game_chance := 0.35
@export_range(1.0, 6.0, 0.1) var sit_idle_time := 3.0
@export_range(3.0, 30.0, 0.5) var min_game_time := 6.0
@export_range(5.0, 60.0, 0.5) var max_game_time := 15.0
@export_range(0.0, 40.0, 1.0) var sit_offset := 18.0
@export_range(0.0, 40.0, 1.0) var sit_sprite_raise := 18.0

var _state := State.REST
var _state_timer := 0.0
var _walk_timer := 0.0
var _direction := 1
var _position := Vector2()
var _walk_bounds := Rect2()
var _screen_bounds := Rect2()
var _grab_offset := Vector2()
var _velocity := Vector2()

@onready var _window := get_window()
@onready var _pet: Node2D = $Pet


func _ready():
	_setup_bounds()
	_center_over_taskbar()
	_state_timer = randf_range(min_rest_time, max_rest_time)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _state == State.SIT or _state == State.GAMING:
				_pet.set_seated(false, sit_sprite_raise)
			_grab_offset = Vector2(_window.position) - Vector2(DisplayServer.mouse_get_position())
			_velocity = Vector2.ZERO
			_state = State.DRAG
			_pet.surprised()
		else:
			_velocity *= throw_scale
			_state = State.FALLING


func _process(delta):
	match _state:
		State.REST:
			_state_timer -= delta
			if _state_timer <= 0.0:
				if randf() < game_chance:
					_start_sit()
				else:
					_start_walk()
		State.WALK:
			_tick_walk(delta)
		State.SIT:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.GAMING
				_state_timer = randf_range(min_game_time, max_game_time)
				_apply_seated()
				_pet.gaming()
		State.GAMING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_stop_gaming()
		State.DRAG:
			_tick_drag(delta)
		State.FALLING:
			_tick_fall(delta)


func _setup_bounds():
	var screen := _window.current_screen
	var screen_origin := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	_screen_bounds = Rect2(screen_origin, screen_size)

	_walk_bounds = Rect2(DisplayServer.screen_get_usable_rect(screen))


func _center_over_taskbar():
	var win_size := Vector2(_window.size)
	var bounds := _walk_bounds
	_position = Vector2(
		bounds.position.x + (bounds.size.x - win_size.x) * 0.5,
		bounds.position.y + bounds.size.y - win_size.y
	)
	_window.position = Vector2i(_position)


func _start_walk():
	_direction = 1 if randf() < 0.5 else -1
	_state = State.WALK
	_walk_timer = randf_range(min_walk_time, max_walk_time)
	_pet.walk(_direction)


func _end_walk():
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _ground_y() -> float:
	return _walk_bounds.end.y - float(_window.size.y)


func _start_sit():
	_state = State.SIT
	_state_timer = sit_idle_time
	_pet.idle()


func _apply_seated():
	_position.y = _ground_y() + sit_offset
	_window.position = Vector2i(_position)
	_pet.set_seated(true, sit_sprite_raise)


func _stop_gaming():
	_position.y = _ground_y()
	_window.position = Vector2i(_position)
	_pet.set_seated(false, sit_sprite_raise)
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _tick_walk(delta):
	_position.x += walk_speed * _direction * delta

	var win_w := float(_window.size.x)

	if _position.x <= _walk_bounds.position.x:
		_position.x = _walk_bounds.position.x
		_end_walk()
	elif _position.x + win_w >= _walk_bounds.end.x:
		_position.x = _walk_bounds.end.x - win_w
		_end_walk()
	else:
		_walk_timer -= delta
		if _walk_timer <= 0.0:
			_end_walk()

	_window.position = Vector2i(_position)


func _tick_drag(delta):
	var win_size := Vector2(_window.size)
	var target := Vector2(DisplayServer.mouse_get_position()) + _grab_offset

	target.x = clampf(target.x, _screen_bounds.position.x, _screen_bounds.end.x - win_size.x)
	target.y = clampf(target.y, _screen_bounds.position.y, _screen_bounds.end.y - win_size.y)

	var instant_velocity: Vector2 = (target - _position) / delta
	_velocity = _velocity.lerp(instant_velocity, 0.4)

	_position = target
	_window.position = Vector2i(_position)


func _tick_fall(delta):
	var win_size := Vector2(_window.size)

	_velocity.y += gravity * delta
	_position += _velocity * delta

	if _position.x < _screen_bounds.position.x:
		_position.x = _screen_bounds.position.x
		_velocity.x = 0.0
	elif _position.x + win_size.x > _screen_bounds.end.x:
		_position.x = _screen_bounds.end.x - win_size.x
		_velocity.x = 0.0

	if _position.y < _screen_bounds.position.y:
		_position.y = _screen_bounds.position.y
		_velocity.y = 0.0

	var ground_y := _walk_bounds.end.y - win_size.y

	if _position.y >= ground_y:
		_position.y = ground_y
		_velocity = Vector2.ZERO
		_window.position = Vector2i(_position)
		_state = State.REST
		_state_timer = randf_range(min_rest_time, max_rest_time)
		_pet.idle()
		return

	_window.position = Vector2i(_position)
