extends "res://tests/helper.gd"
## 其の四の光の橋は、勇者のいる岸から 1 マスずつ架かり、架かりきったら知らせること（#51）。
## 渡れるようになるのは、燭が灯った瞬間（見た目だけを順に出す）。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var near := Vector2i(17, 6)   ## 勇者のいる岸の側
	var far := Vector2i(18, 6)    ## 燭の側
	var candle = null
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(19, 5):
			candle = c
	stage._light_candle(candle)
	await sleep(0.05)
	check(stage.solid_at(near) == 0 and stage.solid_at(far) == 0, "燭が灯った瞬間に、橋は渡れるようになる")
	check(stage._bridges[near].text == "橋" and stage._bridges[far].text == "淵", "橋は勇者のいる岸の側から架かる")
	await sleep(0.6)
	check(stage._bridges[far].text == "橋", "やがて燭の側まで架かる")
	check("光の橋" in stage.hud._toast.text, "架かりきったら「光の橋が架かった」と知らせる（「%s」）" % stage.hud._toast.text)

	## 橋の燭が最後の 1 本なら、「すべての灯」の知らせが消えずに残る。
	for c in stage._candles:
		if stage.cell_of(c.position) != Vector2i(29, 14):
			stage._light_candle(c)
	await sleep(0.8)
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(29, 14):
			stage._light_candle(c)
	await sleep(0.8)
	check("すべての灯" in stage.hud._toast.text, "最後が橋の燭でも、すべて灯ったことが伝わる（「%s」）" % stage.hud._toast.text)
