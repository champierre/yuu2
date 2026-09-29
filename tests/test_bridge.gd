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
