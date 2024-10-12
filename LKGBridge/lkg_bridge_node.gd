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
		printerr("Something wrong with HTTP request. [%s]" % [err])
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
	if http:
		return false
	return true

signal enter_orchestration_succeeded

func _process_enter_orchestration(result, response_code, _headers, body):
	http.request_completed.disconnect(_process_enter_orchestration)
	http.queue_free()
	http = null
	if result != HTTPRequest.Result.RESULT_SUCCESS:
		printerr("Failed to enter orchestration.")
		return
	if response_code != 200:
		printerr("Failed to enter orchestration: HTTP code %d" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
