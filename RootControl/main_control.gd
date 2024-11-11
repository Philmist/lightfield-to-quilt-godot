extends HBoxContainer

signal loading_progress_changed(percent: float)
signal button_disabled_state_changed(disabled: bool)

enum QuiltImageState {
	NONE,
	IMAGE_LOADING,
	IMAGE_LOADED,
	QUILT_CREATING,
	QUILT_CREATED,
}

@onready var description_label = $HorizontalSplitContainer/InformationVBoxContainer/DescriptionLabel as Label
var images: Array[Image] = []
var textures: Texture2DArray
var image_load_thread: Thread
var image_load_mutex: Mutex
@onready var browse_button = $HorizontalSplitContainer/InformationVBoxContainer/ButtonContainer/FileBrowseButton as Button
var load_start_msec: float
var load_end_msec: float
@onready var lfv_scene = %LightfieldView
@onready var slider = %FocusSlider
@onready var loading_progress = %ImageLoadingProgressBar
@onready var quilt_scene = %QuiltView
@onready var lightfield_viewport = %LightfieldSubViewportContainer
@onready var get_crop_option: Callable = %CropOptionButton.get_crop_option
var quilt_create_thread: Thread
var state: QuiltImageState
@onready var _lkg_bridge_scene: PackedScene = load("res://LKGBridge/lkg_bridge_node.tscn")
var lkg_bridge
@onready var lkg_bridge_button = $HorizontalSplitContainer/InformationVBoxContainer/QuiltButtonHBoxContainer/LKGButton
const FOCUS_SCALE = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	image_load_mutex = Mutex.new()
	image_load_thread = Thread.new()
	quilt_create_thread = Thread.new()
	load_start_msec = Time.get_ticks_msec()
	load_end_msec = Time.get_ticks_msec()
	state = QuiltImageState.NONE
	slider.value = 0.0
	get_viewport().files_dropped.connect(_on_files_dropped)
	lkg_bridge = _lkg_bridge_scene.instantiate()
	add_child(lkg_bridge)
	lkg_bridge_button.pressed.connect(lkg_bridge.test_is_bridge_alive)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if (!image_load_thread.is_alive() and state == QuiltImageState.IMAGE_LOADING):
		image_load_thread.wait_to_finish()
		_set_lightfield_texture()
		%QuiltSubViewportContainer.visible = false
		%LightfieldSubViewportContainer.visible = true
		load_end_msec = Time.get_ticks_msec()
		button_disabled_state_changed.emit(false)
		if len(images) == 0:
			description_label.text += "Image Loading is failed.\n"
			state = QuiltImageState.NONE
			return
		var frame_size := images[0].get_size()
		description_label.text += "Finished.\nElapsed: %s msec\n" % (load_end_msec - load_start_msec)
		var sqrt_pixels := sqrt(frame_size.x * frame_size.y * len(images))
		lightfield_viewport.image_pixels = frame_size
		if quilt_scene.IMAGE_MAX_SIDE_PIXEL < sqrt_pixels:
			description_label.text += "Quilt creation may be fail: pixel^(1/2)=%d" % [ceil(sqrt_pixels)]
		state = QuiltImageState.IMAGE_LOADED
	elif (!quilt_create_thread.is_alive() and state == QuiltImageState.QUILT_CREATING):
		quilt_create_thread.wait_to_finish()
		if quilt_scene.quilt_image is not Image:
			description_label.text += "Quilt creation is failed.\n"
			description_label.text += "Width: %d, Height: %d\nMAX: %d" %[
				quilt_scene.quilt_image_size.x,
				quilt_scene.quilt_image_size.y,
				quilt_scene.IMAGE_MAX_SIDE_PIXEL
			]
			state = QuiltImageState.IMAGE_LOADED
			%QuiltSubViewportContainer.visible = false
			%LightfieldSubViewportContainer.visible = true
			button_disabled_state_changed.emit(false)
			return
		%QuiltView.display_quilt()
		load_end_msec = Time.get_ticks_msec()
		%QuiltSubViewportContainer.visible = true
		%LightfieldSubViewportContainer.visible = false
		button_disabled_state_changed.emit(false)
		description_label.text += "Finished.\nElapsed: %s msec\n" % (load_end_msec - load_start_msec)
		state = QuiltImageState.QUILT_CREATED
		description_label.text += "Quilt size: Col %d x Row %d, Total %d frames\nQuilt image: %d x %d\n" % [
		quilt_scene.quilt_view_size.x,
		quilt_scene.quilt_view_size.y,
		len(quilt_scene.images),
		quilt_scene.quilt_image.get_width(),
		quilt_scene.quilt_image.get_height()
		]
		var frame_size = quilt_scene.frame_size as Vector2i
		description_label.text += "Frame size: %d x %d, Aspect ratio: %.2f\n" % [
			frame_size.x,
			frame_size.y,
			float(frame_size.x) / float(frame_size.y)
		]
		%SaveQuiltButton.aspect_ratio = float(frame_size.x) / float(frame_size.y)
		%SaveQuiltButton.quilt_size = Vector2i(quilt_scene.quilt_view_size)
		%SaveQuiltButton.disabled = false
	lfv_scene.set_focus(slider.value)


