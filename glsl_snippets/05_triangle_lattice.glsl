// === Triangle Lattice 三角晶格 ===
// 等邊三角形磁磚 + 隨機翻轉。
// 接縫處理：16 欄整數環繞。Trucht-skew 矩陣的 x 軸週期 1.0 → 跨 2π 是 16 個整週期。

const float TAU  = 6.2831853;
const float NCOL = 16.0;

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

vec2 uv = vec2(lon * NCOL / TAU, lat * 5.0);
uv += vec2(u_time * 0.05, 0.0);

mat2 toTri  = mat2(1.0, 0.0, -0.5773502, 1.1547005);

vec2 tg = toTri * uv;
vec2 ti = floor(tg);
vec2 tf = fract(tg);

float upper = step(tf.x + tf.y, 1.0);
float subId = upper;

vec2 q = upper > 0.5 ? tf : vec2(1.0) - tf;

float a = q.x;
float b = q.y;
float c = 1.0 - q.x - q.y;
float edgeDist = min(min(a, b), c);

// hash 用 mod(ti.x, NCOL) 對齊接縫
float ti_x_mod = mod(ti.x, NCOL);
float seed = hash13(vec3(ti_x_mod, ti.y, subId));

float ripple = clickRipple(dir, 16.0, 1.8, 5.0);
float flip = sin(u_time * 0.6 + seed * 20.0 + ripple * 3.0);

vec3 cA = vec3(0.95, 0.85, 0.25);
vec3 cB = vec3(0.10, 0.30, 0.95);
vec3 fillCol = mix(cA, cB, smoothstep(-0.1, 0.1, flip));

float edge = smoothstep(0.0, 0.04, edgeDist);
float centerDot = exp(-pow(edgeDist - 0.33, 2.0) * 280.0) * 0.6;

vec3 col = mix(vec3(0.04, 0.05, 0.08), fillCol, edge * 0.85);
col += vec3(1.0) * centerDot * (0.4 + 0.6 * abs(flip));

float md = acos(clamp(dot(dir, u_mouseDir), -1.0, 1.0));
col += exp(-md * 3.0) * 0.22 * vec3(1.0, 0.9, 0.7) * u_mouseValid;

return col;
