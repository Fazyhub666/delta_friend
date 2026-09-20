extends Node

const desktop_pet_scene := preload("res://scenes/desktop_pet/desktop_pet.tscn")

const SCREEN := Rect2(0, 0, 1920, 1080)
const WALK := Rect2(0, 0, 1920, 1040)
const WIN_SIZE := Vector2i(192, 96)
const SCALE := 1.5

var _passed := 0
var _failed := 0
var _fail_msgs: Array[String] = []
var _pet: Node2D
var _wm: Node
var _wm_emissions := 0


func _ready() -> void:
	_windows_stop_helper()
	_setup_pet()
	_test_window_manager()
	_test_jump_selection()
	_test_jump_velocity()
	_test_ground_jump_target()
	_test_find_landing()
	_test_land()
	_test_validate_platform()
	_test_reset_to_ground()
	_test_jump_simulation()
	_test_fall_simulation()
	_test_walk()
	_test_preferred_walk_direction()
	_test_maus_chase_delay()
	_test_maus_chase_sequence()
	_windows_stop_helper()
	if _failed == 0:
		print("ALL PASSED (%d checks)" % _passed)
	else:
		printerr("FAILURES (%d/%d):" % [_failed, _passed + _failed])
		for msg in _fail_msgs:
			printerr("  - " + msg)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_fail_msgs.append(msg)
		printerr("FAIL: " + msg)


func _approx(a: float, b: float, eps: float = 0.75) -> bool:
	return absf(a - b) <= eps


func _windows_stop_helper() -> void:
	if Windows != null:
		Windows._stop_helper()
		Windows._helper_path = ""


func _set_platforms(p1: Rect2 = Rect2(), p2: Rect2 = Rect2(), p3: Rect2 = Rect2()) -> void:
	var arr: Array[Rect2] = []
	for p in [p1, p2, p3]:
		if p.size != Vector2.ZERO:
			arr.append(p)
	Windows.active = true
	Windows.platforms = arr


func _clear_platforms() -> void:
	var empty: Array[Rect2] = []
	Windows.active = true
	Windows.platforms = empty


func _setup_pet() -> void:
	_pet = desktop_pet_scene.instantiate()
	add_child(_pet)
	var win := Window.new()
	win.size = WIN_SIZE
	win.position = Vector2i.ZERO
	_pet._window = win
	_pet._size_scale = SCALE
	_set_ground_state()


func _set_ground_state() -> void:
	_pet._screen_bounds = SCREEN
	_pet._walk_bounds = WALK
	_pet._feet_y = WALK.end.y
	_pet._platform = Rect2()
	_pet._launch_platform = Rect2()
	_pet._velocity = Vector2.ZERO
	_pet._position = Vector2(500.0, WALK.end.y - WIN_SIZE.y)
	_pet._window.position = Vector2i(_pet._position)
	_pet._window.size = WIN_SIZE
	_pet._maus_stretched = false
	_pet._pet.position.x = 0.0
	_pet._state = _pet.State.REST
	_pet._jump_timer = 999.0


func _set_platform_state(p: Rect2, x: float = 560.0) -> void:
	_pet._platform = p
	_pet._launch_platform = Rect2()
	_pet._feet_y = p.position.y
	_pet._position = Vector2(x, p.position.y - WIN_SIZE.y)
	_pet._window.position = Vector2i(_pet._position)
	_pet._window.size = WIN_SIZE
	_pet._velocity = Vector2.ZERO
	_pet._state = _pet.State.REST


func _reset_wm(tmp: String) -> void:
	_wm = Node.new()
	_wm.set_script(load("res://scripts/window_manager.gd"))
	_wm._out_path = tmp
	_wm._scale = SCALE
	_wm._helper_pid = OS.get_process_id()
	_wm._restarts = 0
	_wm.active = true
	var empty_rects: Array[Rect2] = []
	_wm.platforms = empty_rects
	_wm_emissions = 0
	_wm.platforms_updated.connect(_on_wm_updated)


func _on_wm_updated(_p: Array) -> void:
	_wm_emissions += 1


