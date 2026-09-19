extends Window

const PLAYER := "X"
const AI := "O"
const WIN_LINES := [
	[0, 1, 2],
	[3, 4, 5],
	[6, 7, 8],
	[0, 3, 6],
	[1, 4, 7],
	[2, 5, 8],
	[0, 4, 8],
	[2, 4, 6],
]

var _board: Array[String] = ["", "", "", "", "", "", "", "", ""]
var _buttons: Array[Button] = []
var _status: Label
var _player_turn := true
var _game_over := false
var _ai_pending := false
var _ai_delay := 0.0


func _ready() -> void:
	title = "Tic Tac Toe"
	size = Vector2i(320, 400)
	unresizable = true
	maximize_disabled = true
	_setup_ui()
	_reset_game()


func _process(delta: float) -> void:
	if not _ai_pending:
		return
	_ai_delay -= delta
	if _ai_delay <= 0.0:
		_ai_pending = false
		_do_ai_turn()


func _setup_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_status)

	var grid_center := CenterContainer.new()
	vbox.add_child(grid_center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid_center.add_child(grid)

	for i in 9:
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 88)
		button.add_theme_font_size_override("font_size", 52)
		button.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(button)
		_buttons.append(button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)

	var restart := Button.new()
	restart.text = "Reiniciar"
	restart.pressed.connect(_reset_game)
	actions.add_child(restart)

	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(_on_close_pressed)
	actions.add_child(close_button)


func _on_close_pressed() -> void:
	queue_free()


func _on_cell_pressed(idx: int) -> void:
	if _game_over or not _player_turn or _board[idx] != "":
		return
	_place(idx, PLAYER)
	if _check_end():
		return
	_player_turn = false
	_set_status("Turno de la IA")
	_ai_pending = true
	_ai_delay = 0.45


func _do_ai_turn() -> void:
	if _game_over:
		return
	var idx := _best_ai_move()
	if idx >= 0:
		_place(idx, AI)
	if _check_end():
		return
	_player_turn = true
	_set_status("Tu turno (X)")


func _place(idx: int, mark: String) -> void:
	_board[idx] = mark
	_buttons[idx].text = mark
	_buttons[idx].disabled = true
	var color := Color(0.35, 0.6, 0.95) if mark == PLAYER else Color(0.9, 0.45, 0.45)
	_buttons[idx].add_theme_color_override("font_color", color)


func _check_end() -> bool:
	var winner := _get_winner()
	if winner != "":
		_game_over = true
		_highlight(winner)
		_set_status("Ganaste!" if winner == PLAYER else "Ganó la IA")
		return true
	for cell in _board:
		if cell == "":
			return false
	_game_over = true
	_set_status("Empate")
	return true


func _get_winner() -> String:
	for line in WIN_LINES:
		if _board[line[0]] != "" \
				and _board[line[0]] == _board[line[1]] \
				and _board[line[1]] == _board[line[2]]:
			return _board[line[0]]
	return ""


func _highlight(winner: String) -> void:
	for line in WIN_LINES:
		if _board[line[0]] == winner and _board[line[1]] == winner and _board[line[2]] == winner:
			for idx in line:
				_buttons[idx].add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
			return


func _best_ai_move() -> int:
	var empty: Array[int] = []
	for i in 9:
		if _board[i] == "":
			empty.append(i)
	if empty.is_empty():
		return -1
	var win_idx := _find_finish(AI)
	if win_idx >= 0:
		return win_idx
	var block_idx := _find_finish(PLAYER)
	if block_idx >= 0:
		return block_idx
	if _board[4] == "":
		return 4
	for corner in [0, 2, 6, 8]:
		if _board[corner] == "":
			return corner
	return empty[randi() % empty.size()]


func _find_finish(mark: String) -> int:
	for line in WIN_LINES:
		var marks := 0
		var free_idx := -1
		for idx in line:
			if _board[idx] == mark:
				marks += 1
			elif _board[idx] == "":
				free_idx = idx
		if marks == 2 and free_idx >= 0:
			return free_idx
	return -1


func _reset_game() -> void:
	_game_over = false
	_player_turn = true
	_ai_pending = false
	_ai_delay = 0.0
	for i in 9:
		_board[i] = ""
		_buttons[i].text = ""
		_buttons[i].disabled = false
		_buttons[i].remove_theme_color_override("font_color")
	_set_status("Tu turno (X)")


func _set_status(text: String) -> void:
	_status.text = text