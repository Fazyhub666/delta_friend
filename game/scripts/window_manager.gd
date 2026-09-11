extends Node

signal platforms_updated(platforms: Array)

const POLL_INTERVAL := 0.15
const HELPER_SCRIPT := "res://tools/window_scan.ps1"

var platforms: Array[Rect2] = []
var active := false

var _helper_pid := -1
var _out_path := ""
var _poll_timer := 0.0
var _scale := 1.0
var _restarts := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_scale = DisplayServer.screen_get_scale()
	_out_path = OS.get_environment("TEMP").path_join("delta_friend_windows.json")
	_start_helper()


func _process(delta: float) -> void:
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
	var script_path := ProjectSettings.globalize_path(HELPER_SCRIPT)
	_helper_pid = OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden",
		"-File", script_path,
		"-OutFile", _out_path,
		"-GamePid", str(OS.get_process_id()),
	]))
	active = _helper_pid > 0


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
			rects.append(Rect2(
				float(entry[0]) / _scale,
				float(entry[1]) / _scale,
				float(entry[2]) / _scale,
				float(entry[3]) / _scale
			))
	if rects != platforms:
		platforms = rects
		platforms_updated.emit(platforms)