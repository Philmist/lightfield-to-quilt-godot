extends SubViewportContainer

@onready var CropRect := $SubViewport/CropGuideRect
@onready var Lfv := $SubViewport/LightfieldView
var _origin: Vector2
@export var aspect_ratio_pixels: Vector2 = Vector2(1080, 1920)
@export var keep_aspect_ratio: bool = false
var crop_percentage: Rect2 = Rect2()
var image_pixels: Vector2i = Vector2i(1080, 1920)
var _inital_aspect_ratio_pixels: Vector2

var _mouse_pressed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	accept_event()
	var lfv = $SubViewport/LightfieldView
	image_pixels = Vector2i(lfv.DEFAULT_TEXTURE.get_width(), lfv.DEFAULT_TEXTURE.get_height())
	_inital_aspect_ratio_pixels = Vector2(aspect_ratio_pixels)
	reset_crop_rect()
	item_rect_changed.connect(on_size_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if _mouse_pressed:
		_set_rect_with_mouse()
	pass

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			var pos: Vector2 = get_local_mouse_position()
			CropRect.position = pos
			CropRect.size = Vector2(4, 4)
			if keep_aspect_ratio:
				var aspect := aspect_ratio_pixels.x / aspect_ratio_pixels.y
				CropRect.size = Vector2(4 * aspect, 4)
			_mouse_pressed = true
			_origin = Vector2(pos)
		else:
			_mouse_pressed = false
			_set_rect_with_mouse()
			var vp_r := Rect2(get_viewport_rect())
			vp_r.size = Vector2($SubViewport.size)
			print_verbose("SubViewport: %d, %d -> %d, %d" % [
				vp_r.position.x,
				vp_r.position.y,
				vp_r.end.x,
				vp_r.end.y
				])
			print_verbose("Crop: %d, %d -> %d, %d" % [
				CropRect.position.x,
				CropRect.position.y,
				CropRect.position.x + CropRect.size.x,
				CropRect.position.y + CropRect.size.y
				])
			_set_crop_rect_percentage()
			print_verbose("Percentage: %.1f, %.1f -> %.1f, %.1f" % [
				crop_percentage.position.x,
				crop_percentage.position.y,
				crop_percentage.end.x,
				crop_percentage.end.y
				])
	pass

func _set_crop_rect_percentage() -> void:
	var vp_r := Rect2(Vector2.ZERO, self.size)
	crop_percentage = Rect2(
		CropRect.position.x / vp_r.size.x * 100.0,
		CropRect.position.y / vp_r.size.y * 100.0,
		CropRect.size.x / vp_r.size.x * 100.0,
		CropRect.size.y / vp_r.size.y * 100.0
	)

func _calc_aspect_ratio() -> float:
	var viewport_size := Vector2(Lfv.get_size_pixels())
	if not keep_aspect_ratio:
		return 1.0
	var aspect: float = (
		aspect_ratio_pixels.x / aspect_ratio_pixels.y \
		* viewport_size.y / viewport_size.x
	)
	return aspect

func _set_rect_with_mouse() -> void:
	var mouse_pos: Vector2 = get_local_mouse_position()
	var vp_r: Rect2 = Rect2(Vector2.ZERO, self.size)
	if (mouse_pos.x > vp_r.end.x) or (mouse_pos.y > vp_r.end.y):
		return
	var crop: Rect2 = Rect2(CropRect.position, CropRect.size)
	crop.position = mouse_pos.min(_origin)
	crop.end = mouse_pos.max(_origin)
	if keep_aspect_ratio:
		var aspect := _calc_aspect_ratio()
		if (crop.size.y * aspect) > crop.size.x:
			crop.size.x = crop.size.y * aspect
		elif (crop.size.y * aspect) < crop.size.x:
			crop.size.y = crop.size.x / aspect
		crop.position = mouse_pos.min(_origin)
		var clamped_rect = Rect2(crop)
		clamped_rect.position = crop.position.clamp(Vector2.ZERO, crop.position)
		clamped_rect.end = crop.end.clamp(crop.end, vp_r.end)
		if (clamped_rect == crop):
			CropRect.size = crop.size
			CropRect.position = crop.position
	else:
		crop.position = crop.position.clamp(Vector2.ZERO, crop.position)
		crop.end = crop.end.clamp(crop.end, vp_r.end)
		CropRect.size = crop.size
		CropRect.position = crop.position
	_set_crop_rect_percentage()

func reset_crop_rect() -> void:
	crop_percentage = Rect2()
	aspect_ratio_pixels = Vector2(_inital_aspect_ratio_pixels)
	CropRect.size = Vector2(4, 4)
	if keep_aspect_ratio:
		var aspect := aspect_ratio_pixels.x / aspect_ratio_pixels.y
		CropRect.size = Vector2(4 * aspect, 4)
	var viewport: Rect2 = Rect2(Vector2.ZERO, self.size)
	var center := viewport.get_center()
	var crop: Rect2 = Rect2(CropRect.position, CropRect.size)
	var offset := center - crop.get_center()
	CropRect.position += offset


func set_crop_visiblity(visible: bool) -> void:
	CropRect.visible = visible

func on_size_changed() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, self.size)
	var crop_rect: Rect2 = Rect2(CropRect.position, CropRect.size)
	if !viewport_rect.has_area():
		return
	_helper_print_rect2_pos("PreChanged Rect", crop_rect)
	_helper_print_rect2_pos("Changed Viewport", viewport_rect)
	crop_rect.position.x = viewport_rect.size.x * crop_percentage.position.x / 100.0
	crop_rect.position.y = viewport_rect.size.y * crop_percentage.position.y / 100.0
	crop_rect.end.x = viewport_rect.size.x * crop_percentage.end.x / 100.0
	crop_rect.end.y = viewport_rect.size.y * crop_percentage.end.y / 100.0
	_helper_print_rect2_pos("AfterChanged", crop_rect)
	CropRect.position = crop_rect.position
	CropRect.size = crop_rect.size

func _helper_print_rect2_pos(name: String, rect: Rect2) -> void:
	print_verbose("%s: %d, %d -> %d, %d" % [
		name,
		rect.position.x,
		rect.position.y,
		rect.end.x,
		rect.end.y
	])
