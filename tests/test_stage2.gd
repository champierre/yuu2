extends "res://tests/helper.gd"
## 其の二「鉄」を通しで解く。わざと盗人に金を奪わせるのが答え。

func _test() -> void:
	await open("res://scenes/stage2.tscn")
	var hero = stage.hero

	check(await walk_to(cell(21, 12)), "宝箱の前まで歩ける")
	await face("up")
	await tap("act")
	check(hero.holding("金"), "宝箱から金が出た")

	check(stage.solid_at(Vector2i(12, 5)) != 0, "門は閉じている")

	## 盗人に近づいて、金を奪わせる。
	var robbed := false
	for i in 40:
		if stage._robbed:
			robbed = true
			break
		if is_instance_valid(stage._thief):
			await walk_to(stage._thief.position, false, 6.0, 1.0)
		await sleep(0.05)
	check(robbed, "盗人に金を奪われる")
	await until(func(): return stage.mode == "talk", 3.0)
	await finish_talk()
	check(hero.holding("失") and not hero.holding("金"), "手に失が残る")

	check(await walk_to(cell(21, 12)), "もう一度宝箱の前へ")
	await face("up")
	await tap("act")
	check(hero.holding("金") and hero.holding("失"), "金と失を持った")

	await craft()
	check(hero.holding("鉄"), "金＋失＝鉄")

	check(await walk_to(cell(11, 7)), "門番の前へ")
	await face("up")
	await tap("act")
	await finish_talk()
	await until(func(): return stage.mode == "play", 3.0)
	check(stage._gate_open and stage.solid_at(Vector2i(12, 5)) == 0, "鉄を見せると門が開く")

	check(await walk_to(stage.goal().position), "門を抜けて目標まで歩ける")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
