extends Button

signal file_selected(files: PackedStringArray)

var file_dialog: FileDialog

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.pressed.connect(self._button_pressed)
	file_dialog = FileDialog.new()
	var filter := PackedStringArray(["*.jpg,*.jpeg,*.png;Image Files"])
	file_dialog.filters = filter
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.files_selected.connect(self._file_selected)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _button_pressed() -> void:
	file_dialog.deselect_all()
	file_dialog.show()
	pass

func _file_selected(files: PackedStringArray) -> void:
	file_selected.emit(files)
	pass


func _on_main_control_button_disabled_state_changed(disabled: bool) -> void:
	self.disabled = disabled
