# Authored by:
# Max Royer

class_name Player
extends CharacterBody3D

## third person control
##
## disclaimer: a lot of this is AI-reviewed (netcode is hard) and not implemented
## in C# because PhantomCamera is written in GDScript, so i didn't want
## to mix paradigms. 
## designed to be spawned by a MultiplayerSpawner where the node's
## name is the owning peer id see SETUP.md

@export_group("Movement")
@export var walk_speed: float = 3.2
@export var run_speed: float = 6.0
@export var acceleration: float = 12.0
@export var friction: float = 14.0
@export var air_control: float = 0.35
@export var turn_speed: float = 10.0 
@export var jump_velocity: float = 4.2
@export var gravity_multiplier: float = 1.0

@export_group("Network smoothing")
@export var position_smoothing: float = 18.0
@export var extrapolation_limit: float = 0.25
@export var teleport_distance: float = 3.0

@export_group("Nodes")
@export var visual_root_path: NodePath
@export var pcam_path: NodePath            

@onready var visual_root: Node3D = get_node(visual_root_path)
@onready var pcam: PlayerCamera = get_node(pcam_path)
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## smooth interpolation for rotation
var synced_yaw: float = 0.0

## interpolated between position vectors to smooth appearing movement
var synced_position: Vector3 = Vector3.ZERO

## seconds since the last sync packet, used to extrapolate forward.
var _packet_age: float = 0.0
## the position the last packet reported, held separately so extrapolation
## always builds off a known-good sample rather than compounding itself.
var _net_target: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	# long fucking story short, this detects if the currently controlled character
	# is actually a multiplayer agent, or if it is spawned by the multiplayer
	# spawner. we prob want this game to be peer2peer so this is relevant for
	# testing so we don't have to spin up a new instance every time we want to
	# test if the map is working
	var peer_id := str(name).to_int()
	if peer_id == 0:
		# Not spawned by a MultiplayerSpawner (e.g. dropped into a test
		# scene by hand) - fall back to the local/offline default so the
		# camera still activates instead of treating itself as remote.
		peer_id = 1
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	if is_multiplayer_authority():
		pcam.activate()
		synced_position = global_position
	else:
		pcam.deactivate()

		# Seed from the spawn-replicated value so a joining player doesn't
		# see everyone slide in from the world origin.
		_net_target = synced_position
		global_position = synced_position

		sync.synchronized.connect(_on_synchronized)


## fires on this peer every time a sync packet for this player is accepted
func _on_synchronized() -> void:
	_net_target = synced_position
	_packet_age = 0.0


## if this IS the peer, treat it like god and handle phyics throguh it
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_simulate_local(delta)
	else:
		_smooth_remote(delta)


## actual movement and input stuff
func _simulate_local(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3.ZERO
	if raw_input.length() > 0.0:
		var cam_basis := pcam.get_flat_basis()
		move_dir = (cam_basis * Vector3(raw_input.x, 0.0, raw_input.y)).normalized()

	var moving := move_dir.length() > 0.01
	var target_speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var target_velocity := move_dir * target_speed
	var rate := acceleration if moving else friction
	if not is_on_floor():
		rate *= air_control

	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if moving:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		synced_yaw = lerp_angle(synced_yaw, target_yaw, turn_speed * delta)

	visual_root.rotation.y = synced_yaw

	move_and_slide()

	# Publish AFTER move_and_slide so we're sending where we actually ended up,
	# not where we intended to go before collision resolution.
	synced_position = global_position


func _smooth_remote(delta: float) -> void:
	# Predict forward from the last packet. Capped so a peer that stops sending
	# leaves its proxy parked instead of drifting away forever.
	_packet_age = min(_packet_age + delta, extrapolation_limit)
	var predicted := _net_target + velocity * _packet_age

	if global_position.distance_to(predicted) > teleport_distance:
		# Too far to smooth plausibly - spawn, teleport, or a long dropout.
		global_position = predicted
	else:
		# Framerate-independent exponential smoothing. Using a raw
		# `smoothing * delta` factor would make the catch-up rate depend on
		# framerate, so a 144Hz client and a 60Hz client would disagree.
		var t := 1.0 - exp(-position_smoothing * delta)
		global_position = global_position.lerp(predicted, t)

	# Same idea for facing: steer toward the replicated yaw rather than
	# assigning it, so turns read as turns instead of jumps.
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, synced_yaw, turn_speed * delta)
