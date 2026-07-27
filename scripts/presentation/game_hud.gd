@tool
class_name GameHud
extends Node2D

# The HUD is a pure presentation adapter. It reads game state from the host
# coordinator and only writes screen hit rectangles used by input handling.

const MAP_SIZE := 6
const ROOM_SIZE := 5.0
const TOOL_INVENTORY_CAPACITY := 3
const TRAP_ESCAPE_PRESSES := 20
const PICKUP_DISTANCE := 0.64
const MATCH_ROUNDS := 4

const VIEWPORT_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/viewport_frame.png")
const CENTER_DIVIDER_TEXTURE: Texture2D = preload("res://assets/ui/center_divider.png")
const HEADER_PLAQUE_TEXTURE: Texture2D = preload("res://assets/ui/header_plaque.png")
const MINIMAP_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/minimap_frame.png")
const INVENTORY_TRAY_TEXTURE: Texture2D = preload("res://assets/ui/inventory_tray.png")
const INVENTORY_SLOT_TEXTURE: Texture2D = preload("res://assets/ui/inventory_slot.png")
const BUTTON_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/button_frame.png")
const SQUARE_BUTTON_TEXTURE: Texture2D = preload("res://assets/ui/square_button.png")
const MODAL_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/modal_panel.png")
const COPPER_COIN_TEXTURE: Texture2D = preload("res://GJGamejam素材/2.5D物品/copper_coin.png")
const MAIN_MENU_BACKGROUND_TEXTURE: Texture2D = preload("res://assets/ui/main_menu/menu_background.png")
const MAIN_MENU_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/main_menu/menu_frame.png")
const MAIN_MENU_LOGO_TEXTURE: Texture2D = preload("res://assets/ui/main_menu/deep_seek_logo.png")
const MAIN_MENU_PLAQUE_TEXTURE: Texture2D = preload("res://assets/ui/main_menu/button_plaque.png")
const MAIN_MENU_ITEM_TEXTURES := {
	"start": preload("res://assets/ui/main_menu/start_lantern.png"),
	"settings": preload("res://assets/ui/main_menu/settings_astrolabe.png"),
	"tutorial": preload("res://assets/ui/main_menu/tutorial_book.png"),
	"exit": preload("res://assets/ui/main_menu/exit_door_key.png"),
}
const MAIN_MENU_ITEM_OUTLINES := {
	"start": preload("res://assets/ui/main_menu/start_lantern_outline.png"),
	"settings": preload("res://assets/ui/main_menu/settings_astrolabe_outline.png"),
	"tutorial": preload("res://assets/ui/main_menu/tutorial_book_outline.png"),
	"exit": preload("res://assets/ui/main_menu/exit_door_key_outline.png"),
}

const TOOL_ICON_TEXTURES := {
	"detector": preload("res://assets/ui/icons/detector.png"),
	"alarm": preload("res://assets/ui/icons/alarm.png"),
	"trap": preload("res://assets/ui/icons/trap.png"),
	"adrenaline": preload("res://assets/ui/icons/adrenaline.png"),
	"decoy": preload("res://assets/ui/icons/decoy.png"),
	"phonograph": preload("res://assets/ui/icons/phonograph.png"),
	"teleporter": preload("res://assets/ui/icons/teleporter.png"),
	"spring_glove": preload("res://assets/ui/icons/spring_glove.png"),
	"robot": preload("res://assets/ui/icons/robot.png"),
}
const TREASURE_ICON_TEXTURES := {
	"treasure-1": COPPER_COIN_TEXTURE,
	"treasure-2": preload("res://assets/25d/items/silver_candlestick.png"),
	"treasure-3": preload("res://assets/25d/items/emerald_brooch.png"),
	"treasure-5": preload("res://assets/25d/items/monster_heart.png"),
}

const MONSTER_COLOR := Color("#ff6b4a")
const THIEF_COLOR := Color("#66d9c3")
const BG_COLOR := Color("#0b0c0c")
const PANEL_COLOR := Color("#171a17")
const PANEL_ALT := Color("#111312")
const LINE_COLOR := Color("#3d413b")
const TEXT_COLOR := Color("#eee9dd")
const MUTED_COLOR := Color("#979c94")
const FLOOR_DARK := Color("#63685f")
const GOLD_COLOR := Color("#e6cc64")
const HIT_FLASH_DELAY := 0.06
const HIT_FLASH_SECONDS := 0.34

var game: Node
var font: Font
var viewport_frame_style: StyleBoxTexture
var header_plaque_style: StyleBoxTexture
var minimap_frame_style: StyleBoxTexture
var inventory_tray_style: StyleBoxTexture
var inventory_slot_style: StyleBoxTexture
var button_frame_style: StyleBoxTexture
var modal_panel_style: StyleBoxTexture
var main_menu_hover_amounts := {
	"start": 0.0,
	"settings": 0.0,
	"tutorial": 0.0,
	"exit": 0.0,
}
var main_menu_last_draw_msec := 0

var TREASURES: Array:
	get: return game.TREASURES
var TOOL_DEFS: Dictionary:
	get: return game.TOOL_DEFS
var SHOP_TOOL_TYPES: Array:
	get: return game.SHOP_TOOL_TYPES
var rooms: Array:
	get: return game.rooms
var monster: Dictionary:
	get: return game.monster
var thief: Dictionary:
	get: return game.thief
var selected_treasure: int:
	get: return game.selected_treasure
var phase: String:
	get: return game.phase
var seconds_left: int:
	get: return game.seconds_left
var elapsed: float:
	get: return game.elapsed
var attack_until: float:
	get: return game.attack_until
var noises: Array:
	get: return game.noises
var outcome: String:
	get: return game.outcome
var early_rect: Rect2:
	get: return game.early_rect
	set(value): game.early_rect = value
var result_restart_rect: Rect2:
	get: return game.result_restart_rect
	set(value): game.result_restart_rect = value
var match_end_selected: int:
	get: return int(game.match_end_selected)
var match_end_rects: Dictionary:
	get: return game.match_end_rects
var help_open: Dictionary:
	get: return game.help_open
var help_rects: Dictionary:
	get: return game.help_rects
var tool_inventories: Dictionary:
	get: return game.tool_inventories
var tool_selected: Dictionary:
	get: return game.tool_selected
var status_effects: Dictionary:
	get: return game.status_effects
var trapped_by: Dictionary:
	get: return game.trapped_by
var trap_escape_progress: Dictionary:
	get: return game.trap_escape_progress
var current_round: int:
	get: return maxi(int(game.current_round), 1)
var player_coins: Dictionary:
	get: return game.player_coins
var player_stashes: Dictionary:
	get: return game.player_stashes
var player_loadouts: Dictionary:
	get: return game.player_loadouts
var shop_selected: Dictionary:
	get: return game.shop_selected
var shop_focus: Dictionary:
	get: return game.shop_focus
var warehouse_selected: Dictionary:
	get: return game.warehouse_selected
var loadout_selected: Dictionary:
	get: return game.loadout_selected
var shop_ready: Dictionary:
	get: return game.shop_ready
var match_totals: Dictionary:
	get: return game.match_totals
var gm_console_open: bool:
	get: return bool(game.gm_console_open)
var gm_command: String:
	get: return str(game.gm_command)
var gm_output: String:
	get: return str(game.gm_output)
var gm_history: Array[String]:
	get:
		var result: Array[String] = []
		result.assign(game.gm_history)
		return result
var main_menu_open: bool:
	get: return bool(game.main_menu_open)
var main_menu_panel: String:
	get: return str(game.main_menu_panel)
var main_menu_selected: int:
	get: return int(game.main_menu_selected)
var main_menu_volume_step: int:
	get: return int(game.main_menu_volume_step)
var main_menu_rects: Dictionary:
	get: return game.main_menu_rects
var game_pause_open: bool:
	get: return bool(game.game_pause_open)
var game_pause_selected: int:
	get: return int(game.game_pause_selected)
var game_pause_rects: Dictionary:
	get: return game.game_pause_rects
var tutorial_transition_active: bool:
	get: return game.get("tutorial_transition_active") == true
var world_25d: World25D:
	get: return game.world_25d


func setup(host: Node) -> void:
	game = host
	font = ThemeDB.fallback_font
	viewport_frame_style = _make_texture_style(VIEWPORT_FRAME_TEXTURE, 54.0, 46.0, false)
	header_plaque_style = _make_texture_style(HEADER_PLAQUE_TEXTURE, 58.0, 30.0)
	minimap_frame_style = _make_texture_style(MINIMAP_FRAME_TEXTURE, 42.0, 42.0, false)
	inventory_tray_style = _make_texture_style(INVENTORY_TRAY_TEXTURE, 72.0, 32.0)
	inventory_slot_style = _make_texture_style(INVENTORY_SLOT_TEXTURE, 42.0, 26.0)
	button_frame_style = _make_texture_style(BUTTON_FRAME_TEXTURE, 52.0, 22.0)
	modal_panel_style = _make_texture_style(MODAL_PANEL_TEXTURE, 66.0, 56.0)
	set_process(true)
	queue_redraw()


