extends SceneTree
## テストの土台。各テストはこれを継承して _test() を書く。
##
##   godot --headless --path . --script tests/test_stage1.gd
##
## 待つときは実時間で測る（ヘッドレスは 1 コマが極端に短いため、コマ数では測れない）。

var stage: Node = null
var _failed := false

func _initialize() -> void:
	_main()

func _main() -> void:
	## autoload の _ready（記録を読む）が済んでから、テスト用の記録に切り替える。
	await process_frame
	var game := root.get_node("Game")
	game.save_path = "user://test_save.cfg"
	game.wipe()
	await _test()
	if _failed:
		print("FAIL")
		quit(1)
	else:
		print("OK")
		quit(0)

func _test() -> void:
	pass

func open(scene: String) -> void:
	change_scene_to_file(scene)
	await process_frame
	await process_frame
	stage = current_scene
	## 題が消えて遊べるようになるまで待つ。
	await until(func(): return stage.mode == "play", 3.0)

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_failed = true

## 秒数だけ待つ。
func sleep(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < sec * 1000.0:
		await physics_frame

## 条件が満たされるまで待つ。満たされたら true。
func until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < timeout * 1000.0:
		if cond.call():
			return true
		await physics_frame
	return false

## ボタンを一瞬押す。
func tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame
	await process_frame

## ボタンを押し続ける。
func hold(action: String, sec: float) -> void:
	Input.action_press(action)
	await sleep(sec)
	Input.action_release(action)

func release_all() -> void:
	for a in ["left", "right", "up", "down", "act", "craft"]:
		Input.action_release(a)

## 勇者を歩かせて target に近づける（地形を飛び越えずに、キーで歩く）。
## まず x を合わせてから y を合わせる。first_y なら逆。
func walk_to(target: Vector2, first_y := false, tol := 4.0, timeout := 12.0) -> bool:
	var hero: Node2D = stage.hero
	var t0 := Time.get_ticks_msec()
	var axes := ["y", "x"] if first_y else ["x", "y"]
	## 押し戻されたり角で滑ったりしてずれることがあるので、何度か合わせ直す。
	for round in 3:
		if hero.position.distance_to(target) <= tol * 1.5:
			break
		await _walk_axes(target, axes, tol, t0, timeout)
	await sleep(0.05)
	## 目標に触れるとクリアになって、勇者はその場で止まる。それは着いたことにする。
	if stage.mode == "clear":
		return true
	return hero.position.distance_to(target) <= tol * 2.0

func _walk_axes(target: Vector2, axes: Array, tol: float, t0: int, timeout: float) -> void:
	var hero: Node2D = stage.hero
	for ax in axes:
		while (Time.get_ticks_msec() - t0) < timeout * 1000.0:
			if stage.mode == "clear":
				break
			var d: float = target[ax] - hero.position[ax]
			if absf(d) <= tol:
				break
			var a: String
			if ax == "x":
				a = "right" if d > 0 else "left"
			else:
				a = "down" if d > 0 else "up"
			Input.action_press(a)
			await physics_frame
			Input.action_release(a)
		release_all()

## 地図をたどって通れる道を探し、そのマス目に沿って target のマスまで歩く。
## 決め打ちの道筋だと、出発する場所によっては壁や家に突き当たるので、こちらを使う。
func walk_route(target: Vector2i) -> bool:
	var start: Vector2i = stage.cell_of(stage.hero.position)
	var prev := {start: start}
	var q := [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == target:
			break
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if prev.has(n) or stage.solid_at(n) != stage.FREE:
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(target):
		print("    道が見つからない ", start, " -> ", target)
		return false
	var path := []
	var c: Vector2i = target
	while c != start:
		path.push_front(c)
		c = prev[c]
	## 向きが変わる所だけを経由地にする。
	var points := []
	for i in path.size():
		var last := i == path.size() - 1
		if last or (path[i + 1] - path[i]) != (path[i] - (path[i - 1] if i > 0 else start)):
			points.append(stage.cell_center(path[i]))
	## まず今いるマスの真ん中へ寄せる（マスの端にいると角に引っかかる）。
	await walk_to(stage.cell_center(start), false, 3.0, 2.0)
	for p in points:
		if not await walk_to(p, false, 3.0, 6.0):
			print("    walk stuck near ", stage.hero.position, " -> ", p)
			return false
	return true

## 経由地を順にたどる。
func walk_path(points: Array, first_y := false) -> bool:
	for p in points:
		if not await walk_to(p, first_y):
			print("    walk stuck near ", stage.hero.position, " -> ", p)
			return false
	return true

## 敵が触れても命を削らないようにする（道筋を確かめるテスト用）。
func tame_enemies() -> void:
	for e in stage.get_tree().get_nodes_in_group("enemy"):
		e.harm = 0

## 敵を片づける（矢の通り道をふさがれないように）。
func clear_enemies() -> void:
	for e in stage.get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

func cell(x: int, y: int) -> Vector2:
	return stage.cell_center(Vector2i(x, y))

## 向きを変える（1 コマだけ押す）。
func face(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await sleep(0.05)

## 両手の字を合わせ、出てきた札を閉じる。
func craft() -> void:
	await tap("craft")
	await until(func(): return stage.get_tree().paused, 3.0)
	await sleep(0.6)
	await tap("act")
	await until(func(): return stage.mode == "play" and not stage.get_tree().paused, 3.0)

## 会話をすべて送る。
func finish_talk() -> void:
	for i in 30:
		if stage.mode != "talk":
			return
		await tap("act")
		await sleep(0.05)
