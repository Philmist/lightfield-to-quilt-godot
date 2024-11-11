extends Button


func _ready() -> void:
	self.pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if %LKGBridgeNode.test_is_bridge_alive():
		var result = await $"%LKGBridgeNode".bridge_alive_checked
		if result == false:
			%RichTextLabel.text += "\nSomething [color=red]wrong[/color] when ping."
		else:
			%RichTextLabel.text += "\nPing [color=green]completed[/color]."