func _make_texture_style(
	texture: Texture2D,
	horizontal_margin: float,
	vertical_margin: float,
	draw_center := true
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = horizontal_margin
	style.texture_margin_top = vertical_margin
	style.texture_margin_right = horizontal_margin
	style.texture_margin_bottom = vertical_margin
	style.draw_center = draw_center
	return style


func _process(_delta: float) -> void:
	if game:
		queue_redraw()


func _get_actor(role: String) -> Dictionary:
	return game._get_actor(role)


func _room_at(room_pos: Vector2i) -> Dictionary:
	return game._room_at(room_pos)


func _player_for_role(role: String) -> String:
	return game._player_for_role(role)


func _role_for_player(player: String) -> String:
	return game._role_for_player(player)


func _active_storage_furniture() -> Dictionary:
	return game._active_storage_furniture()


func _nearby_tool_for_panel(role: String) -> Dictionary:
	return game._nearby_tool_for_panel(role)


func _role_can_pick_up_item(role: String, item: Dictionary) -> bool:
	return game._role_can_pick_up_item(role, item)


func _selected_shop_tool_type(player: String) -> String:
	return game._selected_shop_tool_type(player)


func _shop_warehouse_items(player: String) -> Array:
	return game._shop_warehouse_items(player)


func _shop_equipped_items(player: String) -> Array:
	return game._shop_equipped_items(player)


func _direction_vector(direction: String) -> Vector2:
	return game._direction_vector(direction)


func _draw() -> void:
	if not game:
		return
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if tutorial_transition_active:
		_draw_tutorial_transition(size)
		return
	if bool(main_menu_open):
		_draw_main_menu(size)
		if bool(gm_console_open):
			_draw_gm_console(size)
		return
	var layout := _calculate_layout(size)
	_draw_room_panel(layout["monster_panel"], layout["monster_room"], _role_for_player("A"))
	_draw_room_panel(layout["thief_panel"], layout["thief_room"], _role_for_player("B"))
	_draw_center_divider(size)
	if phase == "ready":
		_draw_countdown_overlay(size)
	elif phase == "shop":
		_draw_shop_overlay(size)
	elif phase == "ended":
		_draw_result_overlay(size)
	if bool(game_pause_open):
		_draw_game_pause(size)
	if bool(gm_console_open):
		_draw_gm_console(size)


func _draw_main_menu(size: Vector2) -> void:
	var screen_rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(MAIN_MENU_BACKGROUND_TEXTURE, screen_rect, false)

	var ui_scale := minf(size.x / 1600.0, size.y / 900.0)
	var logo_width := minf(size.x * 0.57, 760.0 * ui_scale)
	var logo_ratio := (
		float(MAIN_MENU_LOGO_TEXTURE.get_height())
		/ float(MAIN_MENU_LOGO_TEXTURE.get_width())
	)
	var logo_size := Vector2(logo_width, logo_width * logo_ratio)
	var logo_rect := Rect2(
		Vector2((size.x - logo_size.x) * 0.5, 34.0 * ui_scale),
		logo_size,
	)
	draw_texture_rect(MAIN_MENU_LOGO_TEXTURE, logo_rect, false)

	var now_msec := Time.get_ticks_msec()
	var frame_delta := 1.0 / 60.0
	if main_menu_last_draw_msec > 0:
		frame_delta = clampf(
			float(now_msec - main_menu_last_draw_msec) / 1000.0,
			0.0,
			0.05,
		)
	main_menu_last_draw_msec = now_msec

	var baseline := size.y * 0.755
	var plaque_y := size.y * 0.815
	var entries := [
		{
			"id": "start",
			"label": "开始比赛",
			"x": 0.17,
			"height": 365.0,
			"plaque_width": 250.0,
		},
		{
			"id": "settings",
			"label": "设置",
			"x": 0.39,
			"height": 320.0,
			"plaque_width": 210.0,
		},
		{
			"id": "tutorial",
			"label": "教程",
			"x": 0.63,
			"height": 275.0,
			"plaque_width": 210.0,
		},
		{
			"id": "exit",
			"label": "退出游戏",
			"x": 0.84,
			"height": 300.0,
			"plaque_width": 220.0,
		},
	]
	main_menu_rects.clear()
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var action := str(entry["id"])
		var texture: Texture2D = MAIN_MENU_ITEM_TEXTURES[action]
		var texture_size := Vector2(texture.get_width(), texture.get_height())
		var item_height := float(entry["height"]) * ui_scale
		var item_size := Vector2(item_height * texture_size.x / texture_size.y, item_height)
		var center_x := size.x * float(entry["x"])
		var item_rect := Rect2(
			Vector2(center_x - item_size.x * 0.5, baseline - item_size.y),
			item_size,
		)
		var plaque_width := float(entry["plaque_width"]) * ui_scale
		var plaque_height := 60.0 * ui_scale
		var plaque_rect := Rect2(
			Vector2(center_x - plaque_width * 0.5, plaque_y),
			Vector2(plaque_width, plaque_height),
		)
		var hit_rect := item_rect.merge(plaque_rect).grow(10.0 * ui_scale)
		if main_menu_panel == "root":
			main_menu_rects[action] = hit_rect
		var selected := main_menu_panel == "root" and main_menu_selected == entry_index
		var hover_target := 1.0 if selected else 0.0
		main_menu_hover_amounts[action] = move_toward(
			float(main_menu_hover_amounts[action]),
			hover_target,
			frame_delta * 7.5,
		)
		var hover := smoothstep(0.0, 1.0, float(main_menu_hover_amounts[action]))
		var lift := 13.0 * ui_scale * hover
		var item_scale := 1.0 + 0.035 * hover
		var animated_size := item_rect.size * item_scale
		var animated_rect := Rect2(
			Vector2(
				center_x - animated_size.x * 0.5,
				baseline - animated_size.y - lift,
			),
			animated_size,
		)
		_draw_main_menu_shadow(
			Vector2(center_x, baseline + 4.0 * ui_scale),
			Vector2(
				item_rect.size.x * (0.29 - 0.035 * hover),
				9.0 * ui_scale * (1.0 - 0.25 * hover),
			),
			0.42 - 0.12 * hover,
		)
		if hover > 0.01:
			var outline: Texture2D = MAIN_MENU_ITEM_OUTLINES[action]
			draw_texture_rect(
				outline,
				animated_rect.grow(2.0 * ui_scale * hover),
				false,
				Color(1.0, 0.98, 0.86, 0.92 * hover),
			)
		draw_texture_rect(texture, animated_rect, false)
		var plaque_tint := Color(1.0, 1.0, 1.0)
		if hover > 0.0:
			plaque_tint = Color(1.0, 0.96 + 0.04 * hover, 0.82 + 0.18 * hover)
		draw_texture_rect(MAIN_MENU_PLAQUE_TEXTURE, plaque_rect, false, plaque_tint)
		_text_center(
			str(entry["label"]),
			plaque_rect,
			maxi(16, roundi(24.0 * ui_scale)),
			Color("#fff7dc") if selected else Color("#2a1b13"),
		)

	if main_menu_panel == "settings":
		_draw_main_menu_settings(size, ui_scale)
	elif main_menu_panel == "exit_confirm":
		_draw_main_menu_exit_confirm(size, ui_scale)
	draw_texture_rect(MAIN_MENU_FRAME_TEXTURE, screen_rect, false)


func _draw_main_menu_settings(size: Vector2, ui_scale: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.66))
	var card_size := Vector2(690.0, 430.0) * ui_scale
	var card := Rect2((size - card_size) * 0.5, card_size)
	draw_style_box(modal_panel_style, card)
	_text_center(
		"设置",
		Rect2(card.position + Vector2(0, 28.0 * ui_scale), Vector2(card.size.x, 44.0 * ui_scale)),
		maxi(20, roundi(30.0 * ui_scale)),
		TEXT_COLOR,
	)

	var content_left := card.position.x + 82.0 * ui_scale
	var content_width := card.size.x - 164.0 * ui_scale
	var volume_row := Rect2(
		Vector2(content_left, card.position.y + 104.0 * ui_scale),
		Vector2(content_width, 82.0 * ui_scale),
	)
	if main_menu_selected == 0:
		draw_rect(volume_row, Color(GOLD_COLOR, 0.11))
		draw_rect(volume_row, GOLD_COLOR, false, 1.5 * ui_scale)
	_text(
		"主音量",
		volume_row.position + Vector2(18.0, 31.0) * ui_scale,
		maxi(16, roundi(20.0 * ui_scale)),
		TEXT_COLOR,
	)
	_text_right(
		"%d%%" % (main_menu_volume_step * 10),
		Vector2(volume_row.end.x - 18.0 * ui_scale, volume_row.position.y + 31.0 * ui_scale),
		maxi(14, roundi(18.0 * ui_scale)),
		GOLD_COLOR,
	)
	var bar_rect := Rect2(
		volume_row.position + Vector2(118.0, 50.0) * ui_scale,
		Vector2(volume_row.size.x - 236.0 * ui_scale, 12.0 * ui_scale),
	)
	var segment_gap := 4.0 * ui_scale
	var segment_width := (bar_rect.size.x - segment_gap * 9.0) / 10.0
	for segment in range(10):
		var segment_rect := Rect2(
			Vector2(
				bar_rect.position.x + segment * (segment_width + segment_gap),
				bar_rect.position.y,
			),
			Vector2(segment_width, bar_rect.size.y),
		)
		draw_rect(
			segment_rect,
			GOLD_COLOR if segment < main_menu_volume_step else Color("#393a34"),
		)
	var minus_rect := Rect2(
		volume_row.position + Vector2(10.0, 42.0) * ui_scale,
		Vector2(42.0, 30.0) * ui_scale,
	)
	var plus_rect := Rect2(
		Vector2(volume_row.end.x - 52.0 * ui_scale, volume_row.position.y + 42.0 * ui_scale),
		Vector2(42.0, 30.0) * ui_scale,
	)
	main_menu_rects["volume_down"] = minus_rect
	main_menu_rects["volume_up"] = plus_rect
	_draw_main_menu_modal_button(minus_rect, "－", main_menu_selected == 0)
	_draw_main_menu_modal_button(plus_rect, "＋", main_menu_selected == 0)

	var fullscreen_rect := Rect2(
		Vector2(content_left, card.position.y + 207.0 * ui_scale),
		Vector2(content_width, 66.0 * ui_scale),
	)
	main_menu_rects["fullscreen"] = fullscreen_rect
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]
	_draw_main_menu_modal_button(
		fullscreen_rect,
		"显示模式　%s" % ("全屏" if fullscreen else "窗口"),
		main_menu_selected == 1,
	)

	var back_rect := Rect2(
		Vector2(card.get_center().x - 120.0 * ui_scale, card.end.y - 104.0 * ui_scale),
		Vector2(240.0, 54.0) * ui_scale,
	)
	main_menu_rects["settings_back"] = back_rect
	_draw_main_menu_modal_button(back_rect, "返回", main_menu_selected == 2)
	_text_center(
		"W/S选择 · A/D调整 · Enter确认 · Esc返回",
		Rect2(
			Vector2(card.position.x, card.end.y - 42.0 * ui_scale),
			Vector2(card.size.x, 24.0 * ui_scale),
		),
		maxi(10, roundi(12.0 * ui_scale)),
		MUTED_COLOR,
	)


