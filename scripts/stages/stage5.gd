extends Stage
## 其の五「森」。見張りの目をかいくぐって、城の奥へ忍び込む。
##
## 【解き方】見張りの「目」に見つかると、入口へ戻される。
## 「茂」の中にいる間は見つからない。木を隠すなら森の中。
## 庭の「苗」から木を取り、木＋木＝林、林＋木＝森。
## 林は 1 マス、森は 3 マス、向いている方へまっすぐ植わり、茂みと同じく身を隠せる。
## 見張りの前の、茂みの切れ目（4 マス）を森と林で埋めて、隠れたまま通り抜ける。
##
## 【隠し】「鳥」と「口」。鳥＋口＝鳴。放つと鳥が飛んでいって鳴き、
## 見張りがしばらくそちらを向く。その隙に通ってもよい。

const MAP := [
	"壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁",
	"壁・・・壁・・・・・・壁見壁・・・・・・壁苗苗・・壁",
	"壁・標・壁・・・・・・・・・・・・・・・壁・庭・・壁",
	"壁・・・壁・・・・・・・・・・・・・・・壁・・・・壁",
	"壁・・・・茂茂茂茂茂茂・・・・茂茂茂・・・・・・・壁",
	"壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁・壁",
	"壁鳥・・・・・・・・・・・・・・・・・・・・・・・壁",
	"壁・・・・・・・・・・・・・・・・・・・・・・・・壁",
	"壁・・・・・・・・・・・・・・・・・・・・・・・・壁",
	"壁・・巡・・・・・・・・・・・・・・・・・・・・・壁",
	"壁垣垣垣垣垣垣垣垣・・垣垣垣垣垣・・垣垣垣垣・・・壁",
	"壁・・・・・・・・・・・・・・・・・・・・・・・・壁",
	"壁・勇札・・・・・茂茂・・・・・茂茂・・・・・・・壁",
	"壁口・・・・・・・・・・・・・・・・・・・・・・・壁",
	"壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁壁",
]

const COL_CASTLE := Color("#7a6a5a")
const COL_HEDGE := Color("#4a7a3a")
const COL_BUSH := Color("#6aa04a")
const COL_BED := Color("#8a6a3a")
const COL_EYE := Color("#a02828")
const COL_GARDENER := Color("#3a6a4a")

## 見張りの目の届く距離と、見える角度（片側）。
const SIGHT := 150.0
const SIGHT_HALF := deg_to_rad(42.0)
## 見られ続けてから見つかるまでの秒数。一瞬かすめただけでは見つからない。
const NOTICE_TIME := 0.35
## 見張りの巡る速さ。
const PATROL_SPEED := 42.0
## 鳴き声で気をそらせる長さ（秒）。
const DISTRACT_TIME := 5.0

var _cover := {}          ## Vector2i -> Glyph（身を隠せるマス）
var _guards: Array[Guard] = []
var _start := Vector2.ZERO
var _hidden := false
var _caught := false

func number() -> int:
	return 5

func subtitle() -> String:
	return "見張りの目を、かいくぐれ"

func bgm_name() -> String:
	return "stealth"

func _build() -> void:
	build_map(MAP, {
		"壁": func(c): tile(c, "壁", COL_CASTLE, WALL),
		"垣": func(c): tile(c, "垣", COL_HEDGE, WALL),
		"茂": func(c): _add_cover(c, "茂"),
		"苗": func(c): _bed(c),
		"見": func(c): _guard(c, Vector2.DOWN, []),
		"巡": func(c): _guard(c, Vector2.RIGHT, [cell_center(Vector2i(3, 9)), cell_center(Vector2i(22, 9))]),
		"庭": func(c): add_npc(cell_center(c), "庭師", COL_GARDENER, [
			["庭師", "苗木なら、好きなだけ持っていきなされ。"],
			["庭師", "木を二本合わせれば林。林にもう一本足せば森じゃ。"],
			["庭師", "林は一本、森は三本、向いた方へまっすぐ植わる。"],
			["庭師", "あの見張りの前は、茂みが途切れておる。……木を隠すなら、森の中じゃよ。"],
		]),
		"札": func(c): add_sign(c, [
			["札", "木を隠すなら森の中。"],
			["札", "城の見張り「目」に見つかった者は、入口へ戻される。茂みに身をひそめよ。"],
		]),
		"鳥": func(c): drop_item("鳥", cell_center(c)),
		"口": func(c): drop_item("口", cell_center(c)),
	})
	_start = hero.position

