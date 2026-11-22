extends Control
## Owns the run. Catch value stays separate from spendable gold until sold.

enum Phase { DOCK, FISHING, GAME_OVER }

const FONT = preload("res://art/ui/m3x6.ttf")
@export_range(15.0, 600.0, 5.0) var day_length_seconds := 120.0
@export var starting_quota := 50
@export var quota_multiplier := 1.5
@export var extra_seconds_per_round := 5.0

@onready var shop = get_node("../UpgradeStore")
@onready var fishing_minigame = get_node("../FishingMinigame")
@onready var boat = get_node("../../Paat")
@onready var fish_school = get_node("../../FishSchool")

var phase := Phase.DOCK
var day_number := 1
var rounds_survived := 0
var quota := 0
var catch_value := 0
var bucket_count := 0
var total_gold_earned := 0
var time_remaining := 0.0
@onready var day_label: Label = %RoundLabel
@onready var timer_label: Label = %TimerLabel
@onready var quota_label: Label = %CatchProgress
@onready var message_label: Label = %KrakenMessage
@onready var catch_text_color: Color = quota_label.get_theme_color("font_color")
@export var quota_met_color := Color("79bd68")
var message_time := 0.0

func _ready() -> void:
	quota = starting_quota
	time_remaining = round_duration()
	update_hud()
	# Sibling shop/boat references are initialized after this node's _ready.
	open_initial_dock.call_deferred()

func open_initial_dock() -> void:
	boat.reset_fishing(true)
	shop.open_dock("Catch at least %d gold of fish. Return before the deep claims you." % quota)

func round_duration() -> float:
	return day_length_seconds + (day_number - 1) * extra_seconds_per_round

func is_fishing() -> bool:
	return phase == Phase.FISHING

func start_round() -> void:
	if phase != Phase.DOCK:
		return
	catch_value = 0
	bucket_count = 0
	time_remaining = round_duration()
	message_time = 0.0
	message_label.text = ""
	fish_school.replenish()
	boat.reset_fishing(true)
	shop.close_dock()
	phase = Phase.FISHING
	update_hud()

func _process(delta: float) -> void:
	if not is_fishing():
		return
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""
	time_remaining = maxf(0.0, time_remaining - delta)
	update_hud()
	if time_remaining <= 0.0:
		if catch_value >= quota:
			complete_round()
		else:
			end_run()

func record_catch(value: int) -> void:
	if not is_fishing():
		return
	bucket_count += 1
	catch_value += value
	update_hud()
	if catch_value >= quota:
		show_message("QUOTA MET - RETURN TO THE DOCK")

func go_to_dock() -> void:
	if not is_fishing():
		return
	if catch_value < quota:
		show_message("KRAKEN: Not enough fish! %d / %d GOLD" % [catch_value, quota])
		boat.boat_x = boat.max_x - 14.0
		return
	complete_round()

func complete_round() -> void:
	if not is_fishing():
		return
	phase = Phase.DOCK
	boat.reset_fishing(true)
	var sold_value := catch_value
	var sold_count := bucket_count
	shop.award_coins(sold_value)
	total_gold_earned += sold_value
	rounds_survived += 1
	day_number += 1
	quota = ceili(quota * quota_multiplier)
	catch_value = 0
	bucket_count = 0
	time_remaining = round_duration()
	message_label.text = ""
	update_hud()
	shop.open_dock("Sold %d fish for %d gold. Next quota: %d gold." % [sold_count, sold_value, quota])

func end_run() -> void:
	if not is_fishing():
		return
	phase = Phase.GAME_OVER
	boat.reset_fishing()
	boat.set_process(false)
	shop.close_dock()
	message_label.text = ""
	# Sink the existing boat before fading to the results screen.
	var sink := create_tween()
	sink.tween_property(boat, "position:y", boat.position.y + 35.0, 1.0)
	sink.parallel().tween_property(boat, "rotation", 0.45, 1.0)
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(overlay)
	sink.tween_property(overlay, "modulate:a", 1.0, 0.5)
	var content := VBoxContainer.new()
	content.position = Vector2(30, 24)
	content.size = Vector2(260, 132)
	content.add_theme_constant_override("separation", 6)
	overlay.add_child(content)
	for text_value in ["GAME OVER", "The Kraken claimed your boat.", "Catch: %d / %d gold" % [catch_value, quota], "Rounds survived: %d" % rounds_survived, "Gold: %d   Total earned: %d" % [shop.coins, total_gold_earned]]:
		var label := Label.new()
		label.text = text_value
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 14)
		content.add_child(label)
	var retry := Button.new()
	retry.text = "TRY AGAIN"
	retry.add_theme_font_override("font", FONT)
	retry.add_theme_font_size_override("font_size", 14)
	retry.pressed.connect(restart_run)
	content.add_child(retry)
	retry.grab_focus()

func restart_run() -> void:
	get_tree().reload_current_scene()

func show_message(value: String) -> void:
	message_label.text = value
	message_time = 3.0

func update_hud() -> void:
	day_label.text = "ROUND %d" % day_number
	var seconds := ceili(time_remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	quota_label.text = "CATCH %d / %d GOLD" % [catch_value, quota]
	quota_label.add_theme_color_override("font_color", quota_met_color if catch_value >= quota else catch_text_color)
