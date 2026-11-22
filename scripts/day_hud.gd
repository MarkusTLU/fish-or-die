extends Control

const FONT = preload("res://art/ui/m3x6.ttf")

@export_range(15.0, 600.0, 15.0) var day_length_seconds := 120.0

@onready var shop = get_node("../UpgradeStore")
@onready var fishing_minigame = get_node("../FishingMinigame")

var day_number := 1
var time_remaining := 0.0
var waiting_for_shop := false
var bucket_label: Label
var day_label: Label
var timer_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_remaining = day_length_seconds
	bucket_label = make_label("BUCKET 0", Vector2(60, 4), Vector2(82, 18))
	timer_label = make_label("02:00", Vector2(210, 4), Vector2(44, 18))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_label = make_label("DAY 1", Vector2(260, 4), Vector2(50, 18))
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(bucket_label)
	add_child(day_label)
	add_child(timer_label)
	shop.shop_closed.connect(_on_shop_closed)
	update_hud()

func _process(delta: float) -> void:
	if waiting_for_shop or shop.visible or fishing_minigame.visible:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	update_hud()
	if time_remaining <= 0.0:
		waiting_for_shop = true
		timer_label.text = "00:00"
		shop.open_for_end_of_day()

func make_label(value: String, label_position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.text = value
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("f2dfb7"))
	return label

func update_hud() -> void:
	day_label.text = "DAY %d" % day_number
	var total_seconds := ceili(time_remaining)
	var minutes := floori(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func set_bucket_count(count: int) -> void:
	bucket_label.text = "BUCKET %d" % count

func _on_shop_closed(ended_day: bool) -> void:
	if not ended_day:
		return
	day_number += 1
	time_remaining = day_length_seconds
	waiting_for_shop = false
	update_hud()


# Mängija sõitis doki juurde ja vajutas E: päev lõpeb ja avaneb Krakeni pood
func go_to_dock() -> void:
	if waiting_for_shop:
		return
	waiting_for_shop = true
	shop.open_for_end_of_day()
