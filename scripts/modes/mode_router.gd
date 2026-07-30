class_name GameModeRouter
extends Control

signal classic_local_requested
signal main_menu_requested

const MODE_CATALOG := preload("res://scripts/modes/game_mode_catalog.gd")
const NETWORK_LOBBY_SCRIPT := preload("res://scripts/network/network_lobby.gd")
const NETWORK_MATCH_SCRIPT := preload("res://scripts/network/network_match.gd")
const MAIN_MENU_STYLE := preload("res://scripts/presentation/main_menu_overlay_style.gd")
const UI_FONT: Font = preload("res://assets/fonts/MaShanZheng-Regular.ttf")

var active := false
var current_mode_id := ""
var mode_selection: Control
var mode_status: Label
var network_lobby: NetworkLobby
var network_match: NetworkMatch


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_viewport_rect()
	get_viewport().size_changed.connect(_sync_viewport_rect)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 20
	MAIN_MENU_STYLE.add_backdrop(self)
	_build_mode_selection()
	network_lobby = NETWORK_LOBBY_SCRIPT.new()
	network_lobby.name = "NetworkLobby"
	network_lobby.back_requested.connect(open_mode_selection)
	add_child(network_lobby)
	network_lobby.hide()
	network_match = NETWORK_MATCH_SCRIPT.new()
	network_match.name = "NetworkMatch"
	network_match.setup(network_lobby.session)
	network_match.leave_requested.connect(_leave_network_match)
	network_lobby.session.match_started.connect(_on_network_match_started)
	add_child(network_match)
	network_match.hide()
	hide()


func _sync_viewport_rect() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func open_mode_selection() -> void:
	active = true
	current_mode_id = ""
	show()
	network_match.stop_match()
	network_lobby.close()
	mode_selection.show()
	mode_status.text = "选择要进入的游戏模式。"
	MAIN_MENU_STYLE.animate_page(mode_selection)


func open_online_lobby(options: Dictionary = {}) -> void:
	active = true
	current_mode_id = MODE_CATALOG.ONLINE_HUNT
	show()
	network_match.stop_match()
	mode_selection.hide()
	network_lobby.open(options)
	MAIN_MENU_STYLE.animate_page(network_lobby)


func close() -> void:
	active = false
	current_mode_id = ""
	network_match.stop_match()
	network_lobby.close()
	mode_selection.hide()
	hide()


func select_mode(mode_id: String) -> void:
	var definition: GameModeDefinition = MODE_CATALOG.find(mode_id)
	if not definition:
		mode_status.text = "未知游戏模式：%s" % mode_id
		return
	if not definition.available:
		mode_status.text = "%s仍在规划中。" % definition.title
		return
	match mode_id:
		MODE_CATALOG.LOCAL_DUEL:
			current_mode_id = mode_id
			classic_local_requested.emit()
		MODE_CATALOG.ONLINE_HUNT:
			open_online_lobby()


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if network_match.visible:
		return network_match.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if network_lobby.visible:
			open_mode_selection()
		else:
			close()
			main_menu_requested.emit()
		return true
	return false


func _on_network_match_started(players: Dictionary) -> void:
	mode_selection.hide()
	network_lobby.hide_for_match()
	network_match.start_match(players)
	MAIN_MENU_STYLE.animate_page(network_match)


func _leave_network_match() -> void:
	network_match.stop_match()
	network_lobby.session.shutdown()
	network_lobby.open()
	MAIN_MENU_STYLE.animate_page(network_lobby)


func _build_mode_selection() -> void:
	mode_selection = Control.new()
	mode_selection.name = "ModeSelection"
	mode_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mode_selection)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 72
	center.offset_top = 48
	center.offset_right = -72
	center.offset_bottom = -48
	mode_selection.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 680)
	MAIN_MENU_STYLE.apply_panel(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := Label.new()
	title.text = "选择游戏模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "经典玩法保持独立；新模式使用各自的入口、规则与控制方式。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", MAIN_MENU_STYLE.MUTED)
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	for definition in MODE_CATALOG.all():
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		content.add_child(card)
		var button := Button.new()
		button.text = definition.title if definition.available else "%s（规划中）" % definition.title
		button.custom_minimum_size = Vector2(0, 58)
		button.disabled = not definition.available
		button.pressed.connect(select_mode.bind(definition.id))
		MAIN_MENU_STYLE.apply_button(button)
		card.add_child(button)
		var description := Label.new()
		description.text = definition.description
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.modulate = Color("#969b91") if definition.available else Color("#62665f")
		card.add_child(description)

	mode_status = Label.new()
	mode_status.text = "选择要进入的游戏模式。"
	mode_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_status.add_theme_color_override("font_color", MAIN_MENU_STYLE.GOLD)
	mode_status.custom_minimum_size.y = 42
	content.add_child(mode_status)

	var back := Button.new()
	back.text = "返回主菜单"
	back.custom_minimum_size = Vector2(0, 52)
	MAIN_MENU_STYLE.apply_button(back)
	back.pressed.connect(func():
		close()
		main_menu_requested.emit()
	)
	content.add_child(back)
