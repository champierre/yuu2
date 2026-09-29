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
## 【隠し】行き止まりの「丁」。火＋丁＝灯（持ち歩ける明かり。蝙も寄ってこない）。
## 火＋火＝炎（放つと蝙を焼き払う）。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山・・・・岩・・・・・・・蝙・・・淵淵・・・・・・・岩・・・・・蝙・・山",
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
	"山・焚・・・・岩・・・・・岩・・・淵淵・岩岩岩岩岩岩岩・・・・・・・・山",
	"山・・・・・・岩・・・・・岩・・・淵淵・岩・・・・・岩・・・蝙・・・・山",
	"山・勇・・箱・岩・・丁・・岩・・・淵淵・岩・・蝙・・岩・・・・標・・・山",
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
		"丁": func(c): drop_item("丁", cell_center(c)),
		"蝙": func(c): _bat(cell_center(c)),
		"札": func(c): add_sign(c, [
			["札", "この淵は底が見えない。"],
			["札", "昔、向こう岸の燭に火がともると、光の橋が架かったという。"],
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

## 燭に火が移って、灯になる。
func _light_candle(g: Glyph) -> void:
	if g.get_meta("lit"):
		return
	g.set_meta("lit", true)
	g.set_meta("lamp", true)
	g.text = "灯"
	g.color = COL_LAMP
	g.remove_from_group("shootable")
	add_light(g, LAMP_R, 1.0)
	Sfx.play("light")
	Fx.pop(g, 0.6)
	Fx.ring(world, g.position, COL_LAMP, 180.0, 0.5, 3.0)
	Fx.burst(world, g.position, COL_LAMP, 10, "・", 90.0, 10)
	var lit := 0
	for c in _candles:
		if c.get_meta("lit"):
			lit += 1
	hud.toast("灯がともった（%d / %d）" % [lit, _candles.size()], COL_LAMP)

func on_shot_hit(shot: Shot, target: Glyph) -> bool:
	if _candles.has(target):
		if shot.fire:
			_light_candle(target)
		else:
			Sfx.play("clink")
			hud.toast("矢が刺さっただけだ。火のついた矢なら……")
		return true
	return super.on_shot_hit(shot, target)

## 明かり（勇者の手元の火は数えない）。蝙と橋はこれを見る。
func lamp_light_at(p: Vector2) -> float:
	var lit := 0.0
	for l in _lights:
		var n: Node2D = l["node"]
		if n == _hero_light and not hero.holding("灯"):
			continue
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d := p.distance_to(n.global_position)
		var r: float = l["r"]
		lit = maxf(lit, (1.0 - smoothstep(r * 0.35, r, d)) * float(l["s"]))
	return lit

func _stage_process(_delta: float) -> void:
	var r := HERO_R
	if hero.holding("灯"):
		r = HERO_LANTERN_R
	elif hero.holding("火") or hero.holding("炎"):
		r = HERO_FIRE_R
	set_light_radius(_hero_light, r)
	_update_bridges()

## 照らされた淵にだけ、橋が現れる。
func _update_bridges() -> void:
	for c in _bridges:
		var g: Glyph = _bridges[c]
		var on := lamp_light_at(cell_center(c)) > BRIDGE_LIT
		var was := solid_at(c) == FREE
		if on == was:
			continue
		if on:
			set_solid(c, FREE)
			g.text = "橋"
			g.color = COL_BRIDGE
			Fx.pop(g, 0.5)
			Fx.burst(world, g.position, COL_BRIDGE, 5, "・", 60.0, 9)
			Sfx.play("pop", 0.7)
		else:
			## 勇者が上にいるときは消さない（落ちてしまうので）。
			if Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).intersects(hero.rect()):
				continue
			set_solid(c, WATER)
			g.text = "淵"
			g.color = COL_ABYSS

# ---------------------------------------------------------------- 蝙

## 暗がりを漂い、勇者に寄ってくる。明かりには入らない。
class Bat extends Enemy:
	var _flap := randf() * TAU

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
