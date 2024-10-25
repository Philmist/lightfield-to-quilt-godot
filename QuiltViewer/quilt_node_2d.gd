extends Node2D
@onready var sprite = $QuiltSprite2D
var images: Array[Image]
var quilt_image: Image
var quilt_view_size: Vector2i
var quilt_image_size: Vector2i
var quilt_frames_length: int
var focus: float
var quilt_mutex: Mutex
var frame_size: Vector2i

signal quilt_create_completed
signal quilt_create_progress_changed(percent: float)
signal quilt_saved

const IMAGE_MAX_SIDE_PIXEL := 16384

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	focus = 0
	quilt_mutex = Mutex.new()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func create_quilt(crop: Rect2i = Rect2i()) -> void:
	if len(images) < 2:
		return
	# Calculate quilt size
	# Quilt size should be close to square
	if !quilt_mutex.try_lock():
		print("Cannot lock quilt mutex.")
		return
	quilt_mutex.unlock()
	var image_size: Vector2i = images[0].get_size()
	var crop_rect: Rect2i = Rect2i(crop.abs())
	if (crop_rect.size.x * crop_rect.size.y) <= 100:
		print("Crop region is too small or not set. Take original.")
		crop_rect.position = Vector2i(0, 0)
		crop_rect.size = Vector2i(images[0].get_size())
	elif (crop_rect.position.x < 0 or crop_rect.position.y < 0):
		print("Crop start position is invalid.")
		return
	elif (crop_rect.end.x >= image_size.x or crop_rect.end.y >= image_size.y):
		print("Crop end position is invalid.")
		return
	frame_size = crop_rect.size
	var format = images[0].get_format() as Image.Format
	quilt_frames_length = len(images)
	print("Source image size: (%d, %d)" % [
		image_size.x,
		image_size.y
	])
	print("Quilt frames: %d, size: (%d, %d)" % [
		quilt_frames_length,
		frame_size.x,
		frame_size.y
		])
	print("Rect: %d, %d -> %d, %d" % [
		crop_rect.position.x,
		crop_rect.position.y,
		crop_rect.end.x,
		crop_rect.end.y
		])
	var sqrt_frames := ceilf(sqrt(quilt_frames_length))
	quilt_view_size = Vector2i(sqrt_frames, ceilf(quilt_frames_length / sqrt_frames))
	quilt_image_size = Vector2i(
		quilt_view_size.x * crop_rect.size.x,
		quilt_view_size.y * crop_rect.size.y
	)
	if quilt_image_size.x >= IMAGE_MAX_SIDE_PIXEL or quilt_image_size.y >= IMAGE_MAX_SIDE_PIXEL:
		var sqrt_total_pixels = sqrt(crop_rect.size.x * crop_rect.size.y * quilt_frames_length)
		var column_num: int = ceil(sqrt_total_pixels / float(crop_rect.size.x))
		var row_num: int = ceil(quilt_frames_length / float(column_num))
		quilt_view_size = Vector2i(column_num, row_num)
		quilt_image_size = Vector2i(
			quilt_view_size.x * crop_rect.size.x,
			quilt_view_size.y * crop_rect.size.y
		)
	quilt_create_progress_changed.emit.call_deferred(0.0)
	quilt_mutex.lock()
	quilt_image = Image.create_empty(quilt_image_size.x, quilt_image_size.y, false, format)
	if (quilt_image is not Image) or (quilt_image.get_width() != quilt_image_size.x or quilt_image.get_height() != quilt_image_size.y):
		printerr("Cannot create quilt image object(quilt may be too large).")
		quilt_mutex.unlock()
		quilt_image = null
		return
	quilt_image.fill(Color.BLACK)
	var mod_focus = float(focus)
	var images = self.images.duplicate()
	images.reverse()
	for i in range(quilt_frames_length):
		var frame: Image = images[i]
		# offset is source offset (take from +offset)
		var offset: int = int((i - quilt_frames_length / 2.0) * -1.0 * mod_focus * image_size.x)
		var edge_position = Vector2i((0 if offset < 0 else frame.get_size().x - 1), crop_rect.position.y)
		var edge_size = Vector2i(1, crop_rect.size.y)
		var edge_image = frame.get_region(Rect2i(edge_position, edge_size))
		var pos = Vector2i(
			i % quilt_view_size.x,
			quilt_view_size.y - 1 - floor(float(i) / quilt_view_size.x)
			)
		var target = Vector2i(pos.x * crop_rect.size.x, pos.y * crop_rect.size.y)
		for j in range(crop_rect.size.x):
			quilt_image.blit_rect(
				edge_image,
				Rect2i(0, 0, 1, edge_size.y - 1),
				target + Vector2i(j, 0)
				)
		#var source_rect = Rect2i(
		#	offset if offset >= 0 else 0,
		#	0,
		#	frame.get_size().x - abs(offset),
		#	frame.get_size().y
		#)
		var source_rect = Rect2i(crop_rect)
		source_rect.position = source_rect.position + Vector2i(offset, 0)
		var draw_offset = Vector2i(0, 0)
		if source_rect.position.x < 0:
			source_rect.size.x -= abs(source_rect.position.x)
			draw_offset.x = abs(source_rect.position.x)
			source_rect.position.x = 0
		#draw_offset.x = 0 if offset > 0 else abs(offset)
		if source_rect.end.x >= image_size.x:
			#print("E, %d, %d" % [source_rect.end.x, source_rect.size.x])
			source_rect.end.x = image_size.x - 1
		#if (draw_offset.x + source_rect.size.x) > crop_rect.size.x:
		#	source_rect.size = crop_rect.size - draw_offset
		quilt_image.blit_rect(
			frame,
			source_rect,
			target + draw_offset
			)
		quilt_create_progress_changed.emit.call_deferred(float(i+1) / float(quilt_frames_length) * 100.0)
		print("Progress: %d / %d, quilt pos: (%d, %d), source pos & size: (%d, %d)-(%d, %d), (%d, %d), offset: %d" % [
			i+1,
			quilt_frames_length,
			target.x,
			target.y,
			source_rect.position.x,
			source_rect.position.y,
			source_rect.end.x,
			source_rect.end.y,
			source_rect.size.x,
			source_rect.size.y,
			offset
			])
	quilt_mutex.unlock()
	print("Quilt: quilt %d x %d, overall size (%d, %d), frame size (%d, %d)" % [
		quilt_view_size.x,
		quilt_view_size.y,
		quilt_image.get_size().x,
		quilt_image.get_size().y,
		frame_size.x,
		frame_size.y
	])
	quilt_create_completed.emit.call_deferred()

func display_quilt() -> void:
	sprite.texture = ImageTexture.create_from_image(quilt_image)

func reset_display() -> void:
	sprite.reset_texture()
	images.clear()
	quilt_image = Image.create_empty(10, 10, false, Image.FORMAT_RGB8)

func save_quilt(path: String) -> void:
	var err = quilt_image.save_jpg(path, 0.9)
	if err:
		printerr("Cannot save quilt: %s" % [path])
		return
	quilt_saved.emit()
	return
