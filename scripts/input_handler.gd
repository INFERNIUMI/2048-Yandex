# InputHandler - обработка ввода (клавиатура и свайпы)
extends Node

# Сигнал для передачи направления движения
signal move_input(direction: Vector2i)

# Параметры свайпа
const MIN_SWIPE_DISTANCE: float = 50.0

# Переменные для отслеживания свайпа
var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false


func _input(event: InputEvent) -> void:
	# Обработка клавиатуры
	if event.is_action_pressed("ui_up"):
		move_input.emit(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		move_input.emit(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		move_input.emit(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		move_input.emit(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	
	# Обработка свайпов (touch + mouse)
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			swipe_start = event.position
			is_swiping = true
		else:
			if is_swiping:
				_process_swipe(event.position)
			is_swiping = false


# Обработка свайпа
func _process_swipe(swipe_end: Vector2) -> void:
	var swipe_vector: Vector2 = swipe_end - swipe_start
	
	# Проверяем минимальную дистанцию
	if swipe_vector.length() < MIN_SWIPE_DISTANCE:
		return
	
	# Определяем направление
	var abs_x: float = abs(swipe_vector.x)
	var abs_y: float = abs(swipe_vector.y)
	
	if abs_x > abs_y:
		# Горизонтальный свайп
		if swipe_vector.x > 0:
			move_input.emit(Vector2i.RIGHT)
		else:
			move_input.emit(Vector2i.LEFT)
	else:
		# Вертикальный свайп
		if swipe_vector.y > 0:
			move_input.emit(Vector2i.DOWN)
		else:
			move_input.emit(Vector2i.UP)
