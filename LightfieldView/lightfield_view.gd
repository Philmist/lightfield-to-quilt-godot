extends Node3D

@onready var meshinstance = $MeshInstance
@onready var camera = $Camera
const MESH_SIZE: float = 1.0
const EPSILON = 0.0001
var DEFAULT_TEXTURE = load("res://LightfieldView/lightfield_4x4.jpg")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_camera_pos()
	pass

func set_texture_array(textures: Texture2DArray, numberOfFrames: int):
	meshinstance.set_texture_array(textures, numberOfFrames)

func update_camera_pos() -> void:
	var fov = camera.fov
	var pos: float = MESH_SIZE / (2.0 * tan(fov * PI / 360.0))
	if (abs(camera.position.z - pos) > EPSILON):
		camera.position.z = pos
		print_verbose("Camera pos: %s" % pos)
	pass

func set_focus(focus: float) -> void:
	meshinstance.set_focus(focus)

func get_size_pixels() -> Vector2i:
	return Vector2i(meshinstance.texture_size)
