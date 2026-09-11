extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")
const FIXTURE := Rect2(400, 860, 260, 120)

var pet: Node2D
var _frames := 0
var _phase := -1


func _ready() -> void:
	Windows.active = false
	Windows._stop_helper()
	Engine.max_fps = 60
	pet = SCENE.instantiate()
	add_child(pet)
	pet._walk_bounds = Rect2(0, 840, 1920, 168)
	pet._screen_bounds = Rect2(0, 0, 1920, 1080)
	pet._feet_y = 1008.0
	pet._platform = Rect2()
	pet._position = Vector2(236, 944)


func _process(_delta: float) -> void:
	_frames += 1
	if _phase < 0:
		if _frames < 150:
			return
		_phase = 0
		Windows.platforms = [FIXTURE]
		Windows.active = true
		var ok: bool = pet._try_jump_to_platform(0)
		Windows.active = false
		print("[TEST] try_jump=", ok, " state=", pet._state)
		if not ok or pet._state != 6:
			print("[TEST] FAIL jump not started")
			get_tree().quit(1)
		return
	match _phase:
		0:
			if pet._state == 6:
				print("[TEST] in air, vel=", pet._velocity)
				_phase = 1
		1:
			if pet._state == 0 and absf(pet._feet_y - FIXTURE.position.y) < 0.5 and pet._platform == FIXTURE:
				print("[TEST] landed on window, pos=", pet._position)
				Windows.platforms = []
				_phase = 2
		2:
			if pet._state == 8:
				print("[TEST] platform removed, falling")
				_phase = 3
		3:
			if pet._state == 0 and absf(pet._feet_y - 1008.0) < 0.5 and not pet._is_on_window():
				print("[TEST] released below taskbar, falling to ground")
				pet._position = Vector2(236, 990)
				pet._enter_fall(Vector2.ZERO)
				_phase = 4
		4:
			if pet._state == 0 and absf(pet._feet_y - 1008.0) < 0.5:
				print("[TEST] PASS feet=", pet._feet_y, " pos=", pet._position)
				get_tree().quit(0)
			if pet._position.y > 1100.0 or pet._state == 8 and pet._position.y > 1080.0:
				print("[TEST] FAIL void fall pos=", pet._position)
				get_tree().quit(1)
	if _frames > 900:
		print("[TEST] FAIL phase=", _phase, " state=", pet._state, " feet=", pet._feet_y, " pos=", pet._position)
		get_tree().quit(1)