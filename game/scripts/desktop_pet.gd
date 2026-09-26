extends Node2D

const MausTexture := preload("res://sprites/maus/idle.png")
const ScareStream := preload("res://sounds/elly/scare.ogg")
const GrabStream := preload("res://sounds/elly/snd_grab.ogg")
const TicTacToe := preload("res://scripts/tictactoe.gd")
const Pong := preload("res://scripts/pong.gd")
const MENU_TICTACTOE := 300
const MENU_PONG := 301
const MENU_SHUTDOWN := 302
const MENU_MUTE := 303
const MENU_WINDOW_STANDING := 304
const MENU_WINDOW_HOP := 305
const MAUS_SIZE := Vector2(35, 12)
const SIZE_SCALES := [1.0, 1.5, 2.0, 2.5, 3.0]
const SIZE_LABELS := ["x0.5", "x1.0", "x1.5", "x2.0", "x2.5"]
const SIZE_OPT_IDS := [98, 100, 101, 102, 103]
const MAX_FALL_SPEED := 1600.0
const JUMP_MIN_DIST := 24.0
const JUMP_MAX_UP := 260.0
const JUMP_MAX_DROP := 600.0
const JUMP_MIN_T := 0.35
const JUMP_MAX_T := 1.1
const JUMP_SPEED_REF := 400.0
const JUMP_MAX_DIST := JUMP_SPEED_REF * JUMP_MAX_T
const JUMP_CLEAR := 36.0
const TOPMOST_REASSERT_INTERVAL := 0.25
const MAUS_FLEE_TIME := 5.0
const MAUS_CHASE_WAIT := 1.0
const MAUS_CATCH_CLOSER := 35.0
const MAUS_CATCH_CLOSER_LEFT := 60.0

enum State { REST, WALK, SIT, GAMING, WATCH, SCARED, JUMP, DRAG, FALLING, LAND, SIT_CALL, SIT_CALL_END, SIT_BOOK, MAUS_CHASE, BOOK }

enum MausPhase { WALK1, WALK2_AWAY, WALK3_RETURN, CATCH, CATCH2_AWAY, RETURN_HOME }

enum BookPhase { LEAVE, HIDDEN, RETURN, READING, END_LEAVE, END_HIDDEN, END_RETURN }

enum BookAction { IDLE, WALK, SIT }

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
@export_range(0.0, 1.0, 0.05) var maus_chance := 0.3
@export_range(5.0, 120.0, 1.0) var maus_chase_delay := 30.0
@export_range(0.2, 3.0, 0.1) var watch_time := 0.8
@export_range(0.0, 40.0, 1.0) var scared_offset := 6.0
@export_range(0.0, 1.0, 0.05) var platform_jump_chance := 0.35
@export_range(0.0, 1.0, 0.05) var sit_call_chance := 0.25
@export_range(15.0, 60.0, 1.0) var sit_call_min_time := 15.0
@export_range(15.0, 60.0, 1.0) var sit_call_max_time := 60.0
@export_range(0.0, 40.0, 1.0) var sit_call_offset := 8.0
@export_range(0.0, 1.0, 0.05) var sit_book_chance := 0.25
@export_range(5.0, 120.0, 1.0) var sit_book_min_time := 30.0
@export_range(5.0, 120.0, 1.0) var sit_book_max_time := 60.0
@export_range(0.0, 40.0, 1.0) var sit_book_offset := 10.0
@export_range(0.0, 1.0, 0.05) var book_chance := 0.2
@export_range(30.0, 300.0, 5.0) var book_min_time := 60.0
@export_range(30.0, 300.0, 5.0) var book_max_time := 180.0
@export_range(2.0, 15.0, 0.5) var book_away_time := 5.0
@export_range(0.0, 1.0, 0.05) var book_sit_chance := 0.2
@export_range(5.0, 60.0, 1.0) var book_sit_min_time := 15.0
@export_range(5.0, 60.0, 1.0) var book_sit_max_time := 30.0
@export_range(0.1, 4.0, 0.1) var scare_pitch_scale := 1.0
@export_range(-40.0, 6.0, 0.5) var scare_volume_db := 0.0
@export_range(-40.0, 6.0, 0.5) var grab_volume_db := 0.0

var _state := State.REST
var _state_timer := 0.0
var _walk_timer := 0.0
var _jump_timer := 0.0
var _direction := 1
var _position := Vector2()
var _walk_bounds := Rect2()
var _screen_bounds := Rect2()
var _grab_offset := Vector2()
var _velocity := Vector2()
var _maus: Sprite2D
var _maus_active := false
var _maus_timer := 0.0
var _maus_side := 1
var _maus_phase := MausPhase.WALK1
var _maus_phase_timer := 0.0
var _maus_flee_dir := 1
var _maus_anchor_x := 0.0
var _maus_catch_elapsed := 0.0
var _maus_catch_vanish := 0.0
var _maus_home_x := 0.0
var _maus_off_screen := false
var _maus_stretched := false
var _maus_stretch_left := 0.0
var _maus_win_w := 0.0
var _maus_saved_size := Vector2i.ZERO
var _sprite_hit_cache := {}
var _sprite_bounds_cache := {}
var _context_menu: PopupMenu
var _size_menu: PopupMenu
var _tictactoe_window: Window
var _pong_window: Window
var _base_win_size := Vector2i.ZERO
var _size_scale := 1.5
var _muted := false
var _window_standing := false
var _window_hop := false
var _feet_y := 0.0
var _platform := Rect2()
var _launch_platform := Rect2()
var _topmost_timer := 0.0
var _book_mode := false
var _book_phase := BookPhase.LEAVE
var _book_side := 1
var _book_target_x := 0.0
var _book_timer := 0.0
var _book_action := BookAction.IDLE
var _book_action_timer := 0.0
var _book_walk_timer := 0.0
var _book_walk_dir := 1
var _book_first_return := true

@onready var _window := get_window()
@onready var _pet: Node2D = $Pet
@onready var _pet_sprite: AnimatedSprite2D = _pet.get_node("AnimatedSprite2D")


