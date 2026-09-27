class_name Walker
extends Glyph
## 歩き回るもの。村人・盗人・敵の土台。
##
## 地形にはぶつかって止まる。決めた範囲（area）の外へは出ない。

var stage: Node = null
var speed := 40.0
## うろつく範囲。空なら地図のどこでも。
var area := Rect2()
var active := true

var _target := Vector2.INF
var _pause := 0.0

func _physics_process(delta: float) -> void:
	if stage == null or not active or stage.frozen():
		return
	think(delta)

## 毎コマの動き。継承して書き換える。
func think(delta: float) -> void:
	wander(delta)

func wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	if _target == Vector2.INF or position.distance_to(_target) < 3.0:
		_pick_target()
		_pause = randf_range(0.2, 1.2)
		return
	if not move_toward_point(_target, speed, delta):
		_target = Vector2.INF

func _pick_target() -> void:
	var r := area if area.has_area() else Rect2(Vector2.ZERO, Vector2(stage.cols, stage.rows) * stage.CELL)
	for i in 8:
		var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
		if p.distance_to(position) > 20.0:
			_target = p
			return

## p へ向かって 1 コマぶん進む。どちらの軸にも進めなければ false。
func move_toward_point(p: Vector2, sp: float, delta: float) -> bool:
	var d := p - position
	if d.length() < 1.0:
		return true
	var step := d.normalized() * minf(sp * delta, d.length())
	var a := _try(Vector2(step.x, 0))
	var b := _try(Vector2(0, step.y))
	return a or b

func _try(v: Vector2) -> bool:
	if v.length() < 0.001:
		return false
	position += v
	if stage.blocked(rect(), self) or (area.has_area() and not area.has_point(position)):
		position -= v
		return false
	return true
