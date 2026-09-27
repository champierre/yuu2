class_name Fx
## 演出の部品。どれも「親を渡すと、そこに勝手に出て勝手に消える」。

## 飛び散る粒。字でも、点でもよい。
class Bit extends Glyph:
	var vel := Vector2.ZERO
	var gravity := 300.0
	var life := 0.6
	var spin := 0.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		vel.y += gravity * delta
		position += vel * delta
		tilt += spin * delta
		modulate.a = clampf(1.0 - _age / life, 0.0, 1.0)
		if _age >= life:
			queue_free()

## 広がって消える輪。墨がにじむように。
class Ring extends Node2D:
	var color := Color.BLACK
	var radius := 4.0
	var grow := 120.0
	var width := 3.0
	var life := 0.35
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		radius += grow * delta
		queue_redraw()
		if _age >= life:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.0 - _age / life, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, color.a * a), width * a + 0.5, true)

## 粒を散らす。
static func burst(parent: Node, pos: Vector2, col: Color, count := 10, chars := "・", speed := 140.0, size := 12) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	for i in count:
		var b := Bit.new()
		b.text = chars[randi() % chars.length()]
		b.color = col
		b.size = size
		b.shadow = false
		b.position = pos
		var ang := randf() * TAU
		b.vel = Vector2.from_angle(ang) * randf_range(speed * 0.4, speed)
		b.vel.y -= speed * 0.4
		b.spin = randf_range(-8, 8)
		b.life = randf_range(0.4, 0.8)
		b.z_index = 50
		parent.add_child(b)

## 字がばらばらに砕ける（倒した敵など）。
static func shatter(parent: Node, g: Glyph, speed := 160.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	for i in 6:
		var b := Bit.new()
		b.text = g.text.substr(0, 1)
		b.color = g.color
		b.size = int(g.size * 0.55)
		b.position = g.global_position - parent.global_position if parent is Node2D else g.global_position
		b.vel = Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.5, speed)
		b.vel.y -= speed * 0.5
		b.spin = randf_range(-10, 10)
		b.life = 0.7
		b.z_index = 50
		parent.add_child(b)

static func ring(parent: Node, pos: Vector2, col: Color, grow := 120.0, life := 0.35, width := 3.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var r := Ring.new()
	r.position = pos
	r.color = col
	r.grow = grow
	r.life = life
	r.width = width
	r.z_index = 49
	parent.add_child(r)

## 文字がふわっと浮いて消える。
static func float_text(parent: Node, pos: Vector2, t: String, col: Color, size := 14, rise := 26.0, life := 0.9) -> Glyph:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var g := Glyph.make(t, col, size)
	g.position = pos
	g.outline = 4
	g.z_index = 60
	parent.add_child(g)
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_property(g, "position:y", pos.y - rise, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tw.chain().tween_callback(g.queue_free)
	return g

## ぽんと弾む。
static func pop(g: Glyph, amount := 0.35, dur := 0.25) -> void:
	if not is_instance_valid(g):
		return
	var tw := g.create_tween()
	g.squash = Vector2(1.0 + amount, 1.0 - amount * 0.6)
	tw.tween_property(g, "squash", Vector2.ONE, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## 白く光ってすっと戻る。
static func flash(g: Glyph, dur := 0.15) -> void:
	if not is_instance_valid(g):
		return
	g.flash = 1.0
	var tw := g.create_tween()
	tw.tween_property(g, "flash", 0.0, dur)

## 左右に震える（うまくいかないとき）。
static func shake(g: Node2D, amount := 4.0, dur := 0.25) -> void:
	if not is_instance_valid(g):
		return
	var base := g.position
	var tw := g.create_tween()
	var n := 6
	for i in n:
		var k := 1.0 - float(i) / n
		tw.tween_property(g, "position:x", base.x + (amount if i % 2 == 0 else -amount) * k, dur / n)
	tw.tween_property(g, "position:x", base.x, dur / n)