func _draw_main_menu_exit_confirm(size: Vector2, ui_scale: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.7))
	var card_size := Vector2(560.0, 270.0) * ui_scale
	var card := Rect2((size - card_size) * 0.5, card_size)
	draw_style_box(modal_panel_style, card)
	_text_center(
		"确定要退出游戏吗？",
		Rect2(
			card.position + Vector2(0, 54.0 * ui_scale),
			Vector2(card.size.x, 52.0 * ui_scale),
		),
		maxi(20, roundi(28.0 * ui_scale)),
		TEXT_COLOR,
	)
	var button_size := Vector2(190.0, 58.0) * ui_scale
	var gap := 24.0 * ui_scale
	var cancel_rect := Rect2(
		Vector2(card.get_center().x - button_size.x - gap * 0.5, card.end.y - 104.0 * ui_scale),
		button_size,
	)
	var confirm_rect := Rect2(
		Vector2(card.get_center().x + gap * 0.5, card.end.y - 104.0 * ui_scale),
		button_size,
	)
	main_menu_rects["exit_cancel"] = cancel_rect
	main_menu_rects["exit_confirm"] = confirm_rect
	_draw_main_menu_modal_button(cancel_rect, "取消", main_menu_selected == 0)
	_draw_main_menu_modal_button(confirm_rect, "退出游戏", main_menu_selected == 1, true)


func _draw_main_menu_modal_button(
	rect: Rect2,
	label: String,
	selected: bool,
	danger := false,
) -> void:
	draw_style_box(button_frame_style, rect)
	var hovered := rect.has_point(get_viewport().get_mouse_position())
	if selected or hovered:
		var accent := Color("#c65c4b") if danger else GOLD_COLOR
		draw_rect(rect.grow(-5.0), Color(accent, 0.18))
		draw_rect(rect.grow(-3.0), accent, false, 1.5)
	_text_center(
		label,
		rect,
		maxi(13, roundi(18.0 * minf(rect.size.y / 54.0, 1.0))),
		Color("#ffd9cf") if danger and (selected or hovered) else TEXT_COLOR,
	)


func _draw_game_pause(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.78))
	var ui_scale := minf(size.x / 1600.0, size.y / 900.0)
	var card_size := Vector2(620.0, 330.0) * ui_scale
	var card := Rect2((size - card_size) * 0.5, card_size)
	draw_style_box(modal_panel_style, card)
	_text_center(
		"游戏已暂停",
		Rect2(card.position + Vector2(0, 45.0 * ui_scale), Vector2(card.size.x, 52.0 * ui_scale)),
		maxi(22, roundi(30.0 * ui_scale)),
		TEXT_COLOR,
	)
	_text_center(
		"第 %d / %d 局 · 返回主菜单将结束当前比赛" % [current_round, MATCH_ROUNDS],
		Rect2(card.position + Vector2(0, 98.0 * ui_scale), Vector2(card.size.x, 30.0 * ui_scale)),
		maxi(10, roundi(12.0 * ui_scale)),
		MUTED_COLOR,
	)
	var button_size := Vector2(220.0, 64.0) * ui_scale
	var gap := 26.0 * ui_scale
	var continue_rect := Rect2(
		Vector2(card.get_center().x - button_size.x - gap * 0.5, card.end.y - 128.0 * ui_scale),
		button_size,
	)
	var menu_rect := Rect2(
		Vector2(card.get_center().x + gap * 0.5, card.end.y - 128.0 * ui_scale),
		button_size,
	)
	game_pause_rects.clear()
	game_pause_rects["continue"] = continue_rect
	game_pause_rects["main_menu"] = menu_rect
	_draw_main_menu_modal_button(continue_rect, "继续游戏", game_pause_selected == 0)
	_draw_main_menu_modal_button(menu_rect, "退出到主菜单", game_pause_selected == 1, true)
	_text_center(
		"WASD / 方向键选择 · R / Num1 / Enter 确认 · Esc 继续",
		Rect2(
			Vector2(card.position.x, continue_rect.position.y - 38.0 * ui_scale),
			Vector2(card.size.x, 24.0 * ui_scale),
		),
		maxi(9, roundi(11.0 * ui_scale)),
		MUTED_COLOR,
	)


func _draw_tutorial_transition(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090b09"))
	var ui_scale := minf(size.x / 1600.0, size.y / 900.0)
	var card_size := Vector2(590.0, 250.0) * ui_scale
	var card := Rect2((size - card_size) * 0.5, card_size)
	draw_style_box(modal_panel_style, card)
	_text_center(
		"正在准备新的游戏",
		Rect2(card.position + Vector2(0, 48.0 * ui_scale), Vector2(card.size.x, 48.0 * ui_scale)),
		maxi(22, roundi(28.0 * ui_scale)),
		TEXT_COLOR,
	)
	_text_center(
		"正在清理教程场景并生成第 1 局宅邸，请稍候…",
		Rect2(card.position + Vector2(0, 101.0 * ui_scale), Vector2(card.size.x, 30.0 * ui_scale)),
		maxi(10, roundi(12.0 * ui_scale)),
		MUTED_COLOR,
	)
	var center := Vector2(card.get_center().x, card.end.y - 61.0 * ui_scale)
	var radius := 18.0 * ui_scale
	var angle := fmod(Time.get_ticks_msec() / 280.0, TAU)
	draw_arc(center, radius, angle, angle + PI * 1.45, 28, GOLD_COLOR, maxf(2.0, 3.0 * ui_scale))


func _draw_main_menu_shadow(center: Vector2, radii: Vector2, alpha: float) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _calculate_layout(size: Vector2) -> Dictionary:
	var margin := 10.0
	var gap := 10.0
	var side_width := (size.x - margin * 2.0 - gap) / 2.0
	var panel_height := size.y - margin * 2.0
	var frame_inset := 32.5
	var room_side := minf(side_width - frame_inset * 2.0, panel_height - 150.0)
	room_side = maxf(room_side, 280.0)
	var left_panel := Rect2(margin, margin, side_width, panel_height)
	var right_panel := Rect2(left_panel.end.x + gap, margin, side_width, panel_height)
	var left_room := Rect2(
		left_panel.position.x + (side_width - room_side) / 2.0,
		left_panel.position.y + 58.0,
		room_side,
		room_side
	)
	var right_room := Rect2(
		right_panel.position.x + (side_width - room_side) / 2.0,
		right_panel.position.y + 58.0,
		room_side,
		room_side
	)
	return {
		"monster_panel": left_panel,
		"monster_room": left_room,
		"thief_panel": right_panel,
		"thief_room": right_room,
	}


func _draw_center_divider(size: Vector2) -> void:
	var divider_width := 42.0
	var divider := Rect2(
		Vector2(size.x * 0.5 - divider_width * 0.5, 5.0),
		Vector2(divider_width, size.y - 10.0),
	)
	draw_texture_rect(CENTER_DIVIDER_TEXTURE, divider, false)


func _draw_button(rect: Rect2, label: String, secondary := false) -> void:
	draw_style_box(button_frame_style, rect)
	var hovered := rect.has_point(get_viewport().get_mouse_position())
	var pressed := hovered and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if secondary:
		draw_rect(rect.grow(-5.0), Color(0.02, 0.025, 0.02, 0.34))
	if hovered:
		draw_rect(rect.grow(-5.0), Color(0.84, 0.67, 0.31, 0.12 if not pressed else 0.24))
	var color := Color("#d9c9ad") if not secondary else TEXT_COLOR
	var label_rect := Rect2(rect.position + Vector2(0, 1.0 if pressed else 0.0), rect.size)
	_text_center(label, label_rect, 12, color)


func _draw_square_button(rect: Rect2, label: String, accent: Color) -> void:
	draw_texture_rect(SQUARE_BUTTON_TEXTURE, rect, false)
	var hovered := rect.has_point(get_viewport().get_mouse_position())
	if hovered:
		draw_rect(rect.grow(-4.0), Color(accent, 0.14))
	draw_rect(rect.grow(-4.0), Color(accent, 0.82), false, 1.2)
	_text_center(label, rect, 15, accent)


func _draw_tool_icon(tool_type: String, rect: Rect2, modulate := Color.WHITE) -> void:
	var icon: Texture2D = TOOL_ICON_TEXTURES.get(tool_type)
	if icon:
		draw_texture_rect(icon, rect, false, modulate)


func _draw_gm_console(size: Vector2) -> void:
	var output_text := str(gm_output)
	var output_lines := output_text.split("\n")
	var detailed_help := output_lines.size() > 1
	var output_font_size := 12 if detailed_help else 11
	var output_line_height := 19.0 if detailed_help else 18.0
	var width := minf(size.x - 40.0, 1180.0 if detailed_help else 1040.0)
	var card_height := minf(
		size.y - 40.0,
		maxf(158.0, 92.0 + float(output_lines.size()) * output_line_height)
	)
	var card := Rect2(
		Vector2((size.x - width) * 0.5, size.y - card_height - 20.0),
		Vector2(width, card_height),
	)
	draw_rect(card, Color(0.015, 0.018, 0.015, 0.98))
	draw_rect(card, Color("#86e36f"), false, 2.0)
	draw_rect(Rect2(card.position, Vector2(card.size.x, 31.0)), Color("#172018"))
	_text("GM CONSOLE", card.position + Vector2(12, 21), 12, Color("#86e36f"))
	_text_right("~ / Esc 关闭", card.position + Vector2(card.size.x - 12, 21), 10, MUTED_COLOR)
	_multiline(
		output_text,
		card.position + Vector2(14, 55),
		card.size.x - 28.0,
		output_font_size,
		TEXT_COLOR,
		output_line_height,
	)
	if not detailed_help:
		var history_y := card.position.y + 78.0
		for index in range(mini(gm_history.size(), 2) - 1, -1, -1):
			_text(str(gm_history[index]), Vector2(card.position.x + 14, history_y), 9, MUTED_COLOR)
			history_y += 17.0
	var input_rect := Rect2(
		Vector2(card.position.x + 12, card.end.y - 38),
		Vector2(card.size.x - 24, 27),
	)
	draw_rect(input_rect, Color("#090b09"))
	draw_rect(input_rect, Color("#456d43"), false, 1.0)
	_text("> " + str(gm_command) + "▌", input_rect.position + Vector2(8, 19), 12, Color("#b8f0ae"))


func _draw_room_panel(panel: Rect2, room_rect: Rect2, role: String) -> void:
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel, LINE_COLOR, false, 1)

	_draw_room(room_rect, role, room, actor)
	if role == "monster":
		_draw_storage_exchange(room_rect)
	_draw_view_minimap(room_rect, role)
	_draw_role_status(room_rect, role)
	_draw_nearby_tool_panel(room_rect, role)
	if bool(help_open[role]):
		_draw_help_overlay(room_rect, role)
	var footer := Rect2(panel.position.x, room_rect.end.y + 10, panel.size.x, panel.end.y - room_rect.end.y - 10)
	draw_rect(footer, PANEL_ALT)
	draw_line(footer.position, Vector2(footer.end.x, footer.position.y), LINE_COLOR, 1)
	_draw_toolbelt(footer, role)
	draw_style_box(viewport_frame_style, panel)
	_draw_room_panel_header(panel, role, actor, accent)


