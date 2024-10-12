extends ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_control_loading_progress_changed(percent: float) -> void:
	self.value = percent
	pass # Replace with function body.
