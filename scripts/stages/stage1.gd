extends Stage
## 其の一「斧」。
##
## 【解き方】川は渡れない。岸の大木を倒せば橋になる。
## 木を切るには斧が要るが、宝箱にあるのは刃の「斤」だけ。
## 父に話すと「わしも持っていけ」とついてくる。父＋斤＝斧。
## 斧で大木を 3 度切ると、川へ倒れて橋になる。
##
## 【隠し】旅人「人」は休みたがっている。ふつうの木を斧で切ると苗木「木」が取れる。
## 人＋木＝休（人が木にもたれて休む）。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山木木・・・・・・木木・・・・川川・・・木・・・木山",
	"山木・・・・・・・・・・・・・川川・・・・・・・・山",
	"山・・・・父・・・・・・・・・川川・・花・・・・・山",
	"山・・草・・・・・・・・・・・川川・・・・・・草・山",
	"山・・・・・・・・・・・・・大川川・・・・・・・・山",
	"山・・・・・・・・・・・・・大川川・・・・・・・・山",
	"山・勇・・・・・・・・・・・大川川・・・・・標・・山",
	"山・・・・・・・・・・・・・・川川・・・・・・・・山",
	"山・・花・・・・・・・・札・・川川・・・・花・・・山",
	"山・・・・・・・・・人・・・・川川・・・・・・・・山",
	"山・木・・・・・箱・・・・・・川川・・草・・・・・山",
	"山木木・・・・・・・・・・・・川川・・・・・・木木山",
	"山木木木・・・・・・草・・・・川川・・・・・木木木山",
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
]

const COL_FATHER := Color("#5a3f2a")
const COL_TRAVELER := Color("#4a5a7a")
const COL_CUT := Color("#ff7729")
const COL_STUMP := Color("#9e6a3f")
## 大木を倒すまでに切る回数。
const CUTS_NEEDED := 3

var _tall: Array[Glyph] = []   ## 大木（下から順に）
var _cuts := 0
var _felled := false
var _scar: Glyph = null

func number() -> int:
	return 1

func subtitle() -> String:
	return "川の向こうの目標へ"

func bgm_name() -> String:
	return "field"

func _build() -> void:
	build_map(MAP, {
		"木": func(c): _tree(c),
		"大": func(c): _tall_tree(c),
		"父": func(c): _father(c),
		"人": func(c): _traveler(c),
		"箱": func(c): add_chest(c, "斤"),
		"札": func(c): add_sign(c, [
			["札", "この川は深い。泳いで渡るのは無理だ。"],
			["札", "……岸の大木が、川の方へ傾いている。"],
		]),
	})
	## 大木は上から並べたので、下（根元）から順に並べ直す。
	_tall.sort_custom(func(a, b): return a.position.y > b.position.y)

func _tree(c: Vector2i) -> void:
	var g := tile(c, "木", COL_TREE, WALL)
	g.add_to_group("choppable")

func _tall_tree(c: Vector2i) -> void:
	var g := tile(c, "木", COL_TREE, WALL)
	g.add_to_group("choppable")
	g.set_meta("tall", true)
	_tall.append(g)

func _father(c: Vector2i) -> void:
	## 話し終えたら、父が手にやってくる。
	add_npc(cell_center(c), "父", COL_FATHER, _talk_father)

func _talk_father(g: Glyph) -> void:
	if hero.holding("斧"):
		await talk([["父", "おお、立派な斧になったな。大木の根元を、何度か切ってみるがいい。"]])
		return
	await talk([
		["父", "勇よ、川の向こうへ行きたいのか。"],
		["父", "わしが若いころは、斤（おの）の刃を振り上げて、大木を切り倒したものよ。"],
		["父", "刃は宝箱にしまってある。だが刃だけでは振れん。"],
		["父", "……ほれ、わしも持っていけ。父と斤、合わせれば分かる。"],
	])
	if left():
		return
	remove_interact(g)
	solid_things.erase(g)
	Fx.burst(world, g.position, COL_FATHER, 6, "・", 60.0, 10)
	g.queue_free()
	give("父", g.global_position)

