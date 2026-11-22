extends Node2D
## Dokivaade: kalur kõnnib doki peal.
## Vasakus otsas on paat (tagasi kalastama), keskel pood, paremas otsas hiljem Kraken.
## See vaade on peastseeni (main.tscn) sees, nii et kuld, päev ja kvoot jäävad alles.

signal shop_requested
signal row_out_requested

const UI_FONT = preload("res://art/ui/m3x6.ttf")
const SHOP_LEFT := 40.0     # poe laud (x 40-80)
const SHOP_RIGHT := 80.0
const BOAT_X := 2.0         # doki vasak ots, kus paat ootab

@onready var kalur = $Kalur
@onready var ui_layer: CanvasLayer = $DockUI

var active := false   # kas dokivaade on praegu ekraanil
var paused := false   # pood on lahti -> kalur ei liigu
var prompt: Label


func _ready() -> void:
	prompt = make_label(16, Color("f2dfb7"))
	prompt.position = Vector2(40, 56)
	prompt.size = Vector2(240, 14)
	ui_layer.add_child(prompt)
	leave()


func make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("11151a"))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# Mängija jõuab dokile (paadist välja)
func enter(message: String) -> void:
	active = true
	paused = false
	visible = true
	ui_layer.visible = true
	kalur.place_at(BOAT_X)   # kalur astub paadist dokile


# Mängija sõuab välja järvele
func leave() -> void:
	active = false
	visible = false
	ui_layer.visible = false


func near_shop() -> bool:
	var centre: float = kalur.x_pos + 5.0   # kaluri pilt on 10 px lai
	return centre >= SHOP_LEFT and centre <= SHOP_RIGHT


func at_boat() -> bool:
	return kalur.x_pos <= BOAT_X + 0.5


func _process(_delta: float) -> void:
	if not active:
		return
	kalur.can_move = not paused
	if paused:
		prompt.visible = false
	elif near_shop():
		prompt.text = "Press E to open the shop"
		prompt.visible = true
	elif at_boat():
		prompt.text = "Press E to row out"
		prompt.visible = true
	else:
		prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not active or paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if near_shop():
			get_viewport().set_input_as_handled()
			shop_requested.emit()
		elif at_boat():
			get_viewport().set_input_as_handled()
			row_out_requested.emit()
