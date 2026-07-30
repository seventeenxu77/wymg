class_name NetworkSession
extends Node

signal state_changed(state: int, message: String)
signal players_changed(players: Dictionary)
signal match_started(players: Dictionary)
signal match_ended(reason: String)

enum State {
	OFFLINE,
	HOSTING,
	CONNECTING,
	CONNECTED,
	ERROR,
}

const PLAYER_SLOTS := ["monster", "thief-1", "thief-2", "thief-3"]

var state := State.OFFLINE
var status_message := "尚未连接。"
var peer: ENetMultiplayerPeer
var players: Dictionary = {}
var local_name := "玩家"
var preferred_slot := ""
var dedicated := false
var auto_start_when_ready := false
var match_running := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(
	port: int,
	player_name := "房主",
	requested_slot := "monster",
	as_dedicated := false,
	auto_start := false
) -> Error:
	shutdown(false)
	var next_peer := ENetMultiplayerPeer.new()
	var error := next_peer.create_server(port, PLAYER_SLOTS.size())
	if error != OK:
		_set_state(State.ERROR, "无法监听 UDP 端口 %d，错误码 %d。" % [port, error])
		return error
	peer = next_peer
	dedicated = as_dedicated
	auto_start_when_ready = auto_start
	match_running = false
	local_name = player_name.strip_edges() if not player_name.strip_edges().is_empty() else "房主"
	preferred_slot = requested_slot
	multiplayer.multiplayer_peer = peer
	players.clear()
	if not dedicated:
		players[1] = _make_player_entry(1, local_name, _claim_slot(preferred_slot))
	_set_state(
		State.HOSTING,
		"服务器已启动：127.0.0.1:%d%s"
		% [port, "（独立服务器）" if dedicated else ""],
	)
	_emit_players()
	return OK


func join(
	address: String,
	port: int,
	player_name := "玩家",
	requested_slot := ""
) -> Error:
	shutdown(false)
	var next_peer := ENetMultiplayerPeer.new()
	var error := next_peer.create_client(address, port)
	if error != OK:
		_set_state(State.ERROR, "无法连接 %s:%d，错误码 %d。" % [address, port, error])
		return error
	peer = next_peer
	dedicated = false
	auto_start_when_ready = false
	match_running = false
	local_name = player_name.strip_edges() if not player_name.strip_edges().is_empty() else "玩家"
	preferred_slot = requested_slot
	multiplayer.multiplayer_peer = peer
	_set_state(State.CONNECTING, "正在连接 %s:%d……" % [address, port])
	return OK


func shutdown(emit_state := true) -> void:
	if is_instance_valid(peer):
		peer.close()
	peer = null
	players.clear()
	match_running = false
	auto_start_when_ready = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	status_message = "尚未连接。"
	if emit_state:
		state_changed.emit(state, status_message)
		players_changed.emit(players.duplicate(true))


func is_online() -> bool:
	return state in [State.HOSTING, State.CONNECTING, State.CONNECTED]


func is_server() -> bool:
	return is_online() and multiplayer.is_server()


func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 0


func set_local_ready(ready: bool) -> void:
	if not is_online() or match_running:
		return
	var peer_id := local_peer_id()
	if is_server():
		_set_player_ready(peer_id, ready)
	else:
		_request_ready.rpc_id(1, ready)


func can_start_match(require_full_roster := false) -> bool:
	if not is_server() or match_running:
		return false
	var required_count := PLAYER_SLOTS.size() if require_full_roster else 2
	if players.size() < required_count:
		return false
	for entry_variant in players.values():
		var entry: Dictionary = entry_variant
		if str(entry.get("slot", "")) == "spectator" or not bool(entry.get("ready", false)):
			return false
	return true


func request_start_match(require_full_roster := false) -> bool:
	if not can_start_match(require_full_roster):
		return false
	match_running = true
	var snapshot := players.duplicate(true)
	_set_state(State.HOSTING, "所有玩家已准备，正在进入联机对局。")
	match_started.emit(snapshot)
	_receive_match_started.rpc(snapshot)
	return true


func state_label() -> String:
	match state:
		State.HOSTING: return "房主"
		State.CONNECTING: return "连接中"
		State.CONNECTED: return "已连接"
		State.ERROR: return "连接错误"
	return "离线"


func _set_state(next_state: int, message: String) -> void:
	state = next_state
	status_message = message
	print("[NetworkSession][%s] %s" % [local_name, message])
	state_changed.emit(state, status_message)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_set_state(State.HOSTING, "玩家 %d 已连接，等待登记。" % id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		_set_state(State.HOSTING, "玩家 %d 已离开房间。" % id)
		_broadcast_players()


func _on_connected_to_server() -> void:
	_set_state(State.CONNECTED, "已连接服务器，正在登记玩家槽。")
	_register_player.rpc_id(1, local_name, preferred_slot)


func _on_connection_failed() -> void:
	_set_state(State.ERROR, "连接服务器失败。")


func _on_server_disconnected() -> void:
	players.clear()
	if match_running:
		match_running = false
		match_ended.emit("服务器连接已断开。")
	_set_state(State.ERROR, "服务器连接已断开。")
	players_changed.emit(players.duplicate(true))


@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String, requested_slot: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	var slot := _claim_slot(requested_slot)
	players[sender_id] = _make_player_entry(sender_id, player_name, slot)
	_set_state(State.HOSTING, "%s 已加入 %s。" % [player_name, _slot_label(slot)])
	_broadcast_players()


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(ready: bool) -> void:
	if not multiplayer.is_server() or match_running:
		return
	_set_player_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("authority", "call_remote", "reliable")
func _receive_players(snapshot: Dictionary) -> void:
	players = snapshot.duplicate(true)
	players_changed.emit(players.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _receive_match_started(snapshot: Dictionary) -> void:
	match_running = true
	players = snapshot.duplicate(true)
	players_changed.emit(players.duplicate(true))
	match_started.emit(players.duplicate(true))


func _broadcast_players() -> void:
	_emit_players()
	if multiplayer.is_server():
		_receive_players.rpc(players)
		_try_auto_start()


func _emit_players() -> void:
	if multiplayer.is_server():
		print("[NetworkSession][server] players=%s" % str(players))
	players_changed.emit(players.duplicate(true))


func _set_player_ready(peer_id: int, ready: bool) -> void:
	if not players.has(peer_id):
		return
	var entry: Dictionary = (players[peer_id] as Dictionary).duplicate(true)
	entry["ready"] = ready
	players[peer_id] = entry
	_set_state(
		State.HOSTING,
		"%s%s。"
		% [
			str(entry.get("name", "玩家")),
			"已准备" if ready else "取消准备",
		],
	)
	_broadcast_players()


func _try_auto_start() -> void:
	if auto_start_when_ready and can_start_match(true):
		request_start_match(true)


func _claim_slot(requested_slot: String) -> String:
	var occupied: Dictionary = {}
	for entry in players.values():
		occupied[str((entry as Dictionary).get("slot", ""))] = true
	if requested_slot in PLAYER_SLOTS and not occupied.has(requested_slot):
		return requested_slot
	for slot in PLAYER_SLOTS:
		if not occupied.has(slot):
			return slot
	return "spectator"


func _make_player_entry(id: int, player_name: String, slot: String) -> Dictionary:
	return {
		"peer_id": id,
		"name": player_name,
		"slot": slot,
		"ready": false,
	}


func _slot_label(slot: String) -> String:
	match slot:
		"monster": return "怪物"
		"thief-1": return "盗贼 1"
		"thief-2": return "盗贼 2"
		"thief-3": return "盗贼 3"
	return "观战席"