func _draw_room_panel_header(panel: Rect2, role: String, actor: Dictionary, accent: Color) -> void:
	var plaque := Rect2(
		panel.position + Vector2(48.0, 6.0),
		Vector2(panel.size.x - 96.0, 46.0),
	)
	draw_style_box(header_plaque_style, plaque)
	draw_line(
		panel.position + Vector2(72.0, 9.0),
		Vector2(panel.end.x - 72.0, panel.position.y + 9.0),
		Color(accent, 0.78),
		2.0,
	)
	_text(
		"玩家%s · %s视角" % [_player_for_role(role), "怪物" if role == "monster" else "盗贼"],
		panel.position + Vector2(72, 24),
		10,
		MUTED_COLOR,
	)
	_text(
		"房间 %d-%d · %s" % [actor["room"].x + 1, actor["room"].y + 1, _phase_short_label()],
		panel.position + Vector2(72, 43),
		14,
		TEXT_COLOR,
	)
	var help_rect := Rect2(Vector2(panel.end.x - 78, panel.position.y + 13), Vector2(28, 28))
	help_rects[role] = help_rect
	_draw_square_button(help_rect, "?", accent)
	var player := _player_for_role(role)
	var opponent := "B" if player == "A" else "A"
	var prospective_values: Dictionary = game._prospective_round_values()
	var projected_coins: Dictionary = game._projected_player_coins()
	var value_right := help_rect.position.x - 10.0
	if role == "monster" and phase == "hide":
		early_rect = Rect2(Vector2(help_rect.position.x - 126, panel.position.y + 13), Vector2(116, 28))
		_draw_button(early_rect, "提前结束藏宝", true)
		value_right = early_rect.position.x - 10.0
	elif role == "monster":
		early_rect = Rect2()
	_text_right(
		"己方结算后 %d金币 · 本局+%d" % [int(projected_coins[player]), int(prospective_values[player])],
		Vector2(value_right, panel.position.y + 24.0),
		10,
		GOLD_COLOR,
	)
	_text_right(
		"敌方结算后 %d金币 · 本局+%d" % [int(projected_coins[opponent]), int(prospective_values[opponent])],
		Vector2(value_right, panel.position.y + 42.0),
		10,
		MUTED_COLOR,
	)


func _draw_toolbelt(footer: Rect2, role: String) -> void:
	var inventory: Array = tool_inventories[role]
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var tray := footer.grow(-5.0)
	draw_style_box(inventory_tray_style, tray)
	_text("背包", tray.position + Vector2(24, 16), 9, Color("#c5b79e"))
	var start := tray.position + Vector2(18, 21)
	var gap := 6.0
	var slot_width := (tray.size.x - 36.0 - gap * 2.0) / 3.0
	var slot_height := maxf(minf(tray.size.y - 27.0, 52.0), 36.0)
	for index in range(TOOL_INVENTORY_CAPACITY):
		var slot := Rect2(start + Vector2(index * (slot_width + gap), 0), Vector2(slot_width, slot_height))
		draw_style_box(inventory_slot_style, slot)
		var selected := index == int(tool_selected[role]) and index < inventory.size()
		draw_rect(slot.grow(-5.0), Color(accent, 0.9) if selected else LINE_COLOR, false, 1.5)
		if index >= inventory.size():
			_text_center("%d · 空" % [index + 1], slot, 9, MUTED_COLOR)
			continue
		var tool: Dictionary = inventory[index]
		var tool_type := str(tool["tool_type"])
		var label := str(TOOL_DEFS[tool_type]["short"])
		var status := ""
		if tool_type == "detector":
			status = (
				" ON %.0fs" % float(tool.get("charge", 0.0))
				if bool(tool.get("active", false))
				else " %.0fs" % float(tool.get("charge", 0.0))
			)
		elif tool_type == "robot" and bool(tool.get("deployed", false)):
			var remaining := float(tool.get("stunned_until", 0.0)) - elapsed
			status = " 停机%.0fs" % remaining if remaining > 0.0 else " 已部署"
		var icon_size := minf(slot.size.y - 10.0, 42.0)
		var icon_rect := Rect2(slot.position + Vector2(8, (slot.size.y - icon_size) * 0.5), Vector2.ONE * icon_size)
		_draw_tool_icon(tool_type, icon_rect)
		var text_rect := Rect2(
			Vector2(icon_rect.end.x + 3.0, slot.position.y),
			Vector2(slot.end.x - icon_rect.end.x - 10.0, slot.size.y),
		)
		_text_center("%d · %s%s" % [index + 1, label, status], text_rect, 9, TEXT_COLOR)


func _draw_role_status(room_rect: Rect2, role: String) -> void:
	var message := ""
	var color := GOLD_COLOR
	if str(trapped_by.get(role, "")) != "":
		var key_hint := "A/D" if _player_for_role(role) == "A" else "←/→"
		message = "被捕！%s交替按压 %d / %d" % [key_hint, trap_escape_progress[role], TRAP_ESCAPE_PRESSES]
		color = MONSTER_COLOR
	else:
		var effects: Dictionary = status_effects[role]
		if elapsed < float(effects.get("stunned_until", 0.0)):
			message = "眩晕 %.1f秒" % (float(effects["stunned_until"]) - elapsed)
		elif elapsed < float(effects.get("adrenaline_until", 0.0)):
			message = "肾上腺素 2× · %.1f秒" % (float(effects["adrenaline_until"]) - elapsed)
		elif elapsed < float(effects.get("fatigue_until", 0.0)):
			message = "疲劳 0.5× · %.1f秒" % (float(effects["fatigue_until"]) - elapsed)
		elif float(effects.get("teleport_ends", -1.0)) > elapsed:
			message = "传送器轰鸣 · %.1f秒" % (float(effects["teleport_ends"]) - elapsed)
			color = Color("#68c8ff")
		elif role == "monster" and elapsed < attack_until:
			message = "横扫冷却 %.1f秒" % (attack_until - elapsed)
			color = MONSTER_COLOR
	if message == "":
		return
	var status_rect := Rect2(
		Vector2(room_rect.get_center().x - 150, room_rect.position.y + 14),
		Vector2(300, 32),
	)
	draw_style_box(header_plaque_style, status_rect)
	draw_rect(status_rect.grow(-5.0), Color(color, 0.86), false, 1.4)
	_text_center(message, status_rect, 12, color)


func _draw_nearby_tool_panel(room_rect: Rect2, role: String) -> void:
	if bool(help_open[role]) or (role == "monster" and not _active_storage_furniture().is_empty()):
		return
	var nearby := _nearby_tool_for_panel(role)
	if nearby.is_empty():
		return
	var item: Dictionary = nearby["item"]
	var tool_type := str(item.get("tool_type", item.get("device_type", "")))
	var definition: Dictionary = TOOL_DEFS[tool_type]
	var accent: Color = definition["color"]
	var panel_width := minf(room_rect.size.x - 32.0, 520.0)
	var panel := Rect2(
		Vector2(room_rect.get_center().x - panel_width / 2.0, room_rect.end.y - 88.0),
		Vector2(panel_width, 70.0),
	)
	draw_style_box(header_plaque_style, panel)
	draw_rect(panel.grow(-7.0), Color(accent, 0.76), false, 1.2)

	var title := str(definition["label"])
	var state := str(item.get("state", ""))
	if tool_type == "trap" and state == "recoverable":
		title += " · 可拾取"
	elif tool_type == "phonograph" and state == "idle":
		title += " · 待启动"
	elif tool_type == "phonograph" and state == "playing":
		title += " · 播放中"
	elif tool_type == "robot" and elapsed < float(item.get("stunned_until", 0.0)):
		title += " · 停机 %.1f秒" % (float(item["stunned_until"]) - elapsed)
	var icon_rect := Rect2(panel.position + Vector2(14, 13), Vector2(44, 44))
	_draw_tool_icon(tool_type, icon_rect)
	_text(title, panel.position + Vector2(66, 27), 14, TEXT_COLOR)
	_text(str(definition["description"]), panel.position + Vector2(66, 51), 10, MUTED_COLOR)

	var hint := "已布置"
	var distance := float(nearby["distance"])
	if _role_can_pick_up_item(role, item):
		if distance > PICKUP_DISTANCE:
			hint = "继续靠近"
		elif str(item.get("kind", "")) in ["tool", "device"] and tool_inventories[role].size() >= TOOL_INVENTORY_CAPACITY:
			hint = "道具栏已满"
		else:
			hint = "R 拾取" if _player_for_role(role) == "A" else "Num1 拾取"
	elif tool_type == "teleporter" and role == "monster":
		hint = "仅盗贼可用"
	elif tool_type == "phonograph" and state == "idle" and str(item.get("owner", "")) == role:
		hint = "F 启动" if _player_for_role(role) == "A" else "Num3 启动"
	elif tool_type == "robot" and str(item.get("owner", "")) != role:
		hint = "G 撞击停机" if _player_for_role(role) == "A" else "Num0 撞击停机"
	_text_right(hint, panel.position + Vector2(panel.size.x - 18, 27), 10, accent)


func _phase_short_label() -> String:
	match phase:
		"hide": return "藏宝 %d:%02d" % [seconds_left / 60, seconds_left % 60]
		"ready": return "准备 %d" % seconds_left
		"hunt": return "搜查 %d:%02d" % [seconds_left / 60, seconds_left % 60]
		"shop": return "局间商店"
		_: return "本局结束"


func _draw_view_minimap(room_rect: Rect2, role: String) -> void:
	var expanded := _map_expanded(role)
	var map_size := clampf(room_rect.size.x * 0.2, 92.0, 124.0)
	var map_rect := Rect2(room_rect.position + Vector2(14, 14), Vector2(map_size, map_size))
	if expanded:
		map_size = minf(room_rect.size.x, room_rect.size.y) * 0.72
		map_rect = Rect2(room_rect.get_center() - Vector2.ONE * map_size / 2.0, Vector2.ONE * map_size)
	var map_frame := map_rect.grow(10.0 if not expanded else 16.0)
	draw_rect(map_frame, Color(0.035, 0.04, 0.035, 0.94))
	draw_style_box(minimap_frame_style, map_frame)
	draw_rect(map_rect.grow(2.0), MONSTER_COLOR if role == "monster" else THIEF_COLOR, false, 1.2)
	_draw_minimap(map_rect, role)
	if not expanded:
		_text("TAB" if _player_for_role(role) == "A" else "N8", map_rect.position + Vector2(4, 12), 8, Color(1, 1, 1, 0.7))


