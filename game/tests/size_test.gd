extends Node

const SCENE := preload("res://scenes/desktop_pet/desktop_pet.tscn")

var pet: Node2D


func _ready() -> void:
	Windows.active = false
	Windows._stop_helper()
	Windows._helper_pid = OS.get_process_id()
	Windows._out_path = OS.get_environment("TEMP").path_join("delta_friend_never.json")
	pet = SCENE.instantiate()
	add_child(pet)
	print("[TEST] headless base_win=", pet._base_win_size, " window=", pet._window.size)
	var ok := true

	if not is_equal_approx(pet._size_scale, 1.5):
		print("[TEST] FAIL default scale=", pet._size_scale)
		ok = false
	var base := Vector2(pet._base_win_size)
	if pet._window.size != Vector2i(round(base * 1.5)):
		print("[TEST] FAIL default window size=", pet._window.size, " base=", base)
		ok = false
	if not is_equal_approx(pet._pet.scale.x, 1.5):
		print("[TEST] FAIL default pet scale=", pet._pet.scale)
		ok = false

	var expected_scales := [1.0, 1.5, 2.0, 2.5, 3.0]
	var expected_labels := ["x0.5", "x1.0", "x1.5", "x2.0", "x2.5"]
	if pet.SIZE_SCALES != expected_scales or pet.SIZE_LABELS != expected_labels:
		print("[TEST] FAIL labels/scales ", pet.SIZE_SCALES, " ", pet.SIZE_LABELS)
		ok = false

	for i in pet.SIZE_OPT_IDS.size():
		if not is_equal_approx(pet.SIZE_SCALES[i], expected_scales[i]):
			ok = false
			print("[TEST] FAIL scale idx ", i)

	pet._set_pet_scale(1.0)
	if pet._window.size != Vector2i(base):
		print("[TEST] FAIL reset window=", pet._window.size)
		ok = false
	if not is_equal_approx(pet._pet.scale.x, 1.0):
		print("[TEST] FAIL reset pet scale=", pet._pet.scale)
		ok = false

	pet._set_pet_scale(1.5)
	if pet._window.size != Vector2i(round(base * 1.5)):
		print("[TEST] FAIL re-apply window=", pet._window.size)
		ok = false

	var checked_idx := -1
	for i in pet.SIZE_OPT_IDS.size():
		var ii: int = pet._context_menu.get_item_index(pet.SIZE_OPT_IDS[i])
		if pet._context_menu.is_item_checked(ii):
			checked_idx = i
	if checked_idx != 1:
		print("[TEST] FAIL checkmark idx=", checked_idx)
		ok = false

	print("[TEST] ", "PASS" if ok else "FAIL", " default=", pet._size_scale, " size=", pet._window.size, " labels=", pet.SIZE_LABELS)
	get_tree().quit(0 if ok else 1)