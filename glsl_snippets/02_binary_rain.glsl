// === Binary Rain 二進位降雨 ===
// 直立 0/1 數字列從上往下流動，領頭白光，尾巴漸暗綠。
// 接縫處理：36 個欄位剛好包圍 2π → 跨 ±π 兩側 hash mod 36 對齊。

const float TAU  = 6.2831853;
const float NCOL = 36.0;
const float NROW = 40.0;

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

vec2 uv = vec2(lon * NCOL / TAU, (0.5 - lat / 3.14159265) * NROW);

float col_id = floor(uv.x);
float row_id = floor(uv.y);
vec2  cellUV = fract(uv) - 0.5;

// hash 一律過 mod(_, NCOL) → 接縫兩側同 cell 同 hash
float col_mod = mod(col_id, NCOL);

float speed = 2.5 + hash13(vec3(col_mod, 0.0, 0.0)) * 4.5;
float head  = u_time * speed + hash13(vec3(col_mod, 1.0, 0.0)) * 50.0;

float tail = mod(head - row_id, NROW);

float tick = floor(u_time * 4.0 + hash13(vec3(col_mod, row_id, 7.0)) * 5.0);
float digit = step(0.5, fract(hash13(vec3(col_mod, row_id, tick))));

vec2 p = cellUV * 1.6;
float d;
if (digit < 0.5) {
  float r = length(p);
  d = 1.0 - smoothstep(0.20, 0.26, abs(r - 0.30));
} else {
  d = 1.0 - smoothstep(0.04, 0.08, abs(p.x));
  d *= step(abs(p.y), 0.34);
}

float brightness = exp(-tail * 0.18);
float isHead = exp(-tail * 6.0);

vec3 colA = mix(vec3(0.05, 0.85, 0.30), vec3(1.0), isHead);
vec3 col = colA * brightness * d;
col += vec3(0.01, 0.03, 0.02) * (1.0 - d);

float ripple = clickRipple(dir, 18.0, 1.8, 7.0);
col += abs(ripple) * vec3(0.9, 1.0, 0.9) * 0.5;

return col;
