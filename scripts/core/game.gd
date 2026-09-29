extends Node
## autoload `Game`。遊びの記録（どこまで進んだか・字典）と、場面の移り変わり。
##
## ステージの中の状態（持ち物・命）はステージ自身が持つ。
## ここに置くのは、ステージをまたいで残るものだけ。

const STAGES := [
	{"no": 1, "kanji": "斧", "name": "其の一", "scene": "res://scenes/stage1.tscn"},
	{"no": 2, "kanji": "鉄", "name": "其の二", "scene": "res://scenes/stage2.tscn"},
	{"no": 3, "kanji": "蟲", "name": "其の三", "scene": "res://scenes/stage3.tscn"},
	{"no": 4, "kanji": "灯", "name": "其の四", "scene": "res://scenes/stage4.tscn"},
	{"no": 5, "kanji": "森", "name": "其の五", "scene": "res://scenes/stage5.tscn"},
	{"no": 6, "kanji": "明", "name": "終の章", "scene": "res://scenes/stage6.tscn"},
]
const TITLE_SCENE := "res://scenes/title.tscn"
const ENDING_SCENE := "res://scenes/ending.tscn"
## 記録の置き場所。テストは別の所を使う（遊んだ記録を消さないように）。
var save_path := "user://save.cfg"

## いま遊んでいるステージ（1 始まり）。
var stage_no := 1
## クリアしたステージと、そのときの最短の時間（秒）。
var cleared := {}
## 合わせて作ったことのある字。
var discovered := {}
## 遊び始めてから倒れた回数（エンディングで出す）。
var deaths := 0
## デバッグモード。全部のステージを選べ、ステージの中からも数字キーで飛べる。
## ?debug=true（Web）/ -- debug=true / エディタから起動したとき。
var debug := false

var _fade: CanvasLayer
var _fade_rect: ColorRect
var _changing := false

func _enter_tree() -> void:
	_setup_input()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug = _detect_debug()
	_build_fade()
	load_save()

# ---------------------------------------------------------------- 入力

## キーの割り当て。project.godot に書かず、ここで足す。
## Web 版は明示しないとスペースが効かないことがあるため、ui_accept も書き直す。
const KEYS := {
	"left": [KEY_LEFT, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"up": [KEY_UP, KEY_W],
	"down": [KEY_DOWN, KEY_S],
	"act": [KEY_SPACE, KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_J],
	"craft": [KEY_X, KEY_C, KEY_K],
	"pause": [KEY_ESCAPE, KEY_P],
	"ui_accept": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z],
	"ui_cancel": [KEY_ESCAPE, KEY_X],
	"ui_left": [KEY_LEFT, KEY_A],
	"ui_right": [KEY_RIGHT, KEY_D],
	"ui_up": [KEY_UP, KEY_W],
	"ui_down": [KEY_DOWN, KEY_S],
}

