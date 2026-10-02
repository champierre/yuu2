class_name Hero
extends Glyph
## 勇者「勇」。なめらかに 8 方向へ歩き、両手に字を 1 つずつ持てる。

const MAX_SPEED := 118.0
const ACCEL := 1100.0
const FRICTION := 1400.0
## 角に引っかかったとき、これだけまでなら横へ滑らせて通す。
const CORNER_SLIDE := 7.0
const HAND_SIZE := 13

var stage: Node = null
var vel := Vector2.ZERO
var facing := Vector2.DOWN
var can_move := true
var speed_scale := 1.0

## 両手の字。最大 2 つ。新しく持ったものが後ろ。
var hands: Array[String] = []
var _hand_glyphs: Array[Glyph] = []

var max_hp := 3
var hp := 3
var invuln := 0.0

var _bob := 0.0
var _dust := 0.0
var _hurt_flash := 0.0

func _ready() -> void:
	text = "勇"
	color = Color("#1a1a1a")
	size = 22
	hit_size = Vector2(15, 17)
	hit_offset = Vector2(0, 1)
	z_index = 0
	for i in 2:
		var g := Glyph.make("", Color("#3a3a3a"), HAND_SIZE)
		g.outline = 3
		g.z_index = 1
		add_child(g)
		_hand_glyphs.append(g)
	_refresh_hands()

func _process(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
		visible = true
		modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
		if invuln <= 0.0:
			modulate.a = 1.0
	_bob += delta
	_place_hands()

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("left", "right", "up", "down")
	if input.length() > 0.2:
		facing = _snap8(input)
		vel = vel.move_toward(input.normalized() * MAX_SPEED * speed_scale, ACCEL * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, FRICTION * delta)
	if vel == Vector2.ZERO:
		squash = squash.lerp(Vector2.ONE, 0.3)
		return
	_move_axis(Vector2(vel.x * delta, 0))
	_move_axis(Vector2(0, vel.y * delta))
	## 足元に小さな土ぼこり。
	_dust -= delta
	if _dust <= 0.0 and vel.length() > MAX_SPEED * 0.6:
		_dust = 0.16
		Fx.burst(get_parent(), position + Vector2(0, 9), Color(0.5, 0.42, 0.33, 0.5), 1, "・", 25.0, 8)
	## 歩いている間、少しだけ弾ませる。
	var k := sin(_bob * 18.0) * 0.06 * clampf(vel.length() / MAX_SPEED, 0, 1)
	squash = Vector2(1.0 - k, 1.0 + k)
	queue_redraw()

## 8 方向に丸める（斜めは 45 度）。
static func _snap8(v: Vector2) -> Vector2:
	var ang := snappedf(v.angle(), PI / 4.0)
	return Vector2.from_angle(ang).snapped(Vector2(0.001, 0.001))

func _blocked() -> bool:
	return stage != null and stage.blocked(rect())

## 1 つの軸だけ動かす。ぶつかったら戻し、角ならわきへ滑らせる。
func _move_axis(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	position += d
	if not _blocked():
		return
	position -= d
	## 少しずつ詰めて、壁ぎわまで寄せる。
	var step := d.normalized()
	var remain := d.length()
	while remain > 0.0:
		var s := minf(1.0, remain)
		position += step * s
		if _blocked():
			position -= step * s
			break
		remain -= s
	## 角の手前なら、横へずらして抜けられないか試す。
	## 斜めに押しているときは、もう片方の軸が勝手に滑るので要らない。
	var side := Vector2(absf(step.y), absf(step.x))
	if absf(vel.dot(side)) > 10.0:
		return
	for dist in range(1, int(CORNER_SLIDE) + 1):
		for sgn in [1.0, -1.0]:
			var off: Vector2 = side * dist * sgn
			if not _free_at(off + step):
				continue
			## 一度に全部ずらさず、1px ずつ寄せる。
			if _free_at(side * sgn):
				position += side * sgn
			return

## いまの場所から off だけずらした所が空いているか。
func _free_at(off: Vector2) -> bool:
	position += off
	var ok := not _blocked()
	position -= off
	return ok

func _draw() -> void:
	super._draw()
	## 向いている方に小さな三角を出す（矢や斧の向きが分かるように）。
	var tip := facing * 16.0
	var side := facing.orthogonal() * 3.5
	var base := facing * 11.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.1, 0.1, 0.1, 0.55))

# ---------------------------------------------------------------- 手

func holding(k: String) -> bool:
	return hands.has(k)

func hands_full() -> bool:
	return hands.size() >= 2

## 字を持つ。両手がふさがっていたら持たずに false を返す。
## 黙って古い方を手放すと、大事な字を落としても気づけない（#4）。
## どれを置くかは Stage.give() が遊ぶ人に聞く。
func give(k: String) -> bool:
	if hands_full():
		return false
	hands.append(k)
	_refresh_hands()
	return true

func take(k: String) -> bool:
	var i := hands.find(k)
	if i < 0:
		return false
	hands.remove_at(i)
	_refresh_hands()
	return true

func set_hands(list: Array) -> void:
	hands.clear()
	for k in list:
		hands.append(k)
	_refresh_hands()

func _refresh_hands() -> void:
	for i in _hand_glyphs.size():
		var g := _hand_glyphs[i]
		g.text = hands[i] if i < hands.size() else ""
		g.color = _hand_color(g.text)
	_place_hands()

func _hand_color(k: String) -> Color:
	match k:
		"金": return Color("#c9a227")
		"火", "炎", "灯": return Color("#e0561b")
		"明", "日", "星": return Color("#d9a400")
		"月": return Color("#5a6fb0")
		"木", "林", "森": return Color("#3f8a3a")
		"鉄", "斧", "斤": return Color("#6b7680")
		"失": return Color("#7a4d8c")
	return Color("#3a3a3a")

func _place_hands() -> void:
	## 持っている字は、勇者の左右の肩のあたりに浮かせる。
	var n := hands.size()
	for i in _hand_glyphs.size():
		var g := _hand_glyphs[i]
		if i >= n:
			continue
		var x := -15.0 if (n == 2 and i == 0) else 15.0
		if n == 1:
			x = 15.0
		g.position = Vector2(x, -12.0 + sin(_bob * 3.0 + i * 1.7) * 1.5)

func hand_glyph(k: String) -> Glyph:
	var i := hands.find(k)
	return _hand_glyphs[i] if i >= 0 else null

# ---------------------------------------------------------------- 命

func damage(n: int, from: Vector2) -> bool:
	if invuln > 0.0 or hp <= 0:
		return false
	hp = maxi(0, hp - n)
	invuln = 1.3
	var away := (global_position - from).normalized()
	if away == Vector2.ZERO:
		away = -facing
	vel = away * 260.0
	Fx.flash(self)
	return true

func heal_full() -> void:
	hp = max_hp
