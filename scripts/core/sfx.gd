extends Node
## autoload `Sfx`。効果音と BGM を、音の素材を使わずにその場で作って鳴らす。
##
## 効果音は起動時にまとめて作る（どれも短いので一瞬で済む）。
## BGM は琴の音（Karplus-Strong）で組むので少し重い。
## 何コマかに分けて作り、できあがったら鳴らす。

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _bgm: AudioStreamPlayer
var _bgm_cache := {}
var _bgm_want := ""
var _bgm_building := {}
## いま鳴っている曲と、その頭が鳴った時刻（マイクロ秒）。
## 同じ旋律の別の曲へ、同じ所から乗り換えるのに使う（bgm() の keep_pos）。
var _bgm_now := ""
var _bgm_head_usec := 0
var _bgm_fade: Tween
## 旋律と低音だけを先に組んだもの。太鼓だけが違う曲は、これを使い回す。
var _tune_cache := {}
var _tune_building := {}
var _pluck_cache := {}
## 画面を持たない（テストの）ときは音を作らない。時間がかかるだけなので。
var _silent := false

var sfx_volume_db := -6.0
var bgm_volume_db := -10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)
	if _silent:
		return
	_make_sounds()

# ---------------------------------------------------------------- 鳴らす

func play(sound: String, pitch := 1.0, vol_db := 0.0) -> void:
	if _silent or not _sounds.has(sound):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = sfx_volume_db + vol_db
	p.play()

## BGM を切り替える。まだ作っていなければ作ってから鳴らす。
##
## keep_pos が true なら、頭からではなく、いま鳴っている曲と同じ所から鳴らす。
## 旋律が同じで太鼓だけが違う曲（final → final2 → final3）へ、途切れずに移るため。
## 長さが違う曲へは、ふつうに頭から鳴らす。
func bgm(song: String, keep_pos := false) -> void:
	if song == _bgm_want:
		return
	## 音を作らないテストでも、どの曲を頼まれたかは覚えておく。
	_bgm_want = song
	if _silent:
		return
	if song == "":
		_fade_out_bgm()
		return
	if _bgm_cache.has(song):
		_start_bgm(song, keep_pos)
		return
	if not _bgm_building.has(song):
		_bgm_building[song] = true
		await _render_song(song)
		_bgm_building.erase(song)
	if _bgm_want == song:
		_start_bgm(song, keep_pos)

## いま頼まれている曲（"" は無音）。
func bgm_wanted() -> String:
	return _bgm_want

## 次に使いそうな曲を先に作っておく。
func prepare(song: String) -> void:
	if _silent or _bgm_cache.has(song) or _bgm_building.has(song):
		return
	_bgm_building[song] = true
	await _render_song(song)
	_bgm_building.erase(song)

func _start_bgm(song: String, keep_pos := false) -> void:
	var stream: AudioStreamWAV = _bgm_cache[song]
	var now := Time.get_ticks_usec()
	var from := 0.0
	if keep_pos and _bgm_now != "" and _bgm_cache.has(_bgm_now) \
			and is_equal_approx(_bgm_cache[_bgm_now].get_length(), stream.get_length()):
		from = fmod((now - _bgm_head_usec) / 1000000.0, stream.get_length())
	## 消えかけの前の曲が、鳴らし始めた曲を止めてしまわないように。
	if _bgm_fade != null and _bgm_fade.is_valid():
		_bgm_fade.kill()
	_bgm_now = song
	_bgm_head_usec = now - int(from * 1000000.0)
	_bgm.stream = stream
	if from > 0.0:
		## 同じ曲の続きなので、音を絞らずにそのまま乗り換える。
		_bgm.volume_db = bgm_volume_db
		_bgm.play(from)
		return
	_bgm.volume_db = -40.0
	_bgm.play()
	_bgm_fade = create_tween()
	_bgm_fade.tween_property(_bgm, "volume_db", bgm_volume_db, 0.6)

func _fade_out_bgm() -> void:
	_bgm_now = ""
	if _bgm_fade != null and _bgm_fade.is_valid():
		_bgm_fade.kill()
	_bgm_fade = create_tween()
	_bgm_fade.tween_property(_bgm, "volume_db", -40.0, 0.5)
	_bgm_fade.tween_callback(_bgm.stop)

# ---------------------------------------------------------------- 効果音を作る

