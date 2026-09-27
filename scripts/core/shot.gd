class_name Shot
extends Glyph
## 飛んでいくもの。勇者の矢・火矢・炎、敵の毒・闇の弾。
##
## 当たり判定は Glyph の rect() なので、見た目を向きに合わせて傾けてもずれない。

var stage: Node = null
var dir := Vector2.UP
var speed := 300.0
## 飛べる距離。これを過ぎると力尽きて落ちる。
var reach := 400.0
## 0〜1。どれだけ引き絞ったか。
var power := 1.0
## 火がついているか（燭に火を移せる、闇を焼ける）。
var fire := false
## 敵が撃ったものか。true なら勇者に当たる。
var hostile := false
var damage := 1
## 地形（山や壁）に当たって止まるか。
var hits_walls := true
## 傾けて向きを見せるか（矢は傾ける、丸い弾は傾けない）。
var orient := true

var _traveled := 0.0
var _dead := false

func _ready() -> void:
	shadow = false
	z_index = 20
	if orient:
		tilt = dir.angle() + PI / 2.0
	hit_size = Vector2(8, 8)

func _physics_process(delta: float) -> void:
	if _dead or stage == null:
		return
	if stage.frozen():
		return
	if fire and randf() < 0.5:
		Fx.burst(get_parent(), position - dir * 6.0, Color("#ff8a2a"), 1, "・", 30.0, 9)
	## 1 コマで進む分を細かく刻む。一気に進めると、的や壁を飛び越えてしまう。
	var total := speed * delta
	var steps := maxi(1, ceili(total / 3.0))
	for i in steps:
		var step := dir * (total / steps)
		position += step
		_traveled += step.length()
		## 的を先に見る。燭のように「壁と同じマス」にある的もあるので、
		## 壁を先に見ると、的に届く前に消えてしまう。
		if _hit_targets():
			return
		if hits_walls and stage.shot_blocked(global_position):
			stage.on_shot_wall(self)
			die(true)
			return
		if _traveled >= reach:
			stage.on_shot_spent(self)
			die(true)
			return

## 何かに当たって消えたら true。
func _hit_targets() -> bool:
	if hostile:
		if stage.hero != null and rect().intersects(stage.hero.rect()):
			if stage.hurt_hero(damage, global_position):
				die(false)
				return true
		return false
	for t in stage.get_tree().get_nodes_in_group("shootable"):
		if t is Glyph and t.is_visible_in_tree() and rect().grow(3.0).intersects(t.rect()):
			if stage.on_shot_hit(self, t):
				die(false)
				return true
	return false

## 消える。drop なら力尽きて落ちる様子を見せる。
func die(drop: bool) -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	if not drop:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 6.0, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)

func is_dead() -> bool:
	return _dead
