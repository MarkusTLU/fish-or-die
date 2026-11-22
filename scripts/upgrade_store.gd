extends Control

const FONT = preload("res://art/ui/m3x6.ttf")
const COIN_ICON = preload("res://art/ui/ikoon_kuld.png")
const STARTING_COINS := 37

@onready var coins_hud: Label = %GoldLabel
@onready var boat: Node2D = get_node("../../Paat")
@onready var day_hud = get_node("../DayHUD")

var coins := STARTING_COINS
var shop_panel: Control
var coins_label: Label
var dialogue_label: Label
var round_label: Label
var depart_button: Button
var card_buttons: Dictionary = {}
var levels := {
	"Deep Line": 0,
	"Quick Reel": 0,
	"Steady Hull": 0,
	"Fish Finder": 0,
	"Golden Bait": 0,
	"Salvage Hook": 0,
}

const ITEMS := [
	{"name": "Deep Line", "description": "Reach deeper water", "price": 20, "tint": Color("31556a")},
	{"name": "Quick Reel", "description": "Move your hook faster", "price": 15, "tint": Color("42634d")},
	{"name": "Steady Hull", "description": "Keep the boat steady", "price": 30, "tint": Color("66543f")},
	{"name": "Fish Finder", "description": "Spot more fish", "price": 25, "tint": Color("354b70")},
	{"name": "Golden Bait", "description": "A tempting little lure", "price": 20, "tint": Color("756238")},
	{"name": "Salvage Hook", "description": "Bring up better finds", "price": 35, "tint": Color("644852")},
]

func _ready() -> void:
	coins_hud.text = str(coins)
	shop_panel = self
	build_shop()
	shop_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		day_hud.start_round()
		get_viewport().set_input_as_handled()

func open_dock(message: String) -> void:
	dialogue_label.text = message
	round_label.text = "ROUND %d: %d GOLD / %ds" % [day_hud.day_number, day_hud.quota, int(day_hud.round_duration())]
	depart_button.text = "ROW OUT [U]"
	visible = true
	depart_button.grab_focus()

