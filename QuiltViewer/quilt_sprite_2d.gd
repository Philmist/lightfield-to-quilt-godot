extends Sprite2D

@onready var camera = $Camera2D
var viewport: Viewport
@onready var default_texture = $".".texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	viewport = camera.get_viewport()
	var rect2 := viewport.get_visible_rect()
	print_verbose("Viewport rect: %d, %d" % [rect2.size.x, rect2.size.y])
	self.texture = default_texture
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	viewport = camera.get_viewport()
	var texture_size := self.texture.get_size()
	var viewport_rect_size := viewport.get_visible_rect().size
	var vertical_ratio := float(texture_size.y) / float(viewport_rect_size.y)
	var horizontal_ratio := float(texture_size.x) / float(viewport_rect_size.x)
	var zoom = 0.99 / (vertical_ratio if vertical_ratio > horizontal_ratio else horizontal_ratio)
	camera.zoom.x = zoom
	camera.zoom.y = zoom
	pass

func reset_texture() -> void:
	$".".texture = default_texture
