extends Button


func _ready() -> void:
	self.pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if %LKGBridgeNode.get_bridge_version():
		var version = await %LKGBridgeNode.got_bridge_version
		%RichTextLabel.text += "\nGot Bridge version: [color=green]%s[/color]" % version
