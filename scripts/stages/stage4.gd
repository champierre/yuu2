extends Stage
## 其の四「灯」。蟲を倒して入った、穴の奥の洞窟。
##
## 【解き方】洞窟は闇に閉ざされ、足元しか見えない。
## 焚き火から「火」を取り、火を持ったまま弓を射ると火矢になる。
## 「燭」を火矢で射る（または火を持って触れる）と「灯」になり、周りが明るくなる。
## 深い「淵」には、明かりに照らされたときだけ現れる「橋」がある。
## 淵の向こうの燭を火矢で灯して、光の橋を渡っていく。
##
## 洞窟の「蝙」は明かりを嫌う。灯した所がそのまま安全地帯になる。
##
## 【隠し】左上の隅、燭を灯すと照らされる所の「丁」。火＋丁＝灯（持ち歩ける明かり。蝙も寄ってこない）。
## 火＋火＝炎（放つと蝙を焼き払う）。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山丁・・・岩・・・・・・・蝙・・・淵淵・・・・・・・岩・・・・・蝙・・山",
	"山・・燭・岩・・・・・・・・・・・淵淵・・・・・・・岩・・・・・・・・山",
	"山・・・・岩・・・岩岩岩岩・・・・淵淵・・蝙・・・・岩・・燭・・・・・山",
	"山・・・・岩・・・・・・岩・・・・淵淵・・・・・・・岩岩岩岩岩・・・・山",
	"山・・・・・・・・・・・岩・・・・淵淵燭・・・・・・・・・・・・・・・山",
	"山・蝙・・・・・・・・・岩・・・・橋橋・・・・・・・・・・・・蝙・・・山",
	"山岩岩岩岩岩岩・・・・・岩・・・・淵淵・・・・・岩岩岩岩・・・・・・・山",
	"山・・・・・岩・・・・・岩札・・・淵淵・・・・・岩・・・・・・・・・・山",
	"山・・・・・岩・・蝙・・・・・・・淵淵・・・・・岩・・・・燭・・・・・山",
	"山・・・・・岩岩岩岩岩岩岩岩・・・淵淵・・・・・岩・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・淵淵・・・・・岩・・・・・蝙・・・・山",
	"山岩岩岩岩・・岩岩岩・岩岩岩・・・淵淵淵淵淵淵淵淵淵淵淵淵橋橋淵淵淵淵山",
	"山・・・岩・・岩・・・・・岩・・・淵淵淵淵淵淵淵淵淵淵淵淵橋橋淵淵淵淵山",
	"山・・・岩・・岩・・燭・・岩・・・淵淵・・・・・・・・・・燭・・・・・山",
	"山・焚・・・・岩・・・・・岩・・・淵淵・岩岩岩・岩岩岩・・・・・・・・山",
	"山・・・・・・岩・・・・・岩・・・淵淵・岩・・・・・岩・・・蝙・・・・山",
	"山・勇・・箱・岩・・命・・岩・・・淵淵・岩・・蝙・・岩・・・・標・・・山",
	"山・・・・・・岩・・・・・岩・・・淵淵・岩・・・・・岩・・・・・・・・山",
	"山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山",
]

const COL_ABYSS := Color("#26304a")
const COL_BRIDGE := Color("#b08a4a")
const COL_CANDLE := Color("#b8a888")
const COL_LAMP := Color("#e8902a")
const COL_BAT := Color("#4a3a5a")

## 明かりの広さ。
const LAMP_R := 105.0
const HERO_R := 46.0
const HERO_FIRE_R := 78.0
const HERO_LANTERN_R := 135.0
## これより明るい所に、蝙は入ってこない。
const BAT_FEAR := 0.35
## 蝙の羽音が聞こえる距離と、鳴らす間隔（秒）。
const FLAP_HEAR := 120.0
const FLAP_SOUND_EVERY := 0.6
## 橋はこれより明るいと現れる。
const BRIDGE_LIT := 0.4

var _candles: Array[Glyph] = []
var _bridges := {}   ## Vector2i -> Glyph
var _hero_light: Node2D

func number() -> int:
	return 4

func subtitle() -> String:
	return "闇の洞窟を、灯りで照らせ"

func bgm_name() -> String:
	return "cave"