func _make_sounds() -> void:
	_sounds["blip"] = _wav(_tone(0.035, 900, 900, "sq", 0.12))
	_sounds["select"] = _wav(_tone(0.05, 1320, 1320, "sq", 0.12))
	_sounds["confirm"] = _wav(_cat([_tone(0.06, 880, 880, "sq", 0.15), _tone(0.1, 1320, 1320, "sq", 0.15)]))
	_sounds["pick"] = _wav(_cat([_tone(0.05, 700, 1000, "tri", 0.35), _tone(0.09, 1400, 1400, "tri", 0.3)]))
	_sounds["drop"] = _wav(_tone(0.1, 500, 250, "tri", 0.3))
	_sounds["fail"] = _wav(_tone(0.2, 220, 110, "saw", 0.2))
	_sounds["craft"] = _wav(_mix(
		_cat([_tone(0.07, 523, 523, "sq", 0.12), _tone(0.07, 659, 659, "sq", 0.12),
			_tone(0.07, 784, 784, "sq", 0.12), _tone(0.3, 1047, 1047, "sq", 0.12)]),
		_delay(_tone(0.5, 2093, 2093, "sin", 0.12, 3.0), 0.2)))
	_sounds["open"] = _wav(_mix(_noise(0.08, 0.2), _tone(0.2, 300, 600, "tri", 0.3)))
	_sounds["swing"] = _wav(_noise(0.12, 0.25, 2.0))
	_sounds["chop"] = _wav(_mix(_noise(0.1, 0.4), _tone(0.14, 140, 60, "sin", 0.6)))
	_sounds["fall"] = _wav(_mix(_noise(0.7, 0.35, 1.2), _tone(0.7, 80, 40, "sin", 0.6, 1.0)))
	_sounds["hurt"] = _wav(_tone(0.25, 440, 110, "sq", 0.2))
	_sounds["hit"] = _wav(_mix(_noise(0.07, 0.35), _tone(0.1, 260, 120, "sq", 0.18)))
	_sounds["clink"] = _wav(_mix(_tone(0.18, 2100, 2100, "sin", 0.2, 4.0), _tone(0.18, 2750, 2750, "sin", 0.12, 5.0)))
	_sounds["shoot"] = _wav(_mix(_noise(0.1, 0.2, 3.0), _tone(0.1, 500, 1200, "tri", 0.2)))
	_sounds["charge"] = _wav(_tone(0.04, 600, 600, "tri", 0.15))
	_sounds["enemy_die"] = _wav(_mix(_noise(0.4, 0.35, 1.5), _tone(0.4, 400, 60, "sq", 0.15)))
	_sounds["light"] = _wav(_tone(0.45, 300, 1200, "sin", 0.3, 1.2))
	_sounds["thief"] = _wav(_cat([_tone(0.07, 700, 650, "sq", 0.12), _silence(0.04),
		_tone(0.07, 620, 580, "sq", 0.12), _silence(0.04), _tone(0.1, 540, 480, "sq", 0.12)]))
	_sounds["alert"] = _wav(_cat([_tone(0.06, 1500, 1500, "sq", 0.15), _silence(0.03), _tone(0.12, 1900, 1900, "sq", 0.15)]))
	_sounds["roar"] = _wav(_mix(_tone(0.9, 90, 60, "saw", 0.3, 1.0), _noise(0.9, 0.2, 1.0)))
	_sounds["gate"] = _wav(_mix(_tone(0.5, 70, 70, "sq", 0.15, 1.0), _noise(0.5, 0.15, 1.0)))
	_sounds["pop"] = _wav(_tone(0.1, 700, 200, "sin", 0.4))
	_sounds["heal"] = _wav(_cat([_tone(0.08, 660, 660, "tri", 0.3), _tone(0.08, 880, 880, "tri", 0.3), _tone(0.2, 1320, 1320, "tri", 0.3)]))
	_sounds["death"] = _wav(_cat([_tone(0.15, 494, 494, "sq", 0.15), _tone(0.15, 440, 440, "sq", 0.15),
		_tone(0.15, 392, 392, "sq", 0.15), _tone(0.5, 294, 200, "sq", 0.15)]))
	_sounds["clear"] = _wav(_cat([_tone(0.1, 587, 587, "sq", 0.13), _tone(0.1, 698, 698, "sq", 0.13),
		_tone(0.1, 880, 880, "sq", 0.13), _tone(0.1, 1047, 1047, "sq", 0.13), _tone(0.5, 1175, 1175, "sq", 0.13, 1.0)]))
	_sounds["stamp"] = _wav(_mix(_noise(0.12, 0.5, 3.0), _tone(0.2, 120, 50, "sin", 0.8)))
	_sounds["bell"] = _wav(_mix(_tone(1.2, 880, 880, "sin", 0.25, 1.5), _tone(1.2, 2210, 2210, "sin", 0.1, 3.0)))
	_sounds["flap"] = _wav(_cat([_noise(0.05, 0.18, 2.5), _silence(0.03), _noise(0.05, 0.14, 2.5)]))
	_sounds["fire"] = _wav(_mix(_noise(0.25, 0.3, 1.5), _tone(0.25, 200, 500, "saw", 0.1)))

