extends "res://tests/helper.gd"
## 曲（BGM）。終の章の決戦は、其の三の蟲戦とは別の長い曲で、
## 魔の段階が進むと、同じ旋律のまま太鼓だけが厚くなる（#62）。

var sfx: Node

func _test() -> void:
	sfx = root.get_node("Sfx")
	var songs: Dictionary = sfx.SONGS

	## 曲の作り。旋律の長さは、低音と太鼓の繰り返しで割り切れること（つなぎ目でずれない）。
	for name in ["final", "final2", "final3"]:
		var mel := _tok(songs[name]["mel"])
		var ok := true
		for part in ["bass", "drum"]:
			var n := _tok(songs[name][part]).size()
			if n > 0 and mel.size() % n != 0:
				ok = false
		check(ok, "%s は、旋律が低音と太鼓の繰り返しで割り切れる" % name)

	check(_secs("final") >= 20.0 and _secs("final") > _secs("battle") * 1.5, "決戦の曲は、蟲戦の曲よりずっと長い（%.1f 秒）" % _secs("final"))
	check(songs["final"]["mel"] != songs["battle"]["mel"], "決戦の曲は、蟲戦の曲とは別の旋律")
	for name in ["final2", "final3"]:
		check(songs[name]["mel"] == songs["final"]["mel"] and songs[name]["bass"] == songs["final"]["bass"] \
			and songs[name]["bpm"] == songs["final"]["bpm"], "%s は final と同じ旋律・同じ速さ" % name)
	check(_hits("final") < _hits("final2") and _hits("final2") < _hits("final3"), "段階が進むほど、太鼓が厚い")

	## 作ってみる（テストでは音を鳴らさないが、作る手続きは直に呼べる）。
	await sfx._render_song("final")
	await sfx._render_song("final2")
	var a: AudioStreamWAV = sfx._bgm_cache["final"]
	var b: AudioStreamWAV = sfx._bgm_cache["final2"]
	check(absf(a.get_length() - _secs("final")) < 0.1, "作った曲の長さが合っている（%.2f 秒）" % a.get_length())
	check(is_equal_approx(a.get_length(), b.get_length()), "final と final2 は同じ長さ")
	check(a.loop_mode == AudioStreamWAV.LOOP_FORWARD, "繰り返して鳴る")
	check(a.data != b.data, "太鼓が違うので、音は別もの")
	check(sfx._tune_cache.size() == 1, "旋律は一度だけ作って、使い回す")
	check(_clipped(a) < 0.01 and _clipped(b) < 0.01, "音が割れていない（頭打ちは 1% 未満）")

	## 同じ旋律の曲へは、頭からではなく、同じ所から乗り換える。
	sfx._silent = false
	sfx.bgm("final")
	await sleep(0.4)
	var head: int = sfx._bgm_head_usec
	check(sfx._bgm_now == "final" and sfx._bgm.stream == a, "final が鳴っている")
	sfx.bgm("final2", true)
	check(sfx._bgm_now == "final2" and sfx._bgm.stream == b, "final2 に乗り換えた")
	check(absi(sfx._bgm_head_usec - head) < 1000, "曲の頭の時刻は変わらない（同じ所から続く）")
	## ふつうの切り替えは、頭から。
	await sleep(0.3)
	sfx.bgm("final", false)
	check(sfx._bgm_head_usec - head > 300000, "ふつうに切り替えると、頭から鳴る")
	sfx.bgm("")
	check(sfx.bgm_wanted() == "" and sfx._bgm_now == "", "止めると、鳴っている曲は無い")
	sfx._silent = true

	## ふつうのステージは、クリアで曲を止める（クリアの音を聞かせる）。
	await open("res://scenes/stage1.tscn")
	check(sfx.bgm_wanted() == "field", "其の一は野の曲")
	stage.add_goal(stage.hero.position)
	stage.clear()
	await sleep(0.1)
	check(sfx.bgm_wanted() == "", "ふつうのステージは、クリアで曲を止める")

func _tok(s: String) -> PackedStringArray:
	return s.split(" ", false)

## 1 周の長さ（秒）。
func _secs(name: String) -> float:
	var song: Dictionary = sfx.SONGS[name]
	return _tok(song["mel"]).size() * 60.0 / float(song["bpm"]) / 2.0

## 太鼓を打つ数（1 回りの中で）。
func _hits(name: String) -> int:
	var n := 0
	for t in _tok(sfx.SONGS[name]["drum"]):
		if t != ".":
			n += 1
	return n

## 頭打ちになっている（音が割れている）割合。
func _clipped(w: AudioStreamWAV) -> float:
	var n := w.data.size() / 2
	var hit := 0
	for i in range(0, n, 7):
		if absi(w.data.decode_s16(i * 2)) >= 32700:
			hit += 1
	return float(hit) / (n / 7.0)
