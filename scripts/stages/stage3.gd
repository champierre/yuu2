extends Stage
## 其の三「蟲」。行く手をふさぐ相手そのものを射る話。
##
## 【解き方】蟲は、頭も節も硬くて矢が通らない。
## 通るのは列のいちばん後ろ「尾」だけ。尾を射ると節が 1 つ減り、
## 新しい末尾が尾になる。最後に残った頭が弱点になる。
## 頭を狙わず、尻尾を狙うのが答え。
##
## 【隠し】けがをした旅人「人」と、苗木「木」。人＋木＝休 で命が戻る。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山・・・・・・・・・・・・穴・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・岩・・・・・・・・・・・・・・岩・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・岩・・・・・・・岩・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・草・・・・・・・・・・・・・・・・・・・・苗・山",
	"山・人・・・・・・・・箱勇・・・・・・・・・・・・山",
	"山草・・・・・・・・・・・・・・・・・・・・・・草山",
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
]

const COL_WORM := Color("#4a6a2a")
const COL_TAIL := Color("#c0392b")
const COL_RAGE := Color("#a02030")
const COL_POISON := Color("#7a3a9a")
const COL_TRAVELER := Color("#4a5a7a")

## 蟲の節の数（頭を除く）。
const SEGMENTS := 6
## 蟲が這う範囲。勇者のいる下の方までは来ない。
const CRAWL := Rect2(60, 50, 520, 170)
const SPEED := 70.0
## 節が減るごとに、これだけ速くなる。
const SPEED_UP := 7.0
## 頭の通った道を刻む間隔と、節どうしの間（刻み何個ぶんか）。
const TRAIL_STEP := 2.0
const TRAIL_SKIP := 10
## 毒を吐く間隔（秒）。
const SPIT_EVERY := 2.1
const POISON_SPEED := 115.0
## 残りの節がこれ以下になると荒れて、三方向へ吐く。
const RAGE_AT := 2
const RAGE_SPREAD := 0.45

var _hole: Glyph
var _head: Glyph = null
var _segs: Array[Glyph] = []
var _trail: Array[Vector2] = []
var _dir := Vector2.DOWN
var _target := Vector2.ZERO
var _spit := 0.0
var _wiggle := 0.0
var _trail_acc := 0.0
var _awake := false
var _dead := false

func number() -> int:
	return 3

func subtitle() -> String:
	return "道をふさぐ蟲を倒せ"

func bgm_name() -> String:
	return "cave"

func _build() -> void:
	build_map(MAP, {
		"穴": func(c): _make_hole(c),
		"箱": func(c): add_chest(c, "弓"),
		"人": func(c): add_npc(cell_center(c), "人", COL_TRAVELER, _talk_traveler),
		"苗": func(c): drop_item("木", cell_center(c)),
	})
	Sfx.prepare("battle")

func _make_hole(c: Vector2i) -> void:
	_hole = Glyph.make("穴", INK, 22)
	_hole.position = cell_center(c)
	floor_layer.add_child(_hole)

func _talk_traveler(g: Glyph) -> void:
	if _dead:
		await talk([["人", "やりましたね……！　穴の奥へ進んでください。"]])
		return
	await talk([
		["人", "うう……あの蟲にやられました。"],
		["人", "あいつは頭も節も、岩のように硬い。矢をはね返すんです。"],
		["人", "でも、いちばん後ろの「尾」だけは柔らかいように見えました……。"],
		["人", "足手まといでなければ、わたしも連れていってください。木陰で休めれば、元気が出るのですが。"],
	])
	if left():
		return
	remove_interact(g)
	solid_things.erase(g)
	g.queue_free()
	give("人", g.global_position)

func on_pick(k: String) -> void:
	if k == "弓" and not _awake:
		_emerge()

func _stage_process(delta: float) -> void:
	if not _awake and hero.position.y < 220.0:
		_emerge()
	if _head == null or _dead:
		return
	_crawl(delta)
	_spit -= delta
	if _spit <= 0.0:
		_spit = SPIT_EVERY
		_spit_poison()
	## 頭や節に触れると命が削られる。
	for g in [_head] + _segs:
		if hero.touching(g):
			hurt_hero(1, g.global_position)
			break

# ---------------------------------------------------------------- 蟲

