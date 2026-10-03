extends Stage
## 終の章「明」。字をばらばらにした魔王「魔」との戦い。
##
## 【解き方】魔は「闇」をまとっていて、矢が届かない。
## 左の祭壇の「日」と右の祭壇の「月」を合わせると「明」。
## 明を手に近づくと、その光で闇がはがれる。その間に弓で射る。
## 両手を明と弓でふさいで戦う（どちらも手放せない）。
##
## 倒すと「魔」は「麻」と「鬼」に分かれ、鬼は逃げていく。
##
## 【隠し】隅の「生」。日＋生＝星（願えば命が戻る）。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・魔・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・柱・・・・・・・・・・・・柱・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・日・・・・・・・・・・・・・・・・・月・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・柱・・・・・・・・・・・・柱・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・箱・・・・・・・・・・・山",
	"山生・・・・・・・・・札・勇・・・・・・・・・・・山",
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
]

const COL_DEMON := Color("#5a1a4a")
const COL_DARK := Color("#2a1040")
const COL_SUN := Color("#e0a020")
const COL_MOON := Color("#6a80c8")
const COL_PILLAR := Color("#6a5a6a")
const COL_OGRE := Color("#8a2a2a")

const MAX_HP := 9
## 明を持ってこの距離まで近づくと、闇がはがれる。
const MEI_RANGE := 175.0
const HERO_R := 58.0
const HERO_MEI_R := 190.0
## 闇がまた集まるまでの秒数。
const SHIELD_BACK := 1.2
## 魔が漂う範囲。
const FLOAT := Rect2(120, 60, 384, 70)

var _boss: Glyph
var _shield: Array[Glyph] = []
var _shield_up := true
var _shield_timer := 0.0
var _hp := MAX_HP
var _phase := 1
var _t_attack := 2.0
var _t_summon := 6.0
var _spin := 0.0
var _float_t := 0.0
var _started := false
var _defeated := false
var _hero_light: Node2D

func number() -> int:
	return 6

func subtitle() -> String:
	return "闇を払い、魔を討て"

func bgm_name() -> String:
	return "cave"

## 魔を倒したあとの曲（ending）を、光に触れても止めず、エンディングまで流し続ける。
## 止めると、エンディングの場面でまた頭から鳴り直して、余韻がとぎれる（#62）。
func clear_keeps_bgm() -> bool:
	return true

## 決戦の曲。魔の段階が進むごとに、同じ旋律のまま太鼓が厚くなる。
static func battle_song(phase: int) -> String:
	return "final" if phase <= 1 else "final%d" % mini(phase, 3)

func _build() -> void:
	enable_dark(0.1)
	dark.tint = Color(0.06, 0.02, 0.08)
	build_map(MAP, {
		"魔": func(c): _make_boss(c),
		"柱": func(c): tile(c, "柱", COL_PILLAR, WALL),
		"日": func(c): _altar(c, "日", COL_SUN),
		"月": func(c): _altar(c, "月", COL_MOON),
		"箱": func(c): add_chest(c, "弓"),
		"生": func(c): drop_item("生", cell_center(c)),
		"札": func(c): add_sign(c, [
			["札", "日と月、ふたつ並べば闇を払う。"],
			["札", "光を手に、恐れず近づけ。"],
		]),
	})
	_hero_light = Node2D.new()
	hero.add_child(_hero_light)
	add_light(_hero_light, HERO_R, 1.0)
	Sfx.prepare(battle_song(1))

