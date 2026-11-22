class_name VeePind
extends Node2D
## Dünaamiline veepind.
## Pind koosneb 320 väikesest "vedrust" (üks iga piksli kohta). Kui mõnda
## neist lükata (splash), hakkab see kõikuma ja laine levib naabritele.
## Teised skriptid saavad kasutada:
##   splash(x, jõud)  – loksuta vett kohas x (positiivne = alla, negatiivne = üles)
##   height_at(x)     – kus veepind kohas x praegu on

@export var surface_y := 107.0   # veepind puhkeasendis (y)
@export var fill_to := 112       # kuhu maani see kiht vett joonistab
@export var width := 320         # ekraani laius
@export var stiffness := 0.025   # kui kiiresti pind tagasi sirgeks tõmbub
@export var damping := 0.03      # kui kiiresti lained vaibuvad
@export var spread := 0.2        # kui kaugele lained levivad
@export var idle_wave := 0.7     # rahulik lainetus ka siis, kui keegi ei loksuta
@export var front_alpha := 0.7   # kui läbipaistev on vesi paadi ees (0 = nähtamatu, 1 = täiesti kinni)
## Doki postid: iga posti vasak serv (x). Postid on 4 px laiad.
@export var post_x: Array[int] = [238, 262, 286, 310]
@export var post_ripple_chance := 0.6   # kui tihti postide juures väike virvendus tekib (korda sekundis)
@export var post_ripple_force := 0.25   # kui tugev see virvendus on

const WATER := Color("2a4a63")   # sama värv mis Vesi.png ülemisel ribal
const LIGHT := Color("5b86a3")   # heledam pinnajoon
const POST_UNDER := Color("1b2633")       # doki post vee all
const POST_UNDER_LIT := Color("24323f")   # posti parem (valgustatud) serv vee all

var height := PackedFloat32Array()
var velocity := PackedFloat32Array()
var left_delta := PackedFloat32Array()
var right_delta := PackedFloat32Array()
var time := 0.0
# Ala (x), kus vett joonistatakse ka paadi EES, et paadi põhi oleks vee sees
var front_from := 0.0
var front_to := -1.0
var _front: Node2D


func _ready() -> void:
	height.resize(width)
	velocity.resize(width)
	left_delta.resize(width)
	right_delta.resize(width)
	# Teine joonistuskiht, mis on paadist eespool (z_index 1)
	_front = Node2D.new()
	_front.z_index = 1
	add_child(_front)
	_front.draw.connect(_draw_front)


# Paat ütleb igal kaadril, kus ta asub, et tema põhi jääks vee alla
func set_front_range(from_x: float, to_x: float) -> void:
	front_from = from_x
	front_to = to_x


func splash(x: float, force: float) -> void:
	var center := clampi(int(x), 0, width - 1)
	for offset in range(-2, 3):
		var i := center + offset
		if i >= 0 and i < width:
			velocity[i] += force


func height_at(x: float) -> float:
	var i := clampi(int(x), 0, width - 1)
	return round(surface_y + height[i] + _idle(i))


# Ainult rahulik lainetus, ilma loksutusteta (paat kasutab seda)
func idle_height_at(x: float) -> float:
	var i := clampi(int(x), 0, width - 1)
	return surface_y + _idle(i)


func _idle(i: int) -> float:
	# Kaks aeglast lainet, et pind elaks ka ilma loksutamata
	return (sin(time * 1.3 + i * 0.11) * 0.6 + sin(time * 0.7 - i * 0.05) * 0.4) * idle_wave


func _physics_process(delta: float) -> void:
	time += delta
	# Vesi loksub vahel vastu doki poste
	for px in post_x:
		if randf() < post_ripple_chance * delta:
			splash(px + 2, post_ripple_force * (1.0 if randf() < 0.5 else -1.0))
	# 1) Iga vedru tõmbab tagasi puhkeasendisse
	for i in width:
		velocity[i] += -stiffness * height[i] - damping * velocity[i]
		height[i] += velocity[i]
	# 2) Laine levib naabritele
	for _pass in 4:
		for i in width:
			if i > 0:
				left_delta[i] = spread * (height[i] - height[i - 1])
				velocity[i - 1] += left_delta[i]
			if i < width - 1:
				right_delta[i] = spread * (height[i] - height[i + 1])
				velocity[i + 1] += right_delta[i]
		for i in width:
			if i > 0:
				height[i - 1] += left_delta[i]
			if i < width - 1:
				height[i + 1] += right_delta[i]
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	for i in width:
		var top := mini(roundi(surface_y + height[i] + _idle(i)), fill_to - 1)
		draw_rect(Rect2(i, top, 1, fill_to - top), WATER)
		draw_rect(Rect2(i, top, 1, 1), LIGHT)


func _draw_front() -> void:
	# Doki postid: veepinna all on post vee värvi, pinnajoon jookseb üle posti
	for px in post_x:
		for dx in 4:
			var i := px + dx
			if i < 0 or i >= width:
				continue
			var top := mini(roundi(surface_y + height[i] + _idle(i)), fill_to - 1)
			_front.draw_rect(Rect2(i, top + 1, 1, fill_to - top - 1), POST_UNDER_LIT if dx == 3 else POST_UNDER)
			_front.draw_rect(Rect2(i, top, 1, 1), LIGHT)
	# Paat
	if front_to < front_from:
		return
	var front_water := WATER
	front_water.a = front_alpha
	for i in range(maxi(0, int(front_from)), mini(width, int(front_to) + 1)):
		var top := mini(roundi(surface_y + height[i] + _idle(i)), fill_to - 1)
		_front.draw_rect(Rect2(i, top + 1, 1, fill_to - top - 1), front_water)
		_front.draw_rect(Rect2(i, top, 1, 1), LIGHT)
