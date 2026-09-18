extends Window

const BALL_RADIUS := 5.0
const PADDLE_W := 10.0
const PADDLE_H := 58.0
const PADDLE_MARGIN := 14.0
const PADDLE_SPEED := 340.0
const AI_SPEED := 260.0
const START_SPEED := 320.0
const MAX_SPEED := 720.0
const SPEED_UP := 1.05
const TARGET_SCORE := 5
const SERVE_DELAY := 1.0

var _court: Court
var _playing := false
var _game_over := false
var _player_won := false
var _serve_timer := 0.0
var _prev_space := false
var _player_score := 0
var _ai_score := 0
var _ball_pos := Vector2()
var _prev_ball_pos := Vector2()
var _ball_vel := Vector2()
var _ball_speed := START_SPEED
var _last_scorer := 1
var _player_rect := Rect2()
var _ai_rect := Rect2()
var _paddles_ready := false


func _ready() -> void:
	title = "Pong"
	size = Vector2i(480, 320)
	unresizable = true
	maximize_disabled = true
	_court = Court.new()
	_court.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_court)
	_reset_all()


func _process(delta: float) -> void:
	if _court == null or not visible:
		return
	var cs := _court.size
	if cs.x <= 0.0 or cs.y <= 0.0:
		return
	_update_paddles(cs)
	_tick_controls(cs, delta)
	if not _game_over and _playing:
		if _serve_timer > 0.0:
			_serve_timer -= delta
			if _serve_timer <= 0.0:
				_serve()
		else:
			_tick_ball(cs, delta)
	_tick_space()
	_redraw()


func _update_paddles(cs: Vector2) -> void:
	_player_rect.position.x = PADDLE_MARGIN
	_ai_rect.position.x = cs.x - PADDLE_MARGIN - PADDLE_W
	_player_rect.size = Vector2(PADDLE_W, PADDLE_H)
	_ai_rect.size = Vector2(PADDLE_W, PADDLE_H)
	if not _paddles_ready:
		_paddles_ready = true
		var y := (cs.y - PADDLE_H) * 0.5
		_player_rect.position.y = y
		_ai_rect.position.y = y


func _tick_controls(cs: Vector2, delta: float) -> void:
	var max_y := cs.y - PADDLE_H
	var key_dir := 0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_dir -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_dir += 1
	if key_dir != 0:
		_player_rect.position.y = clampf(
			_player_rect.position.y + key_dir * PADDLE_SPEED * delta, 0.0, max_y
		)
	else:
		var mouse := _court.get_local_mouse_position()
		if Rect2(Vector2.ZERO, cs).has_point(mouse):
			_player_rect.position.y = clampf(mouse.y - PADDLE_H * 0.5, 0.0, max_y)
	var ai_center := _ai_rect.position.y + PADDLE_H * 0.5
	var target := _ball_pos.y if _ball_vel.x > 0.0 else cs.y * 0.5
	ai_center = move_toward(ai_center, target, AI_SPEED * delta)
	_ai_rect.position.y = clampf(ai_center - PADDLE_H * 0.5, 0.0, max_y)


func _tick_space() -> void:
	var space := Input.is_key_pressed(KEY_SPACE)
	if space and not _prev_space:
		if _game_over:
			_reset_all()
		elif _playing:
			_playing = false
		else:
			_playing = true
			_serve_timer = SERVE_DELAY
	_prev_space = space


func _tick_ball(cs: Vector2, delta: float) -> void:
	_prev_ball_pos = _ball_pos
	_ball_pos += _ball_vel * delta
	if _ball_pos.y - BALL_RADIUS < 0.0:
		_ball_pos.y = BALL_RADIUS
		_ball_vel.y = absf(_ball_vel.y)
	elif _ball_pos.y + BALL_RADIUS > cs.y:
		_ball_pos.y = cs.y - BALL_RADIUS
		_ball_vel.y = -absf(_ball_vel.y)
	if _check_paddle_hit(_player_rect, true):
		_bounce(_player_rect, true)
	if _check_paddle_hit(_ai_rect, false):
		_bounce(_ai_rect, false)
	if _ball_pos.x - BALL_RADIUS > cs.x:
		_last_scorer = 1
		_player_score += 1
		_end_point()
	elif _ball_pos.x + BALL_RADIUS < 0.0:
		_last_scorer = -1
		_ai_score += 1
		_end_point()


func _check_paddle_hit(paddle: Rect2, left: bool) -> bool:
	var crossed := false
	if left:
		var face := paddle.end.x
		crossed = _prev_ball_pos.x - BALL_RADIUS > face and _ball_pos.x - BALL_RADIUS <= face
	else:
		var face := paddle.position.x
		crossed = _prev_ball_pos.x + BALL_RADIUS < face and _ball_pos.x + BALL_RADIUS >= face
	if not crossed:
		return false
	return _ball_pos.y + BALL_RADIUS >= paddle.position.y and _ball_pos.y - BALL_RADIUS <= paddle.end.y


