class_name StatusServer
extends Node
## A tiny HTTP server that answers GET /status with a dedicated server's live
## state as JSON (name, version, players, mode, score...), so the game's
## server list can show who is playing where, and how far away it is.
## Browsers may read it from any page (CORS: Access-Control-Allow-Origin *).
## It serves nothing else, keeps at most MAX_CONNECTIONS open, and drops any
## request that is too big or too slow.

const MAX_CONNECTIONS := 16
const MAX_REQUEST := 4096
const TIMEOUT_MS := 3000

var provider: Callable           # () -> Dictionary, the status to send
var port := 0
var _server := TCPServer.new()
var _conns: Array = []           # [StreamPeerTCP, PackedByteArray request so far, start msec]
var served := 0


func listen(at_port: int, bind := "*") -> String:
	var err := _server.listen(at_port, bind)
	if err != OK:
		return "Could not open TCP port %d for the status page (error %d)" % [at_port, err]
	port = at_port
	return ""


func _exit_tree() -> void:
	for c: Array in _conns:
		(c[0] as StreamPeerTCP).disconnect_from_host()
	_conns.clear()
	_server.stop()


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if _conns.size() >= MAX_CONNECTIONS:
			peer.disconnect_from_host()
		else:
			_conns.append([peer, PackedByteArray(), Time.get_ticks_msec()])
	var now := Time.get_ticks_msec()
	for i in range(_conns.size() - 1, -1, -1):
		var c: Array = _conns[i]
		var peer: StreamPeerTCP = c[0]
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
			var got: Array = peer.get_partial_data(mini(peer.get_available_bytes(), MAX_REQUEST))
			if int(got[0]) == OK:
				var buf: PackedByteArray = c[1]
				buf.append_array(got[1])
				c[1] = buf
		var req: PackedByteArray = c[1]
		var text := req.get_string_from_ascii()
		if status != StreamPeerTCP.STATUS_CONNECTED or now - int(c[2]) > TIMEOUT_MS or req.size() > MAX_REQUEST:
			peer.disconnect_from_host()
			_conns.remove_at(i)
		elif text.contains("\r\n\r\n"):
			_answer(peer, text)
			peer.disconnect_from_host()
			_conns.remove_at(i)


func _answer(peer: StreamPeerTCP, request: String) -> void:
	var line := request.get_slice("\r\n", 0).split(" ")
	var method := line[0] if line.size() > 0 else ""
	var path := (line[1] if line.size() > 1 else "").get_slice("?", 0).trim_suffix("/")
	var code := "200 OK"
	var body := ""
	if method == "OPTIONS":
		code = "204 No Content"
	elif method != "GET" and method != "HEAD":
		code = "405 Method Not Allowed"
	elif path != "" and path != "/status":
		code = "404 Not Found"
	else:
		var st: Dictionary = provider.call() if provider.is_valid() else {}
		body = JSON.stringify(st)
		served += 1
	var bytes := body.to_utf8_buffer()
	var head := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n" % code \
		+ "Access-Control-Allow-Methods: GET, OPTIONS\r\nCache-Control: no-store\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()
	peer.put_data(head.to_utf8_buffer())
	if method != "HEAD" and not bytes.is_empty():
		peer.put_data(bytes)
