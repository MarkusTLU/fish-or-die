extends Node2D

@export_range(3, 40) var fish_count := 18
@export var water_bounds := Rect2(4, 114, 312, 60)

const FISH_TEXTURES: Array[Texture2D] = [
	preload("res://art/kalad/kuldne.png"),
	preload("res://art/kalad/oranz.png"),
	preload("res://art/kalad/sardiin.png"),
]

var school: Array[Dictionary] = []
var elapsed := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	# Include the three fish placed in the scene, then fill out the school.
	for child in get_children():
		if child is Sprite2D:
			add_swimmer(child)
	for index in range(maxi(0, fish_count - school.size())):
		var fish := Sprite2D.new()
		fish.texture = FISH_TEXTURES[index % FISH_TEXTURES.size()]
		fish.centered = false
		fish.position = Vector2(
			rng.randf_range(water_bounds.position.x, water_bounds.end.x - fish.texture.get_width()),
			rng.randf_range(water_bounds.position.y + 3, water_bounds.end.y - fish.texture.get_height() - 3)
		)
		add_child(fish)
		add_swimmer(fish)
	update_swimmers(0.0)


func add_swimmer(fish: Sprite2D) -> void:
	var direction := -1.0 if rng.randf() < 0.5 else 1.0
	school.append({
		"sprite": fish,
		"x": fish.position.x,
		"depth": fish.position.y,
		"speed": rng.randf_range(4.0, 11.0) * direction,
		"phase": rng.randf_range(0.0, TAU),
		"sway_speed": rng.randf_range(0.7, 1.4),
		"fade_speed": rng.randf_range(0.3, 0.65),
	})
	# The source sprites face left.
	fish.flip_h = direction > 0.0


func _process(delta: float) -> void:
	elapsed += delta
	update_swimmers(delta)


func update_swimmers(delta: float) -> void:
	for swimmer in school:
		var fish: Sprite2D = swimmer["sprite"]
		var width := float(fish.texture.get_width())
		var left := water_bounds.position.x
		var right := water_bounds.end.x - width
		var swim_x: float = swimmer["x"] + swimmer["speed"] * delta
		if swim_x < left or swim_x > right:
			swim_x = clampf(swim_x, left, right)
			swimmer["speed"] = -swimmer["speed"]
			fish.flip_h = swimmer["speed"] > 0.0
		swimmer["x"] = swim_x
		fish.position = Vector2(swim_x, swimmer["depth"] + sin(elapsed * swimmer["sway_speed"] + swimmer["phase"]) * 2.0)
		# Independent smooth fades suggest fish moving into deeper water.
		var visibility_wave := (sin(elapsed * swimmer["fade_speed"] + swimmer["phase"]) + 1.0) * 0.5
		var depth_ratio := inverse_lerp(water_bounds.position.y, water_bounds.end.y, swimmer["depth"])
		fish.modulate = Color(0.72, 0.88, 0.95, smoothstep(0.15, 0.85, visibility_wave) * lerpf(0.7, 0.4, depth_ratio))
