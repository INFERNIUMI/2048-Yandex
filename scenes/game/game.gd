# Game - главная игровая сцена
extends Node2D

# =============================================================================
# НАСТРОЙКИ INPUT ANTICIPATION И ERROR FEEDBACK
# Меняй значения здесь, чтобы добить ощущения. Сохрани файл → F5.
# =============================================================================

# --- Input Anticipation (Pre-Move Nudge) ---
# Ощущение: "движение", "принято"
const NUDGE_AMPLITUDE: float = 4.5        # px (3–5) — сила смещения
const NUDGE_DURATION_OUT: float = 0.090  # сек (0.07–0.10) — смещение в сторону
const NUDGE_DURATION_BACK: float = 0.065 # сек — возврат к центру
const NUDGE_EASING: Tween.EaseType = Tween.EASE_OUT
const NUDGE_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC

# --- Error Feedback (Invalid Move) ---
# Ощущение: "нет", "упёрлось", вибрация
const ERROR_AMPLITUDE: float = 3.0        # px (1–2) — меньше чем Nudge!
const ERROR_DURATION_TOTAL: float = 0.15  # сек (0.09–0.12) — общая длина
const ERROR_JERKS: int = 3                # кол-во рывков (2–3)
const ERROR_EASING: Tween.EaseType = Tween.EASE_IN_OUT
const ERROR_TRANS: Tween.TransitionType = Tween.TRANS_LINEAR

# =============================================================================

# Ссылки на узлы
@onready var grid: Node2D = $GridContainer/Grid
@onready var input_handler: Node = $InputHandler
@onready var score_value: Label = $UI/TopPanel/ScoreValue
@onready var best_value: Label = $UI/TopPanel/BestValue
@onready var restart_button: Button = $UI/TopPanel/RestartButton

# Utility Bar
@onready var music_button: Button = $UI/UtilityBar/HBox/MusicButton
@onready var sfx_button: Button = $UI/UtilityBar/HBox/SFXButton
@onready var help_button: Button = $UI/UtilityBar/HBox/HelpButton
@onready var undo_button: Button = $UI/UtilityBar/HBox/UndoButton
@onready var restart_button_2: Button = $UI/UtilityBar/HBox/RestartButton2

# Ссылка на GameManager (синглтон)
var game_manager: Node = null

# UNDO: состояние до последнего хода
var pre_move_grid_state: Array = []
var pre_move_score: int = 0
var pre_move_best_score: int = 0

# Audio state (архитектура для возможного объединения)
var music_enabled: bool = true
var sfx_enabled: bool = true

# Фиксированная "домашняя" позиция GridContainer (защита от дрифта при спаме)
var _grid_container_home: Vector2 = Vector2.ZERO
var _grid_effect_tween: Tween = null

# Game Over: блокировка ввода
var _is_game_over: bool = false


