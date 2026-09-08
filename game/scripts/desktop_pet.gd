extends Node2D

enum State { REST, WALK }

@export var walk_speed := 60.0
@export_range(0.2, 3.0, 0.1) var min_walk_time := 1.0
@export_range(0.5, 8.0, 0.1) var max_walk_time := 3.0
@export_range(0.5, 5.0, 0.1) var min_rest_time := 1.0
@export_range(1.0, 15.0, 0.1) var max_rest_time := 6.0

var _state := State.REST
var _state_timer := 0.0
var _walk_timer := 0.0
var _direction := 1
var _position := Vector2()
var _walk_bounds := Rect2()

@onready var _window := get_window()
@onready var _pet: Node2D = $Pet


func _ready():
	_center_over_taskbar()
	_state_timer = randf_range(min_rest_time, max_rest_time)


func _process(delta):
	match _state:
		State.REST:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_start_walk()
		State.WALK:
			_tick_walk(delta)


func _center_over_taskbar():
	var usable := DisplayServer.screen_get_usable_rect(_window.current_screen)
	var win_size := _window.size

	# Región (en coordenadas de pantalla) donde la ventana puede caminar.
	_walk_bounds = Rect2(usable)

	# Pies de la ventana sobre el borde superior de la barra de tareas.
	_position = Vector2(
		usable.position.x + (usable.size.x - win_size.x) * 0.5,
		usable.position.y + usable.size.y - win_size.y
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