func _map_expanded(role: String) -> bool:
	return Input.is_key_pressed(KEY_TAB) if _player_for_role(role) == "A" else Input.is_key_pressed(KEY_KP_8)


func _draw_help_overlay(room_rect: Rect2, role: String) -> void:
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var card := room_rect.grow(-42)
	draw_style_box(modal_panel_style, card)
	draw_rect(card.grow(-14.0), Color(accent, 0.7), false, 1.5)
	_text_center("本局规则", Rect2(card.position + Vector2(0, 20), Vector2(card.size.x, 28)), 20, TEXT_COLOR)
	var rules := (
		"· 怪物一击打开家具；盗贼所需撞击数 = 家具耐久 + 内部财物价值。\n"
		+ "· 场上只生成地面药丸与家具内肾上腺素；其他道具只能在局间商店购买。\n"
		+ "· 每场共4局，A/B轮流担任怪物；搜查限时8分钟。\n"
		+ "· 财物只有从入口撤离后才结算；1点价值折算1金币。\n"
		+ "· 盗贼停止移动后立刻从怪物视野中隐匿；移动时会显形。\n"
		+ "· 真实藏品不会自行晃动；探测器开启后才按价值显示信号。\n"
		+ "· 每人最多装备3件道具；未使用道具会退回个人仓库并跨局继承。\n"
		+ "· 警报器只能靠近完好家具安装；全图噪音会暴露方向。\n"
		+ "· 巡夜偶在召唤点九宫格内自动巡逻；敌方撞击可令其停机10秒。\n"
		+ "· 捕兽夹需左右键严格交替20次挣脱；传送器轰鸣5秒后撤离。"
	)
	_multiline(rules, card.position + Vector2(34, 78), card.size.x - 68, 11, MUTED_COLOR, 22)
	var player := _player_for_role(role)
	var controls := ""
	if player == "A":
		controls = (
			"WASD 移动　G 撞击　R 拾取　Q/E 转动视角\n"
			+ "Z/X 选择道具　F 使用　B 发声　Tab 地图　F1 帮助\n"
			+ (
				"空格 攻击　H 结束藏宝　家具面板：A/D 选择、R 存取"
				if role == "monster"
				else "C 使用药丸　V 撤离"
			)
		)
	else:
		controls = (
			"方向键 移动　Num0 撞击　Num1 拾取　Num7/9 转视角\n"
			+ "Num4/6 选择道具　Num3 使用　Num* 发声　Num8 地图　Num+ 帮助\n"
			+ (
				"Num2 攻击　Num5 结束藏宝　家具面板：←/→ 选择、Num1 存取"
				if role == "monster"
				else "Num2 使用药丸　Num5 撤离"
			)
		)
	var controls_title_y := minf(card.position.y + 286.0, card.end.y - 132.0)
	_text("完整键位", Vector2(card.position.x + 34, controls_title_y), 13, accent)
	_multiline(
		controls,
		Vector2(card.position.x + 34, controls_title_y + 28),
		card.size.x - 68,
		11,
		TEXT_COLOR,
		20,
	)
	var close_label := "F1 / Esc 关闭" if player == "A" else "Num+ / Esc 关闭"
	_text_center(close_label, Rect2(Vector2(card.position.x, card.end.y - 48), Vector2(card.size.x, 25)), 11, accent)


func _draw_storage_exchange(room_rect: Rect2) -> void:
	var furniture := _active_storage_furniture()
	if furniture.is_empty():
		return
	var overlay_height := minf(258.0, room_rect.size.y * 0.58)
	var overlay := Rect2(
		room_rect.position + Vector2(14.0, room_rect.size.y - overlay_height - 14.0),
		Vector2(room_rect.size.x - 28.0, overlay_height)
	)
	draw_style_box(modal_panel_style, overlay)
	draw_rect(overlay.grow(-10.0), Color(GOLD_COLOR, 0.75), false, 1.2)
	var title_rect := Rect2(overlay.position + Vector2(18, 10), Vector2(overlay.size.x - 36, 34.0))
	draw_style_box(header_plaque_style, title_rect)
	var storage_controls := (
		"A/D 左右选择 · R 存取"
		if _player_for_role("monster") == "A"
		else "←/→ 左右选择 · Num1 存取"
	)
	_text("家具已打开 · %s · Esc 关闭" % storage_controls, title_rect.position + Vector2(12, 22), 11, GOLD_COLOR)

	var selected: Dictionary = TREASURES[selected_treasure]
	var info_rect := Rect2(
		overlay.position + Vector2(12.0, 49.0),
		Vector2(overlay.size.x - 24.0, 48.0),
	)
	draw_rect(info_rect, Color("#0b0d0b"))
	draw_rect(info_rect, Color(GOLD_COLOR, 0.46), false, 1.0)
	_text(
		"%s　价值 %d" % [selected["label"], selected["value"]],
		info_rect.position + Vector2(12.0, 18.0),
		12,
		GOLD_COLOR,
	)
	_text(
		str(selected.get("description", "")),
		info_rect.position + Vector2(12.0, 38.0),
		10,
		TEXT_COLOR,
	)

	var gap := 10.0
	var content_top := info_rect.end.y + 8.0
	var content_height := overlay.end.y - content_top - 10.0
	var left_width := (overlay.size.x - 34.0 - gap) * 0.64
	var left := Rect2(
		Vector2(overlay.position.x + 12.0, content_top),
		Vector2(left_width, content_height),
	)
	var right := Rect2(
		Vector2(left.end.x + gap, content_top),
		Vector2(overlay.end.x - 12.0 - left.end.x - gap, content_height),
	)
	draw_style_box(inventory_slot_style, left)
	draw_style_box(inventory_slot_style, right)
	_text("怪物藏品", left.position + Vector2(10, 19), 10, TEXT_COLOR)
	_text("家具柜 · %s" % furniture["kind"], right.position + Vector2(10, 19), 10, TEXT_COLOR)

	var slot_gap := 7.0
	var slot_size := minf(
		76.0,
		(left.size.x - 20.0 - slot_gap * float(TREASURES.size() - 1))
		/ float(TREASURES.size()),
	)
	var slots_width := slot_size * float(TREASURES.size()) + slot_gap * float(TREASURES.size() - 1)
	var slots_x := left.get_center().x - slots_width * 0.5
	var slot_y := left.position.y + 28.0
	for index in range(TREASURES.size()):
		var treasure: Dictionary = TREASURES[index]
		var status := _treasure_panel_status(str(treasure["id"]), str(furniture["id"]))
		var slot := Rect2(
			Vector2(slots_x + float(index) * (slot_size + slot_gap), slot_y),
			Vector2(slot_size, slot_size),
		)
		_draw_treasure_slot(
			slot,
			treasure,
			status == "随身",
			index == selected_treasure,
		)
		_text_center(
			status,
			Rect2(Vector2(slot.position.x - 3.0, slot.end.y + 2.0), Vector2(slot.size.x + 6.0, 18.0)),
			8,
			GOLD_COLOR if status == "随身" else MUTED_COLOR,
		)

	var stored_primary: Dictionary = {}
	var trinket_names: Array[String] = []
	for content in furniture["contents"]:
		if content["kind"] in ["treasure", "alarm"]:
			stored_primary = content
		elif content["kind"] == "tool":
			trinket_names.append("道具：%s" % content["label"])
		elif content["kind"] == "trinket":
			trinket_names.append("%s · %d" % [content["label"], content["value"]])

	var furniture_slot_size := minf(76.0, right.size.x - 24.0)
	var furniture_slot := Rect2(
		Vector2(right.get_center().x - furniture_slot_size * 0.5, slot_y),
		Vector2(furniture_slot_size, furniture_slot_size),
	)
	_draw_furniture_storage_slot(furniture_slot, stored_primary)
	_text_center(
		"空槽" if stored_primary.is_empty() else "已存放",
		Rect2(
			Vector2(furniture_slot.position.x - 8.0, furniture_slot.end.y + 2.0),
			Vector2(furniture_slot.size.x + 16.0, 18.0),
		),
		8,
		MUTED_COLOR if stored_primary.is_empty() else GOLD_COLOR,
	)
	var trinket_text := "无" if trinket_names.is_empty() else "、".join(trinket_names)
	_text(
		"其他：%s" % trinket_text,
		Vector2(right.position.x + 9.0, right.end.y - 7.0),
		8,
		MUTED_COLOR,
	)


func _draw_treasure_slot(
	rect: Rect2,
	treasure: Dictionary,
	present: bool,
	is_selected: bool,
) -> void:
	draw_rect(rect, Color("#090b09"))
	draw_rect(rect, Color("#4d5048"), false, 1.0)
	if is_selected:
		draw_rect(rect.grow(3.0), Color(GOLD_COLOR, 0.16))
		draw_rect(rect.grow(2.0), GOLD_COLOR, false, 2.0)
	if present:
		_draw_treasure_icon(str(treasure["id"]), rect.grow(-9.0))
	else:
		var empty_rect := rect.grow(-13.0)
		draw_rect(empty_rect, Color("#20231f"), false, 1.0)
		draw_line(empty_rect.position, empty_rect.end, Color("#343831"), 1.0)
		draw_line(
			Vector2(empty_rect.end.x, empty_rect.position.y),
			Vector2(empty_rect.position.x, empty_rect.end.y),
			Color("#343831"),
			1.0,
		)


func _draw_furniture_storage_slot(rect: Rect2, content: Dictionary) -> void:
	draw_rect(rect, Color("#090b09"))
	draw_rect(rect, Color("#4d5048"), false, 1.0)
	if content.is_empty():
		var empty_rect := rect.grow(-13.0)
		draw_rect(empty_rect, Color("#20231f"), false, 1.0)
		return
	if str(content.get("kind", "")) == "treasure":
		_draw_treasure_icon(str(content["id"]), rect.grow(-9.0))
		return
	if str(content.get("kind", "")) == "alarm":
		_draw_tool_icon("alarm", rect.grow(-8.0))