func _ready() -> void:
	# Получаем GameManager из autoload
	game_manager = get_node("/root/GameManager")
	
	# Подключаем сигналы
	input_handler.move_input.connect(_on_move_input)
	grid.score_updated.connect(_on_score_updated)
	grid.game_over.connect(_on_game_over)
	grid.game_over_settle_completed.connect(_on_game_over_settle_completed)
	grid.move_completed.connect(_on_move_completed)
	grid.combo_triggered.connect(_on_combo_triggered)
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Utility Bar
	music_button.pressed.connect(_on_music_toggle)
	sfx_button.pressed.connect(_on_sfx_toggle)
	help_button.pressed.connect(_on_help_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	restart_button_2.pressed.connect(_on_restart_pressed)
	
	# Обновляем Best Score
	best_value.text = str(game_manager.best_score)
	
	# Запоминаем домашнюю позицию GridContainer (защита от дрифта при спаме)
	_grid_container_home = $GridContainer.position
	
	# Начинаем новую игру
	_start_new_game()


# Начало новой игры
func _start_new_game() -> void:
	_is_game_over = false
	game_manager.start_new_game()
	score_value.text = "0"
	grid.start_new_game()
	_update_undo_button()


# Обработка ввода направления
func _on_move_input(direction: Vector2i) -> void:
	if _is_game_over:
		return
	
	# INPUT ANTICIPATION: Pre-Move Nudge
	if grid.FEATURE_INPUT_ANTICIPATION:
		_input_anticipation_nudge(direction)
	
	# UNDO: сохраняем состояние перед ходом
	if not game_manager.undo_used:
		pre_move_grid_state = grid.get_state()
		pre_move_score = game_manager.current_score
		pre_move_best_score = game_manager.best_score
	
	var moved: bool = await grid.process_move(direction)
	
	# Если ход невозможен - shake (перпендикулярно направлению ввода)
	if not moved and grid.FEATURE_INPUT_ANTICIPATION:
		_input_rejection_shake(direction)


func _on_move_completed() -> void:
	_update_undo_button()


# Обновление счёта
func _on_score_updated(points: int) -> void:
	game_manager.update_score(points)
	score_value.text = str(game_manager.current_score)
	best_value.text = str(game_manager.best_score)
	_update_undo_button()


# Game Over
func _on_game_over() -> void:
	_is_game_over = true
	game_manager.trigger_game_over()
	_update_undo_button()
	grid.play_game_over_settle()


# =============================================================================
# GAME OVER: последовательность эффектов (настраиваемые параметры)
# =============================================================================
const GAME_OVER_OVERLAY_DURATION: float = 0.40   # 200–300 ms
const GAME_OVER_OVERLAY_ALPHA: float = 0.65
const GAME_OVER_TEXT_FADE: float = 0.3
const GAME_OVER_BUTTONS_FADE: float = 0.3
# =============================================================================

func _on_game_over_settle_completed() -> void:
	_show_game_over_screen()


# Показ экрана Game Over: overlay → текст → кнопки
func _show_game_over_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Overlay: явные position/size (без конфликта anchors)
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	overlay.color = Color(0, 0, 0, 0)
	
	# Панель: явные координаты
	var game_over_panel: Panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game_over_panel.position = Vector2((viewport_size.x - 500) / 2, (viewport_size.y - 400) / 2 - 50)
	game_over_panel.custom_minimum_size = Vector2(500, 400)
	game_over_panel.size = Vector2(500, 400)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(460, 360)
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var game_over_label: Label = Label.new()
	game_over_label.text = "Game Over"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.modulate.a = 0
	
	var final_score_label: Label = Label.new()
	final_score_label.text = "Score: " + str(game_manager.current_score)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 32)
	final_score_label.modulate.a = 0
	
	var buttons_container: HBoxContainer = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", 20)
	buttons_container.modulate.a = 0
	
	if not game_manager.revive_used:
		var revive_button: Button = Button.new()
		revive_button.text = "Revive (Watch Ad)"
		revive_button.custom_minimum_size = Vector2(200, 50)
		revive_button.pressed.connect(_on_revive_button_pressed.bind(overlay))
		buttons_container.add_child(revive_button)
	
	var restart_game_over_button: Button = Button.new()
	restart_game_over_button.text = "Restart"
	restart_game_over_button.custom_minimum_size = Vector2(200, 50)
	restart_game_over_button.pressed.connect(_on_restart_from_game_over.bind(overlay))
	buttons_container.add_child(restart_game_over_button)
	
	vbox.add_child(game_over_label)
	vbox.add_child(final_score_label)
	vbox.add_child(buttons_container)
	game_over_panel.add_child(vbox)
	
	overlay.add_child(game_over_panel)
	$UI.add_child(overlay)  # CanvasLayer — overlay поверх всего UI
	
	# 1. Затемнение фона
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(overlay, "color", Color(0, 0, 0, GAME_OVER_OVERLAY_ALPHA), GAME_OVER_OVERLAY_DURATION)
	
	# 2. Текст Game Over (fade-in, вместе)
	tween.set_parallel(true)
	tween.tween_property(game_over_label, "modulate:a", 1.0, GAME_OVER_TEXT_FADE)
	tween.tween_property(final_score_label, "modulate:a", 1.0, GAME_OVER_TEXT_FADE)
	tween.set_parallel(false)
	
	# 3. Кнопки (fade-in)
	tween.tween_property(buttons_container, "modulate:a", 1.0, GAME_OVER_BUTTONS_FADE)


# Перезапуск игры
func _on_restart_pressed() -> void:
	_start_new_game()


# Revive: просмотр рекламы
func _on_revive_button_pressed(game_over_overlay: Control) -> void:
	# Отмечаем, что revive использован
	game_manager.revive_used = true
	
	# Показываем rewarded рекламу
	game_manager.yandex_sdk.show_rewarded_ad(_on_revive_granted.bind(game_over_overlay))