## 1 つの音。f0 から f1 へ滑らせる。env は減衰の強さ（大きいほど早く消える）。
func _tone(dur: float, f0: float, f1: float, wave: String, vol: float, env := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += f / RATE
		var x := ph - floorf(ph)
		var s := 0.0
		match wave:
			"sq": s = 1.0 if x < 0.5 else -1.0
			"tri": s = 4.0 * absf(x - 0.5) - 1.0
			"saw": s = 2.0 * x - 1.0
			_: s = sin(TAU * x)
		## 立ち上がりだけ少しなめらかにして、ぷつっという音を消す。
		var a := minf(1.0, i / 60.0)
		out[i] = s * vol * a * pow(1.0 - t, env)
	return out

func _noise(dur: float, vol: float, env := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		## 少しだけ低い方へ寄せる（ざらつきを和らげる）。
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.6)
		out[i] = prev * vol * pow(1.0 - t, env)
	return out

func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out

func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out

func _delay(a: PackedFloat32Array, sec: float) -> PackedFloat32Array:
	return _cat([_silence(sec), a])

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

# ---------------------------------------------------------------- BGM

## 音階。数字は 1 オクターブの中の半音の位置。
const SCALE_IN := [0, 1, 5, 7, 8]   ## 都節（みやこぶし）。もの悲しい
const SCALE_YO := [0, 2, 5, 7, 9]   ## 民謡の音階。明るい

## 終の章の決戦の曲。其の三の battle（12.8 秒）とは別の、24 秒の曲。
## はじめの 8 小節はタイトルの旋律を速めて追い立て、あとの 8 小節で高く上りつめる。
## 魔の段階が進むごとに、同じ旋律のまま太鼓だけを厚くする（final → final2 → final3）。
const FINAL_MEL := "7 . 8 7 10 . 9 8 7 . 5 7 8 . . . 7 . 8 7 10 . 12 11 10 . 9 8 7 . . . " \
	+ "5 7 8 7 5 7 8 10 9 . 8 7 8 . 5 . 3 5 7 5 3 5 7 8 7 . . . 5 . . . " \
	+ "12 . 12 11 10 . 9 8 10 . 10 9 8 . 7 5 7 8 10 8 7 8 10 12 13 . 12 . 10 . . . " \
	+ "12 . 12 11 10 . 9 8 10 . 12 . 13 . 15 . 14 13 12 10 9 8 7 5 7 . . . . . 5 7"
const FINAL_BASS := "0 0 . 0 0 . 0 . 0 0 . 0 0 . 2 . -2 -2 . -2 -2 . -2 . -1 -1 . -1 -1 . 2 3"

## 曲。mel / bass は 1 つが 8 分音符 1 つぶん。数字は音階の何番目か、「.」は休み。
## drum は k=太鼓（どん）、s=縁（かっ）、h=細かい刻み、o=大太鼓（どおん）。
const SONGS := {
	"title": {
		"bpm": 76, "root": 293.66, "scale": SCALE_IN,
		"mel": "7 . 8 . 10 . 9 8 7 . . . 5 . 7 . 8 . 7 5 4 . 5 . 3 . . . . . . . 7 . 8 . 10 . 12 11 10 . 9 . 8 . 7 . 8 . 9 8 7 . 5 . 7 . . . . . . .",
		"bass": "0 . . . . . . . 2 . . . . . . . 3 . . . . . . . 0 . . . . . . .",
		"drum": "",
	},
	"field": {
		"bpm": 112, "root": 293.66, "scale": SCALE_YO,
		"mel": "5 . 7 8 7 5 4 . 5 7 . 5 4 2 0 . 2 . 4 5 4 2 0 2 4 . . . . . . . 5 . 7 8 10 . 8 7 8 . 7 5 7 . . . 4 5 7 5 4 2 0 2 0 . . . . . . .",
		"bass": "0 . 4 . 0 . 4 . 3 . 7 . 3 . 7 . 1 . 5 . 1 . 5 . 0 . 4 . 0 . 4 .",
		"drum": "k . h . s . h . k . h k s . h .",
	},
	"battle": {
		"bpm": 150, "root": 293.66, "scale": SCALE_IN,
		"mel": "5 5 7 5 8 7 5 3 5 . 2 3 5 . . . 5 5 7 5 8 7 10 8 7 . 8 7 5 . . . 10 . 9 . 8 . 7 . 8 7 5 3 5 . 7 . 3 . 5 . 7 . 8 . 7 8 7 5 3 . 2 .",
		"bass": "0 0 . 0 0 . 3 . 0 0 . 0 1 . 2 . ",
		"drum": "k . s k k . s . k . s k k s s s",
	},
	"final": {
		"bpm": 160, "root": 220.0, "scale": SCALE_IN,
		"mel": FINAL_MEL, "bass": FINAL_BASS,
		"drum": "k . . . s . . . k . k . s . . .",
	},
	"final2": {
		"bpm": 160, "root": 220.0, "scale": SCALE_IN,
		"mel": FINAL_MEL, "bass": FINAL_BASS,
		"drum": "o . h . s . h k k . h k s . h s",
	},
	"final3": {
		"bpm": 160, "root": 220.0, "scale": SCALE_IN,
		"mel": FINAL_MEL, "bass": FINAL_BASS,
		"drum": "o h k h s h k k o h k h s k s s",
	},
	"cave": {
		"bpm": 70, "root": 220.0, "scale": SCALE_IN,
		"mel": "5 . . . . . 6 . 5 . . . 3 . . . . . . . . . . . 2 . 3 . . . . . . . . . . . . . 5 . . . 8 . . . 7 . . . . . . . . . . .",
		"bass": "0 . . . . . . . . . . . . . . . -1 . . . . . . . . . . . . . . .",
		"drum": "k . . . . . . . . . . . . . . .",
	},
	"stealth": {
		"bpm": 100, "root": 261.63, "scale": SCALE_IN,
		"mel": "5 . 6 . . . 5 . 3 . . . 2 . . . 5 . 6 . . . 8 . 7 . . . . . . . 5 . 6 . 5 . 3 . 2 . 3 . 0 . . . 2 . 1 . 0 . . . . . . . . . . .",
		"bass": "0 . . 0 . . 0 . 0 . . 0 . . 0 . -2 . . -2 . . -2 . -1 . . -1 . . -1 .",
		"drum": "h . . h . . s . h . . h . . . .",
	},
	"ending": {
		"bpm": 84, "root": 293.66, "scale": SCALE_YO,
		"mel": "7 . 9 . 10 . 12 . 10 . 9 . 7 . . . 5 . 7 . 9 . 7 . 5 . 4 . 5 . . . 7 . 9 . 10 . 12 . 14 . 12 . 10 . 9 . 10 . 9 . 7 . 5 . 7 . . . . . . .",
		"bass": "0 . . . 4 . . . 3 . . . 2 . . . 0 . . . 4 . . . 1 . . . 0 . . .",
		"drum": "k . . . s . . . k . . . s . . h",
	},
}

func _degree_hz(song: Dictionary, deg: int) -> float:
	var sc: Array = song["scale"]
	var octave := floori(float(deg) / sc.size())
	var idx := deg - octave * sc.size()
	var semi: int = sc[idx] + octave * 12
	return float(song["root"]) * pow(2.0, semi / 12.0)

## 琴の一音。弦をはじいた音を、雑音をなまらせていくことで作る。
func _pluck_key(freq: float, dur: float, bright: float) -> String:
	return "%d_%d_%d" % [int(freq * 10), int(dur * 100), int(bright * 10)]

func _pluck(freq: float, dur: float, bright := 0.5) -> PackedFloat32Array:
	var key := _pluck_key(freq, dur, bright)
	if _pluck_cache.has(key):
		return _pluck_cache[key]
	var n := int(dur * RATE)
	var period := maxi(2, int(RATE / freq))
	var buf := PackedFloat32Array()
	buf.resize(period)
	for i in period:
		buf[i] = randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	var decay := 0.996
	for i in n:
		var nxt := (idx + 1) % period
		var v := buf[idx]
		out[i] = v
		buf[idx] = decay * (bright * v + (1.0 - bright) * buf[nxt])
		idx = nxt
	_pluck_cache[key] = out
	return out

func _drum(kind: String) -> PackedFloat32Array:
	var key := "drum_" + kind
	if _pluck_cache.has(key):
		return _pluck_cache[key]
	var s: PackedFloat32Array
	match kind:
		"k": s = _mix(_tone(0.35, 110, 45, "sin", 0.9, 2.5), _noise(0.05, 0.2))
		"o": s = _mix(_tone(0.55, 85, 34, "sin", 1.0, 2.0), _noise(0.08, 0.3))
		"s": s = _mix(_noise(0.06, 0.35, 3.0), _tone(0.05, 900, 700, "sq", 0.08))
		_: s = _noise(0.03, 0.12, 3.0)
	_pluck_cache[key] = s
	return s

## 曲を 1 周ぶん作る。重いので、少しずつ進めて何コマかに分ける。
func _render_song(name: String) -> void:
	var song: Dictionary = SONGS[name]
	var tune := await _render_tune(song)
	var buf := tune.duplicate()
	var total := buf.size()
	var steps := _tokens(song["mel"]).size()
	var step_n := total / steps
	var drum := _tokens(song["drum"])
	var work := 0
	for i in steps:
		if drum.is_empty():
			break
		var d: String = drum[i % drum.size()]
		if d == ".":
			continue
		var ev := _drum(d)
		var start := i * step_n
		for j in ev.size():
			buf[(start + j) % total] += ev[j] * 0.35
		work += ev.size()
		if work > 30000:
			work = 0
			await get_tree().process_frame
	_bgm_cache[name] = _wav(buf, true)

## 旋律と低音だけを組んだもの。同じ旋律の曲（太鼓だけが違う）は、作ったものを使い回す。
func _tune_key(song: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [song["bpm"], song["root"], song["scale"], song["mel"], song["bass"]]

func _render_tune(song: Dictionary) -> PackedFloat32Array:
	var key := _tune_key(song)
	## ほかで作っている最中なら、できあがるのを待つ。
	while _tune_building.has(key):
		await get_tree().process_frame
	if _tune_cache.has(key):
		return _tune_cache[key]
	_tune_building[key] = true
	var step_sec := 60.0 / float(song["bpm"]) / 2.0
	var mel := _tokens(song["mel"])
	var bass := _tokens(song["bass"])
	var steps := mel.size()
	var step_n := int(step_sec * RATE)
	var total := steps * step_n
	var buf := PackedFloat32Array()
	buf.resize(total)
	## 弦の音は 1 つ作るのが重いので、先に 1 音ずつ作ってはひと休みする。
	for i in steps:
		if mel[i] != "." and not _pluck_cache.has(_pluck_key(_degree_hz(song, int(mel[i])), 1.4, 0.5)):
			_pluck(_degree_hz(song, int(mel[i])), 1.4, 0.5)
			await get_tree().process_frame
		if bass.size() > 0 and bass[i % bass.size()] != ".":
			var bf := _degree_hz(song, int(bass[i % bass.size()])) * 0.5
			if not _pluck_cache.has(_pluck_key(bf, 1.8, 0.45)):
				_pluck(bf, 1.8, 0.45)
				await get_tree().process_frame
	var work := 0
	for i in steps:
		var events := []
		if mel[i] != ".":
			events.append(_pluck(_degree_hz(song, int(mel[i])), 1.4, 0.5))
		if bass.size() > 0:
			var b: String = bass[i % bass.size()]
			if b != ".":
				events.append(_scale(_pluck(_degree_hz(song, int(b)) * 0.5, 1.8, 0.45), 0.8))
		for ev in events:
			var start := i * step_n
			for j in ev.size():
				## 曲の終わりを越えたぶんは頭に回す。つなぎ目で音が切れないように。
				buf[(start + j) % total] += ev[j] * 0.35
			work += ev.size()
			if work > 30000:
				work = 0
				await get_tree().process_frame
	_tune_cache[key] = buf
	_tune_building.erase(key)
	return buf

func _scale(a: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in out.size():
		out[i] *= k
	return out

func _tokens(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for t in s.split(" ", false):
		out.append(t)
	return out