func close_dock() -> void:
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func build_shop() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Opaque deep-water backdrop makes this read as a separate end-of-day screen.
	var backdrop := ColorRect.new()
	backdrop.color = Color("101d2b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var top_rule := ColorRect.new()
	top_rule.position = Vector2(8, 24)
	top_rule.size = Vector2(304, 1)
	top_rule.color = Color("557487")
	backdrop.add_child(top_rule)

	var title := make_label("DOCK SHOP", 20, Color("f2dfb7"))
	title.position = Vector2(10, 3)
	title.size = Vector2(100, 20)
	add_child(title)

	var coin_box := PanelContainer.new()
	coin_box.position = Vector2(222, 4)
	coin_box.size = Vector2(90, 18)
	coin_box.add_theme_stylebox_override("panel", panel_style(Color("203444"), Color("8ca6ad"), 1, 2))
	add_child(coin_box)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_END
	coin_row.add_theme_constant_override("separation", 3)
	coin_box.add_child(coin_row)
	var coin_icon := TextureRect.new()
	coin_icon.texture = COIN_ICON
	coin_icon.custom_minimum_size = Vector2(9, 9)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_row.add_child(coin_icon)
	coins_label = make_label(str(coins), 14, Color("f2dfb7"))
	coins_label.custom_minimum_size = Vector2(24, 12)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_row.add_child(coins_label)

	round_label = make_label("", 12, Color("e7c77c"))
	round_label.position = Vector2(10, 27)
	round_label.size = Vector2(200, 14)
	add_child(round_label)
	depart_button = Button.new()
	depart_button.position = Vector2(218, 26)
	depart_button.size = Vector2(92, 15)
	depart_button.add_theme_font_override("font", FONT)
	depart_button.add_theme_font_size_override("font_size", 12)
	depart_button.add_theme_stylebox_override("normal", panel_style(Color("263f4d"), Color("aec0b5"), 1, 1))
	depart_button.add_theme_stylebox_override("hover", panel_style(Color("355565"), Color("e7c77c"), 1, 1))
	depart_button.add_theme_stylebox_override("pressed", panel_style(Color("172b37"), Color("e7c77c"), 1, 1))
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("e7c77c")
	focus_style.set_border_width_all(1)
	depart_button.add_theme_stylebox_override("focus", focus_style)
	depart_button.pressed.connect(day_hud.start_round)
	add_child(depart_button)

	for index in range(ITEMS.size()):
		var item: Dictionary = ITEMS[index]
		var card := make_card(item)
		card.position = Vector2(10 + (index % 3) * 100, 43 + floori(float(index) / 3.0) * 43)
		add_child(card)

	var dialogue_box := PanelContainer.new()
	dialogue_box.position = Vector2(8, 131)
	dialogue_box.size = Vector2(304, 41)
	dialogue_box.add_theme_stylebox_override("panel", panel_style(Color("1b2b37"), Color("91a9ae"), 1, 4))
	add_child(dialogue_box)
	var dialogue_content := Control.new()
	dialogue_box.add_child(dialogue_content)
	var speaker := make_label("KRAKEN", 12, Color("e7c77c"))
	speaker.position = Vector2(4, 0)
	speaker.size = Vector2(50, 12)
	dialogue_content.add_child(speaker)
	dialogue_label = make_label("Oh, you survived another day. Better gear might keep you alive tomorrow.", 12, Color("e3e5df"))
	dialogue_label.position = Vector2(4, 11)
	dialogue_label.size = Vector2(285, 25)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_content.add_child(dialogue_label)

func make_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size = Vector2(94, 41)
	card.add_theme_stylebox_override("panel", panel_style(item["tint"], Color("9eb1ad"), 1, 3))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	card.add_child(content)
	var title := make_label(item["name"], 13, Color("fff0ce"))
	title.size = Vector2(82, 11)
	content.add_child(title)
	var description := make_label(item["description"], 10, Color("d0d9d2"))
	description.size = Vector2(82, 10)
	content.add_child(description)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 2)
	content.add_child(footer)
	var price := make_label("%d C" % item["price"], 11, Color("f2dfb7"))
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(price)
	var buy_button := Button.new()
	buy_button.text = "BUY"
	buy_button.custom_minimum_size = Vector2(27, 14)
	buy_button.add_theme_font_override("font", FONT)
	buy_button.add_theme_font_size_override("font_size", 10)
	buy_button.add_theme_color_override("font_color", Color("fff0ce"))
	buy_button.add_theme_stylebox_override("normal", panel_style(Color("263f4d"), Color("aec0b5"), 1, 1))
	buy_button.pressed.connect(purchase.bind(item))
	footer.add_child(buy_button)
	card_buttons[item["name"]] = buy_button
	return card

func make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func panel_style(fill: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_content_margin_all(margin)
	return style

func purchase(item: Dictionary) -> void:
	if not visible or day_hud.phase != day_hud.Phase.DOCK:
		return
	var item_name: String = item["name"]
	var price: int = item["price"]
	if int(levels[item_name]) > 0:
		dialogue_label.text = "You already bought that one, chum."
		return
	if coins < price:
		dialogue_label.text = "Not enough coins, chum. Bring me a better haul tomorrow."
		return
	coins -= price
	levels[item_name] += 1
	coins_label.text = str(coins)
	coins_hud.text = str(coins)
	apply_upgrade(item_name)
	dialogue_label.text = "A fine choice. Let's see if it helps you survive tomorrow."
	var button: Button = card_buttons[item_name]
	button.text = "OWNED"
	button.disabled = true

func award_coins(amount: int) -> void:
	coins += amount
	coins_hud.text = str(coins)
	if is_instance_valid(coins_label):
		coins_label.text = str(coins)

func apply_upgrade(item_name: String) -> void:
	match item_name:
		"Deep Line":
			boat.max_depth += 10.0
		"Quick Reel":
			boat.speed += 12.0
		"Steady Hull":
			boat.drift_distance = maxf(0.0, boat.drift_distance - 0.5)
