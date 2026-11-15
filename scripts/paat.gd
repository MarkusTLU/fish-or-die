extends Node2D

@export var speed := 40.0
@export var min_depth := 4.0
@export var max_depth := 70.0
@export var bob_height := 0.8
@export var drift_distance := 2.0
@export var rocking_angle := 0.012

const SURFACE_Y := 10.0            # veepind (106 - 96)
const LINE_X := -5.0               # kus tamiil vette läheb
const HANG_LENGTH := 6.0           # kui pikalt konks otsas ripub
const ROD_VECTOR := Vector2(-24, -16)  # käest õnge otsani

enum State { IDLE, CASTING, IN_WATER }
var state := State.IDLE
var depth := 0.0
var fly_t := 0.0   # 0 = konks õnge otsas, 1 = konks vees
var sailing_time := 0.0
var rest_position := Vector2.ZERO
var rest_rotation := 0.0

@export var rod: Sprite2D
@onready var line: Line2D = $Tamiil
@onready var bobber: Sprite2D = $Ujuk
@onready var hook: Sprite2D = $Konks

func _ready() -> void:
	rest_position = position
	rest_rotation = rotation
	line.width = 1.0
	line.default_color = Color("9aa7b0")

# Kus õnge ots praegu on (arvestab pööramist)
func rod_tip() -> Vector2:
	return rod.position + ROD_VECTOR.rotated(rod.rotation)

func _process(delta: float) -> void:
	sailing_time += delta
	position = rest_position + Vector2(
		sin(sailing_time * 0.65) * drift_distance,
		sin(sailing_time * 1.8) * bob_height
	)
	rotation = rest_rotation + sin(sailing_time * 1.35) * rocking_angle

	if Input.is_action_just_pressed("ui_accept"):
		if state == State.IDLE:
			start_cast()
		elif state == State.IN_WATER:
			state = State.IDLE

	var tip := rod_tip()
	# Keep the float and submerged hook in the water as the boat rocks.
	var water_position := rest_position + Vector2(LINE_X, SURFACE_Y)
	var bob := to_local(get_parent().to_global(water_position))

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

		State.IN_WATER:
			var dir := Input.get_axis("ui_up", "ui_down")
			depth = clamp(depth + dir * speed * delta, min_depth, max_depth)
			var hook_pos := to_local(get_parent().to_global(water_position + Vector2(0, depth)))
			bobber.visible = true
			bobber.position = bob + Vector2(-1, -2)
			hook.position = hook_pos + Vector2(-2, 0)
			line.points = PackedVector2Array([tip, bob, hook_pos])

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
	tw.tween_callback(func(): state = State.IN_WATER)
