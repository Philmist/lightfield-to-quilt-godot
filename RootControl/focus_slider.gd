extends HSlider

@onready var label = $"../FocusValueLabel"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label.text = "Focus: %+.5f" % self.value
	pass


func _on_main_control_button_disabled_state_changed(disabled: bool) -> void:
	self.editable = !disabled
