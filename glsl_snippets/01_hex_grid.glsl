// === Hex Grid Pulse 六邊形脈動網格 ===
// 球面上的六邊形磁磚 — 點擊產生波紋穿過格線。
// 接縫處理：欄數選 12 (整數) → 2π 完整繞回，hash 用 mod 12 對齊。

const float TAU  = 6.2831853;
const float NCOL = 12.0;

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

// uv.x 在 2π 內剛好走 NCOL 格 → 接縫處跨整數格界
vec2 uv = vec2(lon * NCOL / TAU, lat * 3.6);
uv += vec2(u_time * 0.08, 0.0);

vec2 r = vec2(1.0, 1.7320508);
vec2 h = r * 0.5;
vec2 a = mod(uv,     r) - h;
vec2 b = mod(uv + h, r) - h;
vec2 gv = (dot(a, a) < dot(b, b)) ? a : b;
vec2 gid = uv - gv;

float hex = 0.5 - max(abs(gv.x) * 1.1547, max(abs(gv.x) * 0.5774 + abs(gv.y), 0.0));

// mod(gid.x, NCOL) 讓繞球面一圈後 hash 對齊
float seed = hash13(vec3(mod(gid.x, NCOL), gid.y, 0.0));
float pulse = 0.5 + 0.5 * sin(u_time * 1.5 + seed * 28.0);

float md = acos(clamp(dot(dir, u_mouseDir), -1.0, 1.0));
float mouseGlow = exp(-md * 4.0) * u_mouseValid;

float ripple = clickRipple(dir, 22.0, 1.5, 6.0);

float edge = smoothstep(0.02, 0.06, hex);
float fill = smoothstep(0.12, 0.40, hex);

vec3 cBg   = vec3(0.03, 0.04, 0.08);
vec3 cEdge = vec3(0.20, 0.45, 0.75);
vec3 cHot  = paletteAurora(seed + u_time * 0.05);

vec3 col = cBg;
col = mix(col, cEdge, edge * 0.9);
col = mix(col, cHot * pulse, fill * (0.25 + 0.35 * pulse));
col += mouseGlow * vec3(0.4, 0.7, 1.0);
col += abs(ripple) * vec3(1.0, 0.6, 0.3) * 0.6;

return col;
