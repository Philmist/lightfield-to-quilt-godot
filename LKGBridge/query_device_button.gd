extends Button


func _ready() -> void:
	self.pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if !%LKGBridgeNode.is_inside_of_orchestration():
		printerr("Can't query devices because haven't entered orchestration.")
		%RichTextLabel.text += "\nCan't query devices: [color=red]outside[/color] of orchestration."
	else:
		%LKGBridgeNode.query_available_devices()