func _on_file_browse_button_file_selected(files: PackedStringArray) -> void:
	description_label.text = "Loading...\n"
	%SaveQuiltButton.disabled = true
	%QuiltSubViewportContainer.visible = false
	%LightfieldSubViewportContainer.visible = true
	%QuiltView.reset_display()
	%CropOptionButton.reset()
	button_disabled_state_changed.emit(true)
	images.clear()
	state = QuiltImageState.IMAGE_LOADING
	load_start_msec = Time.get_ticks_msec()
	var image_load_callable: Callable = _image_load_process.bind(files)
	image_load_thread.start(image_load_callable)

func _image_load_process(files: PackedStringArray) -> void:
	var percent: float = 0.0
	files.sort()
	for i in range(len(files)):
		var image = Image.new()
		var err: Error = image.load(files[i])
		if err:
			var err_str = "Image load err: %d(%s)" % [err, error_string(err)]
			printerr(err_str)
			description_label.text = err_str + "\n"
			loading_progress_changed.emit.call_deferred(0.0)
			images.clear()
			textures = null
			return
		image_load_mutex.lock()
		images.append(image)
		image_load_mutex.unlock()
		percent = max((float(i+1) / len(files) * 100.0) - 0.1, 0.0)
		loading_progress_changed.emit.call_deferred(percent)
	var texs = Texture2DArray.new()
	images.reverse()
	var err = texs.create_from_images(images)
	if err:
		loading_progress_changed.emit.call_deferred(0.0)
		images.clear()
		textures = null
	else:
		loading_progress_changed.emit.call_deferred(100.0)
		textures = texs

func _set_lightfield_texture() -> void:
	if len(images) > 0:
		lfv_scene.set_texture_array(textures, len(images))

func _flip_images_order() -> void:
	if not len(images) > 1:
		return
	button_disabled_state_changed.emit(true)
	images.reverse()
	var texs = Texture2DArray.new()
	var err	= texs.create_from_images(images)
	if err:
		images.reverse()
	else:
		textures = texs
		_set_lightfield_texture()
	button_disabled_state_changed.emit(false)


func _on_create_quilt_button_pressed() -> void:
	if len(images) < 2:
		description_label.text += "Cannot create quilt (less than 2 images).\n"
		return
	quilt_scene.images = images
	quilt_scene.focus = slider.value
	var crop_percentage := Rect2(%LightfieldSubViewportContainer.crop_percentage)
	var crop_option = get_crop_option.call()
	if crop_option.enable == true and (\
	min(crop_percentage.position.x, crop_percentage.position.y) < 0\
	or max(crop_percentage.end.x, crop_percentage.end.y) > 100\
	):
		description_label.text += "Cannot create quilt (crop region extends beyond).\n"
		return
	description_label.text = "Creating...\n"
	var crop_pixels := Rect2i()
	if crop_option.enable == true:
		var size = images[0].get_size()
		crop_pixels.position = Vector2i((Vector2(size) * (crop_percentage.position / 100.0)).floor())
		crop_pixels.end = Vector2i((Vector2(size) * (crop_percentage.end / 100.0)).floor())
	load_start_msec = Time.get_ticks_msec()
	var qv_func: Callable = %QuiltView.create_quilt.bind(crop_pixels)
	quilt_create_thread.start(qv_func)
	state = QuiltImageState.QUILT_CREATING

func _on_quilt_saved() -> void:
	description_label.text += "Quilt saved.\n"

func _on_quilt_viewer_pressed() -> void:
	%QuiltSubViewportContainer.visible = false
	%LightfieldSubViewportContainer.visible = true
	%SaveQuiltButton.disabled = true
	state = QuiltImageState.IMAGE_LOADED

func _on_files_dropped(files):
	var result = []
	for file in files:
		var is_file = FileAccess.file_exists(file)
		var is_dir = DirAccess.dir_exists_absolute(file)
		if is_dir:
			var dir = DirAccess.open(file)
			if dir:
				dir.include_hidden = false
				var dir_files_packed := dir.get_files()
				var dir_files := Array(dir_files_packed)
				var image_files = dir_files.filter(func(f: String): return is_image_extension(f.get_extension())).map(
					func(f: String): return file + "/" + f
				)
				if !image_files.is_empty():
					result = image_files
					break
		if is_file:
			result.append(file)
	if !result.is_empty():
		var packed = PackedStringArray(result)
		_on_file_browse_button_file_selected(packed)

func is_image_extension(extension: String) -> bool:
	var EXTENSIONS: Array[String] = ["jpeg", "jpg", "png"]
	return extension in EXTENSIONS


func _on_crop_option_button_item_selected(index: int) -> void:
	_on_quilt_viewer_pressed()
	if index <= 0:
		lightfield_viewport.set_crop_visiblity(false)
		lightfield_viewport.keep_aspect_ratio = false
		return
	var crop_option = get_crop_option.call()
	if crop_option.aspect_pixels.x <= 0 or crop_option.aspect_pixels.y <= 0:
		lightfield_viewport.keep_aspect_ratio = false
	else:
		lightfield_viewport.keep_aspect_ratio = true
		lightfield_viewport.aspect_ratio_pixels = crop_option.aspect_pixels
	lightfield_viewport.set_crop_visiblity(true)