func _ready():
	_setup_bounds()
	_base_win_size = _window.size
	_apply_default_scale()
	_center_over_taskbar()
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_setup_context_menu()
	_jump_timer = randf_range(2.0, 4.0)
	_pet_sprite.animation_finished.connect(_on_pet_animation_finished)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reassert_topmost()


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_open_context_menu()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _state == State.WATCH or _state == State.SCARED or _state == State.MAUS_CHASE:
				if _clicked_on_maus(event.position):
					_remove_maus()
					_cancel_maus_chase()
					_reset_to_ground()
					_state = State.REST
					_state_timer = randf_range(min_rest_time, max_rest_time)
					_pet.idle()
					return
			if not _clicked_on_pet(event.position):
				return
			if _state == State.SIT or _state == State.GAMING:
				_pet.set_seated(false, sit_sprite_raise)
			elif _state == State.SIT_CALL or _state == State.SIT_CALL_END:
				_clear_sit_call()
			elif _state == State.SIT_BOOK:
				_clear_sit_book()
			elif _state == State.BOOK:
				_cancel_book_event()
			if _state == State.WATCH or _state == State.SCARED or _state == State.MAUS_CHASE:
				_remove_maus()
				_cancel_maus_chase()
				_reset_to_ground()
			_grab_offset = Vector2(_window.position) - Vector2(DisplayServer.mouse_get_position())
			_velocity = Vector2.ZERO
			_state = State.DRAG
			_pet.surprised()
			_play_grab_sound()
		else:
			if _state == State.DRAG:
				_enter_fall(_velocity * throw_scale)


func _process(delta):
	_topmost_timer += delta
	if _topmost_timer >= TOPMOST_REASSERT_INTERVAL:
		_topmost_timer = 0.0
		_reassert_topmost()
	if _window and _window.mode == Window.MODE_MINIMIZED:
		_window.mode = Window.MODE_WINDOWED
		_reassert_topmost()
	if _state != State.DRAG and _state != State.FALLING and _state != State.JUMP and _state != State.MAUS_CHASE:
		_validate_platform()
	match _state:
		State.REST:
			_state_timer -= delta
			if _state_timer <= 0.0:
				if randf() < platform_jump_chance and _try_jump_to_platform(0):
					return
				if randf() < maus_chance and not _is_on_window():
					_start_maus_event()
				elif randf() < sit_call_chance:
					_start_sit_call()
				elif randf() < sit_book_chance:
					_start_sit_book()
				elif randf() < book_chance:
					_start_book_event()
				elif randf() < game_chance:
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
		State.WATCH:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_enter_scared()
			_tick_maus_wait(delta)
		State.SCARED:
			_tick_maus_wait(delta)
		State.MAUS_CHASE:
			_tick_maus_chase(delta)
		State.JUMP:
			_tick_jump(delta)
		State.SIT_CALL:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.SIT_CALL_END
				_state_timer = _pet.animation_duration(&"sit_call_end") + 0.5
				_pet.sit_call_end()
		State.SIT_CALL_END:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_end_sit_call()
		State.SIT_BOOK:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_end_sit_book()
		State.BOOK:
			_tick_book(delta)
		State.DRAG:
			_tick_drag(delta)
		State.FALLING:
			_tick_fall(delta)
		State.LAND:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_end_land()


func _setup_bounds():
	var screen := _window.current_screen
	var screen_origin := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	_screen_bounds = Rect2(screen_origin, screen_size)

	_walk_bounds = Rect2(DisplayServer.screen_get_usable_rect(screen))


func _center_over_taskbar():
	var win_size := Vector2(_window.size)
	_feet_y = _walk_bounds.end.y
	_position = Vector2(
		_walk_bounds.position.x + (_walk_bounds.size.x - win_size.x) * 0.5,
		_feet_y - win_size.y
	)
	_window.position = Vector2i(_position)


func _reassert_topmost() -> void:
	if _window == null:
		return
	if _context_menu and _context_menu.visible:
		if _window.always_on_top:
			_window.always_on_top = false
		return
	if _is_tictactoe_open() or _is_pong_open():
		return
	_window.always_on_top = true


func _setup_context_menu():
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Comer")
	var play_menu := PopupMenu.new()
	play_menu.name = "Juegos"
	play_menu.add_item("Tic Tac Toe", MENU_TICTACTOE)
	play_menu.add_item("Pong", MENU_PONG)
	play_menu.id_pressed.connect(_on_play_menu_item)
	_context_menu.add_child(play_menu)
	_context_menu.add_submenu_item("Play", play_menu.name)
	for action in ["Limpiar", "Dormir"]:
		_context_menu.add_item(action)
	_size_menu = PopupMenu.new()
	_size_menu.name = "SizeMenu"
	for i in SIZE_OPT_IDS.size():
		_size_menu.add_check_item(SIZE_LABELS[i], SIZE_OPT_IDS[i])
		_size_menu.set_item_as_radio_checkable(i, true)
	_size_menu.id_pressed.connect(_on_menu_item)
	_context_menu.add_child(_size_menu)
	_context_menu.add_submenu_item("Size", _size_menu.name)
	_context_menu.add_check_item("Mute", MENU_MUTE)
	_context_menu.add_check_item("Window Standing", MENU_WINDOW_STANDING)
	_context_menu.add_check_item("Window Hop", MENU_WINDOW_HOP)
	_context_menu.add_item("Shutdown", MENU_SHUTDOWN)
	_context_menu.add_item("Exit")
	_context_menu.id_pressed.connect(_on_menu_item)
	_update_size_checkmarks()
	_update_window_checkmarks()
	get_tree().root.add_child.call_deferred(_context_menu)


func _open_context_menu():
	if _state == State.DRAG or _state == State.FALLING:
		return
	if _context_menu.visible:
		return
	_context_menu.position = Vector2i(DisplayServer.mouse_get_position())
	_context_menu.popup()


func _on_menu_item(id: int) -> void:
	if id == MENU_SHUTDOWN:
		get_tree().quit()
		return
	var idx := SIZE_OPT_IDS.find(id)
	if idx >= 0:
		_set_pet_scale(SIZE_SCALES[idx])
		return
	if id == MENU_MUTE:
		_muted = not _muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), _muted)
		_context_menu.set_item_checked(_context_menu.get_item_index(MENU_MUTE), _muted)
		return
	if id == MENU_WINDOW_STANDING:
		_set_window_standing(not _window_standing)
		return
	if id == MENU_WINDOW_HOP:
		_set_window_hop(not _window_hop)
		return
	print("[MENU] placeholder presionado: ", _context_menu.get_item_text(id))