func _write_json(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


func _test_window_manager() -> void:
	var tmp := "user://test_windows.json"
	_reset_wm(tmp)

	_write_json(tmp, "[[100,200,300,400],[50,60,70,80]]")
	_wm._refresh()
	_check(_wm.platforms.size() == 2, "wm: parsea 2 ventanas")
	if _wm.platforms.size() == 2:
		_check(_approx(_wm.platforms[0].position.x, 100.0 / SCALE) and _approx(_wm.platforms[0].position.y, 200.0 / SCALE), "wm: coord pasada a logical")
		_check(_approx(_wm.platforms[0].size.x, 300.0 / SCALE) and _approx(_wm.platforms[0].size.y, 400.0 / SCALE), "wm: tamano escalado")
	_check(_wm_emissions == 1, "wm: emite tras cambio")

	_wm._refresh()
	_check(_wm_emissions == 1, "wm: no reemite con datos iguales")

	_write_json(tmp, "[]")
	_wm._refresh()
	_check(_wm.platforms.is_empty(), "wm: array vacio limpia plataformas")

	_write_json(tmp, "no es json")
	var before: Array[Rect2] = _wm.platforms.duplicate()
	_wm._refresh()
	_check(_wm.platforms == before, "wm: json invalido no cambia estado")

	_write_json(tmp, "[[1,2,3],[10,20,30,40],[50,60],[70,80,90,100,999]]")
	_wm._refresh()
	_check(_wm.platforms.size() == 2, "wm: descarta entradas != 4 numeros")

	_write_json(tmp, "[[10,20,null,40],[\"a\",\"b\",\"c\",\"d\"]]")
	_wm._refresh()
	_check(_wm.platforms.is_empty(), "wm: descarta entradas con tipos invalidos")

	DirAccess.remove_absolute("user://test_windows.json")


func _test_jump_selection() -> void:
	_set_ground_state()

	var p := Rect2(600, 900, 400, 200)
	_set_platforms(p)
	var ok: bool = _pet._try_jump_to_platform(0)
	_check(ok, "salto: plataforma alcanzable y ancha -> true")
	_check(_pet._state == _pet.State.JUMP, "salto: estado pasa a JUMP")
	_check(_pet._velocity.x > 0.0, "salto: velocidad horizontal hacia el destino")
	_check(_pet._velocity.y < 0.0, "salto: velocidad vertical hacia arriba")
	_set_ground_state()

	var high := Rect2(600, 700, 400, 200)
	_set_platforms(high)
	ok = _pet._try_jump_to_platform(0)
	_check(not ok, "salto: plataforma demasiado alta (dy<-260) -> false")
	_check(_pet._state == _pet.State.REST, "salto: permanece REST sin saltar")
	_set_ground_state()

	var low := Rect2(600, 1700, 400, 200)
	_set_platforms(low)
	ok = _pet._try_jump_to_platform(0)
	_check(not ok, "salto: plataforma demasiado baja (dy>600) -> false")
	_set_ground_state()

	var slim := Rect2(600, 900, 190, 200)
	_set_platforms(slim)
	ok = _pet._try_jump_to_platform(0)
	_check(not ok, "salto: plataforma estrecha (w<192+12) -> false")

	Windows.active = false
	_clear_platforms()
	ok = _pet._try_jump_to_platform(0)
	_check(not ok, "salto: Windows inactivo -> false")
	Windows.active = true
	_set_ground_state()

	var same := Rect2(600, 900, 400, 200)
	_set_platform_state(same)
	_set_platforms(same)
	ok = _pet._try_jump_to_platform(0)
	_check(ok, "salto: parado en ventana sin otra plataforma -> salta al suelo")
	_check(_pet._state == _pet.State.JUMP, "salto: transicion a JUMP hacia el suelo")
	_check(_pet._launch_platform == same, "salto: guarda plataforma de lanzamiento")


func _test_jump_velocity() -> void:
	var p := Rect2(600, 900, 400, 200)
	var feet := 1040.0
	var cx := 596.0
	var win := Vector2(WIN_SIZE)
	var target_cx := clampf(cx, p.position.x + win.x * 0.5, p.end.x - win.x * 0.5)
	var dx := target_cx - cx
	var dy := p.position.y - feet
	var t := clampf(absf(dx) / (400.0 * SCALE), 0.35, 1.1)
	var expected := Vector2(dx / t, (dy - 36.0) / t - 0.5 * 3000.0 * t)

	_set_ground_state()
	_pet._try_jump_to_platform(0)
	var got: Vector2 = _pet._velocity
	_check(got.distance_to(expected) < 1.0, "salto: velocidad fisica coincide (%s ~ %s)" % [got, expected])


func _test_ground_jump_target() -> void:
	_set_ground_state()
	var win := Vector2(WIN_SIZE)
	var res: Rect2 = _pet._ground_jump_target(596.0, 900.0, win)
	_check(res.size != Vector2.ZERO, "suelo: salto al suelo desde ventana es valido")
	_check(res.position.y == WALK.end.y, "suelo: destino es la linea del suelo")

	res = _pet._ground_jump_target(596.0, 400.0, win)
	_check(res.size == Vector2.ZERO, "suelo: sin salto si la caida supera el limite")

	res = _pet._ground_jump_target(596.0, 1040.0, win)
	_check(res.size != Vector2.ZERO, "suelo: desde el nivel del suelo devuelve un destino valido")


func _test_find_landing() -> void:
	_set_ground_state()
	_pet._velocity = Vector2(0, 800)

	var p := Rect2(600, 900, 400, 200)
	_set_platforms(p)
	var res: Dictionary = _pet._find_landing(880.0, 920.0, 700.0)
	_check(res.get("is_ground") == false, "aterrizaje: cruza una ventana en el suelo del salto")
	_check(_approx(float(res.get("feet_y", -1.0)), 900.0), "aterrizaje: feet en la parte superior")
	_check(res.get("rect") == p, "aterrizaje: rect de la ventana correcta")

	var p2 := Rect2(600, 850, 400, 200)
	_set_platforms(p, p2)
	res = _pet._find_landing(800.0, 920.0, 700.0)
	_check(_approx(float(res.get("feet_y", -1.0)), 850.0), "aterrizaje: elige la mas alta cruzada")
	_check(res.get("rect") == p2, "aterrizaje: rect de la mas alta")

	_pet._launch_platform = p2
	res = _pet._find_landing(800.0, 940.0, 700.0)
	_pet._launch_platform = Rect2()
	_check(_approx(float(res.get("feet_y", -1.0)), 900.0), "aterrizaje: omite la plataforma de lanzamiento")

	var side := Rect2(1200, 900, 400, 200)
	_set_platforms(p, side)
	res = _pet._find_landing(880.0, 920.0, 700.0)
	_check(_approx(float(res.get("feet_y", -1.0)), 900.0), "aterrizaje: ignora ventanas fuera del eje X")

	var very_high := Rect2(600, 40, 400, 200)
	_set_platforms(very_high, p)
	res = _pet._find_landing(50.0, 120.0, 700.0)
	_check(res.is_empty(), "aterrizaje: no pisa ventana cuyo borde queda sobre la pantalla")

	_set_platforms(p)
	_pet._velocity = Vector2(0, -50)
	res = _pet._find_landing(880.0, 920.0, 700.0)
	_check(res.is_empty(), "aterrizaje: no detecta aterrizaje al ascender")

	_pet._velocity = Vector2.ZERO
	_clear_platforms()
	res = _pet._find_landing(800.0, 920.0, 700.0)
	_check(res.is_empty(), "aterrizaje: sin ventanas y sin tocar suelo -> vacio")

	_pet._velocity = Vector2(0, 800)
	res = _pet._find_landing(1000.0, 1060.0, 700.0)
	_check(res.get("is_ground") == true, "aterrizaje: toca el suelo al superar la linea")
	_check(_approx(float(res.get("feet_y", -1.0)), WALK.end.y), "aterrizaje: suelo en la linea del suelo")


func _test_land() -> void:
	_set_ground_state()
	var p := Rect2(600, 900, 400, 200)
	var res := {"feet_y": 900.0, "is_ground": false, "rect": p}
	_pet._land(res)
	_check(_pet._feet_y == 900.0, "land: ventana -> feet en la parte superior")
	_check(_pet._platform == p, "land: plataforma guardada")
	_check(_pet._position.y == 900.0 - WIN_SIZE.y, "land: ventana posicionada sobre la ventana")
	_check(_pet._velocity == Vector2.ZERO, "land: velocidad anulada")
	_check(_pet._state == _pet.State.REST, "land: vuelve a REST")

	_set_ground_state()
	res = {"feet_y": float(WALK.end.y), "is_ground": true, "rect": Rect2()}
	_pet._land(res)
	_check(_pet._feet_y == WALK.end.y, "land: suelo -> feet en la linea del suelo")
	_check(_pet._platform.size == Vector2.ZERO, "land: suelo -> sin plataforma")
	_check(_pet._position.y == WALK.end.y - WIN_SIZE.y, "land: posicionado sobre el suelo")


func _test_validate_platform() -> void:
	var p := Rect2(600, 900, 400, 200)
	_set_platform_state(p, 700.0)
	_set_platforms(p)
	_pet._state = _pet.State.SIT
	_pet._validate_platform()
	_check(_pet._platform == p, "validate: plataforma presente -> se mantiene")
	_check(_pet._state == _pet.State.SIT, "validate: no cambia de estado")

	_set_platforms()
	_pet._validate_platform()
	_check(_pet._platform.size == Vector2.ZERO, "validate: plataforma desaparece -> cae")
	_check(_pet._state == _pet.State.FALLING, "validate: pasa a FALLING")

	_set_platform_state(p, 700.0)
	_set_platforms(p)
	_pet._position.x = 1050.0
	_pet._validate_platform()
	_check(_pet._platform.size == Vector2.ZERO, "validate: centro fuera de la plataforma -> cae")


func _test_reset_to_ground() -> void:
	var p := Rect2(600, 900, 400, 200)
	_set_platform_state(p)
	_set_platforms(p)
	_pet._reset_to_ground()
	_check(_pet._platform.size == Vector2.ZERO, "reset: se limpia la plataforma")
	_check(_pet._feet_y == WALK.end.y, "reset: feet en el suelo")
	_check(_pet._position.y == WALK.end.y - WIN_SIZE.y, "reset: posicionado en el suelo")


func _test_jump_simulation() -> void:
	_set_ground_state()
	var p := Rect2(600, 900, 400, 200)
	_set_platforms(p)
	var ok: bool = _pet._try_jump_to_platform(0)
	_check(ok, "sim_salto: inicia salto")
	var steps := 0
	while _pet._state == _pet.State.JUMP and steps < 3000:
		_pet._tick_jump(1.0 / 60.0)
		steps += 1
	_check(_pet._platform == p, "sim_salto: aterriza en la ventana objetivo (%d pasos)" % steps)
	_check(_pet._state == _pet.State.REST, "sim_salto: estado REST al aterrizar")
	_check(_approx(_pet._feet_y, p.position.y), "sim_salto: feet sobre la ventana")
	_check(_approx(_pet._position.x + WIN_SIZE.x * 0.5, 600.0 + 96.0, 64.0), "sim_salto: cae dentro del eje X de la ventana")


func _test_fall_simulation() -> void:
	_set_ground_state()
	var p := Rect2(600, 900, 400, 200)
	_set_platforms(p)
	_pet._position.x = p.position.x + 128.0
	_pet._position.y = 500.0 - WIN_SIZE.y
	_pet._window.position = Vector2i(_pet._position)
	_pet._velocity = Vector2(0, 400)
	_pet._state = _pet.State.FALLING
	var steps := 0
	while _pet._state == _pet.State.FALLING and steps < 3000:
		_pet._tick_fall(1.0 / 60.0)
		steps += 1
	_check(_pet._platform == p, "sim_caida: aterriza en la ventana del camino (%d pasos)" % steps)
	_check(_pet._state == _pet.State.REST, "sim_caida: estado REST al aterrizar")


func _test_walk() -> void:
	_clear_platforms()
	_set_ground_state()
	_pet._state = _pet.State.WALK
	_pet._direction = 1
	_pet._walk_timer = 999.0
	var start_x: float = _pet._position.x
	_pet._tick_walk(0.5)
	_check(_approx(_pet._position.x, start_x + 60.0 * 0.5), "walk: avanza a velocidad constante en el suelo")
	_check(_pet._state == _pet.State.WALK, "walk: sigue caminando")

	var p := Rect2(600, 900, 400, 200)
	_set_platform_state(p)
	_pet._state = _pet.State.WALK
	_pet._walk_timer = 999.0
	var rng: Vector2 = _pet._walk_range()
	_pet._direction = -1
	var steps := 0
	while true:
		_pet._tick_walk(0.5)
		steps += 1
		if _pet._direction != -1:
			break
		if steps > 20:
			break
	_check(_approx(_pet._position.x, rng.x, 2.0), "walk: se detiene en el borde izquierdo de la ventana")


func _test_preferred_walk_direction() -> void:
	_set_ground_state()
	var rng: Vector2 = _pet._walk_range()
	_pet._position.x = rng.x + 1.0
	_check(_pet._preferred_walk_direction(rng) == 1, "dir: en el borde izquierdo camina a la derecha")
	_pet._position.x = rng.y - 1.0
	_check(_pet._preferred_walk_direction(rng) == -1, "dir: en el borde derecho camina a la izquierda")
	_pet._position.x = (rng.x + rng.y) * 0.5
	var dir: int = _pet._preferred_walk_direction(rng)
	_check(dir == 1 or dir == -1, "dir: en el centro decide aleatoriamente")


func _spawn_test_maus(side: int) -> void:
	_pet._maus_side = side
	_pet._spawn_maus(side)
	_pet._maus_active = true
	_pet._maus_timer = 0.0


func _advance_maus_until(phase: int, max_steps: int = 6000) -> void:
	var steps := 0
	while _pet._state == _pet.State.MAUS_CHASE and _pet._maus_phase != phase and steps < max_steps:
		_pet._tick_maus_chase(1.0 / 60.0)
		steps += 1


func _test_maus_chase_delay() -> void:
	_set_ground_state()
	_spawn_test_maus(-1)
	_pet._maus_timer = _pet.maus_chase_delay - 0.1
	_pet._tick_maus_wait(0.05)
	_check(_pet._state != _pet.State.MAUS_CHASE, "caza: antes de los 30s no inicia")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "caza: el maus sigue presente antes de los 30s")
	_pet._tick_maus_wait(0.1)
	_check(_pet._state == _pet.State.MAUS_CHASE, "caza: a los 30s inicia la secuencia")
	_check(_pet._maus_phase == _pet.MausPhase.WALK1, "caza: primera fase reproduce maus_walk1")
	_check(_pet._maus_flee_dir == 1, "caza: con el maus a la izquierda huye a la derecha")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "caza: el maus no desaparece al iniciar")

	_set_ground_state()
	_spawn_test_maus(1)
	_pet._maus_timer = _pet.maus_chase_delay
	_pet._tick_maus_wait(0.0)
	_check(_pet._state == _pet.State.MAUS_CHASE, "caza: dispara con el maus a la derecha")
	_check(_pet._maus_flee_dir == -1, "caza: con el maus a la derecha huye a la izquierda")