func _add_cover(c: Vector2i, t: String) -> Glyph:
	var g := Glyph.make(t, COL_BUSH if t == "茂" else COL_TREE, 22)
	g.position = cell_center(c)
	g.modulate.a = 0.85
	g.z_index = 2
	world.add_child(g)
	_cover[c] = g
	return g

func _bed(c: Vector2i) -> void:
	var g := tile(c, "苗", COL_BED, WALL)
	add_interact(g, "取る「木」", func(): give("木", g.global_position))

func _guard(c: Vector2i, facing: Vector2, route: Array) -> void:
	var g := Guard.new()
	g.stage = self
	g.text = "目"
	g.color = COL_EYE
	g.size = 22
	g.facing = facing
	g.route = route
	g.position = cell_center(c)
	world.add_child(g)
	_guards.append(g)
	solid_things.append(g)

# ---------------------------------------------------------------- 植える

## 林と森は、向いている方へまっすぐ植わって、身を隠す茂みになる。
func on_use(k: String) -> bool:
	if k == "林" or k == "森":
		_plant_cover(k)
		return true
	if k == "鳴":
		_release_bird()
		return true
	return false

func _plant_cover(k: String) -> void:
	var f := Vector2i(_facing4())
	var here := cell_of(hero.position)
	var n := 3 if k == "森" else 1
	var cells: Array[Vector2i] = []
	for i in range(1, n + 1):
		var c := here + f * i
		if solid_at(c) != FREE or _cover.has(c):
			break
		cells.append(c)
	if cells.size() < n:
		hud.toast("ここには植えられない（%d マス空きが要る）" % n)
		Sfx.play("fail")
		return
	consume(k)
	for c in cells:
		var g := _add_cover(c, k)
		g.squash = Vector2(0.2, 0.2)
		var tw := g.create_tween()
		tw.tween_property(g, "squash", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.burst(world, g.position, COL_TREE, 5, "・", 60.0, 10)
	Sfx.play("pop")
	hud.toast("「%s」を植えた" % k, COL_TREE)

## 鳥が飛んでいって鳴く。見張りはしばらくそちらを向く。
func _release_bird() -> void:
	consume("鳴")
	var f := hero.facing
	var p := hero.position
	for i in 5:
		var q := p + f * CELL
		if solid_at(cell_of(q)) == WALL:
			break
		p = q
	var bird := Glyph.make("鳥", Color("#3a5a8a"), 16)
	bird.position = hero.position
	bird.z_index = 30
	world.add_child(bird)
	var tw := bird.create_tween()
	tw.tween_property(bird, "position", p, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if left():
		return
	Sfx.play("alert", 1.4)
	Fx.float_text(world, p + Vector2(0, -16), "ピィーッ！", Hud.RED, 14)
	Fx.ring(world, p, Hud.RED, 200.0, 0.6, 2.0)
	for g in _guards:
		if g.position.distance_to(p) < 400.0:
			g.distract(p, DISTRACT_TIME)
	var tw2 := bird.create_tween()
	tw2.tween_interval(DISTRACT_TIME)
	tw2.tween_property(bird, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(bird.queue_free)

# ---------------------------------------------------------------- 見つかる

func hero_hidden() -> bool:
	return _cover.has(cell_of(hero.position))

## 見張りから p が見えるか（壁や垣でさえぎられていないか）。
func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var n := int(d.length() / 6.0)
	for i in range(1, n):
		var k := solid_at(cell_of(a + d * (float(i) / n)))
		if k == WALL or k == PLANT:
			return false
	return true

func _stage_process(_delta: float) -> void:
	_hidden = hero_hidden()
	hero.modulate.a = 0.5 if _hidden else 1.0
	for g in _guards:
		if g.alarm >= 1.0 and not _caught:
			_get_caught(g)
			return

func _get_caught(g: Guard) -> void:
	_caught = true
	mode = "cut"
	hero.vel = Vector2.ZERO
	Sfx.play("alert")
	shake(5.0)
	Fx.float_text(world, g.position + Vector2(0, -22), "！", Hud.RED, 26, 10.0, 1.0)
	Fx.pop(g, 0.6)
	hud.toast("見つかった！　入口へ戻される……", Hud.RED)
	if not await wait(0.9):
		return
	## 城の中で見つかったら庭の入口へ、外なら最初の場所へ。
	var back := _start
	if hero.position.y < 5 * CELL:
		back = cell_center(Vector2i(23, 3))
	var tw := hero.create_tween()
	tw.tween_property(hero, "modulate:a", 0.0, 0.2)
	await tw.finished
	if left():
		return
	hero.position = back
	for gg in _guards:
		gg.alarm = 0.0
	var tw2 := hero.create_tween()
	tw2.tween_property(hero, "modulate:a", 1.0, 0.2)
	await tw2.finished
	_caught = false
	mode = "play"

# ---------------------------------------------------------------- 見張り

class Guard extends Glyph:
	var stage: Node = null
	var facing := Vector2.DOWN
	## 巡る道（空なら動かない）。
	var route: Array = []
	var alarm := 0.0
	var _leg := 1
	var _pause := 0.0
	var _look_at := Vector2.INF
	var _distract := 0.0
	var _cone: Cone

	func _ready() -> void:
		_cone = Cone.new()
		_cone.guard = self
		_cone.z_index = -1
		add_child(_cone)

	func distract(p: Vector2, sec: float) -> void:
		_look_at = p
		_distract = sec
		Fx.float_text(get_parent(), position + Vector2(0, -20), "？", Color("#a02828"), 18)

	func _physics_process(delta: float) -> void:
		if stage == null:
			return
		if not stage.frozen():
			_move(delta)
			_watch(delta)
		_cone.queue_redraw()

	func look_dir() -> Vector2:
		if _distract > 0.0 and _look_at != Vector2.INF:
			return (_look_at - position).normalized()
		return facing

	func _move(delta: float) -> void:
		if _distract > 0.0:
			_distract -= delta
			return
		if route.is_empty():
			return
		if _pause > 0.0:
			_pause -= delta
			return
		var target: Vector2 = route[_leg]
		var d := target - position
		if d.length() < 1.0:
			_leg = (_leg + 1) % route.size()
			_pause = 1.2
			facing = (route[_leg] - position).normalized()
			return
		facing = d.normalized()
		position += facing * minf(PATROL_SPEED * delta, d.length())

	## 勇者が目に入っているか。入っている間、少しずつ気づいていく。
	func _watch(delta: float) -> void:
		var h: Node2D = stage.hero
		var to: Vector2 = h.position - position
		var seen := false
		if not stage.hero_hidden() and to.length() < SIGHT:
			if absf(look_dir().angle_to(to)) < SIGHT_HALF and stage.line_clear(position, h.position):
				seen = true
		if seen:
			if alarm == 0.0:
				Sfx.play("select", 0.6)
			alarm = minf(1.0, alarm + delta / NOTICE_TIME)
		else:
			alarm = maxf(0.0, alarm - delta * 1.5)

## 見張りの目線。壁でさえぎられるところまでの扇形を描く。
class Cone extends Node2D:
	var guard: Guard

	func _draw() -> void:
		var s: Node = guard.stage
		if s == null:
			return
		var dir := guard.look_dir()
		var pts := PackedVector2Array([Vector2.ZERO])
		var rays := 22
		for i in rays + 1:
			var ang := dir.angle() - SIGHT_HALF + (2.0 * SIGHT_HALF) * float(i) / rays
			var v := Vector2.from_angle(ang)
			var dist := 0.0
			while dist < SIGHT:
				dist += 4.0
				var k: int = s.solid_at(s.cell_of(guard.position + v * dist))
				if k == s.WALL or k == s.PLANT:
					break
			pts.append(v * minf(dist, SIGHT))
		var a := 0.12 + guard.alarm * 0.3
		draw_colored_polygon(pts, Color(0.75, 0.15, 0.12, a))
		draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(0.6, 0.1, 0.1, 0.35), 1.0, true)
