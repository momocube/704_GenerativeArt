// === 704 DVD Bounce ===
// 連續 gnomonic 投影彈跳，黑底白字「704」在 CAVE 內 360° 移動並經過地板。
// 比上版降低彈跳高度上限：β 範圍 [-81°, -9°]，主要在腳底/地板與下半牆面之間。
// 大小、速度沿用 (scale=1.2, 速度=原版 1/3)，不淡出不分段。

const float PI  = 3.14159265;
const float TAU = 6.2831853;

// ---- DVD 三角波彈跳 ----
float aN = 2.0 * abs(2.0 * fract(u_time * 0.06) - 1.0) - 1.0;
float bN = 2.0 * abs(2.0 * fract(u_time * 0.09) - 1.0) - 1.0;
float alpha = aN * (PI * 0.85);                  // 方位 ±153°
float beta  = bN * (PI * 0.20) - (PI * 0.25);    // 仰角 [-81°, -9°]，不會跑到牆頂以上

// ---- 點擊抖動 ----
for (int i = 0; i < 32; i++) {
  if (i >= u_clickCount) break;
  vec4 c = u_clicks[i];
  float age = u_time - c.w;
  if (age >= 0.0 && age < 3.0) {
    float damp = exp(-age * 1.5);
    alpha += sin(age * 10.0 + c.w * 7.3) * damp * 0.35;
    beta  += cos(age * 8.0  + c.w * 4.1) * damp * 0.22;
  }
}

// ---- 文字中心方向 P ----
float cb = cos(beta);
vec3 P = vec3(cb * cos(alpha), sin(beta), cb * sin(alpha));

// ---- 切平面標架 ----
float poleD = sqrt(max(1.0 - P.y * P.y, 0.0001));
vec3 right = vec3(P.z, 0.0, -P.x) / poleD;
vec3 up    = cross(P, right);

// ---- gnomonic 投影 ----
float dotDP = dot(dir, P);
if (dotDP < 0.05) return vec3(0.0);
vec3 dirLocal = dir / dotDP;
float u_text = dot(dirLocal, right);
float v_text = dot(dirLocal, up);

const float scale = 1.2;
vec2 p = vec2(u_text, v_text) * scale;

// ---- 704 SDF ----
const float thick = 0.07;
const float h     = 0.45;
float d = 1e9;

// === 7 ===
{
  vec2 pp = p - vec2(-0.70, 0.0);
  vec2 a = vec2(-0.25, h);
  vec2 b = vec2(+0.25, h);
  vec2 ba = b - a;
  vec2 pa = pp - a;
  float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - t * ba) - thick);
  a = vec2(+0.22, h);
  b = vec2(-0.10, -h);
  ba = b - a;
  pa = pp - a;
  t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - t * ba) - thick);
}

// === 0 ===
{
  vec2 pp = p;
  vec2 dO = abs(pp) - vec2(0.22, 0.32);
  float outer = length(max(dO, 0.0)) + min(max(dO.x, dO.y), 0.0) - 0.12;
  vec2 dI = abs(pp) - vec2(0.22 - thick, 0.32 - thick);
  float inner = length(max(dI, 0.0)) + min(max(dI.x, dI.y), 0.0) - max(0.12 - thick, 0.0);
  d = min(d, max(outer, -inner));
}

// === 4 ===
{
  vec2 pp = p - vec2(+0.70, 0.0);
  vec2 a = vec2(+0.20, -h);
  vec2 b = vec2(+0.20, +h);
  vec2 ba = b - a;
  vec2 pa = pp - a;
  float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - t * ba) - thick);
  a = vec2(-0.24, 0.0);
  b = vec2(+0.24, 0.0);
  ba = b - a;
  pa = pp - a;
  t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - t * ba) - thick);
  a = vec2(-0.20, 0.0);
  b = vec2(-0.20, +h);
  ba = b - a;
  pa = pp - a;
  t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - t * ba) - thick);
}

// ---- 黑底白字 + 微微外暈 ----
float aPix = 1.0 - smoothstep(0.0, 0.015, d);
float glow = exp(-max(d, 0.0) * 18.0) * 0.18;
return vec3(aPix + glow);
