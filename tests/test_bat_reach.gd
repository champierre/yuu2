extends "res://tests/helper.gd"
## 其の四の蝙は、どれも岩に閉じ込められていないこと。
## 蝙は岩を越えられないが、淵の上は飛べる。どの蝙からも目標まで飛んで行けるか、地図をたどって確かめる。

func _reachable(from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			return true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			var k: int = stage.solid_at(n)
			if k == stage.FREE or k == stage.WATER:
				seen[n] = true
				q.append(n)
	return false

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	var goal_cell: Vector2i = stage.cell_of(stage.goal().position)
	var trapped := []
	for e in stage.get_tree().get_nodes_in_group("enemy"):
		var c: Vector2i = stage.cell_of(e.position)
		if not _reachable(c, goal_cell):
			trapped.append(c)
	check(trapped.is_empty(), "どの蝙も岩に閉じ込められていない（閉じ込められている所 %s）" % [trapped])
