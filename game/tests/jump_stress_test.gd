extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")
const GROUND_LINE := 1008.0

var pet: Node2D
var _issues: Array[String] = []
var _total := 0
var _ok := 0


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
	Windows.active = true
	_run_all()
	print("[TEST] total=", _total, " ok=", _ok, " issues=", _issues.size())
	for i in _issues:
		print("[TEST] ISSUE: ", i)
	get_tree().quit(0 if _issues.is_empty() else 1)


func _setup_on(cx: float, support: Rect2, scale := 1.0) -> void:
	pet._feet_y = support.position.y
	pet._platform = support
	pet._launch_platform = support
	var win: Vector2 = Vector2(pet._window.size)
	pet._position = Vector2(cx - win.x * 0.5, support.position.y - win.y)
	pet._velocity = Vector2.ZERO
	pet._state = 0
	pet._state_timer = 999.0


func _simulate_jump(max_iters: int) -> int:
	var iters := 0
	while pet._state == 6 and iters < max_iters:
		pet._tick_jump(1.0 / 60.0)
		iters += 1
	return pet._state


func _check_invariants(tag: String) -> void:
	var win: Vector2 = Vector2(pet._window.size)
	var feet: float = pet._position.y + win.y
	if not is_finite(pet._position.x) or not is_finite(pet._position.y):
		_issues.append("%s no-finite pos=%s" % [tag, pet._position])
	elif not is_finite(pet._velocity.y):
		_issues.append("%s no-finite vel=%s" % [tag, pet._velocity])
	if pet._position.y > pet._walk_bounds.end.y + win.y + 2.0:
		_issues.append("%s below-ground pos=%s feet=%s" % [tag, pet._position, feet])
	if pet._position.x < pet._screen_bounds.position.x - win.x or pet._position.x > pet._screen_bounds.end.x:
		_issues.append("%s off-screen-x pos=%s" % [tag, pet._position])


func _landed_where() -> Dictionary:
	if pet._is_on_window():
		return {"kind": "win", "rect": pet._platform}
	if pet._feet_y >= GROUND_LINE - 1.0:
		return {"kind": "ground"}
	return {"kind": "void", "feet": pet._feet_y}


func _test_scenario(cx: float, name: String, platforms: Array[Rect2], shape: Array) -> void:
	_total += 1
	Windows.platforms = platforms
	var support := (shape[0] as Rect2)
	_setup_on(cx, support)
	var ok_started: bool = pet._try_jump_to_platform(0)
	var tag := "%s cx=%s" % [name, cx]

	if not ok_started:
		_check_invariants(tag)
		var landed := _landed_where()
		if pet._state == 0 and (landed["kind"] == "ground" or landed["kind"] == "win"):
			_ok += 1
		else:
			_issues.append("%s no-jump state=%s landed=%s" % [tag, pet._state, landed])
		return

	var st := _simulate_jump(900)
	if st == 6:
		_issues.append("%s timeout vel=%s pos=%s" % [tag, pet._velocity, pet._position])
		return
	_check_invariants(tag)
	if st != 0:
		_issues.append("%s ended-in-wrong-state st=%s" % [tag, st])
		return
	var landed := _landed_where()
	if landed["kind"] == "void":
		_issues.append("%s landed-in-void feet=%s" % [tag, pet._feet_y])
		return
	_ok += 1


func _run_all() -> void:
	_random_many()
	_overlapping_stack()
	_underneath_target()
	_side_landing()
	_same_platform_back()
	_scale_variants()


func _random_many() -> void:
	var seed_val := 12345
	for iter in 400:
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var base_x := rng.randf_range(50.0, 1700.0)
		var base_w := rng.randf_range(150.0, 900.0)
		var base_y := rng.randf_range(550.0, 1000.0)
		var src := Rect2(base_x, base_y, base_w, 150.0)
		var cx := base_x + base_w * rng.randf_range(0.1, 0.9)
		var others: Array[Rect2] = [src]
		var count := rng.randi_range(1, 6)
		for i in count:
			var ow := rng.randf_range(60.0, 700.0)
			var ox := rng.randf_range(0.0, 1800.0)
			var oy := rng.randf_range(500.0, 1010.0)
			others.append(Rect2(ox, oy, ow, 80.0))
		_test_scenario(cx, "rand", others, [src, 0])


func _overlapping_stack() -> void:
	var src := Rect2(300, 800, 300, 150)
	_test_scenario(450, "stack-same-y-overlap", [
		src,
		Rect2(200, 750, 260, 100),
		Rect2(350, 750, 260, 100),
	], [src])
	_test_scenario(450, "stack-same-y-sep", [
		src,
		Rect2(150, 750, 200, 100),
		Rect2(550, 750, 200, 100),
	], [src])
	_test_scenario(450, "stack-below", [
		src,
		Rect2(200, 870, 700, 120),
	], [src])
	_test_scenario(450, "stack-above", [
		src,
		Rect2(250, 700, 600, 90),
	], [src])


func _underneath_target() -> void:
	var src := Rect2(300, 600, 400, 150)
	_test_scenario(500, "under-below-left", [
		src,
		Rect2(150, 760, 200, 100),
	], [src])
	_test_scenario(500, "under-below-full", [
		src,
		Rect2(200, 760, 800, 100),
	], [src])
	_test_scenario(500, "under-up", [
		src,
		Rect2(200, 450, 700, 100),
	], [src])


func _side_landing() -> void:
	var src := Rect2(500, 800, 200, 150)
	_test_scenario(600, "side-far-right", [src, Rect2(1300, 700, 300, 100)], [src])
	_test_scenario(600, "side-near-right", [src, Rect2(800, 800, 150, 100)], [src])
	_test_scenario(600, "side-right-down", [src, Rect2(900, 860, 300, 100)], [src])
	_test_scenario(500, "side-left-up", [src, Rect2(100, 600, 300, 100)], [src])


func _same_platform_back() -> void:
	var src := Rect2(300, 800, 500, 150)
	_test_scenario(550, "back-vertical", [src], [src])
	_test_scenario(550, "back-single-far", [src, Rect2(1200, 760, 300, 100)], [src])


func _scale_variants() -> void:
	for sc in [1.0, 1.5, 2.0, 2.5, 3.0]:
		pet._set_pet_scale(sc)
		var win: Vector2 = Vector2(pet._window.size)
		var src := Rect2(400, 850, 600, 150)
		var ox := 400 + win.x * 1.5
		_test_scenario(400 + win.x, "scale-same", [src, Rect2(ox, 850, 500, 120)], [src])
		_test_scenario(400 + win.x, "scale-up", [src, Rect2(ox, 700, 500, 120)], [src])
		_test_scenario(400 + win.x, "scale-down", [src, Rect2(ox, 950, 500, 120)], [src])
	pet._set_pet_scale(1.0)