extends Node2D

@export var speed := 40.0
@export var min_depth := 4.0
@export var max_depth := 70.0
@export var bob_height := 0.8
@export var drift_distance := 2.0
@export var row_speed := 30.0      # kui kiiresti paat sõuab (pikslit sekundis)
@export var min_x := 8.0           # kui kaugele vasakule paat minna saab
@export var max_x := 186.0         # kui kaugele paremale (enne doki esimest posti)
@export var wake_force := 0.0      # kui palju paat sõites vett loksutab (0 = üldse mitte)
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
var facing_left := true
var boat_x := 0.0   # paadi praegune asukoht (x), muutub sõudes
var rest_rotation := 0.0
var waterline := 0.0   # kui sügavalt paat vees istub
var bite_cooldown := 0.0
var cast_tween: Tween
var target_fish: Sprite2D
var catch_popup: Control

@export var rod: Sprite2D
@export var water: VeePind   # dünaamiline veepind
@onready var water_plop: AudioStreamPlayer = $WaterPlop
@onready var line: Line2D = $Tamiil
@onready var bobber: Sprite2D = $Ujuk
@onready var hook: Sprite2D = $Konks
@onready var fish_school = get_node("../FishSchool")
@onready var fishing_minigame = get_node("../UI/FishingMinigame")
@onready var upgrade_store = get_node("../UI/UpgradeStore")
@onready var day_hud = get_node("../UI/DayHUD")
@onready var dock_prompt: Label = %DockPrompt

func _ready() -> void:
	rest_position = position
	boat_x = position.x
	rest_rotation = rotation
	if water:
		waterline = 10.0   # paadi pildi 10. rida on veepinna kõrgusel
	line.width = 1.0
	line.default_color = Color("9aa7b0")
	fishing_minigame.fish_caught.connect(_on_fish_caught)
	fishing_minigame.fish_escaped.connect(_on_fish_escaped)
	catch_popup = preload("res://scripts/catch_popup.gd").new()
	catch_popup.name = "CatchPopup"
	get_node("../UI").add_child.call_deferred(catch_popup)


# Kas paat on doki juures ja valmis dokile minema?
func is_at_dock() -> bool:
	return day_hud.is_fishing() and state == State.IDLE and boat_x >= max_x - 0.5 and not upgrade_store.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and is_at_dock():
		dock_prompt.visible = false
		day_hud.go_to_dock()
		get_viewport().set_input_as_handled()

# Kus õnge ots praegu on (arvestab pööramist)
func rod_tip() -> Vector2:
	return rod.position + ROD_VECTOR.rotated(rod.rotation)

# Mirror around the hull centre so changing direction keeps the same footprint.
func facing_offset() -> float:
	return 0.0 if facing_left else HULL_LEFT + HULL_RIGHT

func fishing_x() -> float:
	return boat_x + facing_offset() + LINE_X * (1.0 if facing_left else -1.0)

func _process(delta: float) -> void:
	if not day_hud.is_fishing():
		dock_prompt.visible = false
		return
	if bite_cooldown > 0.0:
		bite_cooldown -= delta
	sailing_time += delta
	# Sõudmine nooltega vasakule ja paremale.
	# Ainult siis, kui õng on üleval. Kui konks on vees, tuleb see enne tühikuga välja tõmmata.
	if state == State.IDLE:
		var row_dir := Input.get_axis("ui_left", "ui_right")
		if row_dir != 0.0:
			facing_left = row_dir < 0.0
			scale.x = 1.0 if facing_left else -1.0
			boat_x = clampf(boat_x + row_dir * row_speed * delta, min_x, max_x)
			if water and wake_force > 0.0:
				# Paadi taha tekib väike vool
				var stern_x := boat_x + (HULL_RIGHT + 2.0 if row_dir < 0.0 else HULL_LEFT - 2.0)
				water.splash(stern_x, wake_force)
	dock_prompt.visible = is_at_dock()
	var drift_x := 0.0   # automaatne triivimine on välja lülitatud, paati liigutab mängija
	if water:
		# Paat õõtsub samas rütmis veepinna rahuliku lainetusega.
		# Konksu tekitatud väikesed lained paati ei liiguta.
		var left_x := boat_x + drift_x + HULL_LEFT
		var right_x := boat_x + drift_x + HULL_RIGHT
		var left_y: float = water.idle_height_at(left_x)
		var right_y: float = water.idle_height_at(right_x)
		var surface := (left_y + right_y) * 0.5
		position = Vector2(boat_x + drift_x + facing_offset(), round(surface - waterline))
		var tilt := atan2(right_y - left_y, HULL_RIGHT - HULL_LEFT)
		rotation = clampf(tilt, -max_tilt, max_tilt)
		# Paadi põhi jääb vee alla: vesi joonistatakse paadi kohal ka paadi ette
		water.set_front_range(boat_x + drift_x - 2.0, boat_x + drift_x + 51.0)
	else:
		position = Vector2(boat_x + drift_x + facing_offset(), rest_position.y + sin(sailing_time * 1.8) * bob_height)
		rotation = rest_rotation + sin(sailing_time * 1.35) * rocking_angle
	if state == State.MINIGAME:
		return

	if Input.is_action_just_pressed("ui_accept"):
		if state == State.IDLE:
			start_cast()
		elif state == State.IN_WATER:
			state = State.IDLE
			if water:
				water.splash(fishing_x(), -0.8)
		elif state == State.BITE and is_instance_valid(target_fish):
			state = State.MINIGAME
			queue_redraw()
			fishing_minigame.start_game(target_fish)

	var tip := rod_tip()
	# Keep the float and submerged hook in the water as the boat rocks.
	var water_position := Vector2(fishing_x(), rest_position.y + SURFACE_Y)
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
	if not day_hud.is_fishing():
		return
	if is_instance_valid(target_fish):
		var caught_texture: Texture2D = target_fish.texture
		var reward: int = fish_school.catch_fish(target_fish)
		day_hud.record_catch(reward)
		catch_popup.show_catch(caught_texture, reward)
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
	cast_tween = create_tween()
	var tw := cast_tween
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
	water_plop.pitch_scale = randf_range(0.97, 1.03)
	water_plop.play()
	if water:
		water.splash(fishing_x(), 1.2)


# Cancel pending casts/challenges on every round transition.
func reset_fishing(at_dock: bool = false) -> void:
	if is_instance_valid(catch_popup):
		catch_popup.cancel()
	if cast_tween != null and cast_tween.is_valid():
		cast_tween.kill()
	fishing_minigame.cancel()
	target_fish = null
	state = State.IDLE
	depth = min_depth
	rod.rotation = 0.0
	bobber.visible = false
	bite_cooldown = 0.0
	dock_prompt.visible = false
	if at_dock:
		boat_x = max_x
		facing_left = true
		scale.x = 1.0
		position.x = boat_x
	queue_redraw()
