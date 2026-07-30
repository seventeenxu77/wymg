@tool
class_name MainMenuOverlayStyle
extends RefCounted

const MENU_BACKGROUND: Texture2D = preload("res://assets/ui/main_menu/menu_background.png")
const MENU_FRAME: Texture2D = preload("res://assets/ui/main_menu/menu_frame.png")
const BUTTON_PLAQUE: Texture2D = preload("res://assets/ui/main_menu/button_plaque.png")

const GOLD := Color("#d7b264")
const TEXT := Color("#f5e8c7")
const MUTED := Color("#aaa28c")


static func add_backdrop(parent: Control) -> void:
	var background := TextureRect.new()
	background.name = "MenuBackground"
	background.texture = MENU_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -30
	parent.add_child(background)

	var shade := ColorRect.new()
	shade.name = "MenuShade"
	shade.color = Color(0.015, 0.012, 0.01, 0.36)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = -20
	parent.add_child(shade)

	var frame := TextureRect.new()
	frame.name = "MenuFrame"
	frame.texture = MENU_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 14
	frame.offset_top = 12
	frame.offset_right = -14
	frame.offset_bottom = -12
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 80
	parent.add_child(frame)


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.038, 0.032, 0.90)
	style.border_color = Color("#6f542d")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 18
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	return style


static func apply_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_style())


static func apply_button(button: Button) -> void:
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = BUTTON_PLAQUE
		style.texture_margin_left = 28
		style.texture_margin_top = 8
		style.texture_margin_right = 28
		style.texture_margin_bottom = 8
		style.content_margin_left = 18
		style.content_margin_top = 6
		style.content_margin_right = 18
		style.content_margin_bottom = 6
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color("#3d2b1d"))
	button.add_theme_color_override("font_hover_color", Color("#27180f"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bd"))
	button.add_theme_color_override("font_focus_color", Color("#3d2b1d"))
	button.add_theme_color_override("font_disabled_color", Color("#5f574a"))
	button.add_theme_font_size_override("font_size", 21)
	button.focus_mode = Control.FOCUS_ALL
	button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(_animate_button.bind(button, Vector2(1.035, 1.035), 1.08))
	button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE, 1.0))
	button.focus_entered.connect(_animate_button.bind(button, Vector2(1.035, 1.035), 1.08))
	button.focus_exited.connect(_animate_button.bind(button, Vector2.ONE, 1.0))


static func apply_line_edit(input: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#141713")
	normal.border_color = Color("#57462d")
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("caret_color", GOLD)
	input.add_theme_color_override("selection_color", Color(0.55, 0.39, 0.15, 0.7))


static func animate_page(page: Control) -> void:
	page.modulate = Color(1, 1, 1, 0)
	page.scale = Vector2(0.965, 0.965)
	page.pivot_offset = page.size * 0.5
	var tween := page.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(page, "modulate:a", 1.0, 0.24)
	tween.tween_property(page, "scale", Vector2.ONE, 0.32)


static func _animate_button(
	button: Button,
	target_scale: Vector2,
	brightness: float
) -> void:
	if button.disabled:
		return
	var tween := button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)
	tween.tween_property(
		button,
		"modulate",
		Color(brightness, brightness, brightness, 1.0),
		0.12,
	)
