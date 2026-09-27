class_name Enemy
extends Walker
## 敵。触れると勇者の命を削る。矢や斧で倒せる。

signal died(e: Enemy)

var hp := 1
## 触れたときに削る命。0 なら触れても平気。
var harm := 1
var _knock := Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("shootable")

func _physics_process(delta: float) -> void:
	if stage == null or not active or stage.frozen():
		return
	if _knock.length() > 1.0:
		_try(Vector2(_knock.x * delta, 0))
		_try(Vector2(0, _knock.y * delta))
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		think(delta)
	if harm > 0 and visible and stage.hero != null and touching(stage.hero):
		stage.hurt_hero(harm, global_position)

func hit(dmg: int, from: Vector2) -> void:
	hp -= dmg
	Fx.flash(self)
	Fx.pop(self, 0.4)
	Sfx.play("hit")
	_knock = (global_position - from).normalized() * 220.0
	if hp <= 0:
		die()

func die() -> void:
	Sfx.play("enemy_die")
	Fx.shatter(get_parent(), self)
	Fx.ring(get_parent(), position, color, 100.0, 0.3, 3.0)
	died.emit(self)
	queue_free()