func _draw_treasure_icon(treasure_id: String, rect: Rect2) -> void:
	var icon_id := "treasure-1" if treasure_id.begins_with("wild-treasure-") else treasure_id
	var icon: Texture2D = TREASURE_ICON_TEXTURES.get(icon_id)
	if icon:
		draw_texture_rect(icon, rect, false)
		return
	var center := rect.get_center()
	var unit := minf(rect.size.x, rect.size.y)
	match treasure_id:
		"treasure-2":
			var silver := Color("#d9ded8")
			var shadow := Color("#778078")
			var flame := Color("#efbd55")
			draw_line(
				center + Vector2(0.0, unit * 0.24),
				center - Vector2(0.0, unit * 0.18),
				silver,
				maxf(3.0, unit * 0.12),
				true,
			)
			draw_circle(center + Vector2(0.0, unit * 0.27), unit * 0.22, shadow)
			draw_circle(center + Vector2(0.0, unit * 0.24), unit * 0.20, silver)
			draw_rect(
				Rect2(center + Vector2(-unit * 0.17, -unit * 0.23), Vector2(unit * 0.34, unit * 0.10)),
				silver,
			)
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(0.0, -unit * 0.43),
					center + Vector2(unit * 0.10, -unit * 0.25),
					center + Vector2(0.0, -unit * 0.19),
					center + Vector2(-unit * 0.10, -unit * 0.25),
				]),
				flame,
			)
		"treasure-3":
			var gold := Color("#d5aa4c")
			var emerald := Color("#35b878")
			var emerald_light := Color("#83e6aa")
			draw_circle(center, unit * 0.36, Color("#614c26"))
			draw_circle(center, unit * 0.32, gold)
			var gem := PackedVector2Array([
				center + Vector2(0.0, -unit * 0.27),
				center + Vector2(unit * 0.23, -unit * 0.07),
				center + Vector2(unit * 0.15, unit * 0.25),
				center + Vector2(-unit * 0.15, unit * 0.25),
				center + Vector2(-unit * 0.23, -unit * 0.07),
			])
			draw_colored_polygon(gem, emerald)
			draw_polyline(PackedVector2Array(Array(gem) + [gem[0]]), emerald_light, 1.5, true)
			draw_line(
				center + Vector2(-unit * 0.09, -unit * 0.15),
				center + Vector2(unit * 0.08, unit * 0.14),
				Color(emerald_light, 0.75),
				2.0,
				true,
			)
		"treasure-5":
			var heart := Color("#a92f3b")
			var heart_light := Color("#e05b62")
			draw_circle(center + Vector2(-unit * 0.13, -unit * 0.10), unit * 0.22, heart)
			draw_circle(center + Vector2(unit * 0.13, -unit * 0.10), unit * 0.22, heart)
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(-unit * 0.31, -unit * 0.08),
					center + Vector2(unit * 0.31, -unit * 0.08),
					center + Vector2(0.0, unit * 0.38),
				]),
				heart,
			)
			draw_line(
				center + Vector2(-unit * 0.06, -unit * 0.23),
				center + Vector2(unit * 0.13, unit * 0.16),
				heart_light,
				2.5,
				true,
			)
			draw_line(
				center + Vector2(unit * 0.05, -unit * 0.02),
				center + Vector2(unit * 0.25, -unit * 0.17),
				Color("#69333b"),
				2.0,
				true,
			)


func _treasure_panel_status(treasure_id: String, current_furniture_id: String) -> String:
	for room in rooms:
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content["id"]) == treasure_id:
					return "本家具" if str(furniture["id"]) == current_furniture_id else "已存放"
		for item in room["items"]:
			if str(item["id"]) == treasure_id and not bool(item["collected"]):
				return "已掉落"
	return "随身"


func _door_label(doors: Array) -> String:
	var result: Array[String] = []
	for door in doors:
		match door:
			"up": result.append("上")
			"right": result.append("右")
			"down": result.append("下")
			"left": result.append("左")
	return " · ".join(result)


func _draw_room(rect: Rect2, role: String, room: Dictionary, actor: Dictionary) -> void:
	draw_rect(rect.grow(7), Color("#252620"))
	if world_25d:
		var view_texture: Texture2D = world_25d.texture_for(role)
		if view_texture:
			draw_texture_rect(view_texture, rect, false)
		else:
			draw_rect(rect, FLOOR_DARK)
	else:
		draw_rect(rect, FLOOR_DARK)
	draw_rect(rect, Color("#777b70"), false, 2)
	var vignette := Color(0.01, 0.012, 0.01, 0.18)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), vignette)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 12), Vector2(rect.size.x, 12)), vignette)
	_draw_noise_directions(rect, role, actor)
	if role == "thief":
		_draw_thief_damage_feedback(rect, actor)


func _draw_thief_damage_feedback(rect: Rect2, actor: Dictionary) -> void:
	var hit_age := elapsed - float(actor.get("hit_reaction_started_at", -10.0))
	if hit_age >= HIT_FLASH_DELAY and hit_age < HIT_FLASH_DELAY + HIT_FLASH_SECONDS:
		var flash_t := (hit_age - HIT_FLASH_DELAY) / HIT_FLASH_SECONDS
		var flash_alpha := sin(flash_t * PI) * 0.46
		draw_rect(rect, Color(0.82, 0.025, 0.02, flash_alpha))
	if int(actor.get("hp", 2)) != 1:
		return
	var pulse := 0.5 + 0.5 * sin(elapsed * 3.7)
	var alpha := lerpf(0.10, 0.28, pulse)
	var blood := Color(0.42, 0.015, 0.012, alpha)
	var dark_blood := Color(0.20, 0.006, 0.004, alpha * 0.82)
	var band := clampf(minf(rect.size.x, rect.size.y) * 0.045, 18.0, 32.0)
	for index in range(4):
		var inset := float(index) * band * 0.23
		var strip_alpha := alpha * (0.34 - float(index) * 0.065)
		draw_rect(
			Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2.ONE * inset * 2.0),
			Color(0.55, 0.01, 0.008, strip_alpha),
			false,
			maxf(2.0, band * 0.24),
		)
	var splatters := [
		Vector2(0.04, 0.09), Vector2(0.16, 0.025), Vector2(0.36, 0.035),
		Vector2(0.71, 0.025), Vector2(0.92, 0.08), Vector2(0.975, 0.24),
		Vector2(0.97, 0.66), Vector2(0.89, 0.965), Vector2(0.62, 0.98),
		Vector2(0.28, 0.975), Vector2(0.055, 0.91), Vector2(0.025, 0.58),
	]
	for index in range(splatters.size()):
		var center: Vector2 = rect.position + (splatters[index] as Vector2) * rect.size
		var radius := band * (0.28 + float(index % 4) * 0.10)
		draw_circle(center, radius, blood if index % 2 == 0 else dark_blood)


func _room_point(rect: Rect2, pos: Vector2) -> Vector2:
	return rect.position + Vector2((pos.x + 0.5) / ROOM_SIZE, (pos.y + 0.5) / ROOM_SIZE) * rect.size


func _item_is_hidden(room: Dictionary, item: Dictionary) -> bool:
	for furniture in room["furniture"]:
		if (furniture["pos"] as Vector2).distance_to(item["pos"]) < 0.44:
			return true
	return false


func _draw_furniture(rect: Rect2, furniture: Dictionary, selected: bool, mode: String) -> void:
	var center := _room_point(rect, furniture["pos"])
	var unit := rect.size.x / ROOM_SIZE
	var angle := deg_to_rad(float(furniture["rotation"]))
	var local_points := [
		Vector2(-unit * 0.38, -unit * 0.26), Vector2(unit * 0.38, -unit * 0.26),
		Vector2(unit * 0.38, unit * 0.26), Vector2(-unit * 0.38, unit * 0.26),
	]
	var points := PackedVector2Array()
	for point in local_points:
		points.append(center + (point as Vector2).rotated(angle))
	draw_colored_polygon(points, Color("#65675f"))
	for index in range(4):
		draw_line(points[index], points[(index + 1) % 4], GOLD_COLOR if selected else Color("#b6b0a4"), 2)
	if selected:
		draw_circle(center, 4, GOLD_COLOR if mode == "rotate" else TEXT_COLOR)
	var label_rect := Rect2(center - Vector2(unit * 0.38, 10), Vector2(unit * 0.76, 20))
	_text_center(furniture["kind"], label_rect, int(clamp(unit * 0.13, 9, 12)), TEXT_COLOR)


func _draw_doors(rect: Rect2, doors: Array) -> void:
	var length := rect.size.x * 0.13
	var thickness := 15.0
	for door in doors:
		var door_rect := Rect2()
		match door:
			"up":
				door_rect = Rect2(rect.position.x + rect.size.x / 2.0 - length / 2.0, rect.position.y - thickness / 2.0, length, thickness)
			"down":
				door_rect = Rect2(rect.position.x + rect.size.x / 2.0 - length / 2.0, rect.end.y - thickness / 2.0, length, thickness)
			"left":
				door_rect = Rect2(rect.position.x - thickness / 2.0, rect.position.y + rect.size.y / 2.0 - length / 2.0, thickness, length)
			"right":
				door_rect = Rect2(rect.end.x - thickness / 2.0, rect.position.y + rect.size.y / 2.0 - length / 2.0, thickness, length)
		draw_rect(door_rect, Color("#111311"))
		draw_rect(door_rect, Color("#858a80"), false, 1)


func _draw_actor(rect: Rect2, actor: Dictionary, role: String) -> void:
	var center := _room_point(rect, actor["pos"])
	var radius := rect.size.x / ROOM_SIZE * 0.22
	var color := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	draw_circle(center, radius + 3, Color(1, 1, 1, 0.14))
	draw_circle(center, radius, color)
	_text_center("怪" if role == "monster" else "盗", Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), int(clamp(radius * 0.9, 10, 15)), Color("#101110"))
	var facing := _direction_vector(actor["dir"])
	draw_line(center + facing * radius * 0.7, center + facing * radius * 1.45, color, 3)


func _draw_afterimage(rect: Rect2, pos: Vector2, alpha: float) -> void:
	var center := _room_point(rect, pos)
	var radius := rect.size.x / ROOM_SIZE * 0.21
	draw_circle(center, radius, Color(1.0, 0.12, 0.12, 0.25 * alpha))
	draw_arc(center, radius, 0, TAU, 28, Color(1.0, 0.3, 0.25, alpha), 2)
	_text_center("人", Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), 11, Color(1.0, 0.65, 0.6, alpha))


func _draw_attack_cone(rect: Rect2, actor: Dictionary) -> void:
	var center := _room_point(rect, actor["pos"])
	var unit := rect.size.x / ROOM_SIZE
	var facing := _direction_vector(actor["dir"])
	var left := facing.rotated(-PI / 4.0) * unit * 2.35
	var right := facing.rotated(PI / 4.0) * unit * 2.35
	var points := PackedVector2Array([center, center + left, center + right])
	draw_colored_polygon(points, Color(1.0, 0.25, 0.12, 0.24))
	draw_line(center, center + left, MONSTER_COLOR, 1.5)
	draw_line(center, center + right, MONSTER_COLOR, 1.5)