func _set_window_standing(enabled: bool) -> void:
	if _window_standing != enabled:
		_window_standing = enabled
		if not _window_standing:
			_window_hop = false
			if _is_on_window():
				_reset_to_ground()
	_update_window_checkmarks()


func _set_window_hop(enabled: bool) -> void:
	if enabled and not _window_standing:
		enabled = false
	if _window_hop != enabled:
		_window_hop = enabled
		if not _window_hop and _is_on_window():
			_reset_to_ground()
	_update_window_checkmarks()


func _update_window_checkmarks() -> void:
	if _context_menu == null:
		return
	var standing_idx := _context_menu.get_item_index(MENU_WINDOW_STANDING)
	var hop_idx := _context_menu.get_item_index(MENU_WINDOW_HOP)
	if standing_idx >= 0:
		_context_menu.set_item_checked(standing_idx, _window_standing)
	if hop_idx >= 0:
		_context_menu.set_item_checked(hop_idx, _window_hop)
		_context_menu.set_item_disabled(hop_idx, not _window_standing)


func _on_play_menu_item(id: int) -> void:
	if id == MENU_TICTACTOE:
		_open_tictactoe()
	elif id == MENU_PONG:
		_open_pong()


func _open_tictactoe() -> void:
	_cancel_book_event()
	_window.always_on_top = false
	if is_instance_valid(_tictactoe_window):
		_tictactoe_window.show()
		_tictactoe_window.grab_focus()
		_start_tictactoe_gaming()
		return
	var game: Window = TicTacToe.new()
	_tictactoe_window = game
	get_tree().root.add_child(game)
	var center := Vector2i(_window.position) + Vector2i(_window.size) / 2
	game.position = center - Vector2i(game.size) / 2
	game.close_requested.connect(_on_tictactoe_close_requested)
	game.tree_exited.connect(_on_tictactoe_exited)
	game.grab_focus()
	_start_tictactoe_gaming()


func _is_tictactoe_open() -> bool:
	return is_instance_valid(_tictactoe_window) and _tictactoe_window.visible


func _start_tictactoe_gaming() -> void:
	_state = State.GAMING
	_state_timer = INF
	_apply_seated()
	_pet.gaming()


func _stop_tictactoe_gaming() -> void:
	if _state == State.GAMING:
		_stop_gaming()


func _on_tictactoe_close_requested() -> void:
	_tictactoe_window.hide()
	_window.always_on_top = true
	_stop_tictactoe_gaming()


func _on_tictactoe_exited() -> void:
	_window.always_on_top = true
	_stop_tictactoe_gaming()
	_tictactoe_window = null


func _open_pong() -> void:
	_cancel_book_event()
	_window.always_on_top = false
	if is_instance_valid(_pong_window):
		_pong_window.show()
		_pong_window.grab_focus()
		_start_pong_gaming()
		return
	var game: Window = Pong.new()
	_pong_window = game
	get_tree().root.add_child(game)
	var center := Vector2i(_window.position) + Vector2i(_window.size) / 2
	game.position = center - Vector2i(game.size) / 2
	game.close_requested.connect(_on_pong_close_requested)
	game.tree_exited.connect(_on_pong_exited)
	game.grab_focus()
	_start_pong_gaming()


func _is_pong_open() -> bool:
	return is_instance_valid(_pong_window) and _pong_window.visible


func _start_pong_gaming() -> void:
	_state = State.GAMING
	_state_timer = INF
	_apply_seated()
	_pet.gaming()


func _stop_pong_gaming() -> void:
	if _state == State.GAMING:
		_stop_gaming()


func _on_pong_close_requested() -> void:
	_pong_window.hide()
	_window.always_on_top = true
	_stop_pong_gaming()


func _on_pong_exited() -> void:
	_window.always_on_top = true
	_stop_pong_gaming()
	_pong_window = null


func _apply_default_scale() -> void:
	if is_equal_approx(_size_scale, 1.0):
		return
	_pet.scale = Vector2.ONE * _size_scale
	_window.size = Vector2i(round(Vector2(_base_win_size) * _size_scale))


func _set_pet_scale(scale: float) -> void:
	if scale <= 0.0 or is_equal_approx(scale, _size_scale):
		return
	var anchor_x := _position.x + _base_win_size.x * 0.5
	_window.size = Vector2i(round(Vector2(_base_win_size) * scale))
	_pet.scale = Vector2.ONE * scale
	_size_scale = scale
	_position.x = anchor_x - _window.size.x * 0.5
	var offset := sit_offset * _size_scale if (_state == State.SIT or _state == State.GAMING or _state == State.SIT_CALL or _state == State.SIT_CALL_END or _state == State.SIT_BOOK) else 0.0
	_position.y = maxf(_feet_y - float(_window.size.y) + offset, _screen_bounds.position.y)
	_window.position = Vector2i(round(_position))
	_update_size_checkmarks()


func _update_size_checkmarks() -> void:
	for i in SIZE_OPT_IDS.size():
		_size_menu.set_item_checked(
			_size_menu.get_item_index(SIZE_OPT_IDS[i]),
			is_equal_approx(_size_scale, SIZE_SCALES[i])
		)


func _start_walk():
	_direction = _preferred_walk_direction(_walk_range())
	_state = State.WALK
	_walk_timer = randf_range(min_walk_time, max_walk_time)
	_pet.walk(_direction)


func _preferred_walk_direction(rng: Vector2) -> int:
	var lo := minf(rng.x, rng.y)
	var hi := maxf(rng.x, rng.y)
	var margin := maxf(8.0, (hi - lo) * 0.05)
	if _position.x - lo <= margin:
		return 1
	if hi - _position.x <= margin:
		return -1
	return 1 if randf() < 0.5 else -1


func _end_walk():
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _is_on_window() -> bool:
	return _platform.size.x > 0.0 or _platform.size.y > 0.0


