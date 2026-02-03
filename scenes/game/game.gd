# Game - главная игровая сцена
extends Node2D

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


func _ready() -> void:
	# Получаем GameManager из autoload
	game_manager = get_node("/root/GameManager")
	
	# Подключаем сигналы
	input_handler.move_input.connect(_on_move_input)
	grid.score_updated.connect(_on_score_updated)
	grid.game_over.connect(_on_game_over)
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
	
	# Начинаем новую игру
	_start_new_game()


# Начало новой игры
func _start_new_game() -> void:
	game_manager.start_new_game()
	score_value.text = "0"
	grid.start_new_game()
	_update_undo_button()


# Обработка ввода направления
func _on_move_input(direction: Vector2i) -> void:
	# UNDO: сохраняем состояние перед ходом
	if not game_manager.undo_used:
		pre_move_grid_state = grid.get_state()
		pre_move_score = game_manager.current_score
		pre_move_best_score = game_manager.best_score
	grid.process_move(direction)


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
	game_manager.trigger_game_over()
	_update_undo_button()
	_show_game_over_screen()


# Показ экрана Game Over
func _show_game_over_screen() -> void:
	# Для MVP - просто показываем панель Game Over
	# В будущем можно сделать отдельную сцену
	var game_over_panel: Panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.custom_minimum_size = Vector2(500, 400)
	game_over_panel.position = Vector2(110, 350)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var game_over_label: Label = Label.new()
	game_over_label.text = "Game Over"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	
	var final_score_label: Label = Label.new()
	final_score_label.text = "Score: " + str(game_manager.current_score)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 32)
	
	vbox.add_child(game_over_label)
	vbox.add_child(final_score_label)
	
	# Кнопка Revive (только если ещё не использовали)
	if not game_manager.revive_used:
		var revive_button: Button = Button.new()
		revive_button.text = "Revive (Watch Ad)"
		revive_button.custom_minimum_size = Vector2(250, 60)
		revive_button.pressed.connect(_on_revive_button_pressed.bind(game_over_panel))
		vbox.add_child(revive_button)
	
	# Кнопка Restart
	var restart_game_over_button: Button = Button.new()
	restart_game_over_button.text = "Restart"
	restart_game_over_button.custom_minimum_size = Vector2(250, 60)
	restart_game_over_button.pressed.connect(_on_restart_from_game_over.bind(game_over_panel))
	vbox.add_child(restart_game_over_button)
	
	game_over_panel.add_child(vbox)
	add_child(game_over_panel)


# Перезапуск игры
func _on_restart_pressed() -> void:
	_start_new_game()


# Revive: просмотр рекламы
func _on_revive_button_pressed(game_over_panel: Panel) -> void:
	# Отмечаем, что revive использован
	game_manager.revive_used = true
	
	# Показываем rewarded рекламу
	game_manager.yandex_sdk.show_rewarded_ad(_on_revive_granted.bind(game_over_panel))


# Обработка успешного revive
func _on_revive_granted(game_over_panel: Panel) -> void:
	# Убираем экран Game Over
	game_over_panel.queue_free()
	
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
func _on_restart_from_game_over(game_over_panel: Panel) -> void:
	game_over_panel.queue_free()
	_start_new_game()


# ===== COMBO: визуальный эффект =====
func _on_combo_triggered(multiplier: int) -> void:
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
	if has_node("GameOverPanel") or get_node_or_null("UI/HelpOverlay"):
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
	var no_game_over: bool = not has_node("GameOverPanel")
	undo_button.disabled = not (available and has_state and no_game_over)