func _draw_noise_directions(rect: Rect2, role: String, actor: Dictionary) -> void:
	var actor_global := Vector2(actor["room"]) * ROOM_SIZE + (actor["pos"] as Vector2)
	var origin := _room_point(rect, actor["pos"])
	if world_25d:
		var normalized: Vector2 = world_25d.project_normalized(role, actor["room"], actor["pos"], 0.55)
		origin = rect.position + normalized * rect.size
	for noise in noises:
		if noise["source"] == role:
			continue
		var noise_location: Dictionary = game._noise_location(noise)
		var noise_room: Vector2i = noise_location["room"]
		var noise_pos: Vector2 = noise_location["pos"]
		var room_distance: int = abs(noise_room.x - actor["room"].x) + abs(noise_room.y - actor["room"].y)
		if room_distance >= 3 and not bool(noise.get("global", false)):
			continue
		var source_global := Vector2(noise_room) * ROOM_SIZE + noise_pos
		var screen_direction := _noise_screen_direction(role, actor_global, source_global)
		if screen_direction.is_zero_approx():
			continue
		var angle := screen_direction.angle()
		var color: Color = (
			MONSTER_COLOR if noise["source"] == "monster"
			else THIEF_COLOR if noise["source"] == "thief"
			else GOLD_COLOR
		)
		var duration := maxf(float(noise.get("duration", 2.0)), 0.01)
		var fade: float = clampf((float(noise["expires"]) - elapsed) / duration, 0.0, 1.0)
		for radius in [25.0, 42.0, 59.0]:
			draw_arc(origin, radius, angle - 0.58, angle + 0.58, 12, Color(color, fade), 2)


func _noise_screen_direction(role: String, listener_global: Vector2, source_global: Vector2) -> Vector2:
	var direction := source_global - listener_global
	if direction.is_zero_approx():
		return Vector2.ZERO
	if world_25d:
		return world_25d.project_logical_direction(role, listener_global, source_global)
	return direction.normalized()


func _minimap_rotation(role: String) -> float:
	if not world_25d:
		return 0.0
	return deg_to_rad(float(world_25d.camera_yaw_degrees[role]))


func _rotate_minimap_point(point: Vector2, center: Vector2, angle: float) -> Vector2:
	return center + (point - center).rotated(angle)


func _draw_minimap(rect: Rect2, role: String) -> void:
	var angle := _minimap_rotation(role)
	var center := rect.get_center()
	var rotated_bounds_scale := absf(cos(angle)) + absf(sin(angle))
	var grid_side := minf(rect.size.x, rect.size.y) / maxf(rotated_bounds_scale, 1.0)
	var grid_rect := Rect2(center - Vector2.ONE * grid_side / 2.0, Vector2.ONE * grid_side)
	var gap := 3.0
	var cell := (grid_side - gap * (MAP_SIZE - 1)) / MAP_SIZE
	var actor: Dictionary = _get_actor(role)
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	for room in rooms:
		var coord: Vector2i = room["coord"]
		var owned_robot := _owned_robot_in_room(coord, role)
		var cell_rect := Rect2(
			grid_rect.position + Vector2(coord.x, coord.y) * (cell + gap),
			Vector2(cell, cell)
		)
		var has_actor: bool = actor["room"] == coord
		var fill := accent.darkened(0.2) if has_actor else Color("#252824")
		if (
			not owned_robot.is_empty()
			and elapsed < float(owned_robot.get("alert_until", 0.0))
		):
			var pulse := 0.55 + sin(elapsed * 12.0) * 0.2
			fill = Color("#db4f3f").lerp(Color("#f0b05e"), pulse)
		var corners := PackedVector2Array([
			_rotate_minimap_point(cell_rect.position, center, angle),
			_rotate_minimap_point(Vector2(cell_rect.end.x, cell_rect.position.y), center, angle),
			_rotate_minimap_point(cell_rect.end, center, angle),
			_rotate_minimap_point(Vector2(cell_rect.position.x, cell_rect.end.y), center, angle),
		])
		draw_colored_polygon(corners, fill)
		for corner_index in range(corners.size()):
			draw_line(corners[corner_index], corners[(corner_index + 1) % corners.size()], Color("#4b5048"), 1)
		var door_length := cell * 0.32
		for door in room["doors"]:
			var door_from := Vector2.ZERO
			var door_to := Vector2.ZERO
			match door:
				"up":
					door_from = Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.position.y)
					door_to = Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.position.y)
				"down":
					door_from = Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.end.y)
					door_to = Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.end.y)
				"left":
					door_from = Vector2(cell_rect.position.x, cell_rect.get_center().y - door_length / 2)
					door_to = Vector2(cell_rect.position.x, cell_rect.get_center().y + door_length / 2)
				"right":
					door_from = Vector2(cell_rect.end.x, cell_rect.get_center().y - door_length / 2)
					door_to = Vector2(cell_rect.end.x, cell_rect.get_center().y + door_length / 2)
			draw_line(
				_rotate_minimap_point(door_from, center, angle),
				_rotate_minimap_point(door_to, center, angle),
				TEXT_COLOR,
				2,
			)
		if has_actor:
			var marker_center := _rotate_minimap_point(cell_rect.get_center(), center, angle)
			draw_circle(marker_center, maxf(cell * 0.18, 3.5), accent)
			draw_circle(marker_center, maxf(cell * 0.18, 3.5), Color("#111311"), false, 1.0)
		if not owned_robot.is_empty():
			var robot_center := _rotate_minimap_point(
				cell_rect.get_center() + Vector2(-cell * 0.22, cell * 0.22),
				center,
				angle,
			)
			var robot_color := (
				Color("#6d716b")
				if elapsed < float(owned_robot.get("stunned_until", 0.0))
				else Color("#8fd0a4")
			)
			draw_circle(robot_center, maxf(cell * 0.1, 2.5), robot_color)
			draw_circle(robot_center, maxf(cell * 0.1, 2.5), Color("#111311"), false, 1.0)
		if role == "monster":
			for marker in _monster_treasure_markers(room):
				var local_pos: Vector2 = marker["pos"]
				var marker_center := cell_rect.position + local_pos / ROOM_SIZE * cell_rect.size
				marker_center = _rotate_minimap_point(marker_center, center, angle)
				var marker_size := clampf(cell * 0.38, 8.0, 14.0)
				var marker_rect := Rect2(
					marker_center - Vector2.ONE * marker_size * 0.5,
					Vector2.ONE * marker_size,
				)
				draw_rect(marker_rect.grow(1.5), Color("#111311"))
				_draw_treasure_icon(str(marker["id"]), marker_rect)
				draw_rect(marker_rect.grow(1.5), GOLD_COLOR, false, 1.0)
	for room in rooms:
		for item in room["items"]:
			if (
				bool(item.get("collected", false))
				or str(item.get("device_type", "")) != "decoy"
				or str(item.get("owner", "")) == role
			):
				continue
			var decoy_coord: Vector2i = room["coord"]
			var decoy_center := grid_rect.position + Vector2(decoy_coord.x, decoy_coord.y) * (cell + gap) + Vector2.ONE * cell * 0.5
			decoy_center = _rotate_minimap_point(decoy_center, center, angle)
			var decoy_color := THIEF_COLOR if str(item.get("owner", "")) == "thief" else MONSTER_COLOR
			draw_circle(decoy_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), decoy_color)
			draw_circle(decoy_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), Color("#111311"), false, 1.0)


func _monster_treasure_markers(room: Dictionary) -> Array:
	var treasure_ids: Dictionary = {}
	for treasure in TREASURES:
		treasure_ids[str(treasure["id"])] = true
	var markers: Array = []
	for furniture in room["furniture"]:
		for content in furniture["contents"]:
			var treasure_id := str(content.get("id", ""))
			if treasure_ids.has(treasure_id):
				markers.append({"id": treasure_id, "pos": furniture["pos"]})
	for item in room["items"]:
		var treasure_id := str(item.get("id", ""))
		if (
			not bool(item.get("collected", false))
			and treasure_ids.has(treasure_id)
		):
			markers.append({"id": treasure_id, "pos": item["pos"]})
	return markers


func _owned_robot_in_room(coord: Vector2i, role: String) -> Dictionary:
	var room := _room_at(coord)
	for item in room["items"]:
		if (
			not bool(item.get("collected", false))
			and str(item.get("device_type", "")) == "robot"
			and str(item.get("owner", "")) == role
		):
			return item
	return {}


func _draw_countdown_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.72))
	var card := Rect2(size / 2.0 - Vector2(220, 135), Vector2(440, 270))
	draw_style_box(modal_panel_style, card)
	_text_center("双方玩家准备", Rect2(card.position + Vector2(0, 30), Vector2(card.size.x, 22)), 11, MUTED_COLOR)
	_text_center(str(seconds_left), Rect2(card.position + Vector2(0, 62), Vector2(card.size.x, 100)), 76, TEXT_COLOR)
	_text_center("怪物与盗贼已回到起点，倒计时结束后正式开始。", Rect2(card.position + Vector2(0, 190), Vector2(card.size.x, 30)), 12, MUTED_COLOR)


func _stash_tool_count(player: String, tool_type: String) -> int:
	var count := 0
	for tool in player_stashes[player]:
		if str(tool.get("tool_type", "")) == tool_type:
			count += 1
	return count


func _equipped_tool_count(player: String, tool_type: String) -> int:
	var equipped_ids: Array = player_loadouts[player]
	var count := 0
	for tool in player_stashes[player]:
		if str(tool.get("tool_type", "")) == tool_type and equipped_ids.has(str(tool.get("id", ""))):
			count += 1
	return count


func _shop_column_items(player: String, column: String) -> Array:
	if column == "warehouse":
		return _shop_warehouse_items(player)
	if column == "loadout":
		return _shop_equipped_items(player)
	var products: Array = []
	for tool_type in SHOP_TOOL_TYPES:
		products.append({"tool_type": str(tool_type)})
	return products


func _shop_column_selected(player: String, column: String) -> int:
	if column == "warehouse":
		return int(warehouse_selected[player])
	if column == "loadout":
		return int(loadout_selected[player])
	return int(shop_selected[player])


func _shop_focused_tool_type(player: String) -> String:
	var column := str(shop_focus[player])
	var items := _shop_column_items(player, column)
	if items.is_empty():
		return ""
	var selected := clampi(_shop_column_selected(player, column), 0, items.size() - 1)
	return str((items[selected] as Dictionary).get("tool_type", ""))


