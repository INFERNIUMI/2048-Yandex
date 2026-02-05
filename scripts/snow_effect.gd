extends Control

@export var max_flakes: int = 70
@export var reference_viewport_area: float = 720.0 * 1280.0
@export var symbols: PackedStringArray = ["*", "·"]
@export var flake_color: Color = Color(0.804, 0.902, 1.0, 1.0)
@export var min_speed: float = 12.0
@export var max_speed: float = 28.0
@export var min_alpha: float = 0.40
@export var max_alpha: float = 0.9
@export var min_font_size: int = 14
@export var max_font_size: int = 20
@export var fade_height: float = 80.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var snow_labels: Array[Label] = []
var snow_speeds: Array[float] = []
var snow_bands: Array[int] = []
var snow_alphas: Array[float] = []
var _has_focus: bool = true
var _viewport_size: Vector2 = Vector2.ZERO
var _zone_height: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	call_deferred("_init_snow")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_focus = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_has_focus = true


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _has_focus:
		return
	
	_update_bounds()
	for i in snow_labels.size():
		var label: Label = snow_labels[i]
		var band_bottom: float = _get_band_bottom(snow_bands[i])
		label.position.y += snow_speeds[i] * delta
		
		# Плавное исчезновение у нижней границы зоны
		var fade_start: float = band_bottom - fade_height
		if label.position.y >= fade_start:
			var t: float = (label.position.y - fade_start) / fade_height
			label.modulate.a = snow_alphas[i] * (1.0 - clamp(t, 0.0, 1.0))
		
		if label.position.y > band_bottom:
			_reset_flake(i)


func _update_bounds() -> void:
	_viewport_size = get_viewport_rect().size
	_zone_height = _viewport_size.y / 4.0


func _init_snow() -> void:
	_update_bounds()
	_spawn_all()


func _spawn_all() -> void:
	_clear_flakes()
	var area: float = _viewport_size.x * _viewport_size.y
	var count: int = clampi(int(max_flakes * area / reference_viewport_area), 15, max_flakes)
	for i in count:
		_create_flake()


func _clear_flakes() -> void:
	for label in snow_labels:
		label.queue_free()
	snow_labels.clear()
	snow_speeds.clear()
	snow_bands.clear()
	snow_alphas.clear()


func _create_flake() -> void:
	var label := Label.new()
	label.text = symbols[rng.randi_range(0, symbols.size() - 1)]
	label.add_theme_font_size_override(
		"font_size",
		rng.randi_range(min_font_size, max_font_size)
	)
	var base_alpha: float = rng.randf_range(min_alpha, max_alpha)
	label.add_theme_color_override("font_color", flake_color)
	label.modulate = Color(1, 1, 1, base_alpha)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	
	snow_labels.append(label)
	snow_speeds.append(rng.randf_range(min_speed, max_speed))
	snow_bands.append(0)
	snow_alphas.append(base_alpha)
	_reset_flake(snow_labels.size() - 1)


func _reset_flake(index: int) -> void:
	var band: int = _pick_band()
	var label: Label = snow_labels[index]
	if band < 0:
		label.visible = false
		return
	
	label.visible = true
	label.modulate.a = snow_alphas[index]
	snow_bands[index] = band
	# Градиент X: сильнее к центру (среднее из 3 → уже распределение)
	var u: float = rng.randf()
	var v: float = rng.randf()
	var w: float = rng.randf()
	label.position.x = _viewport_size.x * (u + v + w) / 3.0
	
	label.position.y = rng.randf_range(band * _zone_height, (band + 1) * _zone_height)


func _pick_band() -> int:
	return rng.randi_range(0, 3)


func _get_band_bottom(band: int) -> float:
	return (band + 1) * _zone_height
