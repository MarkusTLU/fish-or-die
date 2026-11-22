extends Control

signal fish_caught
signal fish_escaped

const FONT = preload("res://art/ui/m3x6.ttf")
const METER := Rect2(145, 48, 30, 94)
const HITS_TO_CATCH := 3
const MISSES_ALLOWED := 3

var active := false
var marker_position := 0.15
var marker_direction := 1.0
var marker_speed := 0.78
var target_position := 0.55
var target_half_height := 0.12
var hits := 0
var misses := 0
var prompt := "TAP SPACE WHEN SQUARE HITS GREEN"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func start_game(fish_value: int) -> void:
	active = true
	marker_position = 0.15
	marker_direction = 1.0
	var rarity := inverse_lerp(5.0, 25.0, float(fish_value))
	marker_speed = lerpf(0.62, 1.15, rarity)
	target_half_height = lerpf(0.16, 0.055, rarity)
	target_position = randf_range(0.2, 0.8)
	hits = 0
	misses = 0
	prompt = "TAP SPACE WHEN SQUARE HITS GREEN"
	visible = true
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		try_timing_hit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finish(false)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	marker_position += marker_direction * marker_speed * delta
	if marker_position < 0.06 or marker_position > 0.94:
		marker_position = clampf(marker_position, 0.06, 0.94)
		marker_direction *= -1.0
	queue_redraw()

func try_timing_hit() -> void:
	if absf(marker_position - target_position) <= target_half_height:
		hits += 1
		if hits >= HITS_TO_CATCH:
			finish(true)
			return
		prompt = "NICE HIT! NEXT WINDOW"
		marker_speed = minf(marker_speed * 1.12, 1.25)
	else:
		misses += 1
		if misses >= MISSES_ALLOWED:
			finish(false)
			return
		prompt = "MISSED! %d CHANCES LEFT" % (MISSES_ALLOWED - misses)
	queue_redraw()

func finish(caught: bool) -> void:
	active = false
	visible = false
	if caught:
		fish_caught.emit()
	else:
		fish_escaped.emit()

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.055, 0.84))
	draw_rect(Rect2(72, 22, 176, 140), Color("172b37"))
	draw_rect(Rect2(72, 22, 176, 140), Color("91a9ae"), false, 1.0)
	draw_string(FONT, Vector2(104, 39), "LAND THE FISH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2dfb7"))

	# Time a Space press to stop the moving square inside the green target.
	draw_rect(METER, Color("0c151e"))
	draw_rect(METER, Color("94a8a7"), false, 1.0)
	var target_y := METER.position.y + target_position * METER.size.y
	var target_rect := Rect2(
		METER.position.x + 2,
		target_y - target_half_height * METER.size.y,
		METER.size.x - 4,
		target_half_height * 2.0 * METER.size.y
	)
	draw_rect(target_rect, Color("5c9b54"))
	draw_rect(target_rect, Color("b4dc82"), false, 1.0)

	var marker_y := METER.position.y + marker_position * METER.size.y
	var marker_rect := Rect2(METER.position.x + 7, marker_y - 4, 16, 8)
	draw_rect(marker_rect, Color("f2dfb7"))
	draw_rect(marker_rect, Color("ffffff"), false, 1.0)

	var count_text := "HITS  %d/%d      MISSES  %d/%d" % [hits, HITS_TO_CATCH, misses, MISSES_ALLOWED]
	draw_string(FONT, Vector2(105, 153), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d6e0d8"))
	draw_string(FONT, Vector2(80, 176), prompt, HORIZONTAL_ALIGNMENT_LEFT, 160, 9, Color("e7c77c"))