func _test_maus_chase_sequence() -> void:
	_set_ground_state()
	_pet.walk_speed = 500.0
	_spawn_test_maus(-1)
	_pet._start_maus_chase()
	_check(_pet._state == _pet.State.MAUS_CHASE, "secuencia: entra en estado MAUS_CHASE")
	_check(_pet._maus_phase == _pet.MausPhase.WALK1, "secuencia: empieza con maus_walk1")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "secuencia: maus presente en maus_walk1")
	_check(_pet._maus_stretched, "secuencia: la ventana se estira al iniciar")
	_check(_pet._pet.position.x != 0.0, "secuencia: la pet se dibuja desplazada dentro de la ventana")
	var win_anchor_check: float = float(_pet._window.position.x)
	var maus_screen_check: float = win_anchor_check + _pet._maus.position.x

	_advance_maus_until(_pet.MausPhase.WALK2_AWAY)
	_check(_pet._maus_phase == _pet.MausPhase.WALK2_AWAY, "secuencia: tras la espera pasa a maus_walk2")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "secuencia: maus presente mientras huye")

	_advance_maus_until(_pet.MausPhase.WALK3_RETURN)
	_check(_pet._maus_phase == _pet.MausPhase.WALK3_RETURN, "secuencia: tras salir de pantalla vuelve con maus_walk3")
	_check(_pet._position.x >= _pet._screen_bounds.end.x, "secuencia: salio de pantalla por el borde")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "secuencia: maus presente al volver")
	_check(_approx(float(_pet._window.position.x), win_anchor_check, 0.75), "secuencia: la ventana esta anclada mientras la pet camina")
	_check(_approx(float(_pet._window.position.x) + _pet._maus.position.x, maus_screen_check, 0.75), "secuencia: el maus queda fijo en pantalla al huir")

	_advance_maus_until(_pet.MausPhase.CATCH)
	_check(_pet._maus_phase == _pet.MausPhase.CATCH, "secuencia: al posicionarse frente al maus reproduce maus_catch")
	_check(_pet._maus != null and is_instance_valid(_pet._maus), "secuencia: maus presente en maus_catch")
	_check(_approx(float(_pet._window.position.x) + _pet._maus.position.x, maus_screen_check, 0.75), "secuencia: el maus sigue fijo en la vuelta")
	_check(_approx(_pet._position.x, _pet._maus_anchor_x + float(_pet._maus_side) * _pet.MAUS_CATCH_CLOSER_LEFT, 1.0), "secuencia: la pet se acerca al maus para maus_catch")

	var safety := 0
	while _pet._maus != null and _pet._maus_phase == _pet.MausPhase.CATCH and safety < 1000:
		_pet._tick_maus_chase(1.0 / 60.0)
		safety += 1
	_check(_pet._maus == null or not is_instance_valid(_pet._maus), "secuencia: el maus desaparece al empezar el ultimo frame de maus_catch")
	_check(_pet._maus_phase == _pet.MausPhase.CATCH, "secuencia: la desaparicion ocurre durante maus_catch, no en catch2")

	_advance_maus_until(_pet.MausPhase.CATCH2_AWAY)
	_check(_pet._maus_phase == _pet.MausPhase.CATCH2_AWAY, "secuencia: tras la espera reproduce maus_catch2")
	_check(_pet._maus == null or not is_instance_valid(_pet._maus), "secuencia: el maus no reaparece en maus_catch2")

	_advance_maus_until(_pet.MausPhase.RETURN_HOME)
	_check(_pet._maus_phase == _pet.MausPhase.RETURN_HOME, "secuencia: tras salir de nuevo regresa a la taskbar")

	var steps := 0
	while _pet._state == _pet.State.MAUS_CHASE and steps < 6000:
		_pet._tick_maus_chase(1.0 / 60.0)
		steps += 1
	_check(_pet._state == _pet.State.REST, "secuencia: al volver al centro termina en REST")
	var home_x: float = _pet._walk_bounds.position.x + (_pet._walk_bounds.size.x - float(_pet._window.size.x)) * 0.5
	_check(_approx(_pet._position.x, home_x, 2.0), "secuencia: vuelve al centro de la taskbar")
	_check(_approx(_pet._position.y, _pet._walk_bounds.end.y - float(_pet._window.size.y), 1.0), "secuencia: de vuelta en el suelo")
	_check(not _pet._maus_stretched, "secuencia: la ventana revierte el estirado al terminar")
	_check(_pet._window.size == WIN_SIZE, "secuencia: la ventana recupera su anchura original")
	_check(_pet._pet.position.x == 0.0, "secuencia: la pet vuelve al ancla de la ventana")