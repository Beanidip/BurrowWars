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
##
## Two transports carry the same RPCs:
## - ENet (UDP): player-hosted games and direct-IP / LAN play. "host:port".
## - WebSocket (TCP): public dedicated servers, the only kind a browser can
##   reach. "ws://host:port" or "wss://host[:port][/path]" (wss = TLS, which a
##   browser on an https page such as itch.io requires). A server runs one or
##   the other; desktop players can join both.
## The map a joining player needs is sent in parts after the welcome, paced so
## a WebSocket's send buffer never overflows.

signal joined(info: Dictionary)        # client: the server seated us (new session or new round)
signal join_failed(reason: String)     # client: could not connect or was refused
signal disconnected(reason: String)    # client: lost the server mid-game

const DEFAULT_PORT := 24565
const PROTOCOL := 15                   # bump whenever the wire format or block ids change
const MAX_CLIENTS := 31                # a dedicated server: 16v16 (every seat a player)
const HOST_MAX_CLIENTS := 15           # a game hosted from the menu: 8v8 with the host
const NAME_MAX := 16
const WORLD_PART := 48 * 1024          # bytes of map per message while joining
const WORLD_MAX := 64 * 1024 * 1024    # a client refuses a map bigger than this
const WS_OUT := 1 << 20                # WebSocket send buffer per peer (server) / receive buffer (client)
const WS_IN := 256 * 1024              # WebSocket receive buffer per peer (server) / send buffer (client)
const WS_STALL := 15.0                 # seconds a WebSocket peer may sit on a full buffer before it's dropped

enum Transport { ENET, WEBSOCKET }

enum Role { OFFLINE, SERVER, CLIENT }

var role := Role.OFFLINE
var server: NetServer                  # set by the active NetServer
var client: NetClient                  # set by the active NetClient
var hellos: Dictionary = {}            # server: peer id -> the hello it sent (survives new rounds)
var player_name := ""
var _hello := {}
var _refused := false
var transport := Transport.ENET
var tls_unsafe := false                # tests only: accept a self-signed wss certificate
var _world_out: Dictionary = {}        # server: peer -> {"serial", "parts", "next"} still to send
var _world_in: Dictionary = {}         # client: the welcome waiting for its map parts
var _welcome_serial := 0
var _stall: Dictionary = {}            # server: WebSocket peer -> seconds its send buffer has been nearly full
var _holding := false                  # client: a welcome came; hold what follows until its session is up
var _held: Array = []                  # client: [kind, payload] held meanwhile, in arrival order


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep sending the map while a host's game is paused


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

static func enet_available() -> bool:
	## ENet is UDP, which browsers can't do: a web build only has WebSocket.
	return ClassDB.class_exists("ENetMultiplayerPeer") and not OS.has_feature("web")


static func is_ws_url(address: String) -> bool:
	var a := address.strip_edges().to_lower()
	return a.begins_with("ws://") or a.begins_with("wss://")


static func ws_url_for(address: String, port: int) -> String:
	## What a bare "host" / "host:port" means where only WebSocket exists (a
	## browser): TLS, except to this machine.
	var host_part := address.strip_edges()
	var local := host_part in ["localhost", "127.0.0.1", "::1"]
	if host_part.contains(":") and not host_part.begins_with("["):
		host_part = "[%s]" % host_part   # a bare IPv6 address
	return "%s://%s:%d" % ["ws" if local else "wss", host_part, port]


func host(port: int, options: Dictionary = {}) -> String:
	## Opens a server on this machine. Returns "" or an error for the player.
	## options: "transport": "ws" for WebSocket (default ENet); "tls_cert" and
	## "tls_key": PEM files, to serve wss:// directly instead of behind a proxy;
	## "max_clients" (default HOST_MAX_CLIENTS).
	close()
	var ws := String(options.get("transport", "enet")) in ["ws", "websocket", "wss"] or not enet_available()
	var peer: MultiplayerPeer
	if ws:
		var tls: TLSOptions = null
		if String(options.get("tls_cert", "")) != "":
			var cert := X509Certificate.new()
			var key := CryptoKey.new()
			if cert.load(String(options["tls_cert"])) != OK or key.load(String(options.get("tls_key", ""))) != OK:
				return "Could not read the TLS certificate or key (%s, %s)" % [options.get("tls_cert"), options.get("tls_key", "")]
			tls = TLSOptions.server(key, cert)
		var wsp := WebSocketMultiplayerPeer.new()
		wsp.outbound_buffer_size = WS_OUT
		wsp.inbound_buffer_size = WS_IN
		wsp.max_queued_packets = 4096
		var err := wsp.create_server(port, "*", tls)
		if err != OK:
			return "Could not open TCP port %d (error %d). Is another server already running?" % [port, err]
		peer = wsp
		transport = Transport.WEBSOCKET
	else:
		var ep: MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
		var err: int = ep.call("create_server", port, clampi(int(options.get("max_clients", HOST_MAX_CLIENTS)), 1, MAX_CLIENTS))
		if err != OK:
			return "Could not open port %d (error %d). Is another server already running?" % [port, err]
		peer = ep
		transport = Transport.ENET
	multiplayer.multiplayer_peer = peer
	# clients only ever talk to the server: no relaying between them, and no
	# telling everyone about every arrival and departure (that also sent to
	# players who were leaving themselves)
	(multiplayer as SceneMultiplayer).server_relay = false
	role = Role.SERVER
	hellos.clear()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Log.info("net: hosting on %s port %d" % ["WebSocket (TCP)" if ws else "ENet (UDP)", port])
	return ""