## 穴から蟲が這い出てくる。
func _emerge() -> void:
	_awake = true
	mode = "cut"
	hero.vel = Vector2.ZERO
	Sfx.bgm("")
	Sfx.play("roar")
	shake(8.0)
	hud.toast("地面が揺れている……！", Hud.RED)
	if not await wait(0.8):
		return
	_head = Glyph.make("蟲", COL_WORM, 28)
	_head.position = _hole.position
	_head.hit_size = Vector2(24, 24)
	_head.z_index = 2
	_head.add_to_group("shootable")
	world.add_child(_head)
	Fx.burst(world, _hole.position, Color("#6a5040"), 16, "・土", 150.0, 12)
	_trail.clear()
	for i in SEGMENTS * TRAIL_SKIP + 2:
		_trail.append(_hole.position)
	_dir = Vector2.DOWN
	## 頭が出てきて、続いて節が 1 つずつ現れる。
	var tw := _head.create_tween()
	_head.squash = Vector2(0.2, 0.2)
	tw.tween_property(_head, "squash", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in SEGMENTS:
		if not await wait(0.12):
			return
		var s := Glyph.make("節", COL_WORM, 20)
		s.position = _hole.position
		s.hit_size = Vector2(18, 18)
		s.z_index = 1
		s.add_to_group("shootable")
		world.add_child(s)
		_segs.append(s)
		Sfx.play("pop", 0.6 + i * 0.05)
	_mark_tail()
	await talk([["蟲", "ギチギチギチ……！"]])
	if left():
		return
	Sfx.bgm("battle")
	hud.boss_bar(1.0)
	_pick_target()
	_spit = 1.5
	mode = "play"

## 列の末尾を「尾」にする。ここだけ矢が通る。
func _mark_tail() -> void:
	for i in _segs.size():
		var s := _segs[i]
		var last := i == _segs.size() - 1
		s.text = "尾" if last else "節"
		s.color = COL_TAIL if last else COL_WORM
	if _segs.is_empty():
		_head.color = COL_TAIL
	elif _segs.size() <= RAGE_AT:
		_head.color = COL_RAGE

func _speed() -> float:
	return SPEED + (SEGMENTS - _segs.size()) * SPEED_UP

func _pick_target() -> void:
	_target = Vector2(randf_range(CRAWL.position.x, CRAWL.end.x), randf_range(CRAWL.position.y, CRAWL.end.y))

## 頭が向きを少しずつ変えながら這う。節は頭の通った道をたどる。
func _crawl(delta: float) -> void:
	if _head.position.distance_to(_target) < 24.0:
		_pick_target()
	var want := (_target - _head.position).normalized()
	_dir = _dir.slerp(want, clampf(delta * 2.2, 0.0, 1.0)).normalized()
	_wiggle += delta * 5.0
	var side := _dir.orthogonal() * sin(_wiggle) * 0.5
	var step := (_dir + side).normalized() * _speed() * delta
	var moved := step.length()
	_head.position += step
	_head.tilt = sin(_wiggle) * 0.15
	## 動いたぶんだけ道を刻む。1 コマの動きは刻みより小さいこともある
	## （速い画面ほど小さい）ので、コマをまたいで貯めておく。
	_trail_acc += moved
	while _trail_acc >= TRAIL_STEP:
		_trail.push_front(_head.position)
		_trail_acc -= TRAIL_STEP
	while _trail.size() > (SEGMENTS + 1) * TRAIL_SKIP + 2:
		_trail.pop_back()
	for i in _segs.size():
		var idx := mini((i + 1) * TRAIL_SKIP, _trail.size() - 1)
		_segs[i].position = _trail[idx]
		_segs[i].tilt = sin(_wiggle - (i + 1) * 0.7) * 0.2

func _spit_poison() -> void:
	var aim := (hero.position - _head.position).normalized()
	var dirs := [aim]
	if _segs.size() <= RAGE_AT:
		dirs = [aim.rotated(-RAGE_SPREAD), aim, aim.rotated(RAGE_SPREAD)]
	Sfx.play("shoot", 0.5)
	Fx.pop(_head, 0.4)
	for d in dirs:
		var s := Shot.new()
		s.stage = self
		s.text = "毒"
		s.size = 16
		s.color = COL_POISON
		s.hostile = true
		s.orient = false
		s.dir = d
		s.speed = POISON_SPEED
		s.reach = 520.0
		s.position = _head.position + d * 16.0
		world.add_child(s)

# ---------------------------------------------------------------- 矢

func on_shot_hit(shot: Shot, target: Glyph) -> bool:
	if _dead or _head == null:
		return false
	var tail: Glyph = _segs[-1] if not _segs.is_empty() else _head
	## 尾にかすってさえいれば、尾に当たったことにする。
	## 隣の節と重なって見えるときに、節の方で弾かれると理不尽なので。
	if target == tail or shot.rect().grow(3.0).intersects(tail.rect()):
		_hit_tail(tail)
		return true
	if target == _head or _segs.has(target):
		## 硬いところに当たって、はね返る。
		Sfx.play("clink")
		Fx.burst(world, shot.position, Color("#ffffff"), 5, "＊", 90.0, 9)
		Fx.float_text(world, shot.position + Vector2(0, -10), "カン", Color("#707070"), 11, 14.0, 0.5)
		Fx.pop(target, 0.2)
		return true
	return false

func _hit_tail(t: Glyph) -> void:
	Sfx.play("hit")
	hitstop(0.08)
	shake(6.0)
	Fx.flash(_head)
	if t == _head:
		_die()
		return
	_segs.pop_back()
	Fx.shatter(world, t)
	Fx.ring(world, t.position, COL_TAIL, 120.0, 0.35, 3.0)
	t.queue_free()
	_mark_tail()
	hud.boss_bar(float(_segs.size() + 1) / (SEGMENTS + 1))
	if _segs.size() == RAGE_AT:
		Sfx.play("roar")
		hud.toast("蟲が荒れ狂っている！", Hud.RED)
	elif _segs.is_empty():
		hud.toast("頭だけになった。いまだ！", Hud.RED)
	## 痛がって、向きを変える。
	_pick_target()
	_spit = minf(_spit, 0.8)

func _die() -> void:
	_dead = true
	mode = "cut"
	hud.boss_bar(0.0, false)
	Sfx.bgm("")
	Sfx.play("roar", 1.3)
	for i in 6:
		Fx.flash(_head, 0.1)
		Fx.burst(world, _head.position, COL_WORM, 6, "・", 120.0, 11)
		shake(5.0)
		if not await wait(0.12):
			return
	Sfx.play("enemy_die")
	Fx.shatter(world, _head, 200.0)
	Fx.ring(world, _head.position, COL_TAIL, 260.0, 0.5, 5.0)
	_head.queue_free()
	_head = null
	## 敵の毒も消す。
	for n in world.get_children():
		if n is Shot and n.hostile:
			n.die(true)
	if not await wait(0.8):
		return
	hud.toast("蟲を倒した！　穴の奥へ進もう", Hud.RED, 2.4)
	add_goal(_hole.position, "穴")
	_hole.visible = false
	Sfx.play("bell")
	mode = "play"
