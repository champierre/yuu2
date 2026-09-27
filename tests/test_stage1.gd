extends "res://tests/helper.gd"
## 其の一「斧」を、キーで歩いて通しで解く。

func _test() -> void:
	await open("res://scenes/stage1.tscn")
	var hero = stage.hero

	check(stage.blocked(Rect2(cell(15, 7) - Vector2(4, 4), Vector2(8, 8))), "はじめは川を渡れない")

	check(await walk_to(cell(5, 4)), "父の前まで歩ける")
	await tap("act")
	check(stage.mode == "talk", "父と話せる")
	await finish_talk()
	check(hero.holding("父"), "父を手にした")

	check(await walk_to(cell(8, 10)), "宝箱の前まで歩ける")
	await tap("act")
	check(hero.holding("斤"), "宝箱から斤が出た")

	await craft()
	check(hero.holding("斧") and hero.hands.size() == 1, "父＋斤＝斧")
	check(stage.get_node("/root/Game").discovered.has("斧"), "字典に斧が載った")

	check(await walk_to(cell(13, 7), true), "大木の前まで歩ける")
	await face("right")
	for i in 3:
		await tap("act")
		await sleep(0.5)
	await until(func(): return stage.mode == "play", 3.0)
	check(stage._felled, "大木が倒れた")
	check(not stage.blocked(Rect2(cell(15, 7) - Vector2(4, 4), Vector2(8, 8))), "倒木の上は歩ける")

	check(await walk_to(stage.goal().position), "橋を渡って目標まで歩ける")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
