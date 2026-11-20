class_name ServerList
## The public server list: where it comes from, what each entry means, and
## how a server's live status (its /status page, see StatusServer) is shown.
##
## servers.json (in the game's repository, or wherever `burrow_wars/server_list_url`
## points) lists entries like
##   {"name": "Burrow Wars EU #1", "region": "EU",
##    "url": "wss://play.example.org/eu1",                  (a WebSocket server: browsers too)
##    "status": "https://play.example.org/eu1/status"}      (optional, see status_url_for)
## or, for an ENet (UDP) server, desktop only:
##   {"name": "...", "address": "203.0.113.10", "port": 24565}

const DEFAULT_URL := "https://raw.githubusercontent.com/Beanidip/BurrowWars/main/servers.json"
const SETTING := "burrow_wars/server_list_url"
const MODES := {"race": "Cheese Race", "free": "Free Build", "lobby": "Playground"}


static func list_url() -> String:
	## BW_SERVER_LIST (for testing your own list) beats the project setting.
	var env := OS.get_environment("BW_SERVER_LIST")
	if env != "":
		return env
	var url := String(ProjectSettings.get_setting(SETTING, ""))
	return url if url != "" else DEFAULT_URL


static func parse(json_text: String) -> Array[Dictionary]:
	## Normalised entries: name, region, join (address:port or ws/wss URL),
	## ws (true for WebSocket), status (URL of its status page, may be "").
	var out: Array[Dictionary] = []
	var data: Variant = JSON.parse_string(json_text) if json_text != "" else null
	if not (data is Dictionary) or not (data.get("servers") is Array):
		return out
	for e: Variant in data["servers"]:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		var entry := {"name": Net.clean_name(d.get("name", "")) if d.get("name") is String else "",
			"region": Net.clean_name(d.get("region", "")) if d.get("region") is String else ""}
		var url := String(d.get("url", "")).strip_edges() if d.get("url") is String else ""
		var addr := String(d.get("address", "")).strip_edges() if d.get("address") is String else ""
		var port := int(d.get("port", Net.DEFAULT_PORT)) if (d.get("port") is float or d.get("port") is int) else Net.DEFAULT_PORT
		if Net.is_ws_url(url) and (addr == "" or not Net.enet_available()):
			entry["join"] = url
			entry["ws"] = true
		elif addr != "" and port > 0 and port < 65536:
			entry["join"] = "%s:%d" % [_host(addr.trim_prefix("[").trim_suffix("]")), port]
			entry["ws"] = false
		else:
			continue
		if entry["name"] == "":
			entry["name"] = "Server"
		entry["status"] = String(d["status"]) if d.get("status") is String and String(d["status"]).begins_with("http") \
			else status_url_for(entry["join"])
		out.append(entry)
	return out


static func status_url_for(join: String) -> String:
	## Where a server's status page is when the list doesn't say:
	## - an ENet server "host:port": http://host:<port + 1>/status;
	## - ws://host:port[/path]: http://host:<port + 1>/status (the game serves it itself);
	## - wss://host[:port][/path]: https://host[:port][/path]/status (behind a proxy, as in
	##   docs/MULTIPLAYER.md, which sends /status on to the game's status port).
	var j := join.strip_edges()
	if j.begins_with("wss://"):
		return "https://" + j.substr(6).trim_suffix("/") + "/status"
	if j.begins_with("ws://"):
		var rest := j.substr(5).get_slice("/", 0)
		var hp := MainMenu.split_address(rest)
		return "http://%s:%d/status" % [_host(String(hp[0])), int(hp[1]) + 1]
	var hp2 := MainMenu.split_address(j)
	if String(hp2[0]) == "":
		return ""
	return "http://%s:%d/status" % [_host(String(hp2[0])), int(hp2[1]) + 1]


static func _host(h: String) -> String:
	return "[%s]" % h if h.contains(":") else h


static func describe(st: Dictionary) -> String:
	## "12/31 players  -  Cheese Race 3-1 (to 10)"
	var players := "%d/%d players" % [int(st.get("players", 0)), int(st.get("max_players", 0))]
	var mode := String(MODES.get(String(st.get("mode", "")), ""))
	if st.get("mode") == "race" and st.get("score") is Array and (st["score"] as Array).size() == 2:
		mode += " %d-%d (to %d)" % [int(st["score"][0]), int(st["score"][1]), int(st.get("goal", 0))]
	return players + ("  -  " + mode if mode != "" else "")


static func why_not(entry: Dictionary, st: Variant) -> String:
	## "" when this server can be joined from here, else a short reason.
	if not bool(entry.get("ws", false)) and not Net.enet_available():
		return "Desktop only"
	if st is Dictionary:
		var s: Dictionary = st
		if s.has("protocol") and int(s["protocol"]) != Net.PROTOCOL:
			return "Needs version %s" % Net.clean_name(String(s.get("version", "?")))
		if s.has("max_players") and int(s.get("players", 0)) >= int(s["max_players"]):
			return "Full"
	return ""


static func ping_ms(elapsed_ms: float, url: String) -> int:
	## A status fetch takes about two round trips over http (connect, ask) and
	## three over https (plus the TLS handshake): that, divided out.
	return roundi(elapsed_ms / (3.0 if url.begins_with("https") else 2.0))
