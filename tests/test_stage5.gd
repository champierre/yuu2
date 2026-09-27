extends "res://tests/helper.gd"
## 其の五「森」。見張りの前の茂みの切れ目を、森と林で埋めて通る。

func _take_tree() -> void:
	await face("up")
	await tap("act")

func _test() -> void:
	await open("res://scenes/stage5.tscn")
	var hero = stage.hero
	var patrol = stage._guards[1]
	var sentry = stage._guards[0]

	## 巡る見張りの真正面に出ると見つかって、入口へ戻される。
	hero.position = patrol.position + patrol.facing * 60.0
	await until(func(): return stage._caught, 3.0)
	check(stage._caught, "見張りの正面に出ると見つかる")
	await until(func(): return stage.mode == "play", 4.0)
	check(hero.position.distance_to(stage._start) < 2.0, "入口へ戻された")

	## ここから先は庭の謎を確かめる。巡る見張りには左の端で休んでもらう。
	patrol.route = []
	patrol.position = cell(3, 9)
	patrol.facing = Vector2.LEFT
	check(await walk_path([cell(2, 11), cell(23, 11), cell(24, 11), cell(24, 3), cell(21, 2)]), "庭の入口まで歩ける")

	for i in 2:
		await _take_tree()
	check(hero.hands == ["木", "木"], "苗から木を二本取った")
	await craft()
	check(hero.holding("林"), "木＋木＝林")
	await _take_tree()
	await craft()
	check(hero.holding("森"), "林＋木＝森")

	## 茂みの切れ目の手前（茂みの中）から、左へ森を植える。
	check(await walk_path([cell(21, 4), cell(15, 4)]), "茂みの端まで隠れて歩ける")
	check(not stage._caught, "ここまでは見つかっていない")
	await face("left")
	await tap("act")
	check(stage._cover.has(Vector2i(14, 4)) and stage._cover.has(Vector2i(12, 4)), "森を植えた（3 マス）")

	## まだ 1 マス足りない。真ん中を抜けようとすると見つかる。
	check(await walk_to(cell(12, 4)), "植えた森の中を歩ける")
	check(not stage._caught, "森の中なら見つからない")
	await walk_to(cell(11, 4), false, 4.0, 1.5)
	await until(func(): return stage._caught, 2.0)
	check(stage._caught, "切れ目に出ると見つかる")
	await until(func(): return stage.mode == "play", 4.0)

	## 林を作って、残りの 1 マスを埋める。
	check(await walk_to(cell(21, 2)), "庭へ戻る")
	for i in 2:
		await _take_tree()
	await craft()
	check(await walk_path([cell(21, 4), cell(12, 4)]), "森の中まで戻る")
	await face("left")
	await tap("act")
	check(stage._cover.has(Vector2i(11, 4)), "林を植えた")
	check(await walk_path([cell(4, 4), stage.goal().position]), "隠れたまま城の奥へ")
	check(not stage._caught, "見つからずに通れた")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
