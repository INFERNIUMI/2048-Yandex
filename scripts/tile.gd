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


# =============================================================================
# MERGE ANIMATION: Squash + Pop (настраиваемые параметры)
# =============================================================================
# Категории по "весу" плитки: большие числа ощущаются тяжелее
const MERGE_SMALL_MAX_SCALE: float = 1.15   # 2–64
const MERGE_SMALL_DURATION: float = 0.13
const MERGE_MEDIUM_MAX_SCALE: float = 1.20 # 128–256
const MERGE_MEDIUM_DURATION: float = 0.17
const MERGE_LARGE_MAX_SCALE: float = 1.30  # 512+
const MERGE_LARGE_DURATION: float = 0.20
# =============================================================================

# Анимация слияния: Squash + Pop (только результирующая плитка)
# value — для weight-based: большие числа = сильнее эффект
func animate_merge(tile_value: int = 2) -> void:
	var max_scale_val: float
	var duration: float
	
	if tile_value >= 512:
		max_scale_val = MERGE_LARGE_MAX_SCALE
		duration = MERGE_LARGE_DURATION
	elif tile_value >= 128:
		max_scale_val = MERGE_MEDIUM_MAX_SCALE
		duration = MERGE_MEDIUM_DURATION
	else:
		max_scale_val = MERGE_SMALL_MAX_SCALE
		duration = MERGE_SMALL_DURATION
	
	var half: float = duration * 0.5
	var max_scale: Vector2 = Vector2(max_scale_val, max_scale_val)
	
	var tween: Tween = create_tween()
	# Фаза 1: scale up — ease-out (удар)
	tween.tween_property(self, "scale", max_scale, half).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Фаза 2: scale down — ease-in (возврат)
	tween.tween_property(self, "scale", Vector2.ONE, half).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# Анимация движения к новой позиции
func move_to(target_position: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_position, 0.12)
