class_name NetworkLobby
extends Control

signal back_requested

const NETWORK_SESSION_SCRIPT := preload("res://scripts/network/network_session.gd")
const NETWORK_TOOL_CATALOG := preload(
	"res://scripts/network/network_tool_catalog.gd"
)
const PROFESSION_CATALOG := preload(
	"res://scripts/professions/profession_catalog.gd"
)
const GAME_STATE_BASE := preload("res://scripts/systems/game_state_base.gd")
const MAIN_MENU_STYLE := preload("res://scripts/presentation/main_menu_overlay_style.gd")
const UI_FONT: Font = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const INVENTORY_TRAY_TEXTURE: Texture2D = preload(
	"res://assets/ui/inventory_tray.png"
)
const INVENTORY_SLOT_TEXTURE: Texture2D = preload(
	"res://assets/ui/inventory_slot.png"
)
const ADRENALINE_ICON: Texture2D = preload(
	"res://assets/ui/icons/adrenaline.png"
)

var session: NetworkSession
var name_input: LineEdit
var host_input: LineEdit
var port_input: LineEdit
var status_label: Label
var players_label: Label
var profession_option: OptionButton
var loadout_slot_icons: Array[TextureRect] = []
var loadout_slot_labels: Array[Label] = []
var host_button: Button
var join_button: Button
var leave_button: Button
var ready_button: Button
var start_button: Button
var auto_ready_requested := false
var auto_ready_sent := false
var syncing_profession_option := false
var toolbelt_tray_style: StyleBoxTexture
var toolbelt_slot_style: StyleBoxTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 20
	toolbelt_tray_style = _make_texture_style(
		INVENTORY_TRAY_TEXTURE,
		72.0,
		32.0,
	)
	toolbelt_slot_style = _make_texture_style(
		INVENTORY_SLOT_TEXTURE,
		0.0,
		0.0,
	)
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
	panel.name = "LobbyPanel"
	panel.custom_minimum_size = Vector2(900, 710)
	MAIN_MENU_STYLE.apply_panel(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var title := Label.new()
	title.text = "联机狩猎"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "一名怪物 · 三名盗贼"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", MAIN_MENU_STYLE.MUTED)
	content.add_child(subtitle)

	var separator := HSeparator.new()
	content.add_child(separator)

	var form := GridContainer.new()
	form.columns = 6
	form.add_theme_constant_override("h_separation", 10)
	content.add_child(form)

	name_input = _add_text_field(form, "名称", "本机玩家", 160)
	host_input = _add_text_field(form, "服务器", "127.0.0.1", 190)
	port_input = _add_text_field(form, "端口", "7777", 100)

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

	_build_profession_picker(content)

	players_label = Label.new()
	players_label.text = "尚无玩家。"
	players_label.custom_minimum_size = Vector2(0, 76)
	players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(players_label)

	_build_toolbelt(content)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	start_button = _add_button(footer, "开始游戏", _on_start_pressed)
	start_button.disabled = true
	_add_button(footer, "返回模式选择", request_back)


func _build_profession_picker(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "ProfessionPicker"
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var players_title := Label.new()
	players_title.text = "当前玩家槽"
	players_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	players_title.add_theme_font_size_override("font_size", 25)
	players_title.add_theme_color_override("font_color", MAIN_MENU_STYLE.GOLD)
	row.add_child(players_title)

	var label := Label.new()
	label.text = "职业"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", MAIN_MENU_STYLE.GOLD)
	row.add_child(label)

	profession_option = OptionButton.new()
	profession_option.custom_minimum_size = Vector2(330, 48)
	profession_option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	profession_option.clip_text = true
	profession_option.add_theme_constant_override("arrow_margin", 18)
	profession_option.item_selected.connect(_on_profession_selected)
	MAIN_MENU_STYLE.apply_button(profession_option)
	_expand_profession_button_content()
	row.add_child(profession_option)


func _add_text_field(
	parent: GridContainer,
	label_text: String,
	initial_text: String,
	minimum_width := 420.0,
) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var input := LineEdit.new()
	input.text = initial_text
	input.custom_minimum_size = Vector2(minimum_width, 44)
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


func _build_toolbelt(parent: Container) -> void:
	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#c5b79e"))
	parent.add_child(title)

	var tray := PanelContainer.new()
	tray.name = "LoadoutToolbelt"
	tray.custom_minimum_size = Vector2(0, 76)
	tray.add_theme_stylebox_override("panel", toolbelt_tray_style)
	parent.add_child(tray)

	var tray_margin := MarginContainer.new()
	tray_margin.add_theme_constant_override("margin_left", 54)
	tray_margin.add_theme_constant_override("margin_top", 7)
	tray_margin.add_theme_constant_override("margin_right", 54)
	tray_margin.add_theme_constant_override("margin_bottom", 7)
	tray.add_child(tray_margin)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	tray_margin.add_child(slots)
	for index in range(NETWORK_TOOL_CATALOG.MAX_LOADOUT_SIZE):
		var slot := PanelContainer.new()
		slot.name = "ToolSlot%d" % (index + 1)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0, 62)
		slot.add_theme_stylebox_override("panel", toolbelt_slot_style)
		slots.add_child(slot)

		var slot_margin := MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 58)
		slot_margin.add_theme_constant_override("margin_top", 9)
		slot_margin.add_theme_constant_override("margin_right", 28)
		slot_margin.add_theme_constant_override("margin_bottom", 9)
		slot.add_child(slot_margin)
		var slot_content := HBoxContainer.new()
		slot_content.add_theme_constant_override("separation", 8)
		slot_margin.add_child(slot_content)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_content.add_child(icon)
		loadout_slot_icons.append(icon)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)
		slot_content.add_child(label)
		loadout_slot_labels.append(label)


