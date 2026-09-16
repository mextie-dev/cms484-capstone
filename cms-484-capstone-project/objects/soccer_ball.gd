# Authored by Max Royer

class_name SoccerBall
extends RigidBody3D

## Networking model: the host (authority 1, the default for nodes placed in the
## map) is the only peer that simulates this ball. Clients freeze their copy in
## setup_network() and the MultiplayerSynchronizer writes the host's position
## and rotation onto it. Kicks from anyone are sent to the host as an RPC.

@onready var hitbox_component: HitboxComponent = $HitboxComponent

var _spawn_transform: Transform3D

func _ready() -> void:
	_spawn_transform = global_transform

func _process(_delta: float) -> void:
	hitbox_component.global_basis = Basis.IDENTITY


## Fires on the kicker's own machine (scan_raycast only runs for the local
## player). Works out the direction here, where the kicker's facing is exact,
## then hands the actual kick to the host.
func _on_hitbox_component_player_interacted(player: Player) -> void:
	var direction := player.visual_root.global_transform.basis.z

	if _has_live_session():
		request_kick.rpc_id(1, direction)
	else:
		# Map opened straight from the editor: no peer to send to.
		_apply_kick(direction)


## Runs on the host only. call_local lets the host's own kicks go through the
## same path as everyone else's.
@rpc("any_peer", "call_local", "reliable")
func request_kick(direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_apply_kick(direction)


func _apply_kick(direction: Vector3) -> void:
	# Normalized on the receiving side so a bad vector can't launch the ball
	# into orbit.
	direction = direction.normalized()
	print("kicking in " + str(direction))
	apply_impulse(direction * 50 + Vector3(0, 20, 0))


## Same check as Chat._has_live_session(). The default peer is an
## OfflineMultiplayerPeer, and Main sets it to null on teardown.
func _has_live_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


## Called by MultiplayerTestRoom.initialize() via the "networked" group, once
## the connection exists and authority checks are meaningful.
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
