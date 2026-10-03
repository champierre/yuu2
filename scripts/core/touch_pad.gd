class_name TouchPad
extends CanvasLayer
## スマホ・タブレットで遊ぶための、画面のボタン。
##
## 横に持ったときは遊びの画面に重ねて出す（BUTTONS）。
## 縦に持ったときは、遊びの画面の下の帯に大きく並べる（STACKED）。
## どちらにするかは Game が窓の形から決める（Game.stacked）。
##
## 押すと Input.action_press を呼ぶので、遊びの側はキーボードと同じ書き方でよい。
## （InputEventAction を流すやり方だと、押した瞬間を 1 コマ取りこぼすことがある）

const BUTTONS := [
	{"text": "上", "action": "up", "pos": Vector2(74, 236), "r": 26},
	{"text": "下", "action": "down", "pos": Vector2(74, 320), "r": 26},
	{"text": "左", "action": "left", "pos": Vector2(32, 278), "r": 26},
	{"text": "右", "action": "right", "pos": Vector2(116, 278), "r": 26},
	{"text": "決", "action": "act", "pos": Vector2(588, 300), "r": 32},
	{"text": "合", "action": "craft", "pos": Vector2(522, 318), "r": 26},
	{"text": "止", "action": "pause", "pos": Vector2(612, 72), "r": 16},
]
## 縦持ちのときの並び。帯の真ん中からの位置と、大きさ。
## 640 の幅が 390px ほどに縮むので、横持ちより大きくしている（十字は直径 60px ほど、止 でも 44px ほど）。
## 帯がこの並びより低い窓では、縦持ちの並べ方にしない（stacked_height()）。
const STACKED := {
	"up": {"off": Vector2(-174, -86), "r": 50},
	"down": {"off": Vector2(-174, 86), "r": 50},
	"left": {"off": Vector2(-260, 0), "r": 50},
	"right": {"off": Vector2(-88, 0), "r": 50},
	"act": {"off": Vector2(236, 20), "r": 52},
	"craft": {"off": Vector2(120, 60), "r": 40},
	"pause": {"off": Vector2(280, -100), "r": 26},
}
## 指が当たったとみなす広さは、見た目よりこれだけ大きく取る。
const REACH := 10.0
## 同じ act でも、メニューでは ui_accept を見るので、いっしょに押す。
const ALSO := {
	"act": ["ui_accept"],
	"up": ["ui_up"], "down": ["ui_down"], "left": ["ui_left"], "right": ["ui_right"],
	"craft": [],
	"pause": [],
}

var _pressed := {}   ## 指の id -> action
var _glyphs := {}
## autoload の Game。`Game` と名前で書くと、テスト（--script）がこのファイルを
## 先に読んだとき、まだ autoload が登録されておらず、読み込みに失敗する。
var _game: Node

## 縦持ちの並びで、いちばん上のボタンの押せる範囲の上の端（帯の真ん中から。負の数）。
static func stacked_top() -> float:
	var top := 0.0
	for a in STACKED:
		top = minf(top, STACKED[a]["off"].y - STACKED[a]["r"] - REACH)
	return top

## 縦持ちの並びを置くのに要る帯の高さ（押せる範囲ごと収まる高さ）。
static func stacked_height() -> float:
	var half := 0.0
	for a in STACKED:
		half = maxf(half, absf(STACKED[a]["off"].y) + STACKED[a]["r"] + REACH)
	return half * 2.0

## テストで、指で遊ぶ機械のふりをする。
static var pretend := false

## この端末で画面のボタンが要るか。
static func needed() -> bool:
	if pretend:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	var os := OS.get_name()
	if os == "Android" or os == "iOS":
		return true
	if os == "Web":
		return JavaScriptBridge.eval("""
			(('ontouchstart' in window) ||
			 (navigator.maxTouchPoints > 0) ||
			 /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent))
		""", true) == true
	return false

## 案内に出すボタンの呼び名。
static func act_name() -> String:
	## Z や Enter でも同じことができるが、案内には一番なじみのあるスペースを出す。
	return "決" if needed() else "スペース"

