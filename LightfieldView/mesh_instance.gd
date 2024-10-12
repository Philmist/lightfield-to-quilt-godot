extends MeshInstance3D

var material: ShaderMaterial
var DEFAULT_TEXTURE = load("res://LightfieldView/lightfield_4x4.jpg")
const DEFAULT_NUM_FRAMES: int = 16
const DEFAULT_APERTURE: float = 5.0
const DEFAULT_FOCUS: float = 0.0
var texture_size: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	material = $".".get_active_material(0) as ShaderMaterial
	reset_shader()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_texture_array(texture_array: Texture2DArray, number_or_frames: int) -> void:
	texture_size = Vector2i(texture_array.get_width(), texture_array.get_height())
	material.set_shader_parameter("s2DArray", texture_array)
	var fNumFrames = float(number_or_frames)
	material.set_shader_parameter("numberOfFrames", fNumFrames)

func reset_shader() -> void:
	material.set_shader_parameter("s2DArray", DEFAULT_TEXTURE)
	material.set_shader_parameter("numberOfFrames", DEFAULT_NUM_FRAMES)
	material.set_shader_parameter("aperture", DEFAULT_APERTURE)
	material.set_shader_parameter("focus", DEFAULT_FOCUS)
	texture_size = Vector2i(DEFAULT_TEXTURE.get_width(), DEFAULT_TEXTURE.get_height())
	pass

func set_focus(focus: float) -> void:
	material.set_shader_parameter("focus", focus)
