# Grid - игровое поле 4x4
# Управляет плитками и логикой игры 2048
extends Node2D

# Сигналы
signal score_updated(points: int)
signal game_over
signal move_completed

# Константы
const GRID_SIZE: int = 4
const TILE_SIZE: int = 150
const TILE_SPACING: int = 20
const SPAWN_PROBABILITY_4: float = 0.1  # 10% шанс появления 4
const DEBUG: bool = true

# Сетка плиток (двумерный массив)
var tiles: Array[Array] = []

# Сцена плитки (будет загружена позже)
var tile_scene: PackedScene = null

# Флаг анимации
var is_animating: bool = false


func _ready() -> void:
	_init_grid()
	tile_scene = preload("res://scenes/tile/tile.tscn")


# Инициализация пустой сетки
func _init_grid() -> void:
	tiles.clear()
	for x in GRID_SIZE:
		var column: Array = []
		for y in GRID_SIZE:
			column.append(null)
		tiles.append(column)


# Начало новой игры
func start_new_game() -> void:
	_clear_grid()
	_spawn_initial_tiles()


# Очистка сетки
func _clear_grid() -> void:
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if tiles[x][y] != null:
				tiles[x][y].queue_free()
				tiles[x][y] = null


# Появление начальных плиток (2 штуки)
func _spawn_initial_tiles() -> void:
	_spawn_random_tile()
	_spawn_random_tile()


# Появление случайной плитки
func _spawn_random_tile() -> void:
	var empty_cells: Array[Vector2i] = _get_empty_cells()
	
	if empty_cells.is_empty():
		return
	
	var random_cell: Vector2i = empty_cells[randi() % empty_cells.size()]
	var value: int = 4 if randf() < SPAWN_PROBABILITY_4 else 2
	
	_create_tile(random_cell.x, random_cell.y, value)


# Получение списка пустых ячеек
func _get_empty_cells() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if tiles[x][y] == null:
				empty.append(Vector2i(x, y))
	
	return empty


# Создание плитки
func _create_tile(x: int, y: int, value: int) -> void:
	var tile: Node2D = tile_scene.instantiate()
	tile.position = _get_tile_position(x, y)
	tile.set_value(value)
	
	add_child(tile)
	tiles[x][y] = tile
	
	# Анимация появления
	tile.animate_spawn()


# Получение позиции плитки на экране
func _get_tile_position(x: int, y: int) -> Vector2:
	var offset: float = (TILE_SIZE + TILE_SPACING) / 2.0
	return Vector2(
		x * (TILE_SIZE + TILE_SPACING) + offset,
		y * (TILE_SIZE + TILE_SPACING) + offset
	)


# Обработка хода (направление: UP, DOWN, LEFT, RIGHT)
func process_move(direction: Vector2i) -> void:
	if is_animating:
		return
	
	var moved: bool = false
	
	# Обрабатываем движение в зависимости от направления
	if direction == Vector2i.UP:
		moved = _move_up()
	elif direction == Vector2i.DOWN:
		moved = _move_down()
	elif direction == Vector2i.LEFT:
		moved = _move_left()
	elif direction == Vector2i.RIGHT:
		moved = _move_right()
	
	if moved:
		is_animating = true
		
		# Ждём окончания анимации
		await get_tree().create_timer(0.15).timeout
		
		# Появляется новая плитка
		_spawn_random_tile()
		
		is_animating = false
		move_completed.emit()
		
		# Проверка Game Over
		if _is_game_over():
			game_over.emit()


# Движение вверх
func _move_up() -> bool:
	var moved: bool = false
	
	for x in GRID_SIZE:
		var merged: Array[bool] = [false, false, false, false]
		
		for y in range(1, GRID_SIZE):
			if tiles[x][y] == null:
				continue
			
			var current_y: int = y
			
			# Двигаем плитку вверх, пока можем
			while current_y > 0:
				if tiles[x][current_y - 1] == null:
					# Пустая ячейка - двигаем
					tiles[x][current_y - 1] = tiles[x][current_y]
					tiles[x][current_y] = null
					
					tiles[x][current_y - 1].move_to(_get_tile_position(x, current_y - 1))
					current_y -= 1
					moved = true
				elif tiles[x][current_y - 1].value == tiles[x][current_y].value and not merged[current_y - 1]:
					# Одинаковые значения - объединяем
					var new_value: int = tiles[x][current_y - 1].value * 2
					tiles[x][current_y - 1].set_value(new_value)
					tiles[x][current_y - 1].animate_merge()
					
					score_updated.emit(new_value)
					
					tiles[x][current_y].queue_free()
					tiles[x][current_y] = null
					
					merged[current_y - 1] = true
					moved = true
					break
				else:
					break
	
	return moved


