extends Control

@onready var debug_check_button = $HBoxContainer/VFlowContainer/DebugCheckButton
@onready var text_clear_button = $HBoxContainer/VFlowContainer/TextClearButton

var key_regex: RegEx

func _ready() -> void:
	%LKGBridgeNode.json_received.connect(_on_json_recieved)
	text_clear_button.pressed.connect(_on_text_clear_pressed)
	key_regex = RegEx.new()
	key_regex.compile("([\"']\\S+?[\"'])\\s*?:")  # caution with escape character(\)

func _process(delta: float) -> void:
	pass

func _on_json_recieved(json_str: String) -> void:
	if debug_check_button.button_pressed:
		var re_str = key_regex.sub(json_str, "[color=green]$1[/color]:", true)
		%RichTextLabel.text += "\n"
		%RichTextLabel.text += re_str
		%RichTextLabel.text += "\n"

func _on_text_clear_pressed() -> void:
	%RichTextLabel.text = "Cleared.\n"
