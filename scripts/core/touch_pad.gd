class_name TouchPad
extends CanvasLayer
## スマホ・タブレットで遊ぶための、画面の上のボタン。
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
## 同じ act でも、メニューでは ui_accept を見るので、いっしょに押す。
const ALSO := {
	"act": ["ui_accept"],
	"up": ["ui_up"], "down": ["ui_down"], "left": ["ui_left"], "right": ["ui_right"],
	"craft": [],
	"pause": [],
}

var _pressed := {}   ## 指の id -> action
var _glyphs := {}

## この端末で画面のボタンが要るか。
static func needed() -> bool:
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
		bg.radius = b["r"]
		bg.position = b["pos"]
		add_child(bg)
		var g := Glyph.make(b["text"], Color(0.2, 0.2, 0.2, 0.75), int(b["r"] * 0.9))
		g.shadow = false
		g.position = b["pos"]
		add_child(g)
		_glyphs[b["action"]] = [g, bg]

class _Circle extends Node2D:
	var radius := 24.0
	var on := false:
		set(v):
			on = v
			queue_redraw()
	func _draw() -> void:
		var c := Color(0.73, 0.19, 0.14, 0.45) if on else Color(1, 1, 1, 0.35)
		draw_circle(Vector2.ZERO, radius, c)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.2, 0.2, 0.2, 0.4), 1.5, true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_at(_to_canvas(event.position), event.index)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		var a := _find(_to_canvas(event.position))
		if _pressed.get(event.index, "") != a:
			_release(event.index)
			if a != "":
				_press_at(_to_canvas(event.position), event.index)

## 画面の座標を、ゲームの 640x360 の座標へ直す。
func _to_canvas(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform().affine_inverse() * p

func _find(p: Vector2) -> String:
	for b in BUTTONS:
		if p.distance_to(b["pos"]) <= b["r"] + 10:
			return b["action"]
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