# Движение вниз
func _move_down() -> bool:
	var moved: bool = false
	
	for x in GRID_SIZE:
		var merged: Array[bool] = [false, false, false, false]
		
		for y in range(GRID_SIZE - 2, -1, -1):
			if tiles[x][y] == null:
				continue
			
			var current_y: int = y
			
			while current_y < GRID_SIZE - 1:
				if tiles[x][current_y + 1] == null:
					tiles[x][current_y + 1] = tiles[x][current_y]
					tiles[x][current_y] = null
					
					tiles[x][current_y + 1].move_to(_get_tile_position(x, current_y + 1))
					current_y += 1
					moved = true
				elif tiles[x][current_y + 1].value == tiles[x][current_y].value and not merged[current_y + 1]:
					var new_value: int = tiles[x][current_y + 1].value * 2
					tiles[x][current_y + 1].set_value(new_value)
					tiles[x][current_y + 1].animate_merge()
					
					score_updated.emit(new_value)
					
					tiles[x][current_y].queue_free()
					tiles[x][current_y] = null
					
					merged[current_y + 1] = true
					moved = true
					break
				else:
					break
	
	return moved


# Движение влево
func _move_left() -> bool:
	var moved: bool = false
	
	for y in GRID_SIZE:
		var merged: Array[bool] = [false, false, false, false]
		
		for x in range(1, GRID_SIZE):
			if tiles[x][y] == null:
				continue
			
			var current_x: int = x
			
			while current_x > 0:
				if tiles[current_x - 1][y] == null:
					tiles[current_x - 1][y] = tiles[current_x][y]
					tiles[current_x][y] = null
					
					tiles[current_x - 1][y].move_to(_get_tile_position(current_x - 1, y))
					current_x -= 1
					moved = true
				elif tiles[current_x - 1][y].value == tiles[current_x][y].value and not merged[current_x - 1]:
					var new_value: int = tiles[current_x - 1][y].value * 2
					tiles[current_x - 1][y].set_value(new_value)
					tiles[current_x - 1][y].animate_merge()
					
					score_updated.emit(new_value)
					
					tiles[current_x][y].queue_free()
					tiles[current_x][y] = null
					
					merged[current_x - 1] = true
					moved = true
					break
				else:
					break
	
	return moved


# Движение вправо
func _move_right() -> bool:
	var moved: bool = false
	
	for y in GRID_SIZE:
		var merged: Array[bool] = [false, false, false, false]
		
		for x in range(GRID_SIZE - 2, -1, -1):
			if tiles[x][y] == null:
				continue
			
			var current_x: int = x
			
			while current_x < GRID_SIZE - 1:
				if tiles[current_x + 1][y] == null:
					tiles[current_x + 1][y] = tiles[current_x][y]
					tiles[current_x][y] = null
					
					tiles[current_x + 1][y].move_to(_get_tile_position(current_x + 1, y))
					current_x += 1
					moved = true
				elif tiles[current_x + 1][y].value == tiles[current_x][y].value and not merged[current_x + 1]:
					var new_value: int = tiles[current_x + 1][y].value * 2
					tiles[current_x + 1][y].set_value(new_value)
					tiles[current_x + 1][y].animate_merge()
					
					score_updated.emit(new_value)
					
					tiles[current_x][y].queue_free()
					tiles[current_x][y] = null
					
					merged[current_x + 1] = true
					moved = true
					break
				else:
					break
	
	return moved


# Проверка Game Over
func _is_game_over() -> bool:
	# Есть пустые ячейки - игра продолжается
	if not _get_empty_cells().is_empty():
		return false
	
	# Проверяем возможность объединения по горизонтали
	for y in GRID_SIZE:
		for x in range(GRID_SIZE - 1):
			if tiles[x][y].value == tiles[x + 1][y].value:
				return false
	
	# Проверяем возможность объединения по вертикали
	for x in GRID_SIZE:
		for y in range(GRID_SIZE - 1):
			if tiles[x][y].value == tiles[x][y + 1].value:
				return false
	
	# Нет доступных ходов - Game Over
	return true


# Revive: очистка маленьких плиток (2–3 самых маленьких)
func clear_small_tiles() -> void:
	var small_tiles: Array = []
	
	# Собираем все плитки со значениями 2 и 4
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if tiles[x][y] != null:
				var tile_value: int = tiles[x][y].value
				if tile_value == 2 or tile_value == 4:
					small_tiles.append({"x": x, "y": y, "tile": tiles[x][y]})
	
	# Если маленьких плиток нет - очищаем любые 2-3 самые маленькие
	if small_tiles.is_empty():
		var all_tiles: Array = []
		for x in GRID_SIZE:
			for y in GRID_SIZE:
				if tiles[x][y] != null:
					all_tiles.append({"x": x, "y": y, "value": tiles[x][y].value, "tile": tiles[x][y]})
		
		# Сортируем по значению
		all_tiles.sort_custom(func(a, b): return a["value"] < b["value"])
		
		# Берём 2-3 самые маленькие
		var count: int = mini(3, all_tiles.size())
		for i in count:
			small_tiles.append(all_tiles[i])
	
	# Удаляем 2-3 плитки
	var to_remove: int = mini(3, small_tiles.size())
	
	for i in to_remove:
		var tile_data: Dictionary = small_tiles[i]
		var x: int = tile_data["x"]
		var y: int = tile_data["y"]
		
		# Анимация исчезновения
		var tile: Node2D = tiles[x][y]
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(tile.queue_free)
		
		tiles[x][y] = null
	
	if DEBUG:
		print("[Grid] Revive: очищено %d плиток" % to_remove)


# Проверка, есть ли маленькие плитки для очистки
func has_small_tiles() -> bool:
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if tiles[x][y] != null and (tiles[x][y].value == 2 or tiles[x][y].value == 4):
				return true
	return false
