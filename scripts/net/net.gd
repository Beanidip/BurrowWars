extends Node
## Networking front door (autoload "Net").
##
## Model: one authority. The host (a player's game, or a headless dedicated
## server) runs the real Match. Clients run a replica Match that draws the
## world and moves only their own rat; every gameplay request (dig, place,
## bonk, buy...) is sent here as an RPC and executed by the authority through
## the same validated Match.try_* methods the bots and the host use.
##
## All RPC endpoints live on this autoload so their node path (/root/Net) is
## identical on every peer. They only forward to the active NetServer or
## NetClient, which hold the logic.

signal joined(info: Dictionary)        # client: the server seated us (new session or new round)
signal join_failed(reason: String)     # client: could not connect or was refused
signal disconnected(reason: String)    # client: lost the server mid-game

const DEFAULT_PORT := 24565
const PROTOCOL := 9                    # bump whenever the wire format or block ids change
const MAX_CLIENTS := 15
const NAME_MAX := 16

enum Role { OFFLINE, SERVER, CLIENT }

var role := Role.OFFLINE
var server: NetServer                  # set by the active NetServer
var client: NetClient                  # set by the active NetClient
var hellos: Dictionary = {}            # server: peer id -> the hello it sent (survives new rounds)
var player_name := ""
var _hello := {}
var _refused := false


func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version"))


func is_online() -> bool:
	return role != Role.OFFLINE


static func clean_name(raw: Variant) -> String:
	var s := String(raw) if raw is String else ""
	var out := ""
	for ch in s.strip_edges():
		if ch.unicode_at(0) >= 32 and ch != "[" and ch != "]":
			out += ch
	return out.substr(0, NAME_MAX).strip_edges()


# ---------------------------------------------------------------- start / stop

func host(port: int) -> String:
	## Opens a server on this machine. Returns "" or an error for the player.
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return "Could not open port %d (error %d). Is another server already running?" % [port, err]
	multiplayer.multiplayer_peer = peer
	role = Role.SERVER
	hellos.clear()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Log.info("net: hosting on port %d" % port)
	return ""


func join(address: String, port: int, hello: Dictionary) -> String:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Could not start connecting to %s:%d (error %d)" % [address, port, err]
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_refused = false
	_hello = hello.duplicate()
	_hello["v"] = PROTOCOL
	_hello["gv"] = game_version()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Log.info("net: connecting to %s:%d" % [address, port])
	return ""


func close() -> void:
	for pair: Array in [[multiplayer.peer_connected, _on_peer_connected], [multiplayer.peer_disconnected, _on_peer_disconnected],
			[multiplayer.connected_to_server, _on_connected], [multiplayer.connection_failed, _on_connection_failed],
			[multiplayer.server_disconnected, _on_server_disconnected]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.OFFLINE
	hellos.clear()


# ---------------------------------------------------------------- connection events

func _on_peer_connected(id: int) -> void:
	Log.info("net: peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	Log.info("net: peer %d left" % id)
	hellos.erase(id)
	if server != null:
		server.on_peer_left(id)


func _on_connected() -> void:
	_c_hello.rpc_id(1, _hello)


func _on_connection_failed() -> void:
	close()
	join_failed.emit("Could not reach the server. Check the address and port, and that the host's firewall allows UDP %d." % DEFAULT_PORT)


func _on_server_disconnected() -> void:
	close()
	if _refused:
		return
	disconnected.emit("The server closed the connection.")


# ---------------------------------------------------------------- client -> server

@rpc("any_peer", "call_remote", "reliable")
func _c_hello(hello: Variant) -> void:
	if role != Role.SERVER or not (hello is Dictionary):
		return
	var id := multiplayer.get_remote_sender_id()
	var h: Dictionary = hello
	if int(h.get("v", -1)) != PROTOCOL:
		_s_refuse.rpc_id(id, "Version mismatch: the server runs Burrow Wars %s. Download the same version to join." % game_version())
		return
	hellos[id] = h
	if server != null:
		server.on_hello(id, h)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _c_input(pkt: Variant) -> void:
	if server != null and pkt is Dictionary:
		server.on_input(multiplayer.get_remote_sender_id(), pkt)


@rpc("any_peer", "call_remote", "reliable")
func _c_act(method: Variant, args: Variant) -> void:
	if server != null and method is String and args is Array:
		server.on_act(multiplayer.get_remote_sender_id(), method, args)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _c_aim(yaw: Variant, pitch: Variant) -> void:
	if server != null and (yaw is float) and (pitch is float):
		server.on_aim(multiplayer.get_remote_sender_id(), yaw, pitch)


# ---------------------------------------------------------------- server -> client

@rpc("authority", "call_remote", "reliable")
func _s_welcome(info: Dictionary) -> void:
	joined.emit(info)


@rpc("authority", "call_remote", "unreliable_ordered")
func _s_snap(data: PackedByteArray) -> void:
	## Snapshots and events travel pre-encoded (the server encodes each once
	## for all players). bytes_to_var never decodes objects.
	var pkt: Variant = bytes_to_var(data)
	if client != null and pkt is Dictionary:
		client.on_snap(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_events(data: PackedByteArray) -> void:
	var pkt: Variant = bytes_to_var(data)
	if client != null and pkt is Dictionary:
		client.on_events(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_private(pkt: Dictionary) -> void:
	if client != null:
		client.on_private(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_kick(pkt: Dictionary) -> void:
	if client != null:
		client.on_kick(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_notice(text: String) -> void:
	if client != null:
		client.on_notice(text)


@rpc("authority", "call_remote", "reliable")
func _s_refuse(reason: String) -> void:
	_refused = true
	close()
	join_failed.emit(reason)
