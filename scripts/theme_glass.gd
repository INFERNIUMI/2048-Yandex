class_name ThemeGlass
## Светлая тема (классический 2048 стиль)
## Откат: game.gd → GLASSMORPHISM_ENABLED = false


static func apply(root: Node2D) -> void:
	# Фон — в BackgroundLayer, цвет задаётся в редакторе

	# Тема
	var theme := Theme.new()

	# --- Label ---
	theme.set_color("font_color", "Label", Color("#776E65"))

	# --- Panel (светлая, с мягкой тенью) ---
	theme.set_stylebox("panel", "Panel", _light_box(
		Color("#BBADA0"), 10
	))

	# --- Button ---
	theme.set_color("font_color", "Button", Color("#F9F6F2"))
	theme.set_color("font_hover_color", "Button", Color("#FFFFFF"))
	theme.set_color("font_pressed_color", "Button", Color("#F9F6F2"))
	theme.set_color("font_disabled_color", "Button", Color("#CCC4B8"))

	theme.set_stylebox("normal", "Button", _button_box(
		Color("#8F7A66"), 6
	))
	theme.set_stylebox("hover", "Button", _button_box(
		Color("#9F8A76"), 6
	))
	theme.set_stylebox("pressed", "Button", _button_box(
		Color("#7F6A56"), 6
	))
	theme.set_stylebox("disabled", "Button", _button_box(
		Color("#CCC4B8"), 6
	))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	# Применяем к корневому UI контейнеру
	var safe_area: MarginContainer = root.get_node(
		"UI/CenterContainer/ContentContainer/SafeArea"
	)
	safe_area.theme = theme

	# Grid background — темнее фона
	var grid_bg: Panel = root.get_node(
		"UI/CenterContainer/ContentContainer/SafeArea/MainVBox/GameFieldContainer/GridContainer/GridBackground"
	)
	grid_bg.add_theme_stylebox_override("panel", _light_box(
		Color("#BBADA0"), 8
	))


static func _light_box(bg_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


static func _button_box(bg_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style