func _walk_range() -> Vector2:
	var vb := _visual_bounds_in_window()
	if _is_on_window():
		return Vector2(_platform.position.x - vb.position.x, _platform.end.x - vb.end.x)
	return Vector2(_walk_bounds.position.x - vb.position.x, _walk_bounds.end.x - vb.end.x)


func _start_sit():
	_state = State.SIT
	_state_timer = sit_idle_time
	_pet.idle()


func _apply_seated():
	_position.y = _feet_y - float(_window.size.y) + sit_offset * _size_scale
	_window.position = Vector2i(_position)
	_pet.set_seated(true, sit_sprite_raise)


func _stop_gaming():
	_position.y = _feet_y - float(_window.size.y)
	_window.position = Vector2i(_position)
	_pet.set_seated(false, sit_sprite_raise)
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _start_sit_call():
	_state = State.SIT_CALL
	_state_timer = randf_range(
		minf(sit_call_min_time, sit_call_max_time),
		maxf(sit_call_min_time, sit_call_max_time)
	)
	_apply_sit_call()
	_pet.sit_call()


func _apply_sit_call():
	_position.y = _feet_y - float(_window.size.y) + sit_offset * _size_scale
	_window.position = Vector2i(_position)
	_pet.set_sit_call_offset(true, sit_call_offset)


func _clear_sit_call():
	_position.y = _feet_y - float(_window.size.y)
	_window.position = Vector2i(_position)
	_pet.set_sit_call_offset(false, sit_call_offset)


func _end_sit_call():
	_clear_sit_call()
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _start_sit_book():
	_state = State.SIT_BOOK
	_state_timer = randf_range(
		minf(sit_book_min_time, sit_book_max_time),
		maxf(sit_book_min_time, sit_book_max_time)
	)
	_apply_sit_book()
	_pet.sit_book()


func _apply_sit_book():
	_position.y = _feet_y - float(_window.size.y) + sit_offset * _size_scale
	_window.position = Vector2i(_position)
	_pet.set_sit_book_offset(true, sit_book_offset)


func _clear_sit_book():
	_position.y = _feet_y - float(_window.size.y)
	_window.position = Vector2i(_position)
	_pet.set_sit_book_offset(false, sit_book_offset)


func _end_sit_book():
	_clear_sit_book()
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _start_book_event() -> void:
	_reset_to_ground()
	_book_mode = false
	_book_first_return = true
	_book_phase = BookPhase.LEAVE
	_book_side = _book_exit_side()
	_book_target_x = _book_offscreen_x(_book_side)
	_book_action = BookAction.IDLE
	_state = State.BOOK
	_pet.walk(_book_side)


func _tick_book(delta: float) -> void:
	match _book_phase:
		BookPhase.LEAVE:
			if _book_step_toward(_book_target_x, delta):
				_book_phase = BookPhase.HIDDEN
				_book_timer = book_away_time
		BookPhase.HIDDEN:
			_book_timer -= delta
			if _book_timer <= 0.0:
				_begin_book_return()
		BookPhase.RETURN:
			if _book_step_toward(_book_target_x, delta):
				_begin_book_reading()
		BookPhase.READING:
			_tick_book_reading(delta)
		BookPhase.END_LEAVE:
			if _book_step_toward(_book_target_x, delta):
				_book_phase = BookPhase.END_HIDDEN
				_book_timer = book_away_time
		BookPhase.END_HIDDEN:
			_book_timer -= delta
			if _book_timer <= 0.0:
				_begin_book_return()
		BookPhase.END_RETURN:
			if _book_step_toward(_book_target_x, delta):
				_finish_book_event()


func _book_exit_side() -> int:
	var left_dist := _position.x - _screen_bounds.position.x
	var right_dist := _screen_bounds.end.x - (_position.x + float(_window.size.x))
	return -1 if left_dist < right_dist else 1


func _book_offscreen_x(dir: int) -> float:
	if dir > 0:
		return _screen_bounds.end.x + 8.0
	return _screen_bounds.position.x - float(_window.size.x) - 8.0


func _book_return_x() -> float:
	var rng := _walk_range()
	return randf_range(minf(rng.x, rng.y), maxf(rng.x, rng.y))


func _book_step_toward(target_x: float, delta: float) -> bool:
	var dx := target_x - _position.x
	if is_zero_approx(dx):
		return true
	var step := minf(absf(dx), walk_speed * delta)
	_position.x += signf(dx) * step
	_window.position = Vector2i(round(_position))
	return is_equal_approx(_position.x, target_x)


func _begin_book_return() -> void:
	_book_side = -_book_side
	_book_target_x = _book_return_x()
	if _book_first_return:
		_book_phase = BookPhase.RETURN
		_book_mode = true
		_pet.walk_book(_book_side)
	else:
		_book_phase = BookPhase.END_RETURN
		_book_mode = false
		_pet.walk(_book_side)


func _begin_book_reading() -> void:
	_book_phase = BookPhase.READING
	_book_timer = randf_range(
		minf(book_min_time, book_max_time),
		maxf(book_min_time, book_max_time)
	)
	_book_action = BookAction.IDLE
	_book_action_timer = 0.0
	_pet.idle_book()


func _resume_book_reading() -> void:
	_book_phase = BookPhase.READING
	_book_action = BookAction.IDLE
	_book_action_timer = 0.0
	_pet.idle_book()


func _tick_book_reading(delta: float) -> void:
	_book_timer -= delta
	if _book_timer <= 0.0:
		_begin_book_end_leave()
		return
	match _book_action:
		BookAction.IDLE:
			_book_action_timer -= delta
			if _book_action_timer <= 0.0:
				if randf() < book_sit_chance:
					_begin_book_sit()
				else:
					_begin_book_walk()
		BookAction.WALK:
			_tick_book_walk(delta)
		BookAction.SIT:
			_book_action_timer -= delta
			if _book_action_timer <= 0.0:
				_clear_sit_book()
				_begin_book_idle()


func _begin_book_idle() -> void:
	_book_action = BookAction.IDLE
	_book_action_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle_book()


func _begin_book_walk() -> void:
	_book_action = BookAction.WALK
	_book_walk_timer = randf_range(min_walk_time, max_walk_time)
	_book_walk_dir = _preferred_walk_direction(_walk_range())
	_pet.walk_book(_book_walk_dir)