func _draw_shop_column(rect: Rect2, player: String, column: String, title: String, accent: Color) -> void:
	var focused := str(shop_focus[player]) == column
	draw_style_box(modal_panel_style, rect)
	draw_rect(rect.grow(-7.0), accent if focused else LINE_COLOR, false, 1.5 if focused else 1.0)
	var header := Rect2(rect.position + Vector2(8, 7), Vector2(rect.size.x - 16, 30.0))
	draw_style_box(header_plaque_style, header)
	_text_center(title, header, 11, accent if focused else TEXT_COLOR)

	var items := _shop_column_items(player, column)
	if items.is_empty():
		_text_center(
			"暂无道具",
			Rect2(rect.position + Vector2(0, 46), Vector2(rect.size.x, 30)),
			10,
			MUTED_COLOR,
		)
		return
	var selected := clampi(_shop_column_selected(player, column), 0, items.size() - 1)
	var row_height := 43.0
	var visible_count := maxi(1, int((rect.size.y - 38.0) / row_height))
	var first := clampi(selected - visible_count / 2, 0, maxi(items.size() - visible_count, 0))
	var last := mini(first + visible_count, items.size())
	for item_index in range(first, last):
		var tool: Dictionary = items[item_index]
		var tool_type := str(tool.get("tool_type", ""))
		var definition: Dictionary = TOOL_DEFS[tool_type]
		var row := Rect2(
			Vector2(rect.position.x + 8, rect.position.y + 39 + (item_index - first) * row_height),
			Vector2(rect.size.x - 16, row_height - 4),
		)
		var row_selected := item_index == selected
		draw_style_box(inventory_slot_style, row)
		if row_selected:
			draw_rect(row.grow(-4.0), Color(accent, 0.82), false, 1.0)
		var icon_rect := Rect2(row.position + Vector2(5, 2), Vector2(34, 34))
		_draw_tool_icon(tool_type, icon_rect)
		var marker := "▶ " if row_selected else "   "
		_text("%s%s" % [marker, definition["label"]], row.position + Vector2(41, 16), 10, TEXT_COLOR)
		var detail := ""
		if column == "products":
			detail = "%d 金币" % int(definition["price"])
		elif column == "warehouse":
			detail = "未装备"
		else:
			detail = "装备槽 %d / 3" % (item_index + 1)
		_text(detail, row.position + Vector2(41, 32), 8, MUTED_COLOR)


func _draw_shop_player_panel(rect: Rect2, player: String) -> void:
	var accent := MONSTER_COLOR if player == "A" else THIEF_COLOR
	draw_style_box(modal_panel_style, rect)
	draw_rect(rect.grow(-12.0), Color(accent, 0.72), false, 1.5)
	var next_round := current_round + 1
	var next_role := "怪物" if (
		(player == "A" and next_round % 2 == 1)
		or (player == "B" and next_round % 2 == 0)
	) else "盗贼"
	_text(
		"玩家%s · %d金币 · 下一局：%s" % [player, player_coins[player], next_role],
		rect.position + Vector2(18, 30),
		18,
		TEXT_COLOR,
	)
	_text(
		"仓库未装备 %d件 · 已装备 %d/3" % [
			_shop_warehouse_items(player).size(),
			(player_loadouts[player] as Array).size(),
		],
		rect.position + Vector2(18, 54),
		10,
		MUTED_COLOR,
	)

	var gap := 6.0
	var columns_top := rect.position.y + 72.0
	var columns_bottom := rect.end.y - 118.0
	var column_width := (rect.size.x - 28.0 - gap * 2.0) / 3.0
	var column_height := maxf(columns_bottom - columns_top, 120.0)
	var first_column := Rect2(Vector2(rect.position.x + 14, columns_top), Vector2(column_width, column_height))
	var second_column := Rect2(Vector2(first_column.end.x + gap, columns_top), first_column.size)
	var third_column := Rect2(Vector2(second_column.end.x + gap, columns_top), first_column.size)
	_draw_shop_column(first_column, player, "products", "商品", accent)
	_draw_shop_column(second_column, player, "warehouse", "仓库", accent)
	_draw_shop_column(third_column, player, "loadout", "装备", accent)

	var focused_type := _shop_focused_tool_type(player)
	var description := "此栏暂无道具。"
	if focused_type != "":
		description = str(TOOL_DEFS[focused_type]["description"])
	_text_center(
		description,
		Rect2(
			Vector2(rect.position.x + 18, columns_bottom),
			Vector2(rect.size.x - 36, rect.end.y - 55.0 - columns_bottom),
		),
		15,
		MUTED_COLOR,
	)
	var controls := (
		"A/D 切换栏 · W/S 选择 · R 购买/装备/卸下 · H 准备"
		if player == "A"
		else "←/→ 切换栏 · ↑/↓ 选择 · Num1 购买/装备/卸下 · Num5 准备"
	)
	_text_center(
		controls,
		Rect2(Vector2(rect.position.x, rect.end.y - 55), Vector2(rect.size.x, 22)),
		10,
		TEXT_COLOR,
	)
	var ready_text := "已准备，等待对方" if bool(shop_ready[player]) else "尚未准备"
	_text_center(
		ready_text,
		Rect2(Vector2(rect.position.x, rect.end.y - 31), Vector2(rect.size.x, 20)),
		11,
		accent if bool(shop_ready[player]) else MUTED_COLOR,
	)


func _draw_shop_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.015, 0.92))
	var title_plaque := Rect2(Vector2(size.x * 0.5 - 320.0, 9.0), Vector2(640.0, 66.0))
	draw_style_box(header_plaque_style, title_plaque)
	_text_center(
		"第 %d 局结算完成 · 局间商店" % current_round,
		Rect2(Vector2(0, 15), Vector2(size.x, 34)),
		23,
		TEXT_COLOR,
	)
	_text_center(
		"购买的道具进入个人仓库；装备最多3件，未使用道具可继承到后续局。",
		Rect2(Vector2(0, 48), Vector2(size.x, 24)),
		11,
		MUTED_COLOR,
	)
	var margin := 32.0
	var gap := 18.0
	var panel_width := (size.x - margin * 2.0 - gap) / 2.0
	var panels_top := 82.0
	var panel_height := size.y - panels_top - 24.0
	_draw_shop_player_panel(Rect2(margin, panels_top, panel_width, panel_height), "A")
	_draw_shop_player_panel(Rect2(margin + panel_width + gap, panels_top, panel_width, panel_height), "B")


func _draw_result_overlay(size: Vector2) -> void:
	if current_round >= MATCH_ROUNDS:
		_draw_match_end_overlay(size)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.015, 0.86))
	var card := Rect2(size / 2.0 - Vector2(320, 205), Vector2(640, 410))
	draw_style_box(modal_panel_style, card)
	_text_center(
		"第 %d / %d 局结算" % [current_round, MATCH_ROUNDS],
		Rect2(card.position + Vector2(0, 28), Vector2(card.size.x, 24)),
		13,
		MUTED_COLOR,
	)
	_multiline(outcome, card.position + Vector2(48, 82), card.size.x - 96, 18, TEXT_COLOR, 31, HORIZONTAL_ALIGNMENT_CENTER)
	_text_center(
		"当前金币　A：%d　B：%d" % [player_coins["A"], player_coins["B"]],
		Rect2(card.position + Vector2(0, 205), Vector2(card.size.x, 25)),
		14,
		GOLD_COLOR,
	)
	_text_center(
		"四局累计收入　A：%d　B：%d" % [match_totals["A"], match_totals["B"]],
		Rect2(card.position + Vector2(0, 239), Vector2(card.size.x, 25)),
		12,
		MUTED_COLOR,
	)
	result_restart_rect = Rect2(card.position + Vector2(200, 336), Vector2(240, 46))
	_draw_button(result_restart_rect, "进入局间商店")


func _draw_match_end_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.01, 0.008, 0.9))
	var ui_scale := minf(size.x / 1600.0, size.y / 900.0)
	var card_size := Vector2(650.0, 350.0) * ui_scale
	var card := Rect2((size - card_size) * 0.5, card_size)
	draw_style_box(modal_panel_style, card)
	var winner := "平局"
	if int(match_totals["A"]) != int(match_totals["B"]):
		winner = "玩家A胜利" if int(match_totals["A"]) > int(match_totals["B"]) else "玩家B胜利"
	_text_center(
		"游戏结束",
		Rect2(card.position + Vector2(0, 58.0 * ui_scale), Vector2(card.size.x, 48.0 * ui_scale)),
		maxi(24, roundi(32.0 * ui_scale)),
		TEXT_COLOR,
	)
	_text_center(
		winner,
		Rect2(card.position + Vector2(0, 116.0 * ui_scale), Vector2(card.size.x, 42.0 * ui_scale)),
		maxi(19, roundi(24.0 * ui_scale)),
		GOLD_COLOR,
	)
	var button_size := Vector2(220.0, 64.0) * ui_scale
	var gap := 26.0 * ui_scale
	var restart_button := Rect2(
		Vector2(card.get_center().x - button_size.x - gap * 0.5, card.end.y - 120.0 * ui_scale),
		button_size,
	)
	var menu_button := Rect2(
		Vector2(card.get_center().x + gap * 0.5, card.end.y - 120.0 * ui_scale),
		button_size,
	)
	result_restart_rect = Rect2()
	match_end_rects.clear()
	match_end_rects["restart"] = restart_button
	match_end_rects["main_menu"] = menu_button
	_draw_main_menu_modal_button(restart_button, "重新开始", match_end_selected == 0)
	_draw_main_menu_modal_button(menu_button, "返回到主菜单", match_end_selected == 1, true)
	_text_center(
		"A/D 或方向键选择 · 空格确认",
		Rect2(
			Vector2(card.position.x, restart_button.position.y - 38.0 * ui_scale),
			Vector2(card.size.x, 24.0 * ui_scale),
		),
		maxi(10, roundi(11.0 * ui_scale)),
		MUTED_COLOR,
	)


func _text(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center(text: String, rect: Rect2, size: int, color: Color) -> void:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := rect.position + Vector2((rect.size.x - measured.x) / 2.0, (rect.size.y + measured.y * 0.65) / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _multiline(text: String, pos: Vector2, width: float, size: int, color: Color, line_height: float, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lines := text.split("\n")
	var y := pos.y
	for line in lines:
		if line.is_empty():
			y += line_height
			continue
		draw_string(font, Vector2(pos.x, y), line, alignment, width, size, color)
		y += line_height
