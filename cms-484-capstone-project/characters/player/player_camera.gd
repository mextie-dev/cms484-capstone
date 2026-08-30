class_name PlayerCamera
extends PhantomCamera3D

## only the local player's camera should ever be active: remote
## players call deactivate(), which also hides the node so the addon
## doesn't spend time evaluating a camera that doesn't exist

## we're using phantomcam because i'm envisioning when you enter dialogue,
## the camera moves to frame the subject, and phantomcam makes this real easy

@export var mouse_sensitivity: float = 0.08
@export var min_pitch: float = -40.0
@export var max_pitch: float = 60.0
@export var zoom_speed: float = 0.6
@export var min_spring_length: float = 1.5
@export var max_spring_length: float = 6.0
@export var active_priority: int = 10

var _rotation_degrees: Vector3


func _ready() -> void:
	super._ready() # also calls ready on the extended phantomcam class, default in C# but not gdscript
	_rotation_degrees = get_third_person_rotation_degrees()
	set_process_unhandled_input(false)

## is this the camera?
func activate() -> void:
	priority = active_priority
	visible = true
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## NOUPE
func deactivate() -> void:
	priority = 0
	visible = false
	set_process_unhandled_input(false)

## input and logic for zooming in and out, should work for both mouse and brackets
## because mac and web users can't really use scroll wheels like that
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotation_degrees.x -= event.relative.y * mouse_sensitivity
		_rotation_degrees.x = clampf(_rotation_degrees.x, min_pitch, max_pitch)
		_rotation_degrees.y -= event.relative.x * mouse_sensitivity
		_rotation_degrees.y = wrapf(_rotation_degrees.y, 0.0, 360.0)
		set_third_person_rotation_degrees(_rotation_degrees)
	elif event.is_action_pressed("zoom_in"):
		set_spring_length(clampf(get_spring_length() - zoom_speed, min_spring_length, max_spring_length))
	elif event.is_action_pressed("zoom_out"):
		set_spring_length(clampf(get_spring_length() + zoom_speed, min_spring_length, max_spring_length))
	elif event.is_action_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)


## yaw-only basis, so WASD moves relative to where the camera is
## pointed horizontally without tipping forward/back when you look up or down
func get_flat_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_rotation_degrees.y))
