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
	var s: AnimatedSprite2D = pet._pet.get_node("AnimatedSprite2D")
	var tsize: Vector2 = s.sprite_frames.get_frame_texture(s.animation, s.frame).get_size()
	var go := s.to_global(-tsize * 0.5)
	var g_rect := Rect2(go, s.to_global(tsize * 0.5) - go)
	var inside_hits := 0
	for off in [Vector2.ZERO, Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6)]:
		if pet._clicked_on_pet(g_rect.get_center() + off):
			inside_hits += 1
	var left_hit: bool = pet._clicked_on_pet(g_rect.position + Vector2(-24.0, g_rect.size.y * 0.5))
	var right_hit: bool = pet._clicked_on_pet(Vector2(g_rect.end.x + 24.0, go.y + g_rect.size.y * 0.5))
	print("[TEST] sprite hitbox interior_hits=", inside_hits, " left=", left_hit, " right=", right_hit)
	if inside_hits == 0 or left_hit or right_hit:
		print("[TEST] FAIL sprite hitbox")
		get_tree().quit(1)


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
				var sp: AnimatedSprite2D = pet._pet.get_node("AnimatedSprite2D")
				var base := 0.0
				for i in sp.sprite_frames.get_frame_count("jump"):
					base += sp.sprite_frames.get_frame_duration("jump", i)
				base /= sp.sprite_frames.get_animation_speed("jump")
				var expected_ss := base / 0.41
				print("[TEST] in air, vel=", pet._velocity, " anim=", sp.animation, " ss=", sp.speed_scale, " expected_ss=", expected_ss)
				if sp.animation != "jump" or absf(sp.speed_scale - expected_ss) > 0.05:
					print("[TEST] FAIL jump animation")
					get_tree().quit(1)
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