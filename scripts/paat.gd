extends Node2D

@export var speed := 40.0
@export var min_depth := 4.0
@export var max_depth := 70.0
@export var bob_height := 0.8
@export var drift_distance := 2.0
@export var rocking_angle := 0.012
@export var max_tilt := 0.12   # kui palju lained paati maksimaalselt kallutavad
const UI_FONT = preload("res://art/ui/m3x6.ttf")

const SURFACE_Y := 10.0            # veepind (106 - 96)
const LINE_X := -5.0               # kus tamiil vette läheb
const HANG_LENGTH := 6.0           # kui pikalt konks otsas ripub
const ROD_VECTOR := Vector2(-24, -16)  # käest õnge otsani
const HULL_LEFT := 4.0     # paadi põhja vasak ots (Paat-i suhtes)
const HULL_RIGHT := 44.0   # paadi põhja parem ots

enum State { IDLE, CASTING, IN_WATER, BITE, MINIGAME }
var state := State.IDLE
var depth := 0.0
var fly_t := 0.0   # 0 = konks õnge otsas, 1 = konks vees
var sailing_time := 0.0
var rest_position := Vector2.ZERO
var rest_rotation := 0.0
var waterline := 0.0   # kui sügavalt paat vees istub
var bite_cooldown := 0.0
var target_fish: Sprite2D

@export var rod: Sprite2D
@export var water: VeePind   # dünaamiline veepind
@onready var line: Line2D = $Tamiil
@onready var bobber: Sprite2D = $Ujuk
@onready var hook: Sprite2D = $Konks
@onready var fish_school = get_node("../FishSchool")
@onready var fishing_minigame = get_node("../UI/FishingMinigame")
@onready var upgrade_store = get_node("../UI/UpgradeStore")

func _ready() -> void:
	rest_position = position
	rest_rotation = rotation
	if water:
		waterline = 10.0   # paadi pildi 10. rida on veepinna kõrgusel
	line.width = 1.0
	line.default_color = Color("9aa7b0")
	fishing_minigame.fish_caught.connect(_on_fish_caught)
	fishing_minigame.fish_escaped.connect(_on_fish_escaped)

# Kus õnge ots praegu on (arvestab pööramist)
func rod_tip() -> Vector2:
	return rod.position + ROD_VECTOR.rotated(rod.rotation)

func _process(delta: float) -> void:
	if bite_cooldown > 0.0:
		bite_cooldown -= delta
	sailing_time += delta
	var drift_x := sin(sailing_time * 0.65) * drift_distance
	if water:
		# Paat õõtsub samas rütmis veepinna rahuliku lainetusega.
		# Konksu tekitatud väikesed lained paati ei liiguta.
		var left_x := rest_position.x + drift_x + HULL_LEFT
		var right_x := rest_position.x + drift_x + HULL_RIGHT
		var left_y: float = water.idle_height_at(left_x)
		var right_y: float = water.idle_height_at(right_x)
		var surface := (left_y + right_y) * 0.5
		position = Vector2(rest_position.x + drift_x, round(surface - waterline))
		var tilt := atan2(right_y - left_y, HULL_RIGHT - HULL_LEFT)
		rotation = clampf(tilt, -max_tilt, max_tilt)
		# Paadi põhi jääb vee alla: vesi joonistatakse paadi kohal ka paadi ette
		water.set_front_range(position.x - 2.0, position.x + 51.0)
	else:
		position = rest_position + Vector2(drift_x, sin(sailing_time * 1.8) * bob_height)
		rotation = rest_rotation + sin(sailing_time * 1.35) * rocking_angle
	if state == State.MINIGAME:
		return

	if Input.is_action_just_pressed("ui_accept"):
		if state == State.IDLE:
			start_cast()
		elif state == State.IN_WATER:
			state = State.IDLE
			if water:
				water.splash(rest_position.x + LINE_X, -0.8)
		elif state == State.BITE and is_instance_valid(target_fish):
			state = State.MINIGAME
			queue_redraw()
			fishing_minigame.start_game(target_fish)

	var tip := rod_tip()
	# Keep the float and submerged hook in the water as the boat rocks.
	var water_position := rest_position + Vector2(LINE_X, SURFACE_Y)
	var bob := to_local(get_parent().to_global(water_position))
	if water:
		# Ujuk kõigub koos lainetega
		var surface_here: float = water.height_at(water_position.x)
		bob = to_local(get_parent().to_global(Vector2(water_position.x, surface_here - 1.0)))

	match state:
		State.IDLE:
			bobber.visible = false
			var hang := tip + Vector2(0, HANG_LENGTH)
			hook.position = hang + Vector2(-2, 0)
			line.points = PackedVector2Array([tip, hang])

		State.CASTING:
			bobber.visible = false
			# Konks lendab kaarega õnge otsast veepinnale
			var start := tip + Vector2(0, HANG_LENGTH)
			var p := start.lerp(bob, fly_t)
			p.y -= sin(fly_t * PI) * 12.0
			hook.position = p + Vector2(-2, 0)
			line.points = PackedVector2Array([tip, p])

		State.IN_WATER, State.BITE:
			if state == State.IN_WATER:
				var dir := Input.get_axis("ui_up", "ui_down")
				depth = clamp(depth + dir * speed * delta, min_depth, max_depth)
			var hook_pos := to_local(get_parent().to_global(water_position + Vector2(0, depth)))
			bobber.visible = true
			bobber.position = bob + Vector2(-1, 2) if state == State.BITE else bob + Vector2(-1, -2)
			hook.position = hook_pos + Vector2(-2, 0)
			line.points = PackedVector2Array([tip, bob, hook_pos])
			if state == State.IN_WATER:
				try_find_fish(hook.position)
			elif state == State.BITE:
				queue_redraw()

func _draw() -> void:
	if state == State.BITE:
		draw_string(UI_FONT, bobber.position + Vector2(-1, -7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2dfb7"))

func try_find_fish(hook_local_position: Vector2) -> void:
	if bite_cooldown > 0.0:
		return
	var fish_position: Vector2 = fish_school.to_local(to_global(hook_local_position))
	target_fish = fish_school.find_fish_near(fish_position)
	if target_fish != null:
		state = State.BITE
		queue_redraw()

func _on_fish_caught() -> void:
	if is_instance_valid(target_fish):
		var reward: int = fish_school.catch_fish(target_fish)
		upgrade_store.add_to_bucket()
		upgrade_store.award_coins(reward)
	target_fish = null
	state = State.IDLE
	rod.rotation = 0.0
	bobber.visible = false
	bite_cooldown = 0.8
	queue_redraw()

func _on_fish_escaped() -> void:
	target_fish = null
	state = State.IN_WATER
	bite_cooldown = 1.5
	queue_redraw()

func start_cast() -> void:
	state = State.CASTING
	fly_t = 0.0
	depth = min_depth
	var tw := create_tween()
	# 1) Õng läheb selja taha
	tw.tween_property(rod, "rotation", 1.4, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2) Kiire vise ette
	tw.tween_property(rod, "rotation", -0.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 3) Konks lendab vette, õng tuleb samal ajal tagasi paigale
	tw.tween_property(self, "fly_t", 1.0, 0.35)
	tw.parallel().tween_property(rod, "rotation", 0.0, 0.25)
	tw.tween_callback(_on_hook_lands)


func _on_hook_lands() -> void:
	state = State.IN_WATER
	if water:
		water.splash(rest_position.x + LINE_X, 1.2)
