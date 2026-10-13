extends Node
## شبكة LAN: ENet + اكتشاف الغرف عبر UDP broadcast. المضيف هو المرجع (server-authoritative).

signal players_changed
signal rooms_changed
signal error(msg: String)
signal joined
signal peer_left(id: int)

var players := {}        # peer_id -> {name, team}
var settings := {}
var room_name := ""
var my_name := "لاعب"
var is_host := false
var in_match := false
var match_map := ""
var last_error := ""
var rooms := {}          # ip -> {name, n, max, t}

var _tx: PacketPeerUDP
var _rx: PacketPeerUDP
var _t := 0.0


func _ready() -> void:
	settings = Cfg.default_settings()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


# ---------- إنشاء / انضمام / مغادرة ----------

func host_room(pname: String, rname: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(Cfg.PORT, Cfg.MAX_PLAYERS - 1) != OK:
		error.emit("تعذر إنشاء الغرفة: المنفذ مستخدم أو الشبكة غير متاحة")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	my_name = pname
	room_name = rname
	settings = Cfg.default_settings()
	players = {1: {"name": pname, "team": _pick_team()}}
	_tx = PacketPeerUDP.new()
	_tx.set_broadcast_enabled(true)
	_tx.set_dest_address("255.255.255.255", Cfg.DISCOVERY_PORT)
	return true


func join_room(ip: String, pname: String) -> void:
	leave()
	my_name = pname
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, Cfg.PORT) != OK:
		error.emit("عنوان غير صالح")
		return
	multiplayer.multiplayer_peer = peer


func leave() -> void:
	multiplayer.multiplayer_peer = null
	is_host = false
	in_match = false
	players = {}
	settings = Cfg.default_settings()
	room_name = ""
	_tx = null


func start_search() -> void:
	stop_search()
	_rx = PacketPeerUDP.new()
	if _rx.bind(Cfg.DISCOVERY_PORT) != OK:
		_rx = null


func stop_search() -> void:
	if _rx:
		_rx.close()
	_rx = null
	rooms.clear()


func _process(delta: float) -> void:
	_t += delta
	if is_host and _tx and not in_match and _t >= 1.0:
		_t = 0.0
		var msg := JSON.stringify({"g": "LANWAR", "name": room_name, "n": players.size(), "max": settings.max_players})
		_tx.put_packet(msg.to_utf8_buffer())
	if _rx:
		var changed := false
		while _rx.get_available_packet_count() > 0:
			var txt := _rx.get_packet().get_string_from_utf8()
			var ip := _rx.get_packet_ip()
			var d = JSON.parse_string(txt)
			if d is Dictionary and d.get("g") == "LANWAR":
				rooms[ip] = {"name": d.get("name", "?"), "n": d.get("n", 0), "max": d.get("max", 16), "t": Time.get_ticks_msec()}
				changed = true
		var now := Time.get_ticks_msec()
		for k in rooms.keys():
			if now - int(rooms[k].t) > 4000:
				rooms.erase(k)
				changed = true
		if changed:
			rooms_changed.emit()


# ---------- أحداث الاتصال ----------

func _on_connected() -> void:
	_register.rpc_id(1, my_name)
	joined.emit()


func _on_failed() -> void:
	last_error = "فشل الاتصال بالمضيف"
	error.emit(last_error)
	leave()


func _on_server_lost() -> void:
	last_error = "انقطع الاتصال بالمضيف"
	leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if in_match or players.size() >= int(settings.max_players):
		_rejected.rpc_id(id, "المباراة بدأت بالفعل" if in_match else "الغرفة ممتلئة")
		get_tree().create_timer(0.6).timeout.connect(func():
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(id))


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	_broadcast()
	peer_left.emit(id)


@rpc("authority", "call_remote", "reliable")
func _rejected(msg: String) -> void:
	last_error = msg
	leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------- تسجيل اللاعبين والفرق ----------

@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) or players.size() >= int(settings.max_players):
		return
	players[id] = {"name": pname.substr(0, 20), "team": _pick_team()}
	_broadcast()


func _pick_team() -> int:
	var counts := []
	for i in int(settings.team_count):
		counts.append(0)
	for p in players.values():
		if p.team < counts.size():
			counts[p.team] += 1
	var best := -1
	for i in counts.size():
		if counts[i] < Cfg.MAX_PER_TEAM and (best == -1 or counts[i] < counts[best]):
			best = i
	return maxi(best, 0)


func _rebalance() -> void:
	var ids := players.keys()
	ids.shuffle()
	for i in ids.size():
		players[ids[i]].team = i % int(settings.team_count)


func request_team(t: int) -> void:
	_req_team.rpc_id(1, t)


@rpc("any_peer", "call_local", "reliable")
func _req_team(t: int) -> void:
	if not multiplayer.is_server() or settings.locked or not settings.team_choice:
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if not players.has(id) or t < 0 or t >= int(settings.team_count):
		return
	var c := 0
	for p in players.values():
		if p.team == t:
			c += 1
	if c >= Cfg.MAX_PER_TEAM:
		return
	players[id].team = t
	_broadcast()


# ---------- إعدادات المضيف ----------

func set_setting(key: String, value) -> void:
	if not is_host or settings.locked:
		return
	match key:
		"max_players":
			settings.max_players = clampi(int(value), maxi(players.size(), 1), mini(Cfg.MAX_PLAYERS, int(settings.team_count) * Cfg.MAX_PER_TEAM))
		"team_count":
			settings.team_count = clampi(int(value), 2, 4)
			settings.max_players = mini(int(settings.max_players), int(settings.team_count) * Cfg.MAX_PER_TEAM)
			_rebalance()
		"team_choice", "bots":
			settings[key] = bool(value)
		"map":
			settings.map = str(value)
		"win_score":
			settings.win_score = clampi(int(value), 1, 999)
		"respawn":
			settings.respawn = clampf(float(value), 1.0, 30.0)
		"damage":
			settings.damage = clampf(float(value), 0.25, 3.0)
	_broadcast()


func set_limit(cat: String, v) -> void:
	if not is_host or settings.locked or not Cfg.LIMIT_DEFAULTS.has(cat):
		return
	settings.limits[cat] = clampi(int(v), 0, int(Cfg.LIMIT_DEFAULTS[cat]))
	_broadcast()


func _broadcast() -> void:
	players_changed.emit()
	if multiplayer.is_server():
		_sync_lobby.rpc(players, settings, room_name)


@rpc("authority", "call_remote", "reliable")
func _sync_lobby(p: Dictionary, s: Dictionary, rn: String) -> void:
	players = p
	settings = s
	room_name = rn
	players_changed.emit()


# ---------- بدء / إنهاء المباراة ----------

func start_match() -> void:
	if not is_host:
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		error.emit("المضيف غير متصل")
		return
	var maps := Cfg.MAPS.keys()
	if maps.is_empty():
		error.emit("لا توجد خريطة صالحة")
		return
	var chosen: String = settings.map
	if chosen == "" or not maps.has(chosen):
		chosen = maps.pick_random()
	if not settings.team_choice:
		_rebalance()
	settings.locked = true
	_begin.rpc(chosen, settings, players)


@rpc("authority", "call_local", "reliable")
func _begin(map_id: String, s: Dictionary, p: Dictionary) -> void:
	match_map = map_id
	settings = s
	players = p
	in_match = true
	get_tree().change_scene_to_file("res://scenes/match.tscn")


func end_match() -> void:
	if multiplayer.is_server():
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_match = false
	settings.locked = false
	match_map = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
