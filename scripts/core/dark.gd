class_name Dark
extends CanvasLayer
## 洞窟などの暗がり。画面に墨を重ね、明かりのある所だけ抜く。
##
## Light2D を使わず、明かりの場所をシェーダーに渡して自分で塗る。
## どの描き方（Web の Compatibility でも）でも同じに見え、
## 遊びの側の「ここは明るいか」の計算とも同じ式にできる。

const MAX_LIGHTS := 32

var ambient := 0.0   ## 明かりが無い所の明るさ（0=真っ暗）
var tint := Color(0.05, 0.035, 0.03)
var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 10
	_rect = ColorRect.new()
	_rect.size = Vector2(640, 360)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 lights[32];
uniform int count = 0;
uniform float ambient = 0.0;
uniform vec3 tint = vec3(0.05, 0.035, 0.03);
uniform float t = 0.0;
void fragment() {
	vec2 p = UV * vec2(640.0, 360.0);
	float lit = ambient;
	float warm = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= count) break;
		vec4 L = lights[i];
		float d = length(p - L.xy);
		float flick = 1.0 + 0.03 * sin(t * 9.0 + float(i) * 1.7);
		float k = 1.0 - smoothstep(L.z * 0.35, L.z * flick, d);
		lit = max(lit, k * L.w);
		warm = max(warm, k * (1.0 - k) * L.w);
	}
	/* 光の縁は暖かい色に。 */
	vec3 col = mix(tint, vec3(0.35, 0.16, 0.04), warm * 0.8);
	/* opacity() と同じ式。明かりの無い所は墨で塗りつぶす（透かさない）。 */
	COLOR = vec4(col, clamp(1.0 - lit, 0.0, 1.0));
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)

## その明るさ（0〜1）の所に、どれだけ濃く墨を重ねるか。1 で何も見えない。
## シェーダーの COLOR.a と同じ式。
##
## 以前は少しだけ透かしていた（0.99 倍）。暗い所でも蝙の動きがうっすら見え、
## 燭を灯さなくても敵の居場所が分かってしまっていた。
func opacity(lit: float) -> float:
	return clampf(1.0 - lit, 0.0, 1.0)

## 明かりを渡す。each は [画面上の位置, 半径, 強さ]。
func update_lights(list: Array, time: float) -> void:
	var arr := PackedVector4Array()
	for l in list:
		if arr.size() >= MAX_LIGHTS:
			break
		var p: Vector2 = l[0]
		arr.append(Vector4(p.x, p.y, l[1], l[2]))
	while arr.size() < MAX_LIGHTS:
		arr.append(Vector4.ZERO)
	_mat.set_shader_parameter("lights", arr)
	_mat.set_shader_parameter("count", mini(list.size(), MAX_LIGHTS))
	_mat.set_shader_parameter("ambient", ambient)
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_mat.set_shader_parameter("t", time)
