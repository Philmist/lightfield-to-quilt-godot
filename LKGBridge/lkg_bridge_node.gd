extends Node

const LKG_HOST = "http://127.0.0.1:33334/"

var http: HTTPRequest
var _orchestration_token: String = ""

@export var orchestration_string: String = "default"

func _http_request_helper(sig: Callable) -> bool:
	if http:
		return false
	http = HTTPRequest.new()
	self.add_child(http)
	http.request_completed.connect(sig)
	return true

func test_is_bridge_alive() -> bool:
	if !_http_request_helper(_http_is_bridge_alive):
		return false
	var err := http.request(LKG_HOST)
	if err != OK:
		printerr("Something wrong with HTTP request ping. [%s]" % [error_string(err)])
	return true

signal bridge_alive_checked(result: bool)

func _http_is_bridge_alive(result, response_code, _headers, _body):
	print(response_code)
	http.request_completed.disconnect(_http_is_bridge_alive)
	http.queue_free()
	http = null
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("HTTP request to Bridge is failed.")
		bridge_alive_checked.emit(false)
	else:
		print("LKG Bridge is alive.")
		bridge_alive_checked.emit(true)

func enter_orchestration() -> bool:
	if !_http_request_helper(_process_enter_orchestration):
		enter_orchestration_failed.emit()
		return false
	var json_str = JSON.stringify({
		"name": orchestration_string
	})
	var err := http.request(
		LKG_HOST + "enter_orchestration",
		PackedStringArray(),
		HTTPClient.METHOD_POST,
		json_str
		)
	if err != OK:
		printerr("Something wrong with HTTP request to enter orchestration. [%s]" % [error_string(err)])
	return true

signal enter_orchestration_succeeded(status: String)
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
	var json_obj = JSON.parse_string(body.get_string_from_utf8()) as Dictionary
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
	var status = String(json_obj["status"]["value"])
	enter_orchestration_succeeded.emit(status)
	return

func exit_orchestration() -> bool:
	if !_http_request_helper(_process_exit_orchestration):
		printerr("Can't exit orchetration because creating http request is failed.")
		return false
	var json_str := JSON.stringify({
		"orchestration": _orchestration_token
	})
	var err := http.request(
		LKG_HOST + "exit_orchestration"
	)
	return true

func _process_exit_orchestration(_result, _code, _headers, _body):
	http.request_completed.disconnect(_process_exit_orchestration)
	_orchestration_token = ""
	http.queue_free()
	http = null
	return
