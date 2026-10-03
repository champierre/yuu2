extends "res://tests/helper.gd"
## クリアのあとの行き先（#58）。
## 「ステージを選ぶ」から始めた面では、クリアのあと「次へ」か「ステージを選ぶ」かを選べる。
## 隠れた字を探しに戻った人が、次のステージやエンディングへ押し出されない。
## 「始」から通して遊んでいるときは、今までどおり「次へ」だけ。

var game: Node

func _test() -> void:
	game = root.get_node("Game")

	## 「始」から始めた面は、「次へ」だけ。決定で次のステージへ進む。
	await _open_title()
	var title := current_scene
	title._choose_menu(0)
	await tap("act")   ## 物語を出しきる
	await tap("act")   ## はじめる
	await _wait_stage(1)
	check(not game.from_select, "「始」から始めた面は、選んで始めた面ではない")
	await _clear()
	check(stage._clear_items.is_empty(), "「始」から始めた面は、「次へ」だけ")
	await tap("ui_right")
	await tap("act")
	await _wait_stage(2)
	check(stage.number() == 2, "決定で次のステージへ進む")

	## ステージを選んで始めた面。初めてのクリアなら「次へ」を先に指す。
	game.wipe()
	await _pick_stage(1)
	check(game.from_select, "ステージを選んで始めたことを覚えている")
	await _clear()
	check(stage._clear_items.size() == 2, "選んで始めた面は、行き先を二つから選べる")
	check(stage._clear_items[0].text == "▶ 次へ" and stage._clear_items[1].text == "ステージを選ぶ", "初めてのクリアは「次へ」を指している")
	await tap("ui_right")
	check(stage._clear_sel == 1 and stage._clear_items[1].text == "▶ ステージを選ぶ", "右で「ステージを選ぶ」に移る")
	await tap("ui_left")
	check(stage._clear_sel == 0, "左で「次へ」に戻る")
	await tap("ui_right")
	await tap("act")
	await _wait_title()
	title = current_scene
	check(title._screen == "stages", "「ステージを選ぶ」で、選ぶ画面に戻る")
	check(title._sel == 0, "いま遊んだ面を指している")
	check(not game.title_to_select, "選ぶ画面に戻るのは一度きり")

	## もう一度同じ面をクリアすると、今度は「ステージを選ぶ」を先に指す。
	await sleep(0.5)
	await tap("act")
	await _wait_stage(1)
	await _clear()
	check(stage._clear_sel == 1, "前にもクリアした面は「ステージを選ぶ」を指している")
	## 「次へ」を選べば、次のステージへ進める。選んで始めたことは引き継ぐ。
	await tap("ui_left")
	await tap("act")
	await _wait_stage(2)
	check(stage.number() == 2 and game.from_select, "「次へ」で次のステージへ進む")

	## 終の章を選んでクリアし直しても、エンディングを見ずに選ぶ画面へ戻れる。
	for s in game.STAGES:
		game.cleared[s["no"]] = 100.0
	await _pick_stage(6)
	await _clear()
	check(stage._clear_items[0].get_meta("base") == "エンディングへ", "終の章の「次へ」は「エンディングへ」")
	check(stage._clear_sel == 1, "終の章もクリアし直しなら「ステージを選ぶ」を指している")
	await tap("act")
	await _wait_title()
	title = current_scene
	check(title.name == "Title" and title._screen == "stages", "終の章から、エンディングを見ずに選ぶ画面へ戻る")
	check(title._sel == 5, "終の章を指している")

	## 選ぶ画面から戻ると、ふつうのメニューになる。
	await sleep(0.5)
	await tap("pause")
	check(title._screen == "menu", "選ぶ画面から戻るとメニュー")

	## ふつうにタイトルへ戻ったときは、メニューから始まる。
	await _open_title()
	check(current_scene._screen == "menu", "ふつうにタイトルを開くとメニュー")

func _open_title() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.5)

## タイトルから「ステージを選ぶ」で no 番の面を始める。
func _pick_stage(no: int) -> void:
	await _open_title()
	var title := current_scene
	await tap("ui_down")
	await tap("act")
	check(title._screen == "stages", "ステージを選ぶ画面が開く")
	for i in no - 1:
		await tap("ui_down")
	await tap("act")
	await _wait_stage(no)

func _wait_stage(no: int) -> void:
	await until(func(): return not game.is_changing() and current_scene != null \
		and current_scene.has_method("number") and current_scene.number() == no, 5.0)
	stage = current_scene
	## 入ってすぐ話が始まる面（終の章）は、話を送ってから。
	await until(func(): return stage.mode == "play" or stage.mode == "talk", 4.0)
	await finish_talk()
	await until(func(): return stage.mode == "play", 4.0)

func _wait_title() -> void:
	await until(func(): return not game.is_changing() and current_scene != null \
		and current_scene.name == "Title", 5.0)

## その場でクリアにして、行き先を選べるようになるまで待つ。
func _clear() -> void:
	stage.add_goal(stage.hero.position)
	stage.clear()
	await until(func(): return stage._clear_ready, 5.0)