func _build() -> void:
	## 明かりの無い所は真っ暗。うっすらでも見えると、燭を灯す意味が薄れる。
	enable_dark(0.0)
	build_map(MAP, {
		"淵": func(c): _abyss(c),
		"橋": func(c): _bridge(c),
		"燭": func(c): _candle(c),
		"焚": func(c): _bonfire(c),
		"箱": func(c): add_chest(c, "弓"),
		## 隠しの丁は、左上の燭を灯すと照らされる隅にある（燭を灯すごほうび）。
		"丁": func(c): drop_item("丁", cell_center(c)),
		"命": func(c): drop_heart(cell_center(c)),
		"蝙": func(c): _bat(cell_center(c)),
		"札": func(c): add_sign(c, [
			["札", "この淵は底が見えない。"],
			["札", "昔、向こう岸の燭に火がともると、光の橋が架かったという。"],
			["札", "洞窟の燭をすべて灯した者だけが、奥へ進める。"],
		]),
	})
	## 勇者の手元の明かり。持っているもので広さが変わる。
	_hero_light = Node2D.new()
	hero.add_child(_hero_light)
	add_light(_hero_light, HERO_R, 1.0)
	## 目標はかすかに光って、遠くからでも在りかが分かる。
	var beacon := Node2D.new()
	goal().add_child(beacon)
	add_light(beacon, 34.0, 0.7)
	## すべての燭が灯るまでは、目標は沈んだ色。
	goal().modulate = Color(0.55, 0.5, 0.45, 0.7)

func _abyss(c: Vector2i) -> void:
	var g := tile(c, "淵", COL_ABYSS, WATER)
	g.shadow = false

## 光の橋。暗いうちは淵のまま。
func _bridge(c: Vector2i) -> void:
	var g := tile(c, "淵", COL_ABYSS, WATER)
	g.shadow = false
	_bridges[c] = g

func _candle(c: Vector2i) -> void:
	var g := tile(c, "燭", COL_CANDLE, WALL)
	g.set_meta("lit", false)
	g.add_to_group("shootable")
	_candles.append(g)
	_mark_candle(g)
	add_interact(g, "灯す「燭」", func(): _light_candle(g),
		func(): return has_fire() and not g.get_meta("lit"))
	add_interact(g, "調べる「燭」", func(): hud.toast("燭（ろうそく）だ。火があれば灯せる"),
		func(): return not has_fire() and not g.get_meta("lit"))

func _bonfire(c: Vector2i) -> void:
	var g := tile(c, "焚", COL_LAMP, WALL)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "squash", Vector2(0.92, 1.1), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "squash", Vector2(1.05, 0.95), 0.3).set_trans(Tween.TRANS_SINE)
	add_light(g, 95.0, 1.0)
	g.set_meta("lamp", true)
	add_interact(g, "取る「火」", func():
		Sfx.play("fire")
		give("火", g.global_position))

func _bat(pos: Vector2) -> void:
	var b := Bat.new()
	b.stage = self
	b.text = "蝙"
	b.color = COL_BAT
	b.size = 18
	b.hit_size = Vector2(14, 14)
	b.speed = 34.0
	b.position = pos
	world.add_child(b)

