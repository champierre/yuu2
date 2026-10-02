extends Stage
## 其の二「鉄」。Scratch 版「『勇』の冒険2」を土台にしたもの。
##
## 【解き方】門番は「金より鉄が貴重だ。鉄を持ってこい」と言う。
## 宝箱から出るのは「金」。そのままでは通してもらえない。
## 村人は「盗人に気をつけろ」と言うが、裏を返せば道しるべ。
## 盗人は自分からは寄ってこない。金を持って近づくと、立ち止まってうかがう。
## 自分から盗人に触れて、わざと金を奪わせると、手に「失」が残る。
## もう一度宝箱から金を取り、金＋失＝鉄。失うことで手に入る。
##
## 【隠し】鍛冶屋の炉から「火」が取れる。火＋火＝炎。

const MAP := [
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・花・・・・・・・・標・・・・・・・・花・・・山",
	"山・・・・草・・・・・・・・・・・・・・・・・草・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山壁壁壁壁壁壁壁壁壁壁壁門門壁壁壁壁壁壁壁壁壁壁壁山",
	"山・・・・・・・・・・番・・・・・・・・・・・・・山",
	"山・家家・・・・・・・・・・・・・・・・・家家・・山",
	"山・家家・・・・・・・・・・・・・・・・・家家・・山",
	"山・・・・・・・・・・・・・・・・・・・・・・・・山",
	"山・・炉・・・・・・・・・・・・・・・・・・・・・山",
	"山・・・・・・・・・・・・・・・・・・・・箱・・・山",
	"山・・・・・・・・・・・勇・・・・・・・・・・・・山",
	"山草・・・・・・・・花・・・・・・・・・草・・・・山",
	"山山山山山山山山山山山山山山山山山山山山山山山山山山",
]

const COL_GATE := Color("#2f7f7a")
const COL_KEEPER := Color("#3a4a6a")
const COL_THIEF := Color("#5a2a6a")
const COL_VILLAGER := Color("#6a5a3a")
const COL_HOUSE := Color("#9a6a4a")
const COL_GOLD := Color("#c9a227")
const COL_LOSS := Color("#7a4d8c")

## 下の町の広さ（村人と盗人はここから出ない）。
const TOWN := Rect2(30, 150, 570, 170)
## 金を持った勇者がこの距離に入ると、盗人は立ち止まってうかがう。
const THIEF_NOTICE := 130.0

var _gates: Array[Glyph] = []
var _keeper: Glyph
var _thief: Walker
var _robbed := false
var _thief_eyeing := false
var _gate_open := false

const VILLAGER_LINES := [
	[["村人", "盗人に気をつけな。金を持っていると、すぐに失くしちまうよ。"],
		["村人", "……まあ、失くして初めて分かることもあるがね。"]],
	[["村人", "門番は鉄が大好きでね。「金より鉄が貴重だ」が口ぐせさ。"],
		["村人", "この町には鉄が無い。金ならあの宝箱から、いくらでも湧くのにねえ。"]],
	[["村人", "字というのは、足し算なんだよ。"],
		["村人", "金に何かを足すと、別の金属になる。……何を足すんだったかな。"]],
]

func number() -> int:
	return 2

func subtitle() -> String:
	return "門の向こうの目標へ"

func bgm_name() -> String:
	return "field"

func _build() -> void:
	build_map(MAP, {
		"門": func(c): _gates.append(tile(c, "門", COL_GATE, WALL)),
		"番": func(c): _keeper = add_npc(cell_center(c), "門番", COL_KEEPER, _talk_keeper),
		"家": func(c): tile(c, "家", COL_HOUSE, WALL),
		"炉": func(c): _forge(c),
		"箱": func(c): add_chest(c, func(): return _chest_content(), true),
	})
	for i in 3:
		var v := _walker("村人", COL_VILLAGER, [Vector2(150, 260), Vector2(330, 200), Vector2(470, 290)][i])
		v.speed = 30.0
		var lines: Array = VILLAGER_LINES[i]
		add_interact(v, "話す「村人」", func(): talk(lines))
	_thief = _walker("盗人", COL_THIEF, Vector2(110, 300))
	_thief.speed = 38.0
	add_interact(_thief, "話す「盗人」", func(): talk([["盗人", "へっへっへ。いい金の匂いがするねえ……。"]]),
		func(): return not hero.holding("金"))

func _walker(t: String, col: Color, pos: Vector2) -> Walker:
	var w := Walker.new()
	w.text = t
	w.color = col
	w.size = 18
	w.hit_size = Vector2(16 * t.length(), 16)
	w.stage = self
	w.area = TOWN
	w.position = pos
	world.add_child(w)
	return w

func _forge(c: Vector2i) -> void:
	var g := tile(c, "炉", Color("#8a3a2a"), WALL)
	add_interact(g, "取る「火」", func():
		Sfx.play("fire")
		give("火", g.global_position))
	## 炉の火がちらちら揺れる。
	var f := Glyph.make("火", COL_FIRE, 12)
	f.position = Vector2(0, -16)
	f.shadow = false
	g.add_child(f)
	var tw := f.create_tween().set_loops()
	tw.tween_property(f, "squash", Vector2(0.85, 1.2), 0.25)
	tw.tween_property(f, "squash", Vector2(1.1, 0.9), 0.25)

