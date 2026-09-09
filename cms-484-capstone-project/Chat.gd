# Authored by Max Royer

extends Node

## Emitted on every peer once the server has accepted a message.
## [param peer_id] is the id of the peer that sent it, which is also the node
## name of that player's character, so listeners can route a bubble to the
## right body without any extra replication.
signal message_recieved(peer_id: int, uname: String, color: Color, message: String)

const MAX_MESSAGE_LENGTH := 150
const MAX_NAME_LENGTH := 24

## Minimum seconds between two accepted messages from the same peer. Enforced
## on the server only, so a modified client cannot opt out of it.
const SEND_COOLDOWN := 0.5

## peer_id -> Time.get_ticks_msec() of that peer's last accepted message
var _last_send_msec := {}


func _ready() -> void:
	# Without this the cooldown table grows for the whole session and keeps
	# stale entries for ids that may be reused by a later peer.
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_disconnected(id: int) -> void:
	_last_send_msec.erase(id)


## Called locally by ChatUI when the player hits enter.
func send_message(message: String) -> void:
	message = message.strip_edges()
	if message.is_empty():
		return

	if not _has_live_session():
		# No session at all: sitting on the menu, or a map opened straight from
		# the editor. Echo locally instead of firing an RPC into a null peer.
		# Player nodes that were not spawned by the MultiplayerSpawner fall back
		# to authority 1 in _enter_tree, so 1 is the id that matches them.
		message_recieved.emit(1, PlayerData.player_name, PlayerData.player_color, message)
		return

	submit_message.rpc_id(1, PlayerData.player_name, PlayerData.player_color, message)


## Runs on the server only. Everything the clients are allowed to influence
## gets validated here before it is fanned back out.
@rpc("any_peer", "call_local", "reliable")
func submit_message(uname: String, color: Color, message: String) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		# The host talking to itself through call_local. 4.7 reports the real
		# id here, but older builds report 0, so resolve it explicitly.
		sender = multiplayer.get_unique_id()

	if not _cooldown_elapsed(sender):
		return

	message = message.strip_edges()
	if message.is_empty():
		return
	if message.length() > MAX_MESSAGE_LENGTH:
		message = message.substr(0, MAX_MESSAGE_LENGTH)

	uname = uname.strip_edges()
	if uname.is_empty():
		uname = "player %d" % sender
	elif uname.length() > MAX_NAME_LENGTH:
		uname = uname.substr(0, MAX_NAME_LENGTH)

	_last_send_msec[sender] = Time.get_ticks_msec()

	receive_message.rpc(sender, uname, color, message)


## True if [param sender] is allowed to send right now.
func _cooldown_elapsed(sender: int) -> bool:
	if not _last_send_msec.has(sender):
		return true
	var last: int = _last_send_msec[sender]
	return Time.get_ticks_msec() - last >= int(SEND_COOLDOWN * 1000.0)


## True when a real networked session exists. The default MultiplayerAPI peer
## is an OfflineMultiplayerPeer rather than null, and Main sets it back to null
## on teardown, so both cases have to be covered.
func _has_live_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


## Fans out from the server to every peer, the server included.
@rpc("authority", "call_local", "reliable")
func receive_message(peer_id: int, uname: String, color: Color, message: String) -> void:
	print("%s (%d) says: %s" % [uname, peer_id, message])
	message_recieved.emit(peer_id, uname, color, message)
