class_name NetworkLobby
extends Control

signal back_requested

const NETWORK_SESSION_SCRIPT := preload("res://scripts/network/network_session.gd")
const MAIN_MENU_STYLE := preload("res://scripts/presentation/main_menu_overlay_style.gd")
const UI_FONT: Font = preload("res://assets/fonts/MaShanZheng-Regular.ttf")

var session: NetworkSession
var name_input: LineEdit
var host_input: LineEdit
var port_input: LineEdit
var status_label: Label
var players_label: Label
var host_button: Button
var join_button: Button
var leave_button: Button
var ready_button: Button
var start_button: Button
var auto_ready_requested := false
var auto_ready_sent := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 20
	session = NETWORK_SESSION_SCRIPT.new()
	session.name = "NetworkSession"
	add_child(session)
	session.state_changed.connect(_on_session_state_changed)
	session.players_changed.connect(_on_players_changed)
	_build_ui()
	_refresh_session_ui()


func open(options: Dictionary = {}) -> void:
	show()
	if options.is_empty():
		_refresh_session_ui()
		return
	auto_ready_requested = bool(options.get("auto_ready", false))
	auto_ready_sent = false
	name_input.text = str(options.get("name", "玩家"))
	host_input.text = str(options.get("host", "127.0.0.1"))
	port_input.text = str(int(options.get("port", 7777)))
	var launch_mode := str(options.get("mode", ""))
	if launch_mode == "server":
		session.host(
			_parse_port(),
			name_input.text,
			str(options.get("slot", "monster")),
			bool(options.get("dedicated", true)),
			bool(options.get("auto_start", false)),
		)
	elif launch_mode == "client":
		session.join(
			host_input.text.strip_edges(),
			_parse_port(),
			name_input.text,
			str(options.get("slot", "")),
		)


func close() -> void:
	auto_ready_requested = false
	auto_ready_sent = false
	session.shutdown()
	hide()


func hide_for_match() -> void:
	hide()


func request_back() -> void:
	session.shutdown()
	back_requested.emit()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 72
	center.offset_top = 48
	center.offset_right = -72
	center.offset_bottom = -48
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 650)
	MAIN_MENU_STYLE.apply_panel(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title := Label.new()
	title.text = "联机狩猎"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "网络大厅框架 · 当前用于连接、玩家槽与多实例调试"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", MAIN_MENU_STYLE.MUTED)
	content.add_child(subtitle)

	var separator := HSeparator.new()
	content.add_child(separator)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 18)
	form.add_theme_constant_override("v_separation", 12)
	content.add_child(form)

	name_input = _add_text_field(form, "玩家名称", "本机玩家")
	host_input = _add_text_field(form, "服务器地址", "127.0.0.1")
	port_input = _add_text_field(form, "UDP 端口", "7777")

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	host_button = _add_button(actions, "创建房间", _on_host_pressed)
	join_button = _add_button(actions, "加入房间", _on_join_pressed)
	leave_button = _add_button(actions, "离开连接", _on_leave_pressed)
	ready_button = _add_button(actions, "准备", _on_ready_pressed)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	content.add_child(status_label)

	var players_title := Label.new()
	players_title.text = "当前玩家槽"
	players_title.add_theme_font_size_override("font_size", 25)
	players_title.add_theme_color_override("font_color", MAIN_MENU_STYLE.GOLD)
	content.add_child(players_title)

	players_label = Label.new()
	players_label.text = "尚无玩家。"
	players_label.custom_minimum_size = Vector2(0, 82)
	players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(players_label)

	var note := Label.new()
	note.text = (
		"玩家准备后由房主开始。也可以使用 dev/run_1v3.ps1 启动"
		+ "独立服务器和四个自动准备的本机窗口。"
	)
	note.modulate = Color("#989d94")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	start_button = _add_button(footer, "开始游戏", _on_start_pressed)
	start_button.disabled = true
	_add_button(footer, "返回模式选择", request_back)


func _add_text_field(parent: GridContainer, label_text: String, initial_text: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var input := LineEdit.new()
	input.text = initial_text
	input.custom_minimum_size = Vector2(420, 44)
	MAIN_MENU_STYLE.apply_line_edit(input)
	parent.add_child(input)
	return input


func _add_button(parent: Container, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(
		maxf(170.0, 44.0 + float(label_text.length()) * 23.0),
		48,
	)
	button.pressed.connect(callback)
	MAIN_MENU_STYLE.apply_button(button)
	parent.add_child(button)
	return button


func _on_host_pressed() -> void:
	session.host(_parse_port(), name_input.text, "monster", false)


func _on_join_pressed() -> void:
	var address := host_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	session.join(address, _parse_port(), name_input.text)


func _on_leave_pressed() -> void:
	session.shutdown()


func _on_ready_pressed() -> void:
	var entry: Dictionary = session.players.get(session.local_peer_id(), {})
	session.set_local_ready(not bool(entry.get("ready", false)))


func _on_start_pressed() -> void:
	session.request_start_match()


func _parse_port() -> int:
	return clampi(int(port_input.text), 1, 65535)


func _on_session_state_changed(_state: int, _message: String) -> void:
	_refresh_session_ui()


func _on_players_changed(snapshot: Dictionary) -> void:
	var ids := snapshot.keys()
	ids.sort()
	var lines: Array[String] = []
	for id in ids:
		var entry: Dictionary = snapshot[id]
		lines.append(
			"%s  Peer %-6s  %-10s  %s"
			% [
				"●" if bool(entry.get("ready", false)) else "○",
				str(id),
				_slot_label(str(entry.get("slot", ""))),
				str(entry.get("name", "玩家")),
			]
		)
	players_label.text = "\n".join(lines) if not lines.is_empty() else "尚无玩家。"
	_try_auto_ready()
	_refresh_session_ui()


func _refresh_session_ui() -> void:
	if not status_label:
		return
	status_label.text = "%s · %s" % [session.state_label(), session.status_message]
	status_label.modulate = (
		Color("#e98572")
		if session.state == NetworkSession.State.ERROR
		else Color("#8fd0a4")
		if session.is_online()
		else Color("#c5c0ad")
	)
	var online := session.is_online()
	var local_entry: Dictionary = session.players.get(session.local_peer_id(), {})
	var registered := not local_entry.is_empty()
	var local_ready := bool(local_entry.get("ready", false))
	host_button.disabled = online
	join_button.disabled = online
	leave_button.disabled = not online
	ready_button.text = "取消准备" if local_ready else "准备"
	ready_button.disabled = not registered or session.match_running
	start_button.text = "开始游戏" if session.is_server() else "等待房主开始"
	start_button.disabled = not session.can_start_match()


func _try_auto_ready() -> void:
	if not auto_ready_requested or auto_ready_sent or session.match_running:
		return
	if not session.players.has(session.local_peer_id()):
		return
	auto_ready_sent = true
	session.set_local_ready(true)


func _slot_label(slot: String) -> String:
	match slot:
		"monster": return "怪物"
		"thief-1": return "盗贼 1"
		"thief-2": return "盗贼 2"
		"thief-3": return "盗贼 3"
	return "观战席"
