extends "res://tests/helper.gd"
## 其の三「蟲」。尾だけに矢が通り、頭と節は矢をはね返す。

func _shoot_at(target: Node2D) -> void:
	## 狙いを外さないよう、相手のすぐ手前から射る。
	var s = Shot.new()
	s.stage = stage
	s.text = "矢"
	s.dir = Vector2.UP
	## 相手が岩の上を這っていることもあるので、地形では止めない。
	s.hits_walls = false
	s.speed = 600.0
	s.reach = 16.0
	s.position = target.position + Vector2(0, 14)
	stage.world.add_child(s)
	await sleep(0.1)

func _test() -> void:
	await open("res://scenes/stage3.tscn")
	var hero = stage.hero
	hero.max_hp = 99
	hero.hp = 99

	await face("left")
	await tap("act")
	check(hero.holding("弓"), "宝箱から弓が出た")
	check(stage._awake, "弓を取ると蟲が現れる")
	await until(func(): return stage.mode == "talk", 4.0)
	await finish_talk()
	await until(func(): return stage.mode == "play", 3.0)
	check(stage._segs.size() == 6 and stage._segs[-1].text == "尾", "節が 6 つ、最後が尾")

	## 弓を引き絞って放つと矢が飛ぶ。
	await hold("act", 0.9)
	await sleep(0.05)
	var arrows := 0
	for n in stage.world.get_children():
		if n is Shot and not n.hostile:
			arrows += 1
	check(arrows >= 1, "引き絞って離すと矢が飛ぶ")

	## 出てきた直後は節が穴に重なっているので、蟲が伸びきるまで待つ。
	await sleep(2.5)
	## 尾にかすった矢は尾に当たった扱いになるので、尾が離れているときに撃つ。
	var n0: int = stage._segs.size()
	await until(func(): return stage._segs[-1].position.distance_to(stage._head.position) > 60.0, 5.0)
	await _shoot_at(stage._head)
	check(stage._segs.size() == n0, "頭に当てても効かない")
	await until(func(): return stage._segs[-1].position.distance_to(stage._segs[0].position) > 60.0, 5.0)
	await _shoot_at(stage._segs[0])
	check(stage._segs.size() == n0, "節に当てても効かない")
	await _shoot_at(stage._segs[-1])
	check(stage._segs.size() == n0 - 1 and stage._segs[-1].text == "尾", "尾に当てると節が減り、新しい尾ができる")

	for i in 60:
		if stage._segs.is_empty():
			break
		await _shoot_at(stage._segs[-1])
		await sleep(0.3)
	check(stage._head.color == stage.COL_TAIL, "節が無くなると頭が弱点になる")
	await _shoot_at(stage._head)
	check(stage._dead, "頭を射ると蟲が倒れる")
	await until(func(): return stage.mode == "play", 5.0)
	check(stage.goal() != null and stage.goal().text == "穴", "穴が目標になる")

	## 毒で押し戻されていることがあるので、始めの場所から歩く。
	hero.position = cell(12, 11)
	check(await walk_to(stage.goal().position, true, 4.0, 20.0), "穴まで歩ける")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