func _bounce(paddle: Rect2, left: bool) -> void:
	var center := paddle.position.y + paddle.size.y * 0.5
	var rel := clampf((_ball_pos.y - center) / (paddle.size.y * 0.5), -1.0, 1.0)
	var angle := rel * (PI * 0.42)
	var dir := 1.0 if left else -1.0
	_ball_speed = minf(_ball_speed * SPEED_UP, MAX_SPEED)
	_ball_vel = Vector2(dir * cos(angle), sin(angle)).normalized() * _ball_speed
	if absf(_ball_vel.y) < 8.0:
		_ball_vel.y = 8.0 if rel >= 0.0 else -8.0
		_ball_vel = _ball_vel.normalized() * _ball_speed
	if left:
		_ball_pos.x = paddle.end.x + BALL_RADIUS
	else:
		_ball_pos.x = paddle.position.x - BALL_RADIUS


func _serve() -> void:
	var cs := _court.size
	_ball_pos = Vector2(cs.x * 0.5, cs.y * 0.5 + randf_range(-30.0, 30.0))
	_prev_ball_pos = _ball_pos
	_ball_speed = START_SPEED
	var dir := 1.0 if _last_scorer == 1 else -1.0
	_ball_vel = Vector2(dir, 0.0).rotated(randf_range(-0.45, 0.45)).normalized() * _ball_speed


func _end_point() -> void:
	if _player_score >= TARGET_SCORE:
		_game_over = true
		_player_won = true
		_playing = false
	elif _ai_score >= TARGET_SCORE:
		_game_over = true
		_player_won = false
		_playing = false
	else:
		_ball_pos = _court.size * 0.5
		_prev_ball_pos = _ball_pos
		_ball_vel = Vector2.ZERO
		_ball_speed = START_SPEED
		_serve_timer = SERVE_DELAY


func _reset_all() -> void:
	_player_score = 0
	_ai_score = 0
	_game_over = false
	_player_won = false
	_playing = false
	_last_scorer = 1
	_ball_vel = Vector2.ZERO
	_ball_speed = START_SPEED
	_ball_pos = _court.size * 0.5 if _court else Vector2()
	_prev_ball_pos = _ball_pos
	_redraw()


func _redraw() -> void:
	_court.ball_pos = _ball_pos
	_court.ball_radius = BALL_RADIUS
	_court.player_rect = _player_rect
	_court.ai_rect = _ai_rect
	_court.player_score = _player_score
	_court.ai_score = _ai_score
	_court.game_over = _game_over
	_court.player_won = _player_won
	_court.playing = _playing
	_court.queue_redraw()


class Court:
	extends Control

	const PLAYER_COLOR := Color(0.35, 0.6, 0.95)
	const AI_COLOR := Color(0.9, 0.45, 0.45)

	var ball_pos := Vector2()
	var ball_radius := 5.0
	var player_rect := Rect2()
	var ai_rect := Rect2()
	var player_score := 0
	var ai_score := 0
	var game_over := false
	var player_won := false
	var playing := false

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.07))
		var mid_x := s.x * 0.5
		var y := 0.0
		while y < s.y:
			draw_rect(Rect2(mid_x - 1.5, y, 3.0, minf(12.0, s.y - y)), Color(0.35, 0.4, 0.45))
			y += 22.0
		if player_rect.size.x > 0.0:
			draw_rect(player_rect, PLAYER_COLOR)
			draw_rect(ai_rect, AI_COLOR)
		draw_circle(ball_pos, ball_radius, Color(0.95, 0.95, 0.98))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(mid_x - 130.0, 42.0), str(player_score),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 42, PLAYER_COLOR)
		draw_string(font, Vector2(mid_x + 55.0, 42.0), str(ai_score),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 42, AI_COLOR)
		if game_over:
			var text := "Ganaste!" if player_won else "Gana la IA"
			_draw_centered(font, Vector2(mid_x, s.y * 0.5 - 26.0), text, 34, Color(0.95, 0.95, 0.98))
			_draw_centered(font, Vector2(mid_x, s.y * 0.5 + 16.0), "Espacio para reiniciar", 18, Color(0.7, 0.72, 0.75))
		elif not playing:
			_draw_centered(font, Vector2(mid_x, s.y - 26.0), "Espacio para jugar / pausar", 18, Color(0.7, 0.72, 0.75))

	func _draw_centered(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, pos - Vector2(w * 0.5, 0.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)