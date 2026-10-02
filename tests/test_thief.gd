extends "res://tests/helper.gd"
## 其の二の盗人は、自分からは寄ってこない。
## 金を持って近づいても、立ち止まってうかがうだけ。奪わせるかどうかは遊ぶ人が決める（#7）。

func _test() -> void:
	await open("res://scenes/stage2.tscn")
	var hero = stage.hero
	var thief = stage._thief
	## 盗人を開けた所に置き、金を持った勇者を 60px 離れた所に立たせる。
	thief.position = cell(8, 11)
	hero.position = thief.position + Vector2(60, 0)
	hero.set_hands(["金"])
	await sleep(3.0)
	check(not stage._robbed, "金を持って近くに立っていても、盗人は寄ってこない")
	check(thief.position.distance_to(hero.position) > 40.0, "盗人は離れたまま")

	## 自分から盗人へ歩いていくと、奪われる。
	await walk_to(thief.position, false, 6.0, 3.0)
	await until(func(): return stage._robbed, 2.0)
	check(stage._robbed, "自分から近づくと奪われる")
	await until(func(): return stage.mode == "talk", 3.0)
	await finish_talk()
	check(hero.holding("失") and not hero.holding("金"), "手に失が残る")