# Обработка успешного revive
func _on_revive_granted(game_over_overlay: Control) -> void:
	_is_game_over = false
	# Убираем экран Game Over
	game_over_overlay.queue_free()
	
	# Очищаем маленькие плитки
	grid.clear_small_tiles()
	
	# Показываем визуальный эффект
	_show_revive_effect()
	
	# Игра продолжается!
	print("[Game] Revive активирован! Плитки очищены.")


# Визуальный эффект Revive
func _show_revive_effect() -> void:
	var effect_label: Label = Label.new()
	effect_label.text = "Tiles Cleared!"
	effect_label.add_theme_font_size_override("font_size", 56)
	effect_label.modulate = Color(1, 0.8, 0, 1)  # Золотой цвет
	effect_label.position = Vector2(200, 500)
	
	add_child(effect_label)
	
	# Анимация появления и исчезновения
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect_label, "modulate:a", 0.0, 1.5)
	tween.tween_property(effect_label, "position:y", 400.0, 1.5)
	tween.tween_callback(effect_label.queue_free)


# Перезапуск из экрана Game Over
func _on_restart_from_game_over(game_over_overlay: Control) -> void:
	game_over_overlay.queue_free()
	_start_new_game()


# ===== COMBO: визуальный эффект =====
# Задержка: Combo появляется после merge (merge ~100-160ms + 30-50ms)
const COMBO_DELAY_AFTER_MERGE: float = 0.18

func _on_combo_triggered(multiplier: int) -> void:
	await get_tree().create_timer(COMBO_DELAY_AFTER_MERGE).timeout
	
	var combo_label: Label = Label.new()
	combo_label.text = "COMBO x%d" % multiplier
	combo_label.add_theme_font_size_override("font_size", 64)
	
	# Цвет в зависимости от множителя
	if multiplier == 3:
		combo_label.modulate = Color(1, 0.2, 0.2, 1)  # Красный для x3
	else:
		combo_label.modulate = Color(1, 0.6, 0, 1)  # Оранжевый для x2
	
	combo_label.position = Vector2(180, 600)
	
	add_child(combo_label)
	
	# Анимация: появление, scale up, исчезновение
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Scale эффект
	combo_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.chain().tween_property(combo_label, "scale", Vector2.ONE, 0.1)
	
	# Fade out
	tween.chain().tween_property(combo_label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	
	# Движение вверх
	tween.tween_property(combo_label, "position:y", 500.0, 1.0)
	
	tween.tween_callback(combo_label.queue_free).set_delay(1.0)
	
	# Импульс экрана (лёгкий shake)
	_screen_pulse()


# Лёгкий импульс экрана при Combo
func _screen_pulse() -> void:
	var original_position: Vector2 = position
	var tween: Tween = create_tween()
	
	# Быстрый shake
	tween.tween_property(self, "position", original_position + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_position + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_position, 0.05)
# ====================================


# ===== UTILITY BAR =====

# Music toggle
func _on_music_toggle() -> void:
	music_enabled = !music_enabled
	music_button.text = "🎵 Music" if music_enabled else "🎵 OFF"
	# TODO: управление фоновой музыкой (когда добавится)


# SFX toggle
func _on_sfx_toggle() -> void:
	sfx_enabled = !sfx_enabled
	sfx_button.text = "🔊 SFX" if sfx_enabled else "🔊 OFF"
	# TODO: управление звуковыми эффектами (когда добавятся)


# Help modal
func _on_help_pressed() -> void:
	_show_help_modal()


func _show_help_modal() -> void:
	# Overlay (затемнение) - Control вместо ColorRect
	var overlay: Control = Control.new()
	overlay.name = "HelpOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Фон затемнения
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	
	# Modal panel (центрированная)
	var modal: Panel = Panel.new()
	modal.custom_minimum_size = Vector2(600, 500)
	modal.position = Vector2(60, 390)
	modal.process_mode = Node.PROCESS_MODE_ALWAYS  # Работает при паузе
	
	# VBox для контента
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(560, 460)
	vbox.add_theme_constant_override("separation", 20)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Title
	var title: Label = Label.new()
	title.text = "How to Play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	
	# Instructions
	var instructions: Label = Label.new()
	instructions.text = """• Swipe or use arrow keys to move tiles
• Merge identical tiles to score points
• Try to reach 2048 and get the highest score
• You can revive once by watching an ad"""
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(560, 200)
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 60)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS  # Работает при паузе
	close_btn.pressed.connect(_close_help_modal.bind(overlay))
	
	vbox.add_child(title)
	vbox.add_child(instructions)
	vbox.add_child(close_btn)
	modal.add_child(vbox)
	overlay.add_child(modal)
	
	# Добавляем в UI CanvasLayer (уже существует)
	$UI.add_child(overlay)
	get_tree().paused = true