## 灯っていない燭の目印。暗がりでも在りかが分かるよう、闇より手前にうっすら描き、
## 芯に小さな火種をちらつかせる。狙う先が見えないと、火矢を当てずっぽうに射ることになる（#20）。
func _mark_candle(g: Glyph) -> void:
	var mark := Node2D.new()
	mark.position = g.position
	glow_layer().add_child(mark)
	var ghost := Glyph.make("燭", Color(COL_CANDLE, 0.28), 22)
	ghost.shadow = false
	mark.add_child(ghost)
	var ember := Glyph.make("・", Color(1.0, 0.55, 0.15, 0.9), 12)
	ember.shadow = false
	ember.position = Vector2(0, -14)
	mark.add_child(ember)
	var tw := ember.create_tween().set_loops()
	tw.tween_property(ember, "modulate:a", 0.35, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ember, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	g.set_meta("mark", mark)

## 燭に火が移って、灯になる。
func _light_candle(g: Glyph) -> void:
	if g.get_meta("lit"):
		return
	g.set_meta("lit", true)
	var mark = g.get_meta("mark", null)
	if mark != null and is_instance_valid(mark):
		mark.queue_free()
	g.set_meta("lamp", true)
	g.text = "灯"
	g.color = COL_LAMP
	g.remove_from_group("shootable")
	add_light(g, LAMP_R, 1.0)
	Sfx.play("light")
	Fx.pop(g, 0.6)
	Fx.ring(world, g.position, COL_LAMP, 180.0, 0.5, 3.0)
	Fx.burst(world, g.position, COL_LAMP, 10, "・", 90.0, 10)
	var lit := _lit_count()
	if lit < _candles.size():
		hud.toast("灯がともった（%d / %d）" % [lit, _candles.size()], COL_LAMP)
		return
	## 最後の 1 本。目標が光って、奥へ進めるようになる。
	var gl := goal()
	gl.modulate = Color.WHITE
	Fx.ring(world, gl.position, COL_LAMP, 220.0, 0.6, 4.0)
	Fx.pop(gl, 0.5)
	Sfx.play("bell")
	hud.toast("すべての灯がともった！　目標へ", COL_LAMP, 2.4)

func _lit_count() -> int:
	var n := 0
	for c in _candles:
		if c.get_meta("lit"):
			n += 1
	return n

## すべての燭を灯さないと、目標に入れない。
func can_clear() -> bool:
	return _lit_count() >= _candles.size()

var _told_goal := false

func on_goal_blocked() -> void:
	## 触れ続けている間、何度も出さない。いったん離れたら、また出す。
	if _told_goal:
		return
	_told_goal = true
	Sfx.play("fail", 1.2)
	Fx.shake(goal(), 3.0)
	hud.toast("まだ灯っていない燭がある（%d / %d）" % [_lit_count(), _candles.size()], COL_LAMP)

## 火矢と炎は、小さな明かりを持って飛ぶ。飛んでいく先が暗がりでも見えるように。
## この明かりでは橋は出ない（_light_from_lamps が飛ぶものを数えない）。
func fire_shot(t: String, power: float, fire: bool) -> Shot:
	var s := super.fire_shot(t, power, fire)
	if fire:
		add_light(s, 46.0, 0.85)
	return s

## 外れた火矢は、落ちた所で火の粉を散らして「じゅっ」と消える。
func on_shot_wall(shot: Shot) -> void:
	_fizzle(shot)

func on_shot_spent(shot: Shot) -> void:
	_fizzle(shot)

func _fizzle(shot: Shot) -> void:
	if not shot.fire:
		return
	Sfx.play("fire", 1.7, -8.0)
	Fx.burst(glow_layer(), shot.global_position, COL_LAMP, 6, "・", 60.0, 9)

func on_shot_hit(shot: Shot, target: Glyph) -> bool:
	if _candles.has(target):
		if shot.fire:
			_light_candle(target)
		else:
			Sfx.play("clink")
			hud.toast("矢が刺さっただけだ。火のついた矢なら……")
		return true
	return super.on_shot_hit(shot, target)

## 蝙が嫌う明かり。置いた明かり（燭・焚き火）と、手持ちの「灯」。
## 手持ちの火は小さいので数えない。灯は隠しレシピのご褒美として蝙よけになる。
func lamp_light_at(p: Vector2) -> float:
	return _light_from_lamps(p, hero.holding("灯"))

## 橋が現れる明かり。置いた明かりだけ。手持ちの明かりは、灯でも数えない。
## 数えると、燭を射なくても灯を持って近づくだけで橋が出て、謎を飛ばせてしまう。
func bridge_light_at(p: Vector2) -> float:
	return _light_from_lamps(p, false)

func _light_from_lamps(p: Vector2, with_hero: bool) -> float:
	var lit := 0.0
	for l in _lights:
		var n: Node2D = l["node"]
		if n == _hero_light and not with_hero:
			continue
		## 飛んでいる火矢の明かりは数えない（通り過ぎるだけで橋が出たり、蝙が逃げたりしないように）。
		if n is Shot:
			continue
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d := p.distance_to(n.global_position)
		var r: float = l["r"]
		lit = maxf(lit, (1.0 - smoothstep(r * 0.35, r, d)) * float(l["s"]))
	return lit

func _stage_process(_delta: float) -> void:
	if _told_goal and not hero.touching(goal()):
		_told_goal = false
	var r := HERO_R
	if hero.holding("灯"):
		r = HERO_LANTERN_R
	elif hero.holding("火") or hero.holding("炎"):
		r = HERO_FIRE_R
	set_light_radius(_hero_light, r)
	_update_bridges()

## 照らされた淵にだけ、橋が現れる。
func _update_bridges() -> void:
	var raised: Array[Vector2i] = []
	for c in _bridges:
		var g: Glyph = _bridges[c]
		var on := bridge_light_at(cell_center(c)) > BRIDGE_LIT
		var was := solid_at(c) == FREE
		if on == was:
			continue
		if on:
			## 渡れるようになるのは、照らされた瞬間。見た目は _raise_bridge が順に出す。
			set_solid(c, FREE)
			raised.append(c)
		else:
			## 勇者が上にいるときは消さない（落ちてしまうので）。
			if Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).intersects(hero.rect()):
				continue
			set_solid(c, WATER)
			g.text = "淵"
			g.color = COL_ABYSS
	if not raised.is_empty():
		_raise_bridge(raised)

