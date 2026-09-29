extends "res://tests/helper.gd"
## 終の章「明」。日＋月＝明 の光で闇をはがし、弓で魔を討つ。

func _shoot_at(target: Node2D) -> void:
	var s = Shot.new()
	s.stage = stage
	s.text = "矢"
	s.dir = Vector2.UP
	## 相手が岩の上を這っていることもあるので、地形では止めない。
	s.hits_walls = false
	s.speed = 600.0
	s.reach = 80.0
	s.position = target.position + Vector2(0, 30)
	stage.glow_layer().add_child(s)
	await sleep(0.12)

func _test() -> void:
	await open("res://scenes/stage6.tscn")
	await until(func(): return stage.mode == "talk", 3.0)
	await finish_talk()
	await until(func(): return stage.mode == "play", 3.0)
	var hero = stage.hero
	hero.max_hp = 99
	hero.hp = 99

	check(await walk_path([cell(12, 11), cell(4, 11), cell(3, 9)]), "日の祭壇まで歩ける")
	await face("up")
	await tap("act")
	check(hero.holding("日"), "日を取った")
	check(await walk_path([cell(3, 11), cell(22, 11), cell(22, 9)]), "月の祭壇まで歩ける")
	await face("up")
	await tap("act")
	check(hero.holding("月"), "月を取った")
	await craft()
	check(hero.holding("明"), "日＋月＝明")

	var hp0: int = stage._hp
	await _shoot_at(stage._boss)
	check(stage._hp == hp0, "闇をまとっている間は、矢が届かない")

	check(await walk_path([cell(22, 11), cell(14, 11), cell(14, 12)]), "宝箱の前へ")
	await face("left")
	await tap("act")
	check(hero.holding("弓") and hero.holding("明"), "明と弓を両手に持った")

	## 明を持って魔に近づくと、闇がはがれる。
	for i in 60:
		if not stage._shield_up:
			break
		await walk_to(stage._boss.position + Vector2(0, 110), false, 6.0, 0.5)
	check(not stage._shield_up, "明を持って近づくと闇がはがれる")
	for i in 12:
		if stage._defeated:
			break
		hero.position = stage._boss.position + Vector2(0, 110)
		await sleep(0.05)
		await _shoot_at(stage._boss)
	check(stage._defeated, "魔を討った")
	await until(func(): return stage.mode == "talk", 5.0)
	await finish_talk()
	await until(func(): return stage.goal() != null and stage.mode == "play", 8.0)
	check(stage.goal() != null and stage.goal().text == "光", "光が現れた")
	## 戦いのあとの勇者は、魔に押し戻されてどこにいるか分からない。光のすぐそばから歩く。
	## 光が柱の近くに出ることもあるので、空いている側を選ぶ。
	var free := false
	for off in [Vector2(0, 30), Vector2(0, -30), Vector2(30, 0), Vector2(-30, 0)]:
		hero.position = stage.goal().position + off
		if not stage.blocked(hero.rect()):
			free = true
			break
	check(free, "光のそばに空いている所がある")
	check(await walk_to(stage.goal().position, false, 4.0, 15.0), "光まで歩ける")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
