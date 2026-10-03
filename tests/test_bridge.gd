extends "res://tests/helper.gd"
## ステージ4 の光の橋は、燭を灯したときだけ現れること。
## 手持ちの明かり（火・灯）で照らしても現れてはいけない。
## 手持ちの灯で橋が出てしまうと、燭を射る謎を飛ばせてしまう。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var hero = stage.hero
	var bridge := Vector2i(17, 6)

	## 淵のすぐ手前に、手持ちの明かりを持って立つ。
	hero.position = cell(16, 6)
	hero.set_hands(["灯"])
	await sleep(0.5)
	check(stage.solid_at(bridge) != 0, "手持ちの灯では、橋は現れない")

	hero.set_hands(["火"])
	await sleep(0.3)
	check(stage.solid_at(bridge) != 0, "手持ちの火でも、橋は現れない")

	## 手持ちの灯は、蝙よけとしては効く（隠しレシピのご褒美）。
	hero.set_hands(["灯"])
	await sleep(0.1)
	check(stage.lamp_light_at(hero.position) > 0.35, "手持ちの灯は、蝙よけの明かりになる")

	## 向こう岸の燭を灯すと、橋が現れる。
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(19, 5):
			stage._light_candle(c)
	await sleep(0.3)
	check(stage.solid_at(bridge) == 0, "燭を灯すと、橋が現れる")

	## 橋は、向こう岸の燭を灯したときに、まるごと現れる。
	## 手前の岸の燭が近いと、橋の 1 マスだけが半端に現れてしまう（#55）。
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var first: Array[Vector2i] = [Vector2i(17, 6), Vector2i(18, 6)]
	var second: Array[Vector2i] = [Vector2i(29, 12), Vector2i(30, 12), Vector2i(29, 13), Vector2i(30, 13)]
	var far := {Vector2i(19, 5): first, Vector2i(29, 14): second}
	for c in stage._candles:
		if not far.has(stage.cell_of(c.position)):
			stage._light_candle(c)
	await sleep(0.3)
	check(_count(first) == 0 and _count(second) == 0, "向こう岸の燭のほかを全部灯しても、橋は 1 マスも現れない")
	for b in first + second:
		check(stage.bridge_light_at(stage.cell_center(b)) < stage.BRIDGE_LIT * 0.5, "橋 %s には、手前の明かりがほとんど届かない" % b)
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(29, 14):
			stage._light_candle(c)
	await sleep(0.3)
	check(_count(second) == second.size(), "二つめの橋は、向こう岸の燭でまるごと現れる")
	check(_count(first) == 0, "一つめの橋は、まだ現れない")
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(19, 5):
			stage._light_candle(c)
	await sleep(0.3)
	check(_count(first) == first.size(), "一つめの橋も、向こう岸の燭でまるごと現れる")

## 渡れるようになっている橋のマスの数。
func _count(cells: Array[Vector2i]) -> int:
	var n := 0
	for c in cells:
		if stage.solid_at(c) == 0:
			n += 1
	return n
