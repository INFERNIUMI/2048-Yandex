# Game - главная игровая сцена
extends Node2D

# Ссылки на узлы
@onready var grid: Node2D = $GridContainer/Grid
@onready var input_handler: Node = $InputHandler
@onready var score_value: Label = $UI/TopPanel/ScoreValue
@onready var best_value: Label = $UI/TopPanel/BestValue
@onready var restart_button: Button = $UI/TopPanel/RestartButton

# Ссылка на GameManager (синглтон)
var game_manager: Node = null


func _ready() -> void:
	# Получаем GameManager из autoload
	game_manager = get_node("/root/GameManager")
	
	# Подключаем сигналы
	input_handler.move_input.connect(_on_move_input)
	grid.score_updated.connect(_on_score_updated)
	grid.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Обновляем Best Score
	best_value.text = str(game_manager.best_score)
	
	# Начинаем новую игру
	_start_new_game()


# Начало новой игры
func _start_new_game() -> void:
	game_manager.start_new_game()
	score_value.text = "0"
	grid.start_new_game()


# Обработка ввода направления
func _on_move_input(direction: Vector2i) -> void:
	grid.process_move(direction)


# Обновление счёта
func _on_score_updated(points: int) -> void:
	game_manager.update_score(points)
	score_value.text = str(game_manager.current_score)
	best_value.text = str(game_manager.best_score)


# Game Over
func _on_game_over() -> void:
	game_manager.trigger_game_over()
	
	# Показываем экран Game Over
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