func _altar(c: Vector2i, k: String, col: Color) -> void:
	var g := tile(c, "祭", Color("#7a6a5a"), WALL)
	var orb := Glyph.make(k, col, 16)
	orb.position = Vector2(0, -20)
	orb.outline = 3
	g.add_child(orb)
	var tw := orb.create_tween().set_loops()
	tw.tween_property(orb, "position:y", -24.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(orb, "position:y", -20.0, 0.8).set_trans(Tween.TRANS_SINE)
	add_light(g, 70.0, 0.9)
	add_interact(g, "取る「%s」" % k, func():
		Sfx.play("light")
		give(k, orb.global_position))

func _make_boss(c: Vector2i) -> void:
	var gl := glow_layer()
	_boss = Glyph.make("魔", COL_DEMON, 46)
	_boss.position = cell_center(c)
	_boss.hit_size = Vector2(38, 38)
	_boss.outline = 4
	_boss.outline_color = Color(0.9, 0.7, 1.0, 0.5)
	_boss.add_to_group("shootable")
	gl.add_child(_boss)
	for i in 4:
		var s := Glyph.make("闇", COL_DARK, 20)
		s.outline = 3
		s.outline_color = Color(0.7, 0.5, 0.9, 0.5)
		s.hit_size = Vector2(20, 20)
		s.add_to_group("shootable")
		gl.add_child(s)
		_shield.append(s)

# ---------------------------------------------------------------- 始まり

func _process(delta: float) -> void:
	super._process(delta)
	if _boss != null and is_instance_valid(_boss):
		_animate_boss(delta)
	if not _started and mode == "play":
		_start_battle()

func _start_battle() -> void:
	_started = true
	mode = "cut"
	Sfx.play("roar")
	shake(8.0)
	await talk([
		["魔", "よくぞ来た、勇よ。世の字をばらばらにしたのは、この魔だ。"],
		["魔", "闇をまとったわしに、矢など届かぬわ！"],
		["勇", "（左と右に、光る祭壇がある……）"],
	])
	if left():
		return
	Sfx.bgm(battle_song(1))
	Sfx.prepare(battle_song(2))
	hud.boss_bar(1.0)
	mode = "play"

func _animate_boss(delta: float) -> void:
	_spin += delta * (1.2 + _phase * 0.4)
	for i in _shield.size():
		var s := _shield[i]
		var ang := _spin + i * TAU / _shield.size()
		s.position = _boss.position + Vector2.from_angle(ang) * 38.0
		s.tilt = sin(_spin * 2.0 + i) * 0.3

# ---------------------------------------------------------------- 毎コマ

func _stage_process(delta: float) -> void:
	var r := HERO_MEI_R if hero.holding("明") else HERO_R
	set_light_radius(_hero_light, lerpf(_light_r(), r, 0.1))
	if _defeated or _boss == null:
		return
	_float(delta)
	_update_shield(delta)
	_attack(delta)
	if hero.touching(_boss):
		hurt_hero(1, _boss.position)

func _light_r() -> float:
	for l in _lights:
		if l["node"] == _hero_light:
			return l["r"]
	return HERO_R

func _float(delta: float) -> void:
	_float_t += delta * (0.5 + _phase * 0.15)
	var p := Vector2(
		FLOAT.position.x + FLOAT.size.x * (0.5 + 0.5 * sin(_float_t)),
		FLOAT.position.y + FLOAT.size.y * (0.5 + 0.5 * sin(_float_t * 1.7)))
	_boss.position = _boss.position.lerp(p, clampf(delta * 2.0, 0, 1))
	_boss.squash = Vector2(1.0 + sin(_float_t * 3.0) * 0.04, 1.0 - sin(_float_t * 3.0) * 0.04)

## 明を持って近づくと、闇がはがれる。離れるとまた集まる。
func _update_shield(delta: float) -> void:
	var near := hero.holding("明") and hero.position.distance_to(_boss.position) < MEI_RANGE
	if near:
		_shield_timer = SHIELD_BACK
		if _shield_up:
			_shield_up = false
			Sfx.play("light", 1.3)
			hud.toast("光で闇がはがれた！　いまだ！", COL_SUN)
			for s in _shield:
				var tw := s.create_tween()
				tw.tween_property(s, "modulate:a", 0.0, 0.25)
				Fx.burst(glow_layer(), s.position, COL_DARK, 4, "・", 80.0, 10)
			_boss.outline_color = Color(1.0, 0.85, 0.3, 0.9)
	elif not _shield_up:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			_shield_up = true
			for s in _shield:
				var tw := s.create_tween()
				tw.tween_property(s, "modulate:a", 1.0, 0.4)
			_boss.outline_color = Color(0.9, 0.7, 1.0, 0.5)
	for s in _shield:
		s.visible = s.modulate.a > 0.05

func _attack(delta: float) -> void:
	_t_attack -= delta
	if _t_attack <= 0.0:
		match _phase:
			1:
				_t_attack = 2.2
				var aim := (hero.position - _boss.position).normalized()
				for a in [-0.3, 0.0, 0.3]:
					_bullet(aim.rotated(a), 105.0)
			2:
				_t_attack = 2.6
				var off := randf() * TAU
				for i in 10:
					_bullet(Vector2.from_angle(off + i * TAU / 10.0), 95.0)
			_:
				_t_attack = 0.22
				_bullet(Vector2.from_angle(_spin * 2.3), 115.0)
				_bullet(Vector2.from_angle(_spin * 2.3 + PI), 115.0)
		Fx.pop(_boss, 0.25)
	if _phase >= 2:
		_t_summon -= delta
		if _t_summon <= 0.0:
			_t_summon = 7.0 if _phase == 2 else 9.0
			if get_tree().get_nodes_in_group("enemy").size() < 3:
				_summon()

func _bullet(d: Vector2, speed: float) -> void:
	var s := Shot.new()
	s.stage = self
	s.text = "闇"
	s.size = 13
	s.color = Color("#b070e0")
	s.outline = 3
	s.outline_color = Color(0.1, 0.0, 0.15, 0.9)
	s.hostile = true
	s.orient = false
	s.dir = d
	s.speed = speed
	s.reach = 600.0
	s.position = _boss.position + d * 26.0
	glow_layer().add_child(s)

## 鬼を呼び出す。
func _summon() -> void:
	Sfx.play("roar", 1.5)
	for side in [-1.0, 1.0]:
		var e := Ogre.new()
		e.stage = self
		e.text = "鬼"
		e.color = COL_OGRE
		e.size = 20
		e.outline = 3
		e.outline_color = Color(1, 0.6, 0.5, 0.6)
		e.hit_size = Vector2(16, 16)
		e.hp = 2
		e.speed = 46.0
		e.position = _boss.position + Vector2(side * 40.0, 20.0)
		## 倒した鬼は、ときどき命を落としていく。
		e.died.connect(func(o: Enemy):
			if randf() < 0.6 and not _defeated:
				drop_heart(o.position))
		glow_layer().add_child(e)
		Fx.ring(glow_layer(), e.position, COL_OGRE, 100.0, 0.3, 2.0)

class Ogre extends Enemy:
	func think(delta: float) -> void:
		move_toward_point(stage.hero.position, speed, delta)

# ---------------------------------------------------------------- 矢

func on_shot_hit(shot: Shot, target: Glyph) -> bool:
	if _shield.has(target):
		if not target.visible:
			return false
		_absorb(shot)
		return true
	if target == _boss:
		if _shield_up:
			_absorb(shot)
		else:
			_hurt_boss()
		return true
	return super.on_shot_hit(shot, target)

func _absorb(shot: Shot) -> void:
	Sfx.play("clink", 0.7)
	Fx.float_text(glow_layer(), shot.position + Vector2(0, -8), "闇に呑まれた", Color("#b070e0"), 11, 14.0, 0.6)

func _hurt_boss() -> void:
	_hp -= 1
	Sfx.play("hit", 0.8)
	hitstop(0.08)
	shake(6.0)
	Fx.flash(_boss, 0.2)
	Fx.pop(_boss, 0.4)
	Fx.burst(glow_layer(), _boss.position, COL_SUN, 10, "・＊", 140.0, 11)
	hud.boss_bar(float(_hp) / MAX_HP)
	if _hp <= 0:
		_defeat()
		return
	var p := 1 + (MAX_HP - _hp) / 3
	if p != _phase:
		_phase = p
		_t_attack = 1.5
		_t_summon = 1.0
		Sfx.play("roar")
		shake(10.0)
		## 旋律は途切れさせず、同じ所から太鼓だけを厚くする。
		Sfx.bgm(battle_song(_phase), true)
		## 次に鳴らす曲を先に作っておく。最後の段階なら、倒したあとの曲。
		Sfx.prepare(battle_song(_phase + 1) if _phase < 3 else "ending")
		if _phase == 2:
			hud.toast("魔が鬼を呼んだ！", Hud.RED)
		else:
			hud.toast("魔が荒れ狂っている！", Hud.RED)
			dark.ambient = 0.03

# ---------------------------------------------------------------- 決着

func _defeat() -> void:
	_defeated = true
	mode = "cut"
	hud.boss_bar(0.0, false)
	Sfx.bgm("")
	Sfx.play("roar", 0.7)
	for n in glow_layer().get_children():
		if n is Shot:
			n.die(true)
		elif n is Enemy:
			n.die()
	for s in _shield:
		s.queue_free()
	_shield.clear()
	for i in 10:
		Fx.flash(_boss, 0.1)
		Fx.burst(glow_layer(), _boss.position, COL_DEMON, 6, "・", 150.0, 11)
		shake(6.0)
		if not await wait(0.12):
			return
	## 「魔」が「麻」と「鬼」に分かれる。
	Sfx.play("stamp")
	var pos := _boss.position
	_boss.visible = false
	var hemp := Glyph.make("麻", Color("#8a8a5a"), 30)
	var ogre := Glyph.make("鬼", COL_OGRE, 30)
	hemp.position = pos
	ogre.position = pos
	world.add_child(hemp)
	glow_layer().add_child(ogre)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hemp, "position", pos + Vector2(-40, 10), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ogre, "position", pos + Vector2(40, 10), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if left():
		return
	await talk([
		["魔", "ぐ、ぐわあああ……！　わしの字が、麻と鬼に……！"],
		["鬼", "ひいい、光はこわい！　鬼は外〜！"],
	])
	if left():
		return
	var tw2 := ogre.create_tween()
	tw2.tween_property(ogre, "position", pos + Vector2(420, -40), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_callback(ogre.queue_free)
	## 闇が晴れて、花が咲く。
	Sfx.play("bell")
	var tw3 := create_tween()
	tw3.tween_property(dark, "ambient", 1.0, 2.5)
	for i in 40:
		var c := Vector2i(randi_range(1, cols - 2), randi_range(1, rows - 2))
		if solid_at(c) == FREE:
			var f := decor(c, ["花", "草", "花"][i % 3], COL_FLOWER if i % 3 != 1 else COL_GRASS)
			f.squash = Vector2.ZERO
			var tf := f.create_tween()
			tf.tween_interval(randf() * 2.0)
			tf.tween_property(f, "squash", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not await wait(2.6):
		return
	var g := add_goal(pos, "光")
	g.color = COL_SUN
	g.size = 26
	Fx.ring(world, pos, COL_SUN, 200.0, 0.6, 4.0)
	hud.toast("闇が晴れた。光のもとへ", COL_SUN, 2.5)
	Sfx.bgm("ending")
	mode = "play"
