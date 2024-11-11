extends Node

@export var LKG_ADDRESS: String = "127.0.0.1"
@export var LKG_PORT: int = 33334
@onready var LKG_HOST = "http://%s:%s/" % [LKG_ADDRESS, LKG_PORT]

var http: HTTPRequest
var _orchestration_token: String = ""
func is_inside_of_orchestration():
	return _orchestration_token != null and len(_orchestration_token) > 0
func create_payload_for_orchestration():
	return { "orchestration": _orchestration_token }

@export var orchestration_string: String = "default"

const playlist_prefix = "LkgG-Cast_"
@export var playlists_name: Array[String] = ["front", "back"]
@onready var rng := RandomNumberGenerator.new()
var _salt: String
var hashed_playlists_name: Array[String]
enum PlaylistState {
	DEAD,
	PENDING,
	ALIVE
}
var _playlists_state: Array[PlaylistState]
var _current_cast_playlist: int = 0

# --------------------------------------

func _ready() -> void:
	# Make name of playlists
	if len(playlists_name) < 2:
		printerr("Length of playlists must be grater than 2.")
		playlists_name = ["front", "back"]
	_salt = str(rng.randi_range(10000, 99999))
	hashed_playlists_name = []
	_playlists_state = []
	for i in range(len(playlists_name)):
		var source := _salt + playlists_name[i]
		var target := source.hash()
		hashed_playlists_name.push_back(playlist_prefix + str(target).left(10))
		_playlists_state.push_back(PlaylistState.DEAD)
	# Signals
	enter_orchestration_succeeded.connect(_on_enter_orchestration_succeeded)
	enter_orchestration_failed.connect(_on_enter_orchestration_failed)
	# Be aware of this line. We need to call quit() by ourselves.
	get_tree().set_auto_accept_quit(false)

# ----------------------------------------

signal json_received(json_str: String)

func _emit_json_str_on_debug(json_obj) -> void:
	var json_str = JSON.stringify(json_obj, "  ")
	if OS.is_debug_build():
		json_received.emit(json_str)

func _http_request_helper(sig: Callable) -> bool:
	if http:
		return false
	http = HTTPRequest.new()
	self.add_child(http)
	http.request_completed.connect(sig)
	return true

func _request(endpoint: String, data: Dictionary = {}) -> Error:
	const METHOD = HTTPClient.METHOD_PUT
	var header = PackedStringArray([
		"Content-Type: application/json; charset=utf-8"
	])
	endpoint = endpoint.lstrip("/ ")
	endpoint = endpoint.rstrip("/ ")
	var uri = LKG_HOST + endpoint
	var json_str := JSON.stringify(data)
	var err := http.request(uri, header, METHOD, json_str)
	return err

func _free_http(f: Callable) -> void:
	http.request_completed.disconnect(f)
	http.queue_free()
	http = null

# ------------------------------------

func test_is_bridge_alive() -> bool:
	if !_http_request_helper(_http_is_bridge_alive):
		return false
	var err := http.request(LKG_HOST)
	if err != OK:
		printerr("Something wrong with HTTP request ping. [%s]" % [error_string(err)])
	return true

signal bridge_alive_checked(result: bool)

func _http_is_bridge_alive(result, _response_code, _headers, _body):
	_free_http(_http_is_bridge_alive)
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("HTTP request to Bridge is failed.")
		bridge_alive_checked.emit(false)
	else:
		print("LKG Bridge is alive.")
		bridge_alive_checked.emit(true)

func get_bridge_version() -> bool:
	if !_http_request_helper(_got_bridge_version):
		return false
	var err := http.request(
			LKG_HOST + "bridge_version",
			PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_PUT,
			"{}"
		)
	if err != OK:
		printerr("Something wrong at getting bridge version. [%s]" % error_string(err))
		return false
	return true

signal got_bridge_version(version: String)

func _got_bridge_version(result, response_code, _headers, body) -> void:
	var b = PackedByteArray(body)
	print("/bridge_version: code [%d]" % response_code)
	_free_http(_got_bridge_version)
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Can't got bridge version.")
		got_bridge_version.emit("0.0.0")
	else:
		var s = b.get_string_from_utf8()
		var json_obj = JSON.parse_string(s)
		_emit_json_str_on_debug(json_obj)
		got_bridge_version.emit(String(json_obj["payload"]["value"]))

func enter_orchestration() -> bool:
	if !_http_request_helper(_process_enter_orchestration):
		enter_orchestration_failed.emit()
		return false
	var json_str = JSON.stringify({
		"name": orchestration_string
	})
	var err := http.request(
			LKG_HOST + "enter_orchestration",
			PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_PUT,
			json_str
		)
	if err != OK:
		printerr("Something wrong with HTTP request to enter orchestration. [%s]" % [error_string(err)])
	return true

signal enter_orchestration_succeeded
signal enter_orchestration_failed
signal try_enter_orchestration(result: bool)

func _on_enter_orchestration_succeeded() -> void:
	try_enter_orchestration.emit(true)

func _on_enter_orchestration_failed() -> void:
	try_enter_orchestration.emit(false)

