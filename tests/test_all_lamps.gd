extends "res://tests/helper.gd"
## 其の四は、すべての燭を灯さないとクリアできないこと。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var hero = stage.hero
	var goal = stage.goal()
	check(stage._candles.size() == 6, "燭は 6 本")

	## 一部だけ灯して目標に触れても、クリアにならない。
	stage._light_candle(stage._candles[0])
	stage._light_candle(stage._candles[1])
	hero.position = goal.position
	await sleep(0.4)
	check(stage.mode == "play", "灯っていない燭があると、目標に触れてもクリアにならない")
	check("まだ灯っていない燭" in stage.hud._toast.text, "まだ灯っていない燭があると知らせる（「%s」）" % stage.hud._toast.text)

	## いったん離れて、残りをすべて灯してから触れると、クリアになる。
	hero.position = goal.position + Vector2(-60, 0)
	await sleep(0.2)
	for c in stage._candles:
		stage._light_candle(c)
	await sleep(0.2)
	check("すべての灯" in stage.hud._toast.text, "最後の燭を灯すと知らせる（「%s」）" % stage.hud._toast.text)
	hero.position = goal.position
	await sleep(0.4)
	check(stage.mode == "clear", "すべて灯してから目標に触れると、クリアになる")
