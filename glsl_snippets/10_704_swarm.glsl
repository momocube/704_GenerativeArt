// === 704 Swarm 小數字漂浮 ===
// 100 個小「704」在 CAVE 立方體內 3D 漂浮，獨立三軸三角波彈跳。
// 顏色：白底黑字 + slight glow，與大字版一致。
// 碰撞處理：fragment shader 不能保存粒子狀態 → 用 SDF min 自動融合，
//          兩粒子空間重疊時會黏在一起 (視覺上像柔軟碰撞，不會彈開)。

const vec3 EYE = vec3(0.0, 1.6, 0.0);

// CAVE 內漂浮箱形範圍 (留 margin 避免穿牆 / 太靠近 eye)
const vec3 BMIN = vec3(-2.3, 0.3, -3.6);
const vec3 BMAX = vec3(+2.3, 2.3, +3.6);

const float TEXT_SIZE   = 0.25;  // 每個小 704 實體寬度 (m)
const float CULL_NEAR   = 0.6;   // 比這個近就不畫，避免太靠近 eye 時爆炸大
const float DOT_CULL    = 0.97;  // 角度篩選 (約 14°) — 篩掉跟 dir 偏離太遠的粒子
const float DEPTH_FADE0 = 3.5;   // 開始淡出的距離
const float DEPTH_FADE1 = 5.0;   // 完全淡掉的距離

float total = 0.0;

for (int i = 0; i < 100; i++) {
  float fi = float(i);
  vec3 s = hash33(vec3(fi * 1.317, fi * 2.713 + 5.0, fi * 0.971 + 11.0));

  // ---- 三軸獨立三角波，速率與相位各粒子不同 ----
  // 速率改慢 3 倍：原本 0.05~0.16/秒 → 現在 0.017~0.053/秒
  vec3 rate  = vec3(0.02, 0.017, 0.02) + s * vec3(0.033, 0.03, 0.033);
  vec3 phase = s * 100.0;
  vec3 tri   = abs(2.0 * fract(u_time * rate + phase) - 1.0);
  vec3 P3    = mix(BMIN, BMAX, tri);

  // ---- 從 eye 看 ----
  vec3 d_eP = P3 - EYE;
  float dist = length(d_eP);
  if (dist < CULL_NEAR) continue;
  vec3 dirP = d_eP / dist;

  // 角度大致篩選 (絕大多數粒子在這裡被排除)
  float dotDP = dot(dir, dirP);
  if (dotDP < DOT_CULL) continue;

  // ---- 切平面標架 + gnomonic 投影 ----
  float poleD = sqrt(max(1.0 - dirP.y * dirP.y, 0.0001));
  vec3 right = vec3(dirP.z, 0.0, -dirP.x) / poleD;
  vec3 up    = cross(dirP, right);

  vec3 dirLocal = dir / dotDP;
  float u_t = dot(dirLocal, right);
  float v_t = dot(dirLocal, up);

  // scale 隨距離自動調整 (近的大、遠的小)
  float scale = 1.9 * dist / TEXT_SIZE;
  vec2 p = vec2(u_t, v_t) * scale;

  // bounding box 二次篩選
  if (abs(p.x) > 1.05 || abs(p.y) > 0.6) continue;

  // ---- 704 SDF (粗筆畫，適合小字遠看) ----
  const float thick = 0.10;
  const float h     = 0.45;
  float d = 1e9;

  // 7
  vec2 pp = p - vec2(-0.70, 0.0);
  vec2 a = vec2(-0.25, h);
  vec2 b = vec2(+0.25, h);
  vec2 ba = b - a;
  vec2 pa = pp - a;
  float tt = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - tt * ba) - thick);
  a = vec2(+0.22, h);
  b = vec2(-0.10, -h);
  ba = b - a;
  pa = pp - a;
  tt = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - tt * ba) - thick);

  // 0
  pp = p;
  vec2 dO = abs(pp) - vec2(0.22, 0.32);
  float outer = length(max(dO, 0.0)) + min(max(dO.x, dO.y), 0.0) - 0.12;
  vec2 dI = abs(pp) - vec2(0.22 - thick, 0.32 - thick);
  float inner = length(max(dI, 0.0)) + min(max(dI.x, dI.y), 0.0) - max(0.12 - thick, 0.0);
  d = min(d, max(outer, -inner));

  // 4
  pp = p - vec2(+0.70, 0.0);
  a = vec2(+0.20, -h);
  b = vec2(+0.20, +h);
  ba = b - a;
  pa = pp - a;
  tt = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - tt * ba) - thick);
  a = vec2(-0.24, 0.0);
  b = vec2(+0.24, 0.0);
  ba = b - a;
  pa = pp - a;
  tt = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - tt * ba) - thick);
  a = vec2(-0.20, 0.0);
  b = vec2(-0.20, +h);
  ba = b - a;
  pa = pp - a;
  tt = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  d = min(d, length(pa - tt * ba) - thick);

  // ---- 深度淡出 + 累加 ----
  float depthFade = 1.0 - smoothstep(DEPTH_FADE0, DEPTH_FADE1, dist);
  float aPix = (1.0 - smoothstep(0.0, 0.04, d));
  float glow = exp(-max(d, 0.0) * 16.0) * 0.15;
  total = max(total, (aPix + glow) * depthFade);
}

return vec3(total);
