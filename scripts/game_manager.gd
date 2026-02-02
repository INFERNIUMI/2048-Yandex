# GameManager - главный контроллер игры
# Управляет переключением сцен и общим состоянием игры
# Используется как autoload singleton
extends Node

# Сигналы для событий игры
signal game_started
signal game_over_triggered(score: int)

# Текущий счёт и лучший счёт
var current_score: int = 0
var best_score: int = 0

# Флаг использования revive
var revive_used: bool = false

# Флаг для отладки (включить для логов)
const DEBUG: bool = true

# Ссылка на Yandex SDK
var yandex_sdk: Node = null


func _ready() -> void:
	_load_best_score()
	_init_yandex_sdk()
	
	if DEBUG:
		print("[GameManager] Инициализация завершена")


# Инициализация Yandex SDK
func _init_yandex_sdk() -> void:
	var sdk_script: Script = load("res://scripts/yandex_sdk.gd")
	yandex_sdk = sdk_script.new()
	add_child(yandex_sdk)
	
	# Вызываем gameReady после инициализации
	yandex_sdk.game_ready()


# Начало новой игры
func start_new_game() -> void:
	current_score = 0
	revive_used = false  # Сбрасываем флаг revive
	game_started.emit()
	
	if DEBUG:
		print("[GameManager] Новая игра начата")


# Обновление счёта
func update_score(points: int) -> void:
	current_score += points
	
	if current_score > best_score:
		best_score = current_score
		_save_best_score()


# Завершение игры
func trigger_game_over() -> void:
	game_over_triggered.emit(current_score)
	
	if DEBUG:
		print("[GameManager] Game Over. Счёт: %d" % current_score)
	
	# Показываем рекламу после Game Over
	if yandex_sdk:
		yandex_sdk.show_fullscreen_ad()


# Перезапуск игры
func restart_game() -> void:
	start_new_game()


# Сохранение лучшего счёта в localStorage
func _save_best_score() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('best_score', %d)" % best_score)
	else:
		# Для локальной разработки
		var save_file: FileAccess = FileAccess.open("user://best_score.dat", FileAccess.WRITE)
		if save_file:
			save_file.store_32(best_score)
			save_file.close()


# Загрузка лучшего счёта из localStorage
func _load_best_score() -> void:
	if OS.has_feature("web"):
		var result: String = JavaScriptBridge.eval("localStorage.getItem('best_score') || '0'")
		best_score = int(result)
	else:
		# Для локальной разработки
		if FileAccess.file_exists("user://best_score.dat"):
			var save_file: FileAccess = FileAccess.open("user://best_score.dat", FileAccess.READ)
			if save_file:
				best_score = save_file.get_32()
				save_file.close()
	
	if DEBUG:
		print("[GameManager] Лучший счёт загружен: %d" % best_score)
