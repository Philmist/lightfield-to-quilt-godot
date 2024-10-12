extends HBoxContainer

@onready var parent = $"/root"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.size = parent.size
	pass


func _on_main_control_resized() -> void:
	self.size = parent.size
	pass # Replace with function body.