static func craft_name() -> String:
	return "合" if needed() else "X"

static func pause_name() -> String:
	return "止" if needed() else "Esc"

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUTTONS:
		var bg := _Circle.new()
		add_child(bg)
		var g := Glyph.make(b["text"], Color(0.2, 0.2, 0.2, 0.75), int(b["r"] * 0.9))
		g.shadow = false
		add_child(g)
		_glyphs[b["action"]] = [g, bg]
	_game = get_node("/root/Game")
	_game.layout_changed.connect(_layout)
	_layout()

## ボタンを、いまの並べ方（重ねる／下の帯に並べる）の場所に置く。
func _layout() -> void:
	## 置き場所が変わるので、押したままのものは離す。
	for finger in _pressed.keys():
		_release(finger)
	for b in BUTTONS:
		var a: String = b["action"]
		var g: Glyph = _glyphs[a][0]
		var bg: _Circle = _glyphs[a][1]
		bg.radius = button_r(a)
		bg.solid = _game.stacked
		bg.position = button_pos(a)
		g.size = int(button_r(a) * 0.9)
		g.position = button_pos(a)

## ボタンの真ん中（640x360 と同じ物差し。縦持ちでは y が 360 より下になる）。
func button_pos(action: String) -> Vector2:
	if _game.stacked:
		return Vector2(320, 360 + _game.pad_height * 0.5) + STACKED[action]["off"]
	for b in BUTTONS:
		if b["action"] == action:
			return b["pos"]
	return Vector2.ZERO

func button_r(action: String) -> float:
	if _game.stacked:
		return STACKED[action]["r"]
	for b in BUTTONS:
		if b["action"] == action:
			return b["r"]
	return 0.0

class _Circle extends Node2D:
	var radius := 24.0:
		set(v):
			radius = v
			queue_redraw()
	## 帯の上では、下に透かすものが無いので、はっきり塗る。
	var solid := false:
		set(v):
			solid = v
			queue_redraw()
	var on := false:
		set(v):
			on = v
			queue_redraw()
	func _draw() -> void:
		var c := Color(0.73, 0.19, 0.14, 0.45) if on else Color(1, 1, 1, 0.8 if solid else 0.35)
		draw_circle(Vector2.ZERO, radius, c)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.2, 0.2, 0.2, 0.4), 1.5, true)

## _input に届く座標は、すでにゲームの 640x360 の座標に直されている
## （画面の座標ではない）。ここでもう一度直すと二重になり、
## 画面が 640x360 より大きいスマホでは、どのボタンも外れる。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_at(event.position, event.index)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		var a := _find(event.position)
		if _pressed.get(event.index, "") != a:
			_release(event.index)
			if a != "":
				_press_at(event.position, event.index)

func _find(p: Vector2) -> String:
	for b in BUTTONS:
		var a: String = b["action"]
		if p.distance_to(button_pos(a)) <= button_r(a) + REACH:
			return a
	return ""

func _press_at(p: Vector2, finger: int) -> void:
	var a := _find(p)
	if a == "":
		return
	_pressed[finger] = a
	_apply(a, true)
	if a == "pause":
		## 押した瞬間だけでよい。次のコマで離す。
		await get_tree().process_frame
		_release(finger)

func _release(finger: int) -> void:
	if not _pressed.has(finger):
		return
	var a: String = _pressed[finger]
	_pressed.erase(finger)
	if a in _pressed.values():
		return
	_apply(a, false)

func _apply(action: String, down: bool) -> void:
	var list: Array = [action] + ALSO.get(action, [])
	for x in list:
		if down:
			Input.action_press(x)
		else:
			Input.action_release(x)
	if _glyphs.has(action):
		_glyphs[action][1].on = down

## 場面が変わって消えるとき、押したままのものを全部離す。
## 残すと次の場面が「押しっぱなし」を拾ってしまう。
func _exit_tree() -> void:
	for a in _pressed.values():
		for x in [a] + ALSO.get(a, []):
			Input.action_release(x)
	_pressed.clear()