func join(address: String, port: int, hello: Dictionary) -> String:
	## address: "host" (with `port`), or a ws:// / wss:// URL. In a browser a
	## bare host is reached over wss://.
	close()
	var peer: MultiplayerPeer
	var where := "%s:%d" % [address, port]
	if is_ws_url(address) or not enet_available():
		var url := address.strip_edges() if is_ws_url(address) else ws_url_for(address, port)
		var wsp := WebSocketMultiplayerPeer.new()
		wsp.inbound_buffer_size = WS_OUT
		wsp.outbound_buffer_size = WS_IN
		var tls: TLSOptions = TLSOptions.client_unsafe() if tls_unsafe else null
		var err := wsp.create_client(url, tls)
		if err != OK:
			return "Could not start connecting to %s (error %d)" % [url, err]
		peer = wsp
		where = url
		transport = Transport.WEBSOCKET
	else:
		var ep: MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
		var err: int = ep.call("create_client", address, port)
		if err != OK:
			return "Could not start connecting to %s:%d (error %d)" % [address, port, err]
		peer = ep
		transport = Transport.ENET
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_refused = false
	_world_in = {}
	_hello = hello.duplicate()
	_hello["v"] = PROTOCOL
	_hello["gv"] = game_version()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Log.info("net: connecting to %s" % where)
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
	_world_out.clear()
	_world_in = {}
	_stall.clear()
	_holding = false
	_held.clear()


# ---------------------------------------------------------------- joining: the map in parts

func send_welcome(id: int, info: Dictionary, world: Dictionary) -> void:
	## Server: seat a player. The welcome goes first; the map follows in parts
	## (_process sends them as the connection has room).
	var bytes := var_to_bytes(world)
	var parts: Array[PackedByteArray] = []
	for at in range(0, bytes.size(), WORLD_PART):
		parts.append(bytes.slice(at, at + WORLD_PART))
	if not connected(id):
		return   # (left while we were seating them)
	_welcome_serial += 1
	var w := info.duplicate()
	w["ws"] = _welcome_serial
	w["parts"] = parts.size()
	w["bytes"] = bytes.size()
	_s_welcome.rpc_id(id, w)
	_world_out[id] = {"serial": _welcome_serial, "parts": parts, "next": 0}
	_pump_world()


func connected(id: int) -> bool:
	## Server: can we send to this peer? (A WebSocket that is closing is still
	## listed for a moment, but sending to it is an error.) Tests drive
	## NetServer without any peers at all.
	if role != Role.SERVER or not multiplayer.get_peers().has(id):
		return false
	return is_open(id)


func sendable() -> Dictionary:
	## Server: every peer that can be sent to right now (id -> true), once per tick.
	var out := {}
	if role != Role.SERVER:
		return out
	for id: int in multiplayer.get_peers():
		if is_open(id):
			out[id] = true
	return out


func is_open(id: int) -> bool:
	if multiplayer.multiplayer_peer is WebSocketMultiplayerPeer:
		var wp := (multiplayer.multiplayer_peer as WebSocketMultiplayerPeer).get_peer(id)
		return wp != null and wp.get_ready_state() == WebSocketPeer.STATE_OPEN
	return true


func drop_peer(id: int, reason: String) -> void:
	## Server: tell a player why, then disconnect them a moment later (so the
	## message gets there first).
	if not connected(id):
		return
	_s_refuse.rpc_id(id, reason)
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
		if connected(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))


func backed_up(id: int, limit := 0.75) -> bool:
	## Server: is this peer's send buffer filling up? (WebSocket only: ENet
	## drops unreliable packets itself.) Snapshots skip a backed-up peer.
	if transport != Transport.WEBSOCKET or not (multiplayer.multiplayer_peer is WebSocketMultiplayerPeer):
		return false
	if not multiplayer.get_peers().has(id):
		return false
	var wp := (multiplayer.multiplayer_peer as WebSocketMultiplayerPeer).get_peer(id)
	return wp != null and wp.get_current_outbound_buffered_amount() > int(WS_OUT * limit)


func _pump_world() -> void:
	for id: int in _world_out.keys():
		var job: Dictionary = _world_out[id]
		var parts: Array[PackedByteArray] = job["parts"]
		if not multiplayer.get_peers().has(id):
			_world_out.erase(id)
			continue
		while int(job["next"]) < parts.size() and is_open(id) and not backed_up(id, 0.5):
			var i := int(job["next"])
			_s_world.rpc_id(id, int(job["serial"]), i, parts[i])
			job["next"] = i + 1
		if int(job["next"]) >= parts.size():
			_world_out.erase(id)