## 光の橋が架かる。この面の答えなので、燭が灯るときより大きく見せる（#51）。
## 勇者のいる岸（燭から遠い、暗い側）から 1 マスずつ架け、音を 1 段ずつ上げる。
## 架かりきったら、画面を少し揺らし、光の輪と一言で知らせる。
const BRIDGE_STEP := 0.14

func _raise_bridge(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a, b): return bridge_light_at(cell_center(a)) < bridge_light_at(cell_center(b)))
	var center := Vector2.ZERO
	for c in cells:
		center += cell_center(c)
	center /= cells.size()
	for i in cells.size():
		if i > 0 and not await wait(BRIDGE_STEP):
			return
		var g: Glyph = _bridges[cells[i]]
		g.text = "橋"
		g.color = COL_BRIDGE
		Fx.pop(g, 0.7)
		Fx.flash(g, 0.25)
		Fx.burst(world, g.position, COL_LAMP, 6, "・", 70.0, 9)
		Sfx.play("pop", 0.8 + i * 0.18)
	if not await wait(BRIDGE_STEP):
		return
	shake(5.0)
	Sfx.play("light", 1.2)
	Fx.ring(world, center, COL_BRIDGE, 200.0, 0.6, 4.0)
	## 橋の燭が最後の 1 本だったときは、「すべての灯」の知らせを上書きしないよう、いっしょに出す。
	if _lit_count() >= _candles.size():
		hud.toast("光の橋が架かった！　すべての灯がともった。目標へ", COL_LAMP, 2.6)
	else:
		hud.toast("光の橋が架かった！", COL_LAMP, 2.0)

# ---------------------------------------------------------------- 蝙

## 暗がりを漂い、勇者に寄ってくる。明かりには入らない。
class Bat extends Enemy:
	var _flap := randf() * TAU
	## 暗がりでも見える、光る目。姿は闇に隠れるが、気配は分かるようにする（#2）。
	## 闇より手前の層に置くので、蝙とは別のノードにして毎コマ位置を合わせる。
	var eyes: Glyph = null
	var _flap_sound := randf() * FLAP_SOUND_EVERY

	func _ready() -> void:
		super._ready()
		eyes = Glyph.make("・・", Color(0.95, 0.25, 0.2, 0.85), 10)
		eyes.shadow = false
		stage.glow_layer().add_child(eyes)
		_follow_eyes()

	func _process(delta: float) -> void:
		_follow_eyes()
		## ときどき瞬く。
		eyes.visible = fmod(_flap * 0.13, 4.0) > 0.25
		## 近くにいると羽音がする。
		_flap_sound -= delta
		var s: Node = stage
		if _flap_sound <= 0.0 and not s.frozen() and position.distance_to(s.hero.position) < FLAP_HEAR:
			_flap_sound = FLAP_SOUND_EVERY
			Sfx.play("flap", randf_range(0.9, 1.15), -6.0)

	func _follow_eyes() -> void:
		if eyes != null and is_instance_valid(eyes):
			eyes.global_position = global_position + Vector2(0, -2)

	func _exit_tree() -> void:
		if eyes != null and is_instance_valid(eyes):
			eyes.queue_free()

	func think(delta: float) -> void:
		_flap += delta * 12.0
		squash = Vector2(1.0 + sin(_flap) * 0.25, 1.0 - sin(_flap) * 0.1)
		var s: Node = stage
		var here: float = s.lamp_light_at(position)
		if here > BAT_FEAR:
			## 明かりに入ってしまったら、いちばん近い明かりから離れる。
			var away := Vector2.ZERO
			for l in s._lights:
				var n: Node2D = l["node"]
				if is_instance_valid(n) and n.global_position.distance_to(position) < l["r"]:
					away += (position - n.global_position).normalized()
			move_toward_point(position + away * 20.0, speed * 2.0, delta)
			return
		var to_hero: Vector2 = s.hero.position - position
		if to_hero.length() < 130.0:
			var wob := to_hero.orthogonal().normalized() * sin(_flap * 0.3) * 8.0
			move_toward_point(s.hero.position + wob, speed * 1.6, delta)
		else:
			wander(delta)

	## 明るい所へは踏み込まない。
	func _try(v: Vector2) -> bool:
		var s: Node = stage
		var before: float = s.lamp_light_at(position)
		position += v
		var ok: bool = not s.blocked(rect(), self, true)
		var after: float = s.lamp_light_at(position)
		if after > BAT_FEAR and after >= before:
			ok = false
		if not ok:
			position -= v
		return ok