func _setup_input() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		for code in KEYS[action]:
			## 物理キー（キー配列が違っても同じ場所）と、文字のキーの両方で受ける。
			## ブラウザによっては片方しか届かないことがあるため。
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
			var ev2 := InputEventKey.new()
			ev2.keycode = code
			InputMap.action_add_event(action, ev2)
	## ゲームパッドでも遊べるようにしておく。
	_add_joy("act", JOY_BUTTON_A)
	_add_joy("ui_accept", JOY_BUTTON_A)
	_add_joy("craft", JOY_BUTTON_X)
	_add_joy("ui_cancel", JOY_BUTTON_B)
	_add_joy("pause", JOY_BUTTON_START)
	_add_joy("left", JOY_BUTTON_DPAD_LEFT)
	_add_joy("right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy("up", JOY_BUTTON_DPAD_UP)
	_add_joy("down", JOY_BUTTON_DPAD_DOWN)
	_add_joy("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("down", JOY_AXIS_LEFT_Y, 1.0)

func _add_joy(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_axis(action: String, axis: JoyAxis, dir: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- debug

func _detect_debug() -> bool:
	if OS.get_name() == "Web":
		## URLSearchParams は JavaScriptBridge の中では見つからないことがある。
		## 素の location.search を受け取ってこちらで見る。
		var search := str(JavaScriptBridge.eval("location.search", true))
		return "debug=true" in search
	return debug_from(OS.get_cmdline_args() + OS.get_cmdline_user_args(), EngineDebugger.is_active())

## 起動のしかたからデバッグにするかを決める。
##
## - `godot --path . -- debug=true` と明示したとき
## - エディタの ▶ から起動したとき。エディタのデバッガがつながっている（debugger が true）。
##
## エディタは --remote-debug を付けて起動するが、エンジンが取り除くので
## OS.get_cmdline_args() には残らない。引数を見ても分からない。
func debug_from(args: Array, debugger: bool) -> bool:
	if debugger:
		return true
	for a in args:
		if a == "debug=true" or a == "--debug=true":
			return true
	return false

# ---------------------------------------------------------------- 記録

func stage_info(no: int) -> Dictionary:
	for s in STAGES:
		if s["no"] == no:
			return s
	return {}

## タイトルで選べる最後のステージ。クリアしたものの次まで。
func unlocked_max() -> int:
	if debug:
		return STAGES.size()
	var n := 1
	for s in STAGES:
		if cleared.has(s["no"]):
			n = max(n, s["no"] + 1)
	return min(n, STAGES.size())

func mark_cleared(no: int, sec: float) -> bool:
	var best := sec < float(cleared.get(no, INF))
	if best:
		cleared[no] = sec
	save()
	return best

## 字典に載せる。初めて作った字なら true。
func discover(kanji: String) -> bool:
	if discovered.has(kanji):
		return false
	discovered[kanji] = true
	save()
	return true

func save() -> void:
	var cf := ConfigFile.new()
	for no in cleared:
		cf.set_value("cleared", str(no), cleared[no])
	for k in discovered:
		cf.set_value("dex", k, true)
	cf.set_value("stats", "deaths", deaths)
	cf.save(save_path)

func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return
	if cf.has_section("cleared"):
		for key in cf.get_section_keys("cleared"):
			cleared[int(key)] = float(cf.get_value("cleared", key))
	if cf.has_section("dex"):
		for key in cf.get_section_keys("dex"):
			discovered[key] = true
	deaths = int(cf.get_value("stats", "deaths", 0))

## 記録を消す（テスト用）。
func wipe() -> void:
	cleared.clear()
	discovered.clear()
	deaths = 0

# ---------------------------------------------------------------- 場面

func goto_stage(no: int) -> void:
	var info := stage_info(no)
	if info.is_empty():
		change_scene(ENDING_SCENE)
		return
	stage_no = no
	change_scene(info["scene"])

func goto_next_stage() -> void:
	if stage_no >= STAGES.size():
		change_scene(ENDING_SCENE)
	else:
		goto_stage(stage_no + 1)

func goto_title() -> void:
	change_scene(TITLE_SCENE)

## 墨が閉じるように暗くしてから場面を変え、また開く。
## 途中で重ねて呼ばれても、1 回目だけを通す。
func change_scene(path: String, center := Vector2(-1, -1)) -> void:
	if _changing:
		return
	_changing = true
	var tree := get_tree()
	if center.x < 0:
		center = Vector2(0.5, 0.5)
	_set_iris(center, 1.5)
	_fade.visible = true
	var tw := create_tween()
	tw.tween_method(func(r): _set_iris(center, r), 1.5, 0.0, 0.35)
	await tw.finished
	tree.change_scene_to_file(path)
	await tree.process_frame
	await tree.process_frame
	var tw2 := create_tween()
	tw2.tween_method(func(r): _set_iris(Vector2(0.5, 0.5), r), 0.0, 1.5, 0.4)
	await tw2.finished
	_fade.visible = false
	_changing = false

func is_changing() -> bool:
	return _changing

func _build_fade() -> void:
	_fade = CanvasLayer.new()
	_fade.layer = 100
	_fade.visible = false
	add_child(_fade)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 center = vec2(0.5);
uniform float radius = 1.0;
uniform vec2 aspect = vec2(1.7778, 1.0);
void fragment() {
	vec2 d = (UV - center) * aspect;
	float r = length(d);
	float edge = smoothstep(radius, radius + 0.02, r);
	COLOR = vec4(0.08, 0.06, 0.05, edge);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_fade_rect.material = mat
	_fade.add_child(_fade_rect)

func _set_iris(center: Vector2, r: float) -> void:
	var mat := _fade_rect.material as ShaderMaterial
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("radius", r)
