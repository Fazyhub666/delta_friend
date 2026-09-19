extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")

var pet: Node2D
var _issues: Array[String] = []


func _ready() -> void:
	Windows.active = false
	Windows._stop_helper()
	Windows._helper_pid = OS.get_process_id()
	Windows._out_path = OS.get_environment("TEMP").path_join("delta_friend_never.json")
	pet = SCENE.instantiate()
	add_child(pet)
	pet._set_pet_scale(1.0)
	pet.maus_chance = 0.0
	pet.game_chance = 0.0
	pet.sit_call_chance = 0.0
	pet._walk_bounds = Rect2(0, 840, 1920, 168)
	pet._screen_bounds = Rect2(0, 0, 1920, 1080)

	_test_start_direction_at_both_edges()
	_test_walk_ends_on_narrow_window()
	_test_walk_ends_on_taskbar_edge()

	print("[TEST] total=4 ok=", 4 - _issues.size(), " issues=", _issues.size())
	for i in _issues:
		print("[TEST] ISSUE: ", i)
	get_tree().quit(0 if _issues.is_empty() else 1)


func _test_start_direction_at_both_edges() -> void:
	var win := Vector2(pet._window.size)
	pet._feet_y = pet._walk_bounds.end.y
	pet._platform = Rect2()
	pet._position = Vector2(pet._walk_bounds.position.x - win.x * 0.5, pet._feet_y - win.y)
	pet._state = 0
	var dir_left: int = pet._preferred_walk_direction(pet._walk_range())
	if dir_left != 1:
		_issues.append("near-left-edge started dir=" + str(dir_left) + " (esperado 1=derecha)")
	pet._position = Vector2(pet._walk_bounds.end.x + win.x * 0.5, pet._feet_y - win.y)
	var dir_right: int = pet._preferred_walk_direction(pet._walk_range())
	if dir_right != -1:
		_issues.append("near-right-edge started dir=" + str(dir_right) + " (esperado -1=izquierda)")


func _test_start_direction_middle_is_random() -> void:
	var win := Vector2(pet._window.size)
	pet._feet_y = pet._walk_bounds.end.y
	pet._platform = Rect2()
	pet._position = Vector2(960 - win.x * 0.5, pet._feet_y - win.y)
	pet._state = 0
	var saw_left := false
	var saw_right := false
	for i in 60:
		var d: int = pet._preferred_walk_direction(pet._walk_range())
		if d == 1:
			saw_right = true
		else:
			saw_left = true
	if not saw_left or not saw_right:
		_issues.append("middle direction no es aleatorio (L=" + str(saw_left) + " R=" + str(saw_right) + ")")


func _test_walk_ends_on_narrow_window() -> void:
	var win := Vector2(pet._window.size)
	var plat := Rect2(600, 800, win.x + win.x * 0.5, 120.0)
	pet._feet_y = plat.position.y
	pet._platform = plat
	pet._launch_platform = Rect2()
	pet._position = Vector2(plat.position.x + 4.0, plat.position.y - win.y)
	pet._state = 1
	pet._direction = -1
	pet._walk_timer = 1.0
	pet._jump_timer = 99.0
	var steps := 0
	while pet._state == 1 and steps < 60 * 30:
		pet._tick_walk(1.0 / 60.0)
		steps += 1
	if pet._state == 1:
		_issues.append("narrow-window: WALK atrapado tras %d frames" % steps)
		return
	if pet._state != 0:
		_issues.append("narrow-window: termino en state=" + str(pet._state) + " (esperado 0)")


func _test_walk_ends_on_taskbar_edge() -> void:
	var win := Vector2(pet._window.size)
	pet._feet_y = pet._walk_bounds.end.y
	pet._platform = Rect2()
	pet._position = Vector2(pet._walk_bounds.end.x - 2.0, pet._feet_y - win.y)
	pet._state = 1
	pet._direction = 1
	pet._walk_timer = 1.0
	pet._jump_timer = 99.0
	var steps := 0
	while pet._state == 1 and steps < 60 * 30:
		pet._tick_walk(1.0 / 60.0)
		steps += 1
	if pet._state == 1:
		_issues.append("taskbar-edge: WALK atrapado tras %d frames" % steps)
		return
	if pet._state != 0:
		_issues.append("taskbar-edge: termino en state=" + str(pet._state) + " (esperado 0)")