func _traveler(c: Vector2i) -> void:
	add_npc(cell_center(c), "人", COL_TRAVELER, _talk_traveler)

func _talk_traveler(g: Glyph) -> void:
	await talk([
		["人", "旅の者です。歩き疲れました……。"],
		["人", "どこかの木にもたれて、休みたいものです。"],
		["人", "よければ、連れていってもらえませんか。"],
	])
	if left():
		return
	remove_interact(g)
	solid_things.erase(g)
	g.queue_free()
	give("人", g.global_position)

func on_chop(target: Glyph) -> bool:
	if target.has_meta("tall"):
		_chop_tall()
		return true
	_chop_tree(target)
	return true

## ふつうの木は一振りで切れて、苗木が取れる。
func _chop_tree(g: Glyph) -> void:
	var c := cell_of(g.position)
	Sfx.play("chop")
	shake(3.0)
	Fx.burst(world, g.position, COL_STUMP, 8, "・", 110.0, 10)
	clear_tile(c)
	decor(c, "株", COL_STUMP)
	drop_item("木", g.position)

## 大木の根元に切り込みを入れる。3 度で倒れる。
func _chop_tall() -> void:
	if _felled:
		return
	_cuts += 1
	var base := _tall[0]
	Sfx.play("chop", 1.0 - _cuts * 0.08)
	shake(4.0 + _cuts)
	hitstop(0.05)
	Fx.burst(world, base.position, COL_STUMP, 10, "・木", 120.0, 10)
	Fx.float_text(world, base.position + Vector2(0, -20), "切", COL_CUT, 22, 20.0, 0.6)
	## 切り込みは、切るほど大きくなる。
	if _scar == null:
		_scar = Glyph.make("切", COL_CUT, 10)
		_scar.shadow = false
		_scar.z_index = 3
		base.add_child(_scar)
		_scar.position = Vector2(-2, 4)
	_scar.size = 10 + _cuts * 4
	Fx.pop(_scar, 0.6)
	for t in _tall:
		Fx.shake(t, 2.0 + _cuts, 0.25)
	if _cuts >= CUTS_NEEDED:
		_fell()
	else:
		hud.toast("もう少しだ（%d / %d）" % [_cuts, CUTS_NEEDED])

## 大木が川へ倒れて、橋になる。
func _fell() -> void:
	_felled = true
	mode = "cut"
	hero.vel = Vector2.ZERO
	if not await wait(0.35):
		return
	var base := _tall[0]
	var base_c := cell_of(base.position)
	## 上の 2 つをひとまとめにして、根元を軸に右へ倒す。
	var pivot := Node2D.new()
	pivot.position = base.position
	world.add_child(pivot)
	var trunk := Glyph.make("木木", COL_TREE, 22)
	trunk.vertical = true
	trunk.position = Vector2(0, -36)
	pivot.add_child(trunk)
	for i in range(1, _tall.size()):
		clear_tile(cell_of(_tall[i].position))
	Sfx.play("fall")
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation", PI / 2.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if left():
		return
	shake(10.0)
	Fx.burst(world, base.position + Vector2(36, 0), COL_WATER, 16, "・〜", 160.0, 12)
	pivot.queue_free()
	## 根元は切り株になって通れるように。倒れた幹は橋になる。
	clear_tile(base_c)
	decor(base_c, "株", COL_STUMP)
	for dx in [1, 2]:
		var c := base_c + Vector2i(dx, 0)
		clear_tile(c)
	var bridge := Glyph.make("倒木", COL_STUMP, 22)
	bridge.position = cell_center(base_c) + Vector2(CELL * 1.5, 0)
	floor_layer.add_child(bridge)
	Fx.pop(bridge, 0.4)
	hud.toast("大木が倒れて、橋になった！", Hud.RED)
	if not await wait(0.4):
		return
	mode = "play"
