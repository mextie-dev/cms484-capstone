# Authored by Max Royer

class_name PhysObject
extends RigidBody3D

## Base class for every kickable physics object.
##
## Networking model: the host (authority 1, the default for nodes placed in the
## map) is the only peer that simulates this object. Clients freeze their copy
## in setup_network() and the MultiplayerSynchronizer writes the host's
## position and rotation onto it. Kicks from anyone are sent to the host as an
## RPC.

@export_group("Kick")
@export var kick_strength: float = 50.0
@export var kick_lift: float = 20.0

@onready var hitbox_component: HitboxComponent = $HitboxComponent

var _spawn_transform: Transform3D


func _ready() -> void:
	_spawn_transform = global_transform


func _process(_delta: float) -> void:
	# hitbox stays upright
	hitbox_component.global_basis = Basis.IDENTITY

func _on_hitbox_component_player_interacted(player: Player) -> void:
	var direction := player.visual_root.global_transform.basis.z

	if _has_live_session():
		request_kick.rpc_id(1, direction)
	else:
		_apply_kick(direction)

@rpc("any_peer", "call_local", "reliable")
func request_kick(direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_apply_kick(direction)


func _apply_kick(direction: Vector3) -> void:
	direction = direction.normalized()
	apply_impulse(direction * kick_strength + Vector3.UP * kick_lift)
	_on_kicked(direction)


## Override in a subclass for per-object effects (sound, particles).
## Runs on the host only; use an RPC from here for effects everyone should see.
func _on_kicked(_direction: Vector3) -> void:
	pass


func _has_live_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)

func setup_network() -> void:
	if is_multiplayer_authority():
		return
	# Clients stop simulating and just display what the host sends.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## Called by MultiplayerTestRoom.teardown() when leaving a session.
func teardown_network() -> void:
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn_transform