func _make_texture_style(
	texture: Texture2D,
	horizontal_margin: float,
	vertical_margin: float,
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = horizontal_margin
	style.texture_margin_top = vertical_margin
	style.texture_margin_right = horizontal_margin
	style.texture_margin_bottom = vertical_margin
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _expand_profession_button_content() -> void:
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var current := profession_option.get_theme_stylebox(state_name)
		if not current:
			continue
		var style := current.duplicate()
		style.content_margin_left = 46
		style.content_margin_right = 54
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		profession_option.add_theme_stylebox_override(state_name, style)


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


func _on_profession_selected(index: int) -> void:
	if syncing_profession_option or index < 0:
		return
	var profession_id := str(profession_option.get_item_metadata(index))
	session.set_local_profession(profession_id)


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
			"%s  %s · %s　%s"
			% [
				"●" if bool(entry.get("ready", false)) else "○",
				_slot_label(str(entry.get("slot", ""))),
				PROFESSION_CATALOG.title_for(
					str(entry.get("profession_id", "")),
				),
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
	_refresh_profession_ui(local_entry)
	_refresh_loadout_ui()


func _refresh_profession_ui(local_entry: Dictionary) -> void:
	if not profession_option:
		return
	syncing_profession_option = true
	profession_option.clear()
	if local_entry.is_empty():
		profession_option.add_item("连接后选择职业")
		profession_option.set_item_metadata(0, "")
		profession_option.disabled = true
		syncing_profession_option = false
		return
	var slot := str(local_entry.get("slot", ""))
	var profession_id := str(local_entry.get("profession_id", ""))
	var selected_index := 0
	var definitions := PROFESSION_CATALOG.for_slot(slot)
	for index in range(definitions.size()):
		var definition: Resource = definitions[index]
		profession_option.add_item(definition.title)
		profession_option.set_item_metadata(index, definition.id)
		if definition.id == profession_id:
			selected_index = index
	if not definitions.is_empty():
		profession_option.select(selected_index)
	profession_option.disabled = (
		bool(local_entry.get("ready", false))
		or session.match_running
		or definitions.size() <= 1
	)
	syncing_profession_option = false


func _refresh_loadout_ui() -> void:
	if loadout_slot_labels.size() < NETWORK_TOOL_CATALOG.MAX_LOADOUT_SIZE:
		return
	var entry: Dictionary = session.players.get(session.local_peer_id(), {})
	var loadout: Array = entry.get("loadout", [])
	for index in range(NETWORK_TOOL_CATALOG.MAX_LOADOUT_SIZE):
		var icon := loadout_slot_icons[index]
		var label := loadout_slot_labels[index]
		if index >= loadout.size():
			icon.texture = null
			icon.hide()
			label.text = "%d · 空" % (index + 1)
			label.add_theme_color_override("font_color", MAIN_MENU_STYLE.MUTED)
			continue
		var tool_type := str(loadout[index])
		icon.texture = (
			ADRENALINE_ICON
			if tool_type == "adrenaline"
			else null
		)
		icon.visible = icon.texture != null
		label.text = "%d · %s" % [
			index + 1,
			str(GAME_STATE_BASE.TOOL_DEFS.get(tool_type, {}).get(
				"short",
				tool_type,
			)),
		]
		label.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)


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
