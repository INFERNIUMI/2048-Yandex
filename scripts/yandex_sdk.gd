# YandexSDK - обёртка для работы с Yandex Games SDK
# Все JS-вызовы асинхронные, не блокируют игру
extends Node

const DEBUG: bool = true

# Флаги состояния
var sdk_initialized: bool = false
var ad_showing: bool = false
var rewarded_ad_showing: bool = false

# Callback для rewarded ad
var rewarded_callback: Callable

# Таймер для timeout рекламы
var ad_timeout_timer: Timer = null
var rewarded_timeout_timer: Timer = null


func _ready() -> void:
	_init_ad_timeout_timer()
	_init_rewarded_timeout_timer()
	
	# Проверяем доступность SDK
	if OS.has_feature("web"):
		_check_sdk_availability()
	else:
		if DEBUG:
			push_warning("[YandexSDK] Локальная разработка - SDK недоступен")


# Инициализация таймера для timeout рекламы
func _init_ad_timeout_timer() -> void:
	ad_timeout_timer = Timer.new()
	ad_timeout_timer.one_shot = true
	ad_timeout_timer.wait_time = 5.0
	ad_timeout_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	ad_timeout_timer.timeout.connect(_on_ad_timeout)
	add_child(ad_timeout_timer)


# Инициализация таймера для timeout rewarded рекламы
func _init_rewarded_timeout_timer() -> void:
	rewarded_timeout_timer = Timer.new()
	rewarded_timeout_timer.one_shot = true
	rewarded_timeout_timer.wait_time = 60.0  # 60 сек для rewarded ad
	rewarded_timeout_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	rewarded_timeout_timer.timeout.connect(_on_rewarded_timeout)
	add_child(rewarded_timeout_timer)


# Проверка доступности Yandex SDK
func _check_sdk_availability() -> void:
	var sdk_check = JavaScriptBridge.eval("typeof ysdk !== 'undefined'")
	sdk_initialized = str(sdk_check) == "true"
	
	if DEBUG:
		if sdk_initialized:
			print("[YandexSDK] SDK доступен")
		else:
			push_warning("[YandexSDK] SDK недоступен")


# Вызов gameReady - сообщаем Yandex, что игра загружена
func game_ready() -> void:
	if not OS.has_feature("web"):
		return
	
	if not sdk_initialized:
		if DEBUG:
			push_warning("[YandexSDK] SDK недоступен, пропускаем gameReady")
		return
	
	JavaScriptBridge.eval("""
		if (typeof ysdk !== 'undefined' && ysdk.features && ysdk.features.LoadingAPI) {
			ysdk.features.LoadingAPI.ready();
		}
	""")
	
	if DEBUG:
		print("[YandexSDK] gameReady() вызван")


# Показ полноэкранной рекламы
func show_fullscreen_ad() -> void:
	if not OS.has_feature("web"):
		if DEBUG:
			print("[YandexSDK] Локальная разработка - реклама пропущена")
		return
	
	if not sdk_initialized:
		if DEBUG:
			push_warning("[YandexSDK] SDK недоступен, реклама пропущена")
		return
	
	if ad_showing:
		if DEBUG:
			push_warning("[YandexSDK] Реклама уже показывается")
		return
	
	ad_showing = true
	ad_timeout_timer.start()
	
	# Пауза игры
	get_tree().paused = true
	
	if DEBUG:
		print("[YandexSDK] Показываем полноэкранную рекламу")
	
	JavaScriptBridge.eval("""
		if (typeof ysdk !== 'undefined' && ysdk.adv) {
			ysdk.adv.showFullscreenAdv({
				callbacks: {
					onOpen: function() {
						console.log('[YandexSDK] Реклама открылась');
					},
					onClose: function(wasShown) {
						console.log('[YandexSDK] Реклама закрылась. Показана: ' + wasShown);
						// Возобновляем игру через Godot
					},
					onError: function(error) {
						console.error('[YandexSDK] Ошибка рекламы:', error);
						// Возобновляем игру через Godot
					}
				}
			});
		}
	""")
	
	# Устанавливаем callback для возобновления игры
	# В реальном проекте это будет через JavaScriptBridge callback
	# Для MVP используем простой таймер
	await get_tree().create_timer(2.0, true).timeout
	_resume_game()


# Возобновление игры после рекламы
func _resume_game() -> void:
	ad_showing = false
	ad_timeout_timer.stop()
	get_tree().paused = false
	
	if DEBUG:
		print("[YandexSDK] Игра возобновлена после рекламы")


# Обработка timeout рекламы
func _on_ad_timeout() -> void:
	if ad_showing:
		if DEBUG:
			push_warning("[YandexSDK] Timeout рекламы - возобновляем игру")
		_resume_game()


# Показ rewarded рекламы
func show_rewarded_ad(on_reward: Callable) -> void:
	if not OS.has_feature("web"):
		if DEBUG:
			print("[YandexSDK] Локальная разработка - эмулируем rewarded ad")
			# Для тестирования локально - сразу даём награду
			await get_tree().create_timer(1.0).timeout
			on_reward.call()
		return
	
	if not sdk_initialized:
		if DEBUG:
			push_warning("[YandexSDK] SDK недоступен, rewarded ad пропущена")
		return
	
	if rewarded_ad_showing:
		if DEBUG:
			push_warning("[YandexSDK] Rewarded реклама уже показывается")
		return
	
	rewarded_ad_showing = true
	rewarded_callback = on_reward
	rewarded_timeout_timer.start()
	
	# Пауза игры
	get_tree().paused = true
	
	if DEBUG:
		print("[YandexSDK] Показываем rewarded рекламу")
	
	JavaScriptBridge.eval("""
		if (typeof ysdk !== 'undefined' && ysdk.adv) {
			ysdk.adv.showRewardedVideo({
				callbacks: {
					onOpen: function() {
						console.log('[YandexSDK] Rewarded реклама открылась');
					},
					onRewarded: function() {
						console.log('[YandexSDK] Награда получена!');
						// Вызываем награду через Godot
					},
					onClose: function() {
						console.log('[YandexSDK] Rewarded реклама закрылась');
						// Возобновляем игру через Godot
					},
					onError: function(error) {
						console.error('[YandexSDK] Ошибка rewarded рекламы:', error);
						// Возобновляем игру без награды
					}
				}
			});
		}
	""")
	
	# Эмулируем успешный просмотр для MVP
	# В production это будет через callback из JS
	await get_tree().create_timer(2.0, true).timeout
	_on_rewarded_ad_completed(true)


# Обработка завершения rewarded рекламы
func _on_rewarded_ad_completed(reward_granted: bool) -> void:
	rewarded_ad_showing = false
	rewarded_timeout_timer.stop()
	get_tree().paused = false
	
	if reward_granted:
		if DEBUG:
			print("[YandexSDK] Награда выдана!")
		
		# Вызываем callback с наградой
		if rewarded_callback:
			rewarded_callback.call()
			rewarded_callback = Callable()
	else:
		if DEBUG:
			print("[YandexSDK] Награда не выдана (реклама закрыта досрочно)")


# Обработка timeout rewarded рекламы
func _on_rewarded_timeout() -> void:
	if rewarded_ad_showing:
		if DEBUG:
			push_warning("[YandexSDK] Timeout rewarded рекламы - закрываем без награды")
		_on_rewarded_ad_completed(false)
