extends Node

signal platforms_updated(platforms: Array)

const POLL_INTERVAL := 0.15
const HELPER_SCRIPT := "res://tools/window_scan.ps1"

var platforms: Array[Rect2] = []
var active := false

var _helper_pid := -1
var _out_path := ""
var _helper_path := ""
var _poll_timer := 0.0
var _scale := 1.0
var _restarts := 0
var _retry_timer := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_scale = DisplayServer.screen_get_scale()
	_out_path = OS.get_environment("TEMP").path_join("delta_friend_windows.json")
	_start_helper()


func _process(delta: float) -> void:
	if not active and _helper_path != "":
		_retry_timer += delta
		if _retry_timer >= POLL_INTERVAL * 20.0:
			_retry_timer = 0.0
			_start_helper()
	if not active:
		return
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_refresh()


func _exit_tree() -> void:
	_stop_helper()


func _start_helper() -> void:
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		return
	_helper_path = _materialize_helper()
	if _helper_path == "":
		active = false
		return
	var script_path := _helper_path
	_helper_pid = OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden",
		"-File", script_path,
		"-OutFile", _out_path,
		"-GamePid", str(OS.get_process_id()),
	]))
	active = _helper_pid > 0


func _materialize_helper() -> String:
	var source := FileAccess.get_file_as_string(HELPER_SCRIPT)
	if source.is_empty():
		push_error("window_manager: no se pudo leer " + HELPER_SCRIPT)
		return ""
	var script_dir := OS.get_environment("TEMP").path_join("delta_friend_helper")
	DirAccess.make_dir_recursive_absolute(script_dir)
	var target := script_dir.path_join("window_scan.ps1")
	var f := FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		push_error("window_manager: no se pudo escribir " + target)
		return ""
	f.store_string(source)
	f.close()
	return target


func _stop_helper() -> void:
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		OS.kill(_helper_pid)
	active = false


func _refresh() -> void:
	if not OS.is_process_running(_helper_pid):
		if _restarts >= 3:
			active = false
			return
		_restarts += 1
		_start_helper()
		return
	if not FileAccess.file_exists(_out_path):
		return
	var text := FileAccess.get_file_as_string(_out_path)
	var data = JSON.parse_string(text)
	if not (data is Array):
		return
	var rects: Array[Rect2] = []
	for entry in data:
		if entry is Array and entry.size() >= 4:
			var all_numeric := true
			var vals: Array[float] = []
			for v in entry:
				if v is float or v is int:
					vals.append(float(v))
				else:
					all_numeric = false
					break
			if not all_numeric:
				continue
			rects.append(Rect2(
				vals[0] / _scale,
				vals[1] / _scale,
				vals[2] / _scale,
				vals[3] / _scale
			))
	if rects != platforms:
		platforms = rects
		platforms_updated.emit(platforms)