func _tick_book_walk(delta: float) -> void:
	var new_x: float = _position.x + walk_speed * _book_walk_dir * delta
	var rng := _walk_range()
	var clamped_x := clampf(new_x, minf(rng.x, rng.y), maxf(rng.x, rng.y))
	var hit_edge := not is_equal_approx(clamped_x, new_x)
	_position.x = clamped_x
	_window.position = Vector2i(round(_position))
	if hit_edge:
		_book_walk_dir *= -1
		_pet.walk_book(_book_walk_dir)
	_book_walk_timer -= delta
	if _book_walk_timer <= 0.0:
		_begin_book_idle()


func _begin_book_sit() -> void:
	_book_action = BookAction.SIT
	_apply_sit_book()
	_pet.sit_book()
	_book_action_timer = randf_range(
		minf(book_sit_min_time, book_sit_max_time),
		maxf(book_sit_min_time, book_sit_max_time)
	)


func _begin_book_end_leave() -> void:
	if _book_action == BookAction.SIT:
		_clear_sit_book()
	_book_first_return = false
	_book_phase = BookPhase.END_LEAVE
	_book_side = _book_exit_side()
	_book_target_x = _book_offscreen_x(_book_side)
	_pet.walk_book(_book_side)


func _finish_book_event() -> void:
	_book_mode = false
	_book_first_return = true
	_book_phase = BookPhase.LEAVE
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _cancel_book_event() -> void:
	if _state != State.BOOK and not _book_mode:
		return
	_clear_sit_book()
	_book_mode = false
	_book_first_return = true
	_book_phase = BookPhase.LEAVE


func _on_pet_animation_finished() -> void:
	if _state == State.SIT_CALL_END:
		_end_sit_call()
	elif _state == State.LAND:
		_end_land()


func _start_maus_event():
	var side := _choose_maus_side()
	_maus_side = side
	_pet.face(-side)
	_spawn_maus(side)
	_maus_active = true
	_maus_timer = 0.0
	_state = State.WATCH
	_state_timer = watch_time
	_pet.idle()


func _choose_maus_side() -> int:
	var maus_size := MAUS_SIZE * _size_scale
	var win_x := float(_window.size.x)
	var best_side := -1
	var best_visible := -1.0
	for side in [-1, 1]:
		var maus_x := 0.0 if side < 0 else win_x - maus_size.x
		var global_x := float(_window.position.x) + maus_x
		var lo := maxf(global_x, _screen_bounds.position.x)
		var hi := minf(global_x + maus_size.x, _screen_bounds.end.x)
		var visible := maxf(0.0, hi - lo)
		if visible > best_visible:
			best_visible = visible
			best_side = side
		elif is_equal_approx(visible, best_visible) and randf() < 0.5:
			best_side = side
	return best_side


func _spawn_maus(side: int):
	_remove_maus()
	_maus_side = side
	var maus := Sprite2D.new()
	maus.texture = MausTexture
	maus.centered = false
	maus.scale = Vector2.ONE * _size_scale
	var maus_size := MAUS_SIZE * _size_scale
	var maus_x := 0.0 if side < 0 else float(_window.size.x - int(maus_size.x))
	var maus_y := float(_window.size.y - int(maus_size.y))
	maus.position = Vector2(maus_x, maus_y)
	add_child(maus)
	_maus = maus


func _enter_scared():
	_state = State.SCARED
	_pet.set_scared_offset(true, scared_offset)
	_pet.scared()
	_play_scare_sound()


func _play_scare_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = ScareStream
	player.pitch_scale = scare_pitch_scale
	player.volume_db = scare_volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_grab_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = GrabStream
	player.volume_db = grab_volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _remove_maus():
	_maus_active = false
	_maus_timer = 0.0
	if _maus and is_instance_valid(_maus):
		_maus.queue_free()
	_maus = null


func _tick_maus_wait(delta: float) -> void:
	if not _maus_active:
		return
	_maus_timer += delta
	if _maus_timer >= maus_chase_delay:
		_start_maus_chase()


func _start_maus_chase() -> void:
	_maus_active = false
	_maus_timer = 0.0
	_maus_flee_dir = -_maus_side
	_maus_anchor_x = _position.x
	_begin_maus_stretch()
	_maus_off_screen = false
	_pet.set_scared_offset(false, scared_offset)
	_state = State.MAUS_CHASE
	_maus_phase = MausPhase.WALK1
	_maus_phase_timer = _pet.animation_duration(&"maus_walk1") + MAUS_CHASE_WAIT
	_pet.maus_walk1()


func _tick_maus_chase(delta: float) -> void:
	match _maus_phase:
		MausPhase.WALK1:
			_maus_phase_timer -= delta
			if _maus_phase_timer <= 0.0:
				_begin_maus_flee()
		MausPhase.WALK2_AWAY:
			_tick_maus_leg(delta, _maus_exit_x(), _begin_maus_return)
		MausPhase.WALK3_RETURN:
			if _step_toward_x(_maus_catch_x(), walk_speed * delta):
				_begin_maus_catch()
		MausPhase.CATCH:
			_maus_catch_elapsed += delta
			if _maus and is_instance_valid(_maus) and _maus_catch_elapsed >= _maus_catch_vanish:
				_remove_maus()
			_maus_phase_timer -= delta
			if _maus_phase_timer <= 0.0:
				_begin_maus_catch2()
		MausPhase.CATCH2_AWAY:
			_tick_maus_leg(delta, _maus_exit_x(), _begin_maus_return_home)
		MausPhase.RETURN_HOME:
			if _step_toward_x(_maus_home_x, walk_speed * delta):
				_end_maus_chase()


func _tick_maus_leg(delta: float, target_x: float, on_done: Callable) -> void:
	if _maus_off_screen:
		_maus_phase_timer -= delta
	else:
		if _step_toward_x(target_x, walk_speed * delta):
			_maus_off_screen = true
			_maus_phase_timer = MAUS_FLEE_TIME
	if _maus_off_screen and _maus_phase_timer <= 0.0:
		on_done.call()


func _begin_maus_flee() -> void:
	_maus_phase = MausPhase.WALK2_AWAY
	_maus_off_screen = false
	_pet.maus_walk2(_maus_flee_dir)


