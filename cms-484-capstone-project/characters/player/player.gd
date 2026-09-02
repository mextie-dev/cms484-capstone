
class_name Player
extends CharacterBody3D


@export_group("Movement")
@export var walk_speed: float = 3.2
@export var run_speed: float = 6.0
@export var acceleration: float = 12.0
@export var friction: float = 14.0
@export var air_control: float = 0.35
@export var turn_speed: float = 10.0
@export var jump_velocity: float = 4.2
@export var gravity_multiplier: float = 1.0


@export_group("Nodes")
@export var visual_root_path: NodePath
@export var pcam_path: NodePath


@onready var visual_root: Node3D = get_node(visual_root_path)
@onready var pcam: PlayerCamera = get_node(pcam_path)


var _gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

## Replicated through MultiplayerSynchronizer.
var synced_yaw: float = 0.0


func _enter_tree() -> void:
	# Every multiplayer-spawned Player is named after its owning
	# Godot peer ID:
	#
	#   "1"
	#   "2"
	#   "3"
	#
	# Do NOT silently fall back to peer 1. A fallback can cause an
	# incorrectly spawned player to accidentally gain authority.

	var peer_id := str(name).to_int()

	if peer_id <= 0:
		printerr(
			"Player entered tree with invalid peer ID. Name = ",
			name
		)
		return

	set_multiplayer_authority(peer_id)

	print(
		"Player ",
		name,
		" authority assigned to peer ",
		peer_id
	)


func _ready() -> void:
	if is_multiplayer_authority():
		print(
			"Player ",
			name,
			" is locally authoritative."
		)

		pcam.activate()
	else:
		pcam.deactivate()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_simulate_local(delta)
	else:
		_smooth_remote(delta)


# ============================================================
# LOCAL PLAYER
# ============================================================

func _simulate_local(delta: float) -> void:
	# Gravity.
	if not is_on_floor():
		velocity.y -= (
			_gravity
			* gravity_multiplier
			* delta
		)
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement input.
	var raw_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var move_dir := Vector3.ZERO

	if raw_input.length() > 0.0:
		var cam_basis := pcam.get_flat_basis()

		move_dir = (
			cam_basis
			* Vector3(
				raw_input.x,
				0.0,
				raw_input.y
			)
		).normalized()

	var moving := move_dir.length() > 0.01

	var target_speed := (
		run_speed
		if Input.is_action_pressed("run")
		else walk_speed
	)

	var target_velocity := move_dir * target_speed

	var rate := (
		acceleration
		if moving
		else friction
	)

	if not is_on_floor():
		rate *= air_control

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		rate * delta
	)

	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		rate * delta
	)

	# Turn the visual model toward movement direction.
	if moving:
		var target_yaw := atan2(
			move_dir.x,
			move_dir.z
		)

		synced_yaw = lerp_angle(
			synced_yaw,
			target_yaw,
			turn_speed * delta
		)

	visual_root.rotation.y = synced_yaw

	move_and_slide()


# ============================================================
# REMOTE PLAYER
# ============================================================

func _smooth_remote(delta: float) -> void:
	# Position/velocity/etc. should eventually be supplied through
	# MultiplayerSynchronizer.
	#
	# For now, only smooth the replicated visual rotation.

	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		synced_yaw,
		turn_speed * delta
	)
