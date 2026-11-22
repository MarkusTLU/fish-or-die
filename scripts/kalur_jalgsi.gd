extends Node2D
## Kalur kõnnib doki peal nooltega vasakule ja paremale.

@export var walk_speed := 40.0   # pikslit sekundis
@export var min_x := 2.0         # doki vasak serv
@export var max_x := 160.0       # doki parem ots (hiljem Krakeni juures)

@onready var anim: AnimatedSprite2D = $Anim
var x_pos := 0.0
var can_move := false


func _ready() -> void:
	x_pos = position.x
	anim.play("idle")


# Paneb kaluri kindlasse kohta (nt paadi juurde, kui ta dokile tuleb)
func place_at(x: float) -> void:
	x_pos = clampf(x, min_x, max_x)
	position.x = round(x_pos)
	anim.flip_h = false   # vaatab paadist tulles doki poole (paremale)
	anim.play("idle")


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right") if can_move else 0.0
	if dir != 0.0:
		x_pos = clampf(x_pos + dir * walk_speed * delta, min_x, max_x)
		anim.flip_h = dir < 0.0
		if anim.animation != "walk":
			anim.play("walk")
	elif anim.animation != "idle":
		anim.play("idle")
	# täispikslitel, et pikslikunst ei väriseks
	position.x = round(x_pos)