## 宝箱は、金を持っていなければ何度でも金をくれる。
func _chest_content() -> String:
	if hero.holding("金"):
		hud.toast("もう金は持っている")
		return ""
	if hero.holding("鉄"):
		return ""
	return "金"

## 門番の話は、持っているもので変わる。
func _talk_keeper(_g: Glyph) -> void:
	if _gate_open:
		await talk([["門番", "通るがいい。鉄を持つ者は、この町の宝だ。"]])
		return
	if hero.holding("鉄"):
		await talk([
			["門番", "むっ……それは、鉄！"],
			["門番", "金を失ってこそ手に入る、金より硬いもの。よくぞ見つけた。"],
			["門番", "約束だ。門を開けよう！"],
		])
		if left():
			return
		consume("鉄")
		_open_gate()
		return
	if hero.holding("金"):
		await talk([
			["門番", "金か。そんなもの、この町ではありふれている。"],
			["門番", "金より鉄が貴重だ。鉄を持ってこい。"],
		])
		return
	if hero.holding("失"):
		await talk([["門番", "何かを失くしたような顔をしているな。"], ["門番", "だが、失ったものは、別のものに化けることもある。"]])
		return
	await talk([
		["門番", "ここを通りたければ、鉄を持ってこい。"],
		["門番", "金ではだめだぞ。金より鉄が貴重なのだ。"],
	])

func _open_gate() -> void:
	_gate_open = true
	mode = "cut"
	Sfx.play("gate")
	shake(5.0)
	for i in _gates.size():
		var g := _gates[i]
		var c := cell_of(g.position)
		set_solid(c, FREE)
		var dir := -1.0 if i == 0 else 1.0
		var tw := g.create_tween()
		tw.tween_property(g, "position:x", g.position.x + dir * 20.0, 0.6).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(g, "modulate:a", 0.0, 0.6)
	Fx.burst(world, _gates[0].position + Vector2(12, 0), COL_GATE, 12, "・", 100.0, 10)
	if not await wait(0.7):
		return
	hud.toast("門が開いた！", Hud.RED)
	mode = "play"

func _stage_process(_delta: float) -> void:
	if _thief == null or not is_instance_valid(_thief) or _robbed:
		return
	## 金を持った勇者が近くにいると、盗人は立ち止まってうかがう。
	## 自分からは寄ってこない。奪わせるかどうかは、遊ぶ人が決める（#7）。
	## うろつきも止めるのは、歩いているうちに偶然ぶつかって奪われないようにするため。
	var d := _thief.position.distance_to(hero.position)
	var eyeing := hero.holding("金") and d < THIEF_NOTICE
	_thief.active = not eyeing
	if eyeing and not _thief_eyeing:
		Fx.float_text(world, _thief.position + Vector2(0, -20), "へっへっへ…", COL_THIEF, 11)
	_thief_eyeing = eyeing
	if hero.holding("金") and _thief.touching(hero):
		_rob()

## 金を奪われる。ここが谷であり、答えへの入り口。
func _rob() -> void:
	_robbed = true
	mode = "cut"
	hero.vel = Vector2.ZERO
	_thief.active = false
	Sfx.play("thief")
	shake(9.0)
	hitstop(0.1)
	## 「悲」を大きく出して、すぐ消す。取られた瞬間の気持ち。
	var sad := Glyph.make("悲", Color("#4a5aa0"), 80)
	sad.position = Vector2(320, 170)
	sad.modulate.a = 0.0
	hud.add_child(sad)
	var tw := sad.create_tween()
	tw.tween_property(sad, "modulate:a", 0.8, 0.1)
	tw.tween_interval(0.5)
	tw.tween_property(sad, "modulate:a", 0.0, 0.4)
	tw.tween_callback(sad.queue_free)
	## 金が盗人の手へ飛んでいく。
	var gold := Glyph.make("金", COL_GOLD, 14)
	gold.position = hero.position + Vector2(15, -12)
	gold.z_index = 40
	world.add_child(gold)
	var i := hero.hands.find("金")
	hero.hands[i] = "失"
	hero.set_hands(hero.hands.duplicate())
	_refresh_hud()
	var tw2 := gold.create_tween()
	tw2.tween_property(gold, "position", _thief.position + Vector2(0, -14), 0.3).set_trans(Tween.TRANS_QUAD)
	await tw2.finished
	if left():
		return
	gold.reparent(_thief)
	Fx.float_text(world, _thief.position + Vector2(0, -24), "へっへっへ！", COL_THIEF, 13)
	if not await wait(0.5):
		return
	await talk([
		["盗人", "金はいただいたぜ！　へっへっへ！"],
		["勇", "……金を失った。手には「失」だけが残った。"],
	])
	if left():
		return
	## 盗人は町の外へ逃げていく。
	remove_interact(_thief)
	var tw3 := _thief.create_tween()
	tw3.tween_property(_thief, "position:x", -40.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw3.tween_callback(_thief.queue_free)
	mode = "play"
