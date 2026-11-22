extends Control

signal fish_caught
signal fish_escaped

const FONT = preload("res://art/ui/m3x6.ttf")
const EASY_WORDS: Array[String] = ["BAIT", "NET", "WAVE", "REEL"]
const MEDIUM_WORDS: Array[String] = ["KEEP REELING", "COLD WATER", "HUNGRY KRAKEN"]
const HARD_WORDS: Array[String] = ["THE DEEP REMEMBERS", "KRAKEN IS WATCHING", "NO ONE ESCAPES THE DEEP"]

var active := false
var target_fish: Sprite2D
var target_text := ""
var typed_text := ""
var time_limit := 0.0
var time_remaining := 0.0
var fish_screen_position := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func start_game(fish: Sprite2D) -> void:
	if not is_instance_valid(fish):
		return
	active = true
	target_fish = fish
	typed_text = ""
	var fish_value := 5
	if fish.texture == preload("res://art/kalad/kuldne.png"):
		fish_value = 25
	elif fish.texture == preload("res://art/kalad/oranz.png"):
		fish_value = 10
	var choices: Array[String] = EASY_WORDS
	if fish_value >= 25:
		choices = HARD_WORDS
	elif fish_value >= 10:
		choices = MEDIUM_WORDS
	target_text = choices[randi_range(0, choices.size() - 1)].to_lower()
	time_limit = 2.8 + float(target_text.length()) * 0.34
	time_remaining = time_limit
	visible = true
	update_fish_position()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		finish(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_BACKSPACE:
		if not typed_text.is_empty():
			typed_text = typed_text.substr(0, typed_text.length() - 1)
	elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
		typed_text += String.chr(event.unicode).to_lower()
	if typed_text == target_text:
		finish(true)
	else:
		get_viewport().set_input_as_handled()
		queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(target_fish):
		finish(false)
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	update_fish_position()
	queue_redraw()
	if time_remaining <= 0.0:
		finish(false)

func update_fish_position() -> void:
	if is_instance_valid(target_fish):
		var fish_center := Vector2(target_fish.texture.get_size()) * 0.5
		fish_screen_position = target_fish.global_position + fish_center

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
	var panel_width := 184.0
	var panel_height := 38.0
	var panel_position := Vector2(
		clampf(fish_screen_position.x - panel_width * 0.5, 4.0, size.x - panel_width - 4.0),
		clampf(fish_screen_position.y - 50.0, 4.0, size.y - panel_height - 4.0)
	)
	var panel_rect := Rect2(panel_position, Vector2(panel_width, panel_height))
	draw_rect(panel_rect, Color("172b37"))
	draw_rect(panel_rect, Color("91a9ae"), false, 1.0)
	draw_string(FONT, panel_position + Vector2(6, 12), target_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, int(panel_width - 12), 12, Color("f2dfb7"))

	var bar_rect := Rect2(panel_position + Vector2(6, 16), Vector2(panel_width - 12, 4))
	draw_rect(bar_rect, Color("0c151e"))
	var remaining_width := bar_rect.size.x * (time_remaining / time_limit)
	draw_rect(Rect2(bar_rect.position, Vector2(remaining_width, bar_rect.size.y)), Color("df9860" if time_remaining < time_limit * 0.3 else "79bd68"))

	var typed_color := Color("e3e5df") if target_text.begins_with(typed_text) else Color("e77968")
	var typed_display := "TYPE: " + typed_text.to_upper() + "_"
	draw_string(FONT, panel_position + Vector2(6, 32), typed_display, HORIZONTAL_ALIGNMENT_LEFT, int(panel_width - 12), 10, typed_color)


# Transition cancellation must not emit catch/escape signals.
func cancel() -> void:
	active = false
	visible = false
	target_fish = null
	queue_redraw()
