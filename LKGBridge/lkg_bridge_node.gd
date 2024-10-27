extends Node

const LKG_HOST = "http://127.0.0.1:33334/"

var http: HTTPRequest
var _orchestration_token: String = ""

@export var orchestration_string: String = "default"

@export var playlists_name: Array[String] = ["front", "back"]
@onready var rng := RandomNumberGenerator.new()
var _salt: String
var _hashed_playlists_name: Array[String] = []
var _current_cast_playlist: int = 0

func _ready() -> void:
	_salt = str(rng.randi_range(1000000, 9999999))
	for i in range(len(playlists_name)):
		var source := _salt + playlists_name[i]
		var target := source.hash()
		_hashed_playlists_name.push_back(str(target).left(10))

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

func test_is_bridge_alive() -> bool:
	if !_http_request_helper(_http_is_bridge_alive):
		return false
	var err := http.request(LKG_HOST)
	if err != OK:
		printerr("Something wrong with HTTP request ping. [%s]" % [error_string(err)])
	return true

signal bridge_alive_checked(result: bool)

func _http_is_bridge_alive(result, _response_code, _headers, _body):
	http.request_completed.disconnect(_http_is_bridge_alive)
	http.queue_free()
	http = null
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
	http.request_completed.disconnect(_got_bridge_version)
	http.queue_free()
	http = null
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Can't got bridge version.")
		got_bridge_version.emit("0.0.0")
	else:
		var s = b.get_string_from_utf8()
		var json_obj = JSON.parse_string(s)
		print(json_obj["payload"]["value"])
		got_bridge_version.emit(json_obj["payload"]["value"])

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

func _process_enter_orchestration(result, response_code, _headers, body):
	http.request_completed.disconnect(_process_enter_orchestration)
	http.queue_free()
	http = null
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Failed to enter orchestration (failed to send http request).")
		enter_orchestration_failed.emit()
		return
	if response_code != 200:
		printerr("Failed to enter orchestration: HTTP code %d" % response_code)
		enter_orchestration_failed.emit()
		return
	var s = body.get_string_from_utf8()
	var json_obj = JSON.parse_string(s)
	#print("got json [enter]:")
	#print(JSON.stringify(json_obj, "  "))
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
	http.request_completed.disconnect(_process_exit_orchestration)
	_orchestration_token = ""
	http.queue_free()
	http = null
	var s = body.get_string_from_utf8()
	var j = JSON.parse_string(s)
	print("got json [exit]:")
	print(JSON.stringify(j, "  "))
	#print(_body.get_string_from_utf8())
	exited_orchestration.emit()
	return
