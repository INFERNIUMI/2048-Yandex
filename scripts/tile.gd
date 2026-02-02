# Tile - отдельная плитка на поле
# Содержит значение и анимации
extends Node2D

# Значение плитки (2, 4, 8, 16, ...)
var value: int = 2

# Ссылки на UI элементы (будут заполнены в _ready)
@onready var background: ColorRect = $Background
@onready var label: Label = $Label

# Цвета для разных значений плиток
const TILE_COLORS: Dictionary = {
	2: Color("#eee4da"),
	4: Color("#ede0c8"),
	8: Color("#f2b179"),
	16: Color("#f59563"),
	32: Color("#f67c5f"),
	64: Color("#f65e3b"),
	128: Color("#edcf72"),
	256: Color("#edcc61"),
	512: Color("#edc850"),
	1024: Color("#edc53f"),
	2048: Color("#edc22e"),
}

const DEFAULT_COLOR: Color = Color("#3c3a32")


func _ready() -> void:
	_update_appearance()


# Установка значения плитки
func set_value(new_value: int) -> void:
	value = new_value
	if is_node_ready():
		_update_appearance()


# Обновление внешнего вида
func _update_appearance() -> void:
	if not background or not label:
		return
	
	# Устанавливаем цвет фона
	if TILE_COLORS.has(value):
		background.color = TILE_COLORS[value]
	else:
		background.color = DEFAULT_COLOR
	
	# Устанавливаем текст
	label.text = str(value)
	
	# Размер шрифта в зависимости от количества цифр
	if value < 100:
		label.add_theme_font_size_override("font_size", 48)
	elif value < 1000:
		label.add_theme_font_size_override("font_size", 40)
	else:
		label.add_theme_font_size_override("font_size", 32)


# Анимация появления (scale up from 0 to 1)
func animate_spawn() -> void:
	scale = Vector2.ZERO
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)


# Анимация слияния (scale up to 1.1 then back to 1)
func animate_merge() -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05)


# Анимация движения к новой позиции
func move_to(target_position: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_position, 0.12)
