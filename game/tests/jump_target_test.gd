extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")
const WIN := Vector2(128, 64)
const A := Rect2(150, 700, 400, 240)
const GROUND_LINE := 1008.0

var pet: Node2D
var _hard_fail: Array = []
var _soft_ok := 0
var _ok := 0
var _total := 0
var _timeouts := 0


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
	pet._walk_bounds = Rect2(0, 840, 1920, 168)
	pet._screen_bounds = Rect2(0, 0, 1920, 1080)
	Windows.active = true
	_run_sweep()
	print("[TEST] total=", _total, " ok=", _ok, " soft_ok=", _soft_ok, " timeouts=", _timeouts, " hard_fail=", _hard_fail)
	get_tree().quit(0 if (_hard_fail.is_empty() and _timeouts == 0) else 1)


func _setup_on(cx: float, support: Rect2) -> void:
	pet._feet_y = support.position.y
	pet._platform = support
	pet._launch_platform = support
	pet._position = Vector2(cx - WIN.x * 0.5, support.position.y - WIN.y)
	pet._velocity = Vector2.ZERO
	pet._state = 0
	pet._state_timer = 999.0


func _simulate_jump(max_iters: int) -> int:
	var iters := 0
	while pet._state == 6 and iters < max_iters:
		pet._tick_jump(1.0 / 60.0)
		iters += 1
	return pet._state


func _b_reachable(cx: float, feet_y: float, b: Rect2) -> bool:
	var target_cx := clampf(cx, b.position.x + WIN.x * 0.5, b.end.x - WIN.x * 0.5)
	var dy := b.position.y - feet_y
	return absf(target_cx - cx) <= 440.0 and dy >= -260.0 and dy <= 600.0


func _run_sweep() -> void:
	var source_xs := [200.0, 300.0, 400.0, 480.0]
	var tops := [700.0, 600.0, 800.0]
	var dxs := [250.0, 380.0, 520.0]
	var widths := [200.0, 300.0]
	for cx in source_xs:
		for top in tops:
			for dx in dxs:
				for w in widths:
					_total += 1
					var b := Rect2(A.position.x + dx, top, w, 200)
					Windows.platforms = [A, b]
					_setup_on(cx, A)
					var reachable := _b_reachable(cx, A.position.y, b)
					var started: bool = pet._try_jump_to_platform(0)
					if not started:
						_hard_fail.append(["no-jump", cx, top, dx, w])
						continue
					var st := _simulate_jump(400)
					if st == 6:
						_timeouts += 1
						_hard_fail.append(["timeout", cx, top, dx, w])
						continue
					var landed_on_b: bool = pet._platform == b
					var on_ground: bool = pet._platform.size.x == 0.0 and pet._feet_y >= GROUND_LINE - 1.0
					if reachable:
						if landed_on_b:
							_ok += 1
						else:
							_hard_fail.append(["miss", cx, top, dx, w, pet._platform, pet._feet_y])
					else:
						if on_ground:
							_soft_ok += 1
						else:
							_hard_fail.append(["unreachable-not-homed", cx, top, dx, w])