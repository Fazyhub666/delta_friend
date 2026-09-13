extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")
const FIXTURE := Rect2(400, 860, 260, 120)

var pet: Node2D
var _frames := 0
var _last_state := -1
var _home_after_land := false
var _saw_jump := false
var _saw_walk := false


func _ready() -> void:
	Windows.active = false
	Windows._stop_helper()
	Windows._helper_pid = OS.get_process_id()
	Windows._out_path = OS.get_environment("TEMP").path_join("delta_friend_never.json")
	Engine.max_fps = 60
	pet = SCENE.instantiate()
	add_child(pet)
	pet._set_pet_scale(1.0)
	pet.maus_chance = 0.0
	pet.game_chance = 0.0
	pet.min_rest_time = 0.8
	pet.max_rest_time = 1.6
	pet._walk_bounds = Rect2(0, 840, 1920, 168)
	pet._screen_bounds = Rect2(0, 0, 1920, 1080)
	Windows.platforms = [FIXTURE]
	Windows.active = true
	print("[WHOP] setup done")


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 1:
		print("[WHOP] f1 platforms=", Windows.platforms, " helper_pid=", Windows._helper_pid, " active=", Windows.active)
	if _frames % 30 == 0 and _frames < 90:
		print("[WHOP] f", _frames, " platforms=", Windows.platforms)
	if _frames == 60:
		pet._feet_y = FIXTURE.position.y
		pet._platform = FIXTURE
		pet._position = Vector2(464, 796)
		pet._window.position = Vector2i(pet._position)
		pet._state = 0
		pet._state_timer = 1.2
		print("[WHOP] placed on window f=", _frames)
	if _frames > 60:
		if pet._state != _last_state:
			print("[WHOP] f=", _frames, " st=", pet._state, " pos=", pet._position, " feet=", pet._feet_y)
			_last_state = pet._state
		if pet._state == 6:
			_saw_jump = true
		if pet._state == 1:
			_saw_walk = true
		if not _home_after_land and absf(pet._feet_y - 1008.0) < 0.5:
			_home_after_land = true
			print("[WHOP] reached taskbar f=", _frames, " x=", pet._position.x)
	if _frames > 720:
		var ok := _home_after_land and _saw_jump
		print("[TEST] ", "PASS" if ok else "FAIL", " home=", _home_after_land,
			" saw_jump=", _saw_jump, " saw_walk=", _saw_walk,
			" st=", pet._state, " feet=", pet._feet_y)
		get_tree().quit(0 if ok else 1)
		return