func _close_help_modal(overlay: Control) -> void:
	get_tree().paused = false
	overlay.queue_free()
# =======================


# UNDO
func _on_undo_pressed() -> void:
	if game_manager.undo_used:
		return
	if get_tree().paused:
		return
	if pre_move_grid_state.is_empty():
		return
	if get_node_or_null("UI/GameOverOverlay") or get_node_or_null("UI/HelpOverlay"):
		return
	
	game_manager.undo_used = true
	game_manager.restore_undo_state(pre_move_score, pre_move_best_score)
	grid.restore_state(pre_move_grid_state)
	score_value.text = str(game_manager.current_score)
	best_value.text = str(game_manager.best_score)
	pre_move_grid_state = []
	_update_undo_button()


func _update_undo_button() -> void:
	var available: bool = not game_manager.undo_used and not get_tree().paused and not grid.is_animating
	var has_state: bool = not pre_move_grid_state.is_empty()
	var no_game_over: bool = get_node_or_null("UI/GameOverOverlay") == null
	undo_button.disabled = not (available and has_state and no_game_over)


# ===== INPUT ANTICIPATION =====

# Останавливает предыдущий эффект и возвращает GridContainer домой (защита от дрифта при спаме)
func _stop_grid_effect_and_reset() -> void:
	if _grid_effect_tween != null and _grid_effect_tween.is_valid():
		_grid_effect_tween.kill()
	_grid_effect_tween = null
	$GridContainer.position = _grid_container_home


# Pre-Move Nudge: плавное смещение в направлении ввода (ощущение "движение")
func _input_anticipation_nudge(direction: Vector2i) -> void:
	_stop_grid_effect_and_reset()
	var grid_container: Control = $GridContainer
	var nudge_offset: Vector2 = Vector2(direction) * NUDGE_AMPLITUDE
	
	_grid_effect_tween = create_tween()
	_grid_effect_tween.set_ease(NUDGE_EASING)
	_grid_effect_tween.set_trans(NUDGE_TRANS)
	
	_grid_effect_tween.tween_property(grid_container, "position", _grid_container_home + nudge_offset, NUDGE_DURATION_OUT)
	_grid_effect_tween.tween_property(grid_container, "position", _grid_container_home, NUDGE_DURATION_BACK)
	_grid_effect_tween.tween_callback(func() -> void: _grid_effect_tween = null)


# Error Shake: вибрация перпендикулярно направлению ввода (ощущение "упёрлось")
func _input_rejection_shake(direction: Vector2i) -> void:
	_stop_grid_effect_and_reset()
	var grid_container: Control = $GridContainer
	
	# Перпендикуляр: вверх/вниз → тряска влево-вправо; влево/вправо → тряска вверх-вниз
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	
	_grid_effect_tween = create_tween()
	_grid_effect_tween.set_ease(ERROR_EASING)
	_grid_effect_tween.set_trans(ERROR_TRANS)
	
	var step_count: int = ERROR_JERKS * 2 + 1  # рывки туда-сюда + возврат в центр
	var step_duration: float = ERROR_DURATION_TOTAL / float(step_count)
	for i in range(ERROR_JERKS):
		_grid_effect_tween.tween_property(grid_container, "position", _grid_container_home + perp * ERROR_AMPLITUDE, step_duration)
		_grid_effect_tween.tween_property(grid_container, "position", _grid_container_home - perp * ERROR_AMPLITUDE, step_duration)
	_grid_effect_tween.tween_property(grid_container, "position", _grid_container_home, step_duration)
	_grid_effect_tween.tween_callback(func() -> void: _grid_effect_tween = null)

# ==============================
