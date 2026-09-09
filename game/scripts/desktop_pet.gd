extends Node2D

enum State { REST, WALK, DRAG, FALLING }

@export var walk_speed := 60.0
@export_range(0.2, 3.0, 0.1) var min_walk_time := 1.0
@export_range(0.5, 8.0, 0.1) var max_walk_time := 3.0
@export_range(0.5, 5.0, 0.1) var min_rest_time := 1.0
@export_range(1.0, 15.0, 0.1) var max_rest_time := 6.0
@export var gravity := 2000.0

var _state := State.REST
var _state_timer := 0.0
var _walk_timer := 0.0
var _direction := 1
var _position := Vector2()
var _walk_bounds := Rect2()
var _screen_bounds := Rect2()
var _grab_offset := Vector2()
var _gravity_vel := 0.0

@onready var _window := get_window()
@onready var _pet: Node2D = $Pet


func _ready():
	_setup_bounds()
	_center_over_taskbar()
	_state_timer = randf_range(min_rest_time, max_rest_time)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_grab_offset = Vector2(_window.position) - Vector2(DisplayServer.mouse_get_position())
			_state = State.DRAG
			_pet.surprised()
		else:
			_state = State.FALLING
			_gravity_vel = 0.0


func _process(delta):
	match _state:
		State.REST:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_start_walk()
		State.WALK:
			_tick_walk(delta)
		State.DRAG:
			_tick_drag()
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


func _tick_drag():
	var win_size := Vector2(_window.size)
	_position = Vector2(DisplayServer.mouse_get_position()) + _grab_offset

	_position.x = clampf(_position.x, _screen_bounds.position.x, _screen_bounds.end.x - win_size.x)
	_position.y = clampf(_position.y, _screen_bounds.position.y, _screen_bounds.end.y - win_size.y)

	_window.position = Vector2i(_position)


func _tick_fall(delta):
	_gravity_vel += gravity * delta
	_position.y += _gravity_vel * delta

	var ground_y := _walk_bounds.end.y - float(_window.size.y)

	if _position.y >= ground_y:
		_position.y = ground_y
		_window.position = Vector2i(_position)
		_state = State.REST
		_state_timer = randf_range(min_rest_time, max_rest_time)
		_pet.idle()
		return

	_window.position = Vector2i(_position)