func _begin_maus_return() -> void:
	_maus_phase = MausPhase.WALK3_RETURN
	_pet.maus_walk3(-_maus_flee_dir)


func _begin_maus_catch() -> void:
	_maus_phase = MausPhase.CATCH
	_maus_catch_elapsed = 0.0
	_maus_catch_vanish = _pet.last_frame_start(&"maus_catch")
	_maus_phase_timer = _pet.animation_duration(&"maus_catch") + MAUS_CHASE_WAIT
	_pet.maus_catch(-_maus_flee_dir)


func _maus_catch_x() -> float:
	var closer := MAUS_CATCH_CLOSER if _maus_side > 0 else MAUS_CATCH_CLOSER_LEFT
	return _maus_anchor_x + float(_maus_side) * closer


func _begin_maus_catch2() -> void:
	_remove_maus()
	_maus_phase = MausPhase.CATCH2_AWAY
	_maus_off_screen = false
	_pet.maus_catch2(_maus_flee_dir)


func _begin_maus_return_home() -> void:
	if _is_on_window():
		_feet_y = _walk_bounds.end.y
		_platform = Rect2()
	_position.y = _feet_y - float(_window.size.y)
	_apply_maus_pet_visual()
	_maus_phase = MausPhase.RETURN_HOME
	var win_w := _maus_win_w if _maus_stretched else float(_window.size.x)
	_maus_home_x = _walk_bounds.position.x + (_walk_bounds.size.x - win_w) * 0.5
	var dir := 1 if _maus_home_x >= _position.x else -1
	_pet.walk(dir)


func _end_maus_chase() -> void:
	_maus_active = false
	_maus_timer = 0.0
	_end_maus_stretch()
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)
	_pet.idle()


func _begin_maus_stretch() -> void:
	_maus_saved_size = _window.size
	_maus_win_w = float(_window.size.x)
	var extend := _maus_win_w + 16.0
	_maus_stretch_left = _screen_bounds.position.x - extend
	_window.size.x = maxi(1, int(round(_screen_bounds.size.x + 2.0 * extend)))
	if _maus and is_instance_valid(_maus):
		_maus.position.x = float(_window.position.x) + _maus.position.x - _maus_stretch_left
	_maus_stretched = true
	_apply_maus_pet_visual()


func _end_maus_stretch() -> void:
	if not _maus_stretched:
		return
	_maus_stretched = false
	_window.size = _maus_saved_size
	_pet.position.x = 0.0
	_window.position = Vector2i(round(_position))


func _apply_maus_pet_visual() -> void:
	if _maus_stretched:
		_pet.position.x = _position.x - _maus_stretch_left
		_window.position = Vector2i(round(_maus_stretch_left), round(_position.y))
	else:
		_pet.position.x = 0.0
		_window.position = Vector2i(round(_position))


func _maus_exit_x() -> float:
	var win_w := _maus_win_w if _maus_stretched else float(_window.size.x)
	if _maus_flee_dir < 0:
		return _screen_bounds.position.x - win_w - 8.0
	return _screen_bounds.end.x + 8.0


func _step_toward_x(target_x: float, max_step: float) -> bool:
	var dx := target_x - _position.x
	if is_zero_approx(dx):
		return true
	var step := minf(absf(dx), max_step)
	_position.x += signf(dx) * step
	_apply_maus_pet_visual()
	return is_equal_approx(_position.x, target_x)


func _cancel_maus_chase() -> void:
	if _state == State.MAUS_CHASE:
		_state = State.REST
		_state_timer = randf_range(min_rest_time, max_rest_time)
	_end_maus_stretch()
	_pet.set_scared_offset(false, scared_offset)


func _clicked_on_maus(pos: Vector2) -> bool:
	if _maus == null or not is_instance_valid(_maus):
		return false
	var rect := _maus.get_rect()
	var origin := _maus.to_global(rect.position)
	var end := _maus.to_global(rect.end)
	return Rect2(origin, end - origin).has_point(pos)