func _process(delta: float) -> void:
	if role != Role.SERVER:
		return
	if not _world_out.is_empty():
		_pump_world()
	if transport == Transport.WEBSOCKET:
		# a client that stopped reading would fill its buffer for ever: let it go
		for id: int in multiplayer.get_peers():
			if backed_up(id, 0.9):
				_stall[id] = float(_stall.get(id, 0.0)) + delta
				if float(_stall[id]) > WS_STALL:
					Log.warn("net: peer %d stopped reading; disconnecting" % id)
					_stall.erase(id)
					(multiplayer.multiplayer_peer as WebSocketMultiplayerPeer).disconnect_peer(id)
			else:
				_stall.erase(id)


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
	var ws := transport == Transport.WEBSOCKET
	close()
	if ws:
		join_failed.emit("Could not reach the server. Check the address (ws:// or wss://), and that the server is running and its port is open.")
	else:
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

func release_held(c: Object) -> void:
	## Client: the session for the latest welcome is up (its map applied):
	## everything that arrived since the welcome - block changes, the
	## server's corrections, the inventory - now goes to it, in order. Until
	## then nothing is lost, and nothing reaches the previous round's session.
	_holding = false
	var held := _held
	_held = []
	for item: Array in held:
		match String(item[0]):
			"events": c.on_events(item[1])
			"kick": c.on_kick(item[1])
			"private": c.on_private(item[1])
			"notice": c.on_notice(item[1])


@rpc("authority", "call_remote", "reliable")
func _s_welcome(info: Dictionary) -> void:
	## The map follows in `parts` messages; joined fires once it's all here.
	## From now on what the server sends belongs to this welcome: hold it.
	_holding = true
	_held.clear()
	var parts := int(info.get("parts", 0))
	var size := int(info.get("bytes", 0))
	if parts <= 0 or size <= 0 or size > WORLD_MAX or parts != ceili(float(size) / WORLD_PART):
		_world_in = {}
		Log.warn("net: bad welcome from the server (%d parts, %d bytes)" % [parts, size])
		return
	_world_in = {"info": info, "serial": int(info.get("ws", 0)), "data": PackedByteArray(), "next": 0, "parts": parts, "bytes": size}


@rpc("authority", "call_remote", "reliable")
func _s_world(serial: int, index: int, data: PackedByteArray) -> void:
	if _world_in.is_empty() or serial != int(_world_in["serial"]) or index != int(_world_in["next"]):
		return   # from an older welcome (a new round started meanwhile)
	var buf: PackedByteArray = _world_in["data"]
	buf.append_array(data)
	_world_in["data"] = buf
	_world_in["next"] = index + 1
	if index + 1 < int(_world_in["parts"]):
		return
	var info: Dictionary = _world_in["info"]
	var ok := buf.size() == int(_world_in["bytes"])
	_world_in = {}
	var world: Variant = bytes_to_var(buf) if ok else null   # never decodes objects
	if not (world is Dictionary):
		Log.warn("net: the map from the server did not arrive whole")
		close()
		join_failed.emit("The map from the server arrived damaged. Try joining again.")
		return
	info.erase("parts")
	info.erase("bytes")
	info.erase("ws")
	info["world"] = world
	joined.emit(info)


func join_progress() -> float:
	## Client: how much of the map has arrived (0..1), or -1 when not joining.
	if _world_in.is_empty():
		return -1.0
	return float(_world_in["next"]) / maxf(1.0, float(_world_in["parts"]))


@rpc("authority", "call_remote", "unreliable_ordered")
func _s_snap(data: PackedByteArray) -> void:
	## Snapshots and events travel pre-encoded (the server encodes each once
	## for all players). bytes_to_var never decodes objects.
	var pkt: Variant = bytes_to_var(data)
	if client != null and pkt is Dictionary and not _holding:   # (held: the welcome has a fresh one)
		client.on_snap(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_events(data: PackedByteArray) -> void:
	var pkt: Variant = bytes_to_var(data)
	if not (pkt is Dictionary):
		return
	if _holding:
		_held.append(["events", pkt])
	elif client != null:
		client.on_events(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_private(pkt: Dictionary) -> void:
	if _holding:
		_held.append(["private", pkt])
	elif client != null:
		client.on_private(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_kick(pkt: Dictionary) -> void:
	if _holding:
		_held.append(["kick", pkt])
	elif client != null:
		client.on_kick(pkt)


@rpc("authority", "call_remote", "reliable")
func _s_notice(text: String) -> void:
	if _holding:
		_held.append(["notice", text])
	elif client != null:
		client.on_notice(text)


@rpc("authority", "call_remote", "reliable")
func _s_refuse(reason: String) -> void:
	_refused = true
	close()
	join_failed.emit(reason)
