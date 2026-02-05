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

# --- Glassmorphism (тест — false для отката) ---
const GLASSMORPHISM_ENABLED: bool = true

# =============================================================================

# Ссылки на узлы
@onready var grid: Node2D = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/GameFieldContainer/GridContainer/Grid
@onready var input_handler: Node = $InputHandler
@onready var score_value: Label = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/ScoreArea/ScorePanel/ScoreContainer/ScoreValue
@onready var score_container: VBoxContainer = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/ScoreArea/ScorePanel/ScoreContainer
@onready var best_value: Label = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/ScoreArea/BestPanel/BestContainer/BestValue
@onready var restart_button: Button = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/TopBar/RestartButton

# Top Bar controls
@onready var music_button: Button = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/TopBar/LeftGroup/MusicButton
@onready var help_button: Button = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/TopBar/LeftGroup/HelpButton
@onready var undo_button: Button = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/TopBar/RightGroup/UndoButton

# Ссылка на GameManager (синглтон)
var game_manager: Node = null

# UNDO: состояние до последнего хода
var pre_move_grid_state: Array = []
var pre_move_score: int = 0
var pre_move_best_score: int = 0

# Audio state
var music_enabled: bool = true

# Фиксированная "домашняя" позиция GridContainer (защита от дрифта при спаме)
var _grid_container_home: Vector2 = Vector2.ZERO
var grid_container: Control = null
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
	grid.merge_popup_requested.connect(_on_merge_popup_requested)
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Top Bar controls
	music_button.pressed.connect(_on_music_toggle)
	help_button.pressed.connect(_on_help_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	
	# Обновляем Best Score
	best_value.text = str(game_manager.best_score)
	
	# Запоминаем домашнюю позицию GridContainer (защита от дрифта при спаме)
	grid_container = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/GameFieldContainer/GridContainer
	_grid_container_home = grid_container.position
	
	# Glassmorphism (тест — выключить: GLASSMORPHISM_ENABLED = false)
	if GLASSMORPHISM_ENABLED:
		ThemeGlass.apply(self)

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


# ===== ТЕСТОВАЯ ФИЧА: MERGE POPUP =====
const MERGE_POPUP_DURATION: float = 1.10
const MERGE_POPUP_RISE: float = 20.0
const MERGE_POPUP_FONT_SIZE: int = 25
# ======================================

func _on_merge_popup_requested(points: int, multiplier: int) -> void:
	var popup: Label = Label.new()
	var display_points: int = points
	if grid.FEATURE_COMBO_ENABLED and multiplier > 1:
		display_points = points * multiplier
		popup.text = tr("game.points_combo") % [display_points, multiplier]
	else:
		popup.text = tr("game.points") % display_points
	
	popup.add_theme_font_size_override("font_size", MERGE_POPUP_FONT_SIZE)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.modulate = Color(1, 1, 1, 1)
	popup.z_index = 10
	
	# Позиция в глобальных координатах UI (центр ScoreContainer, смещено вверх и вправо)
	var container_global_pos: Vector2 = score_container.global_position
	var container_size: Vector2 = score_container.size
	var start_pos: Vector2 = container_global_pos + Vector2(container_size.x * 0.5 + 20, container_size.y * 0.5 - 10)
	popup.position = start_pos
	
	# Добавляем в UI слой, чтобы попап был независим от контейнера
	$UI.add_child(popup)
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(popup, "position:y", start_pos.y - MERGE_POPUP_RISE, MERGE_POPUP_DURATION)
	tween.parallel().tween_property(popup, "modulate", Color(1, 1, 1, 0), MERGE_POPUP_DURATION)
	tween.tween_callback(popup.queue_free)
# ======================================


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
	# Overlay: на весь экран
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	
	# CenterContainer: центрирует панель
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Панель: центрируется автоматически
	var game_over_panel: Panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.custom_minimum_size = Vector2(500, 400)
	
	# VBox внутри панели
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var game_over_label: Label = Label.new()
	game_over_label.text = tr("game.game_over")
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.modulate.a = 0
	
	var final_score_label: Label = Label.new()
	final_score_label.text = tr("game.final_score") % game_manager.current_score
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 32)
	final_score_label.modulate.a = 0
	
	var buttons_container: HBoxContainer = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", 20)
	buttons_container.modulate.a = 0
	
	if not game_manager.revive_used:
		var revive_button: Button = Button.new()
		revive_button.text = tr("game.revive")
		revive_button.custom_minimum_size = Vector2(200, 54)
		revive_button.pressed.connect(_on_revive_button_pressed.bind(overlay))
		buttons_container.add_child(revive_button)
	
	var restart_game_over_button: Button = Button.new()
	restart_game_over_button.text = tr("ui.restart")
	restart_game_over_button.custom_minimum_size = Vector2(200, 54)
	restart_game_over_button.pressed.connect(_on_restart_from_game_over.bind(overlay))
	buttons_container.add_child(restart_game_over_button)
	
	vbox.add_child(game_over_label)
	vbox.add_child(final_score_label)
	vbox.add_child(buttons_container)
	game_over_panel.add_child(vbox)
	center.add_child(game_over_panel)
	overlay.add_child(center)
	$UI.add_child(overlay)
	
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
	effect_label.text = tr("game.tiles_cleared")
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
	combo_label.text = tr("game.combo") % multiplier
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


# ===== TOP BAR CONTROLS =====

# Music toggle
func _on_music_toggle() -> void:
	music_enabled = !music_enabled
	music_button.text = tr("ui.music_on") if music_enabled else tr("ui.music_off")
	# TODO: управление фоновой музыкой (когда добавится)


# Help modal
func _on_help_pressed() -> void:
	_show_help_modal()


func _show_help_modal() -> void:
	# Overlay (затемнение) на весь экран
	var overlay: Control = Control.new()
	overlay.name = "HelpOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Фон затемнения
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	
	# CenterContainer: центрирует панель
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Modal panel: центрируется автоматически
	var modal: Panel = Panel.new()
	modal.custom_minimum_size = Vector2(600, 500)
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# VBox для контента
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 20)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Title
	var title: Label = Label.new()
	title.text = tr("overlay.how_to_play")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	
	# Instructions
	var instructions: Label = Label.new()
	instructions.text = tr("overlay.instructions")
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.size_flags_vertical = 3
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = tr("overlay.close")
	close_btn.custom_minimum_size = Vector2(200, 54)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_help_modal.bind(overlay))
	
	vbox.add_child(title)
	vbox.add_child(instructions)
	vbox.add_child(close_btn)
	modal.add_child(vbox)
	center.add_child(modal)
	
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
	if grid_container:
		grid_container.position = _grid_container_home


# Pre-Move Nudge: плавное смещение в направлении ввода (ощущение "движение")
func _input_anticipation_nudge(direction: Vector2i) -> void:
	_stop_grid_effect_and_reset()
	if not grid_container:
		grid_container = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/GameFieldContainer/GridContainer
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
	if not grid_container:
		grid_container = $UI/CenterContainer/ContentContainer/SafeArea/MainVBox/GameFieldContainer/GridContainer
	
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
