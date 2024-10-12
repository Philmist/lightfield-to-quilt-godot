extends Button

signal file_selected(path: String)

var file_dialog: FileDialog
var aspect_ratio: float = 0.65
var quilt_size: Vector2i = Vector2i(8, 6)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	file_dialog = FileDialog.new()
	var filter := PackedStringArray(["*.jpg,*.jpeg;JPEG Image Files"])
	file_dialog.filters = filter
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.file_selected.connect(_on_file_selected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_control_button_disabled_state_changed(disabled: bool) -> void:
	# this button should be enabled explictly.
	if disabled:
		self.disabled = disabled


func _on_pressed() -> void:
	file_dialog.deselect_all()
	file_dialog.current_file = "_qs%dx%da%.2f.jpg" % [
		quilt_size.x,
		quilt_size.y,
		aspect_ratio
	]
	file_dialog.show()

func _on_file_selected(path: String) -> void:
	print(path)
	file_selected.emit(path)