func _process_enter_orchestration(result, response_code, _headers, body):
	_free_http(_process_enter_orchestration)
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Failed to enter orchestration (failed to send http request).")
		enter_orchestration_failed.emit()
		return
	if response_code != 200:
		printerr("Failed to enter orchestration: HTTP response code %d" % response_code)
		enter_orchestration_failed.emit()
		return
	var s = body.get_string_from_utf8()
	var json_obj = JSON.parse_string(s)
	_emit_json_str_on_debug(json_obj)
	if json_obj == null:
		printerr("Parsing json failed.")
		enter_orchestration_failed.emit()
		return
	elif typeof(json_obj) != TYPE_DICTIONARY:
		printerr("enter_orchestration doesn't return dictionary.")
		enter_orchestration_failed.emit()
		return
	elif not ("payload" in json_obj and "status" in json_obj):
		printerr("something wrong with orchestration json")
		printerr(json_obj)
		enter_orchestration_failed.emit()
		return
	_orchestration_token = String(json_obj["payload"]["value"])
	print("got orchestration token: %s" % [_orchestration_token])
	enter_orchestration_succeeded.emit()
	return

func exit_orchestration() -> bool:
	if !_http_request_helper(_process_exit_orchestration):
		printerr("Can't exit orchetration because creating http request is failed.")
		return false
	var payload = { "orchestration": _orchestration_token }
	var _err := _request("exit_orchestration", payload)
	return true

signal exited_orchestration

func _process_exit_orchestration(_result, _code, _headers, body):
	_free_http(_process_exit_orchestration)
	_orchestration_token = ""
	var s = body.get_string_from_utf8()
	var j = JSON.parse_string(s)
	_emit_json_str_on_debug(j)
	print("got json [exit]:")
	print(JSON.stringify(j, "  "))
	_orchestration_token = ""
	exited_orchestration.emit()
	return

var _binded_func_playlist: Callable

func create_initial_playlist() -> bool:
	var index = _playlists_state.find(PlaylistState.DEAD)
	while (index > -1):  # there is no do-while
		_playlists_state[index] = PlaylistState.PENDING
		_binded_func_playlist = _process_create_initial_playlist.bind(index)
		if !_http_request_helper(_binded_func_playlist):
			printerr("Something wrong at creating playlists.")
			var c := _playlists_state.count(PlaylistState.DEAD)
			printerr("Left: %d + 1" % [c])
			return false
		index = _playlists_state.find(PlaylistState.DEAD)
		pass  # TODO: write here
	return true

func _process_create_initial_playlist(index, result, code, _headers, body):
	_free_http(_binded_func_playlist)
	if !result == HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Something wrong at playlist creation: HTTPRequest '%s'[%d]" % [
			hashed_playlists_name[index],
			index
			])
	print("/instance_playlist: HTTP response code %d" % [code])
	if code != 200:
		printerr("!")
		_playlists_state[index] = PlaylistState.DEAD
	var s = body.get_string_from_utf8()
	var json_obj = JSON.parse_string(s) as Dictionary
	# TODO: write here


func query_available_devices() -> bool:
	if !_http_request_helper(_process_query_available_devices):
		printerr("Can't request to query available devices.")
		return false
	var payload = { "orchestration": _orchestration_token }
	var err := _request("available_output_devices", payload)
	if err != OK:
		printerr("Something wrong at querying available devices: [%s]" % [error_string(err)])
		return false
	return true

var recent_available_devices
signal answered_available_devices(result: bool)

func _process_query_available_devices(result, code, _headers, body):
	_free_http(_process_query_available_devices)
	var r_tuple = [result, code]
	match r_tuple:
		[HTTPRequest.Result.RESULT_SUCCESS, 200]:
			var s = (body as PackedByteArray).get_string_from_utf8()
			var j_obj = JSON.parse_string(s)
			_emit_json_str_on_debug(j_obj)
			if "payload" in j_obj and "value" in j_obj["payload"]:
				recent_available_devices = j_obj["payload"]["value"]
				print("List available devices: got answer")
			else:
				answered_available_devices.emit(false)
		[HTTPRequest.Result.RESULT_SUCCESS, _]:
			printerr("List available devices failed: HTTP code %d" % [code])
			answered_available_devices.emit(false)
		_:
			printerr("List available devices failed: something wrong at HTTP request (%d)" % [result])
			answered_available_devices.emit(false)

# ----------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Exit procedure is starting.")
		var hc = HTTPClient.new()
		if _orchestration_token != "":
			# See: https://docs.godotengine.org/en/4.3/tutorials/networking/http_client_class.html
			if hc.connect_to_host(LKG_ADDRESS, LKG_PORT) == OK:
				while hc.get_status() == HTTPClient.STATUS_CONNECTING or hc.get_status() == HTTPClient.STATUS_RESOLVING:
					hc.poll()
					await get_tree().process_frame
				var json_str = JSON.stringify({ "orchestration": _orchestration_token })
				var _err := hc.request(
					HTTPClient.METHOD_PUT,
					"/exit_orchestration",
					PackedStringArray(["Content-Type: application/json"]),
					json_str
					)
				while hc.get_status() == HTTPClient.STATUS_REQUESTING:
					hc.poll()
					await get_tree().process_frame
				if hc.has_response():
					var code = hc.get_response_code()
					print("Exit: /exit_orchestration -> HTTP response code %d" % [code])
					var rb = PackedByteArray()
					while hc.get_status() == HTTPClient.STATUS_BODY:
						hc.poll()
						var chunk = hc.read_response_body_chunk()
						if chunk.size() == 0:
							await get_tree().process_frame
						else:
							rb = rb + chunk
					print("Got response :")
					#print(rb.get_string_from_utf8())
					var jobj = JSON.parse_string(rb.get_string_from_utf8())
					print(JSON.stringify(jobj, "  "))
				hc.close()
		_orchestration_token = ""
		get_tree().quit()
