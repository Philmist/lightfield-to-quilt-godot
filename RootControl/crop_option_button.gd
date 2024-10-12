extends OptionButton

enum CropAspectOption {
	DISABLE = 0,
	FREE = 1,
	GO = 2,
	PORTRAIT = 3
}

const LKG_GO_PIXELS := Vector2(1440, 2560)
const LKG_PORTRAIT_PIXELS := Vector2(1536, 2048)

class CropOption:
	var enable: bool = false
	var target: CropAspectOption = CropAspectOption.DISABLE
	var aspect_pixels: Vector2 = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func reset() -> void:
	self.selected = 0
	item_selected.emit(self.selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_crop_option() -> CropOption:
	var retval := CropOption.new()
	match selected:
		1:
			retval.enable = true
			retval.target = CropAspectOption.FREE
		2:
			retval.enable = true
			retval.target = CropAspectOption.GO
			retval.aspect_pixels = Vector2(LKG_GO_PIXELS)
		3:
			retval.enable = true
			retval.target = CropAspectOption.PORTRAIT
			retval.aspect_pixels = Vector2(LKG_PORTRAIT_PIXELS)
	return retval
