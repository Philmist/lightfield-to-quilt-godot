extends Button

@onready var _bridge = $LKGBridgeNode

enum LKGBridgeState {
	BEFORE_CHECK,
	ALIVE,
	ENTERED,
	EXITED
}
var _lkg_state: LKGBridgeState = LKGBridgeState.BEFORE_CHECK

func _ready() -> void:
	self.text = "Ping Bridge"
	self.pressed.connect(_on_pressed)
	_bridge.got_bridge_version.connect(_on_bridge_version_recieved)
	_bridge.enter_orchestration_succeeded.connect(_on_succsess_enter_orchestration)
	_bridge.exited_orchestration.connect(_on_exit_orchestration)
	self.disabled = false

func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	match _lkg_state:
		LKGBridgeState.BEFORE_CHECK:
			_on_pressed_ping()
		LKGBridgeState.ALIVE:
			_on_pressed_enter_orchestration()
		LKGBridgeState.ENTERED:
			_on_pressed_exit_orchestration()
		_:
			print("Something is wrong at LKGButton.")

func _on_pressed_ping() -> void:
	var r = _bridge.get_bridge_version()
	if !r:
		printerr("Can't send ping to bridge.")
		return
	self.disabled = true

func _on_ping_result_recieved(alive: bool) -> void:
	if !alive:
		printerr("Bridge is NOT alive.")
		self.disabled = false
		return
	self.text = "Enter orches"
	_lkg_state = LKGBridgeState.ALIVE
	self.disabled = false

func _on_bridge_version_recieved(ver: String) -> void:
	if ver == "0.0.0":
		printerr("Can't get bridge version.")
	else:
		self.text = "Enter orches"
		_lkg_state = LKGBridgeState.ALIVE
	self.disabled = false

func _on_pressed_enter_orchestration() -> void:
	var r = _bridge.enter_orchestration()
	if !r:
		printerr("Can't try to enter orchestration.")
		return
	self.disabled = true

func _on_succsess_enter_orchestration() -> void:
	self.disabled = false
	_lkg_state = LKGBridgeState.ENTERED
	self.text = "Exit orches"

func _on_pressed_exit_orchestration() -> void:
	if !_bridge.exit_orchestration():
		printerr("Can't try to exit orchetration.")
		return
	self.disabled = true

func _on_exit_orchestration() -> void:
	self.disabled = false
	_lkg_state = LKGBridgeState.EXITED
