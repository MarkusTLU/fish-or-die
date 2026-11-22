extends Control
## Presentation only: rewards and fishing continue independently of this reveal.

const FONT = preload("res://art/ui/m3x6.ttf")
const GOLD_FISH = preload("res://art/kalad/kuldne.png")
const ORANGE_FISH = preload("res://art/kalad/oranz.png")
const PANEL_SIZE := Vector2(120, 28)

var fish_texture: Texture2D
var fish_name := ""
var reward := 0
var accent := Color("a7d8e8")
var reveal := 0.0
var elapsed := 0.0
var departure := 0.0
var animation: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


func show_catch(texture: Texture2D, value: int) -> void:
	cancel()
	fish_texture = texture
	reward = value
	fish_name = "SARDINE"
	accent = Color("a7d8e8")
	if texture == GOLD_FISH:
		fish_name = "GOLDFISH"
		accent = Color("ffd35a")
	elif texture == ORANGE_FISH:
		fish_name = "ORANGEFISH"
		accent = Color("ff9b42")
	reveal = 0.0
	elapsed = 0.0
	departure = 0.0
	modulate.a = 0.0
	visible = true
	set_process(true)
	animation = create_tween()
	animation.tween_property(self, "modulate:a", 1.0, 0.08)
	animation.parallel().tween_property(self, "reveal", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_interval(1.5)
	animation.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	animation.parallel().tween_property(self, "departure", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	animation.tween_callback(cancel)


func cancel() -> void:
	if animation != null and animation.is_valid():
		animation.kill()
	animation = null
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if fish_texture == null:
		return
	# Occupy the open sky between the HUD panels, leaving the lake unobscured.
	var origin := Vector2(roundf(size.x * 0.5), 23.0)
	origin.y -= (1.0 - reveal) * 52.0 + departure * 52.0
	draw_set_transform(origin)
	var panel := Rect2(-PANEL_SIZE * 0.5, PANEL_SIZE)
	var cream := Color("f2dfb7")
	var outline := Color("3c4a53")
	# Match the existing HUD: square frame, opaque dark fill, one-pixel border.
	draw_rect(panel, Color("11171c"))
	draw_rect(panel, outline, false, 1.0)
	var title_position := Vector2(-23, -2)
	var split := maxf(0.0, 1.0 - elapsed / 0.24) * 4.0
	if split > 0.1:
		draw_string(FONT, title_position + Vector2(split, 1), fish_name + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cream)
		draw_string(FONT, title_position - Vector2(split, 1), fish_name + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, outline)
	draw_string(FONT, title_position, fish_name + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cream)
	draw_string(FONT, Vector2(-23, 9), "+%d GOLD" % reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cream)
	# One quick spin-and-pop settles into a small trophy bob.
	var fish_center := origin + Vector2(-42, sin(elapsed * 4.0) * 1.0)
	draw_set_transform(fish_center, (1.0 - reveal) * -0.5)
	var fish_scale := 1.5 * maxf(0.01, reveal)
	var fish_size := Vector2(fish_texture.get_size()) * fish_scale
	draw_texture_rect(fish_texture, Rect2(-fish_size * 0.5, fish_size), false)