func _clicked_on_pet(pos: Vector2) -> bool:
	var sprite: AnimatedSprite2D = _pet.get_node("AnimatedSprite2D")
	if sprite == null or sprite.sprite_frames == null:
		return true
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return true
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return true
	var half := tex_size * 0.5
	var origin: Vector2
	var end: Vector2
	if sprite.centered:
		origin = sprite.to_global(-half)
		end = sprite.to_global(half)
	else:
		origin = sprite.to_global(Vector2.ZERO)
		end = sprite.to_global(tex_size)
	if not Rect2(origin, end - origin).has_point(pos):
		return false
	var img: Image
	if _sprite_hit_cache.has(tex):
		img = _sprite_hit_cache[tex]
	else:
		img = tex.get_image()
		if img == null:
			return true
		_sprite_hit_cache[tex] = img
	var local := sprite.to_local(pos)
	if sprite.centered:
		local += half
	var u := clampi(int(local.x / tex_size.x * img.get_width()), 0, img.get_width() - 1)
	if sprite.flip_h:
		u = img.get_width() - 1 - u
	var v := clampi(int(local.y / tex_size.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(u, v).a > 0.05


func _reset_to_ground():
	_feet_y = _walk_bounds.end.y
	_platform = Rect2()
	_position.y = _feet_y - float(_window.size.y)
	_window.position = Vector2i(_position)
	_pet.set_scared_offset(false, scared_offset)


func _sprite_alpha_bounds(tex: Texture2D) -> Rect2i:
	if _sprite_bounds_cache.has(tex):
		return _sprite_bounds_cache[tex]
	var img: Image
	if _sprite_hit_cache.has(tex):
		img = _sprite_hit_cache[tex]
	else:
		img = tex.get_image()
		if img == null:
			return Rect2i()
		_sprite_hit_cache[tex] = img
	var iw := img.get_width()
	var ih := img.get_height()
	var min_u := iw
	var min_v := ih
	var max_u := -1
	var max_v := -1
	for i in iw:
		for j in ih:
			if img.get_pixel(i, j).a > 0.05:
				min_u = mini(min_u, i)
				min_v = mini(min_v, j)
				max_u = maxi(max_u, i)
				max_v = maxi(max_v, j)
	var ab := Rect2i()
	if max_u >= 0 and max_v >= 0:
		ab = Rect2i(min_u, min_v, max_u - min_u + 1, max_v - min_v + 1)
	_sprite_bounds_cache[tex] = ab
	return ab


func _visual_bounds_in_window() -> Rect2:
	var sprite: AnimatedSprite2D = _pet.get_node("AnimatedSprite2D")
	if sprite == null or sprite.sprite_frames == null:
		return Rect2(Vector2.ZERO, Vector2(_window.size))
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return Rect2(Vector2.ZERO, Vector2(_window.size))
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(_window.size))
	var ab := _sprite_alpha_bounds(tex)
	if ab.size.x <= 0 or ab.size.y <= 0:
		return Rect2(Vector2.ZERO, Vector2(_window.size))
	var sc := Vector2(_pet.scale)
	var size := Vector2(ab.size) * sc
	if sprite.centered:
		var ab_center := Vector2(ab.position) + Vector2(ab.size) * 0.5
		var offset := (ab_center - tex_size * 0.5) * sc
		if sprite.flip_h:
			offset.x = -offset.x
		return Rect2(sprite.position * sc + offset - size * 0.5, size)
	var origin: Vector2 = sprite.position * sc + Vector2(ab.position) * sc
	if sprite.flip_h:
		origin.x = sprite.position.x * sc.x + (tex_size.x - ab.position.x - ab.size.x) * sc.x
	return Rect2(origin, size)


func _clamp_window_to_screen(pos: Vector2) -> Vector2:
	var win := Vector2(_window.size)
	var vb := _visual_bounds_in_window()
	if vb.size.x <= 0.0 or vb.size.y <= 0.0 \
			or vb.position.x < -0.001 or vb.position.y < -0.001 \
			or vb.end.x > win.x + 0.001 or vb.end.y > win.y + 0.001:
		return pos.clamp(_screen_bounds.position, _screen_bounds.end - win)
	return Vector2(
		clampf(pos.x, _screen_bounds.position.x - vb.position.x, _screen_bounds.end.x - vb.end.x),
		clampf(pos.y, _screen_bounds.position.y - vb.position.y, _screen_bounds.end.y - vb.end.y)
	)


func _clamp_window_to_walk(pos: Vector2) -> Vector2:
	var win := Vector2(_window.size)
	var vb := _visual_bounds_in_window()
	if vb.size.x <= 0.0 or vb.size.y <= 0.0 \
			or vb.position.x < -0.001 or vb.position.y < -0.001 \
			or vb.end.x > win.x + 0.001 or vb.end.y > win.y + 0.001:
		return Vector2(
			clampf(pos.x, _walk_bounds.position.x, maxf(_walk_bounds.end.x - win.x, _walk_bounds.position.x)),
			clampf(pos.y, _walk_bounds.position.y, maxf(_walk_bounds.end.y - win.y, _walk_bounds.position.y))
		)
	return Vector2(
		clampf(pos.x, _walk_bounds.position.x - vb.position.x, _walk_bounds.end.x - vb.end.x),
		clampf(pos.y, _walk_bounds.position.y - vb.position.y, _walk_bounds.end.y - vb.end.y)
	)


func _tick_walk(delta):
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(2.0, 4.0)
		if _try_jump_to_platform(_direction):
			return
	var new_x: float = _position.x + walk_speed * _direction * delta
	var rng := _walk_range()
	var clamped_x := clampf(new_x, minf(rng.x, rng.y), maxf(rng.x, rng.y))
	var hit_edge := not is_equal_approx(clamped_x, new_x)
	_position.x = clamped_x
	if hit_edge:
		if not _is_on_window():
			_end_walk()
			_window.position = Vector2i(_position)
			return
		if _try_jump_to_platform(_direction):
			return
		_direction *= -1
		_pet.walk(_direction)
		_walk_timer -= delta
		if _walk_timer <= 0.0:
			_end_walk()
			_window.position = Vector2i(_position)
			return
		_window.position = Vector2i(_position)
		return
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		_end_walk()
		_window.position = Vector2i(_position)
		return
	_window.position = Vector2i(_position)


func _tick_drag(delta):
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_enter_fall(_velocity * throw_scale)
		return
	var target := Vector2(DisplayServer.mouse_get_position()) + _grab_offset
	target = _clamp_window_to_walk(target)

	var instant_velocity: Vector2 = (target - _position) / delta
	_velocity = _velocity.lerp(instant_velocity, 0.4)

	_position = target
	_window.position = Vector2i(_position)


func _tick_jump(delta):
	var win_size := Vector2(_window.size)
	var prev_feet := _position.y + win_size.y
	_velocity.y += gravity * delta
	_velocity.y = minf(_velocity.y, MAX_FALL_SPEED)
	_position += _velocity * delta
	var prev_pos := _position
	_position = _clamp_window_to_screen(_position)
	if absf(_position.x - prev_pos.x) > 0.001:
		_velocity.x = 0.0
	if absf(_position.y - prev_pos.y) > 0.001:
		_velocity.y = 0.0
	var landing := _find_landing(prev_feet, _position.y + win_size.y, _position.x + win_size.x * 0.5)
	if not landing.is_empty():
		_land(landing)
		return
	_window.position = Vector2i(_position)


func _tick_fall(delta):
	var win_size := Vector2(_window.size)
	var prev_feet := _position.y + win_size.y
	_velocity.y += gravity * delta
	_velocity.y = minf(_velocity.y, MAX_FALL_SPEED)
	_position += _velocity * delta
	var prev_pos := _position
	_position = _clamp_window_to_screen(_position)
	if absf(_position.x - prev_pos.x) > 0.001:
		_velocity.x = 0.0
	if absf(_position.y - prev_pos.y) > 0.001:
		_velocity.y = 0.0
	var landing := _find_landing(prev_feet, _position.y + win_size.y, _position.x + win_size.x * 0.5)
	if not landing.is_empty():
		_land(landing)
		return
	_window.position = Vector2i(_position)


func _find_landing(prev_feet: float, new_feet: float, cx: float) -> Dictionary:
	if _velocity.y <= 0.0:
		return {}
	var best_top := INF
	var best := {}
	if _window_standing:
		var win_h := float(_window.size.y)
		var screen_top := _screen_bounds.position.y
		for p in Windows.platforms:
			if p.position.y > new_feet or p.position.y < prev_feet:
				continue
			if _launch_platform.size.x > 0.0 and absf(p.position.x - _launch_platform.position.x) < 1.0 \
					and absf(p.position.y - _launch_platform.position.y) < 1.0:
				continue
			if p.end.x - p.position.x <= 1.0:
				continue
			if p.position.y - win_h < screen_top:
				continue
			if cx < p.position.x or cx > p.end.x:
				continue
			if p.position.y < best_top:
				best_top = p.position.y
				best = {"feet_y": p.position.y, "is_ground": false, "rect": p}
	var ground_line := _walk_bounds.end.y
	if new_feet >= ground_line:
		if ground_line <= best_top:
			best = {"feet_y": ground_line, "is_ground": true, "rect": Rect2()}
	return best


func _land(res: Dictionary) -> void:
	var win_size := Vector2(_window.size)
	if res.is_ground:
		_feet_y = _walk_bounds.end.y
		_platform = Rect2()
	else:
		_feet_y = res.rect.position.y
		_platform = res.rect
	_position.y = maxf(_feet_y - win_size.y, _screen_bounds.position.y)
	_velocity = Vector2.ZERO
	_launch_platform = Rect2()
	_window.position = Vector2i(round(_position))
	if _is_tictactoe_open():
		_start_tictactoe_gaming()
	elif _is_pong_open():
		_start_pong_gaming()
	elif _book_mode:
		_state = State.BOOK
		_resume_book_reading()
	elif _state == State.FALLING:
		_begin_land()
	else:
		_pet.idle()
		_state = State.REST
		_state_timer = randf_range(min_rest_time, max_rest_time)


func _begin_land() -> void:
	_state = State.LAND
	_state_timer = _pet.animation_duration(&"jump") + 0.5
	_pet.fall_land()


func _end_land() -> void:
	_pet.idle()
	_state = State.REST
	_state_timer = randf_range(min_rest_time, max_rest_time)


func _enter_fall(vel: Vector2) -> void:
	_pet.set_seated(false, sit_sprite_raise)
	_pet.set_scared_offset(false, scared_offset)
	_pet.set_sit_call_offset(false, sit_call_offset)
	_pet.set_sit_book_offset(false, sit_book_offset)
	_remove_maus()
	_platform = Rect2()
	_launch_platform = Rect2()
	_velocity = vel
	_state = State.FALLING
	_pet.fall_start()


func _validate_platform() -> void:
	if not _is_on_window():
		return
	if not _window_standing:
		_reset_to_ground()
		return
	var win := Vector2(_window.size)
	var cx := _position.x + win.x * 0.5
	for p in Windows.platforms:
		if absf(p.position.y - _platform.position.y) <= 1.0 and cx >= p.position.x and cx <= p.end.x:
			_platform = p
			return
	_enter_fall(Vector2.ZERO)


func _try_jump_to_platform(dir_hint: int) -> bool:
	if not _window_hop:
		return false
	if not Windows.active or Windows.platforms.is_empty():
		return false
	var win := Vector2(_window.size)
	var cx := _position.x + win.x * 0.5
	var feet_y := _feet_y
	var best: Rect2
	var best_cost := INF
	for p in Windows.platforms:
		if p.end.x - p.position.x < win.x + 12.0:
			continue
		if p.size.y <= 1.0:
			continue
		if p.position.y - win.y < _screen_bounds.position.y + 1.0:
			continue
		var dy := p.position.y - feet_y
		if dy < -JUMP_MAX_UP or dy > JUMP_MAX_DROP:
			continue
		var min_cx := p.position.x + win.x * 0.5
		var max_cx := p.end.x - win.x * 0.5
		if min_cx >= max_cx:
			continue
		var target_cx := clampf(cx + dir_hint * 140.0, min_cx, max_cx)
		if dir_hint == 0:
			target_cx = clampf(cx, min_cx, max_cx)
		var dx := target_cx - cx
		if absf(dx) > JUMP_MAX_DIST:
			continue
		if absf(dx) < JUMP_MIN_DIST and absf(dy) < JUMP_MIN_DIST:
			continue
		if _is_on_window() and absf(p.position.x - _platform.position.x) < 1.0 and absf(p.position.y - _platform.position.y) < 1.0:
			continue
		var cost := absf(dx) + absf(dy) * 1.2
		if cost < best_cost:
			best_cost = cost
			best = p
	if best.size.x == 0.0 and best.size.y == 0.0 and _is_on_window():
		best = _ground_jump_target(cx, feet_y, win)
	if best.size.x == 0.0 and best.size.y == 0.0:
		return false
	_start_jump(best, cx, feet_y)
	return true


func _ground_jump_target(cx: float, feet_y: float, win: Vector2) -> Rect2:
	var ground_y := _walk_bounds.end.y
	var dy := ground_y - feet_y
	if dy < -JUMP_MAX_UP or dy > JUMP_MAX_DROP:
		return Rect2()
	var min_cx := _walk_bounds.position.x + win.x * 0.5
	var max_cx := _walk_bounds.end.x - win.x * 0.5
	if min_cx >= max_cx:
		return Rect2()
	var target_cx := clampf(cx, min_cx, max_cx)
	if absf(target_cx - cx) > JUMP_MAX_DIST:
		return Rect2()
	return Rect2(_walk_bounds.position.x, ground_y, _walk_bounds.size.x, 2.0)


func _start_jump(target: Rect2, from_cx: float, from_feet: float) -> void:
	var win := Vector2(_window.size)
	var dy := target.position.y - from_feet
	var target_cx := clampf(from_cx, target.position.x + win.x * 0.5, target.end.x - win.x * 0.5)
	var dx := target_cx - from_cx
	var dir := 1 if dx >= 0.0 else -1
	var t := clampf(absf(dx) / (JUMP_SPEED_REF * _size_scale), JUMP_MIN_T, JUMP_MAX_T)
	_launch_platform = _platform
	_platform = Rect2()
	_velocity = Vector2(dx / t, (dy - JUMP_CLEAR) / t - 0.5 * gravity * t)
	_pet.jump(dir, t)
	_state = State.JUMP
