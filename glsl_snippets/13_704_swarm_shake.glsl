// === 704 Swarm Shake 小數字漂浮 + 局部顫抖 ===
// 改自 10_704_swarm。差異:
//   1) 拿掉深度淡出 → 飛到 box 遠端的 704 維持全亮、不消失
//   2) 接近 EYE 的硬切換成軟淡 → 粒子飛近 EYE 時平滑縮淡、不會突然 pop
//   3) 點擊偵測半徑 ∝ 1/dist → 「九宮格」邏輯:偵測範圍跟著 704 視覺大小縮放,
//      遠的 704 不會被旁邊的點擊掃到(避免 CAVE 邊緣固定角度造成大範圍誤觸)
//
// 顏色:白底黑字 + slight glow。
// 碰撞處理:fragment shader 不能保存粒子狀態 → 用 SDF min 自動融合,
//          兩粒子空間重疊時會黏在一起 (視覺上像柔軟碰撞,不會彈開)。

const vec3 EYE = vec3(0.0, 1.6, 0.0);

// CAVE 內漂浮箱形範圍
const vec3 BMIN = vec3(-2.3, 0.3, -3.6);
const vec3 BMAX = vec3(+2.3, 2.3, +3.6);

const float TEXT_SIZE = 0.25;
const float CULL_NEAR = 0.6;       // 完全淡掉的距離(替代原本的硬切)
const float NEAR_FADE = 1.0;       // 在這個距離以內開始淡入,粒子從 EYE 飛遠不再 pop
const float DOT_CULL  = 0.94;      // 角度篩選(放寬到約 20°,讓近距離大字邊緣不被切掉)

// 點擊偵測「九宮格」半徑倍率:
// 視覺角度半寬 ≈ 0.138/dist(來自 1.05/scale,scale = 1.9*dist/TEXT_SIZE)
// detect 半徑 = 倍率 × 半寬。1.5 約等於「中格 + 半格邊」≈ 九宮格範圍
const float SHAKE_RADIUS_MULT = 1.5;

float total = 0.0;

for (int i = 0; i < 100; i++) {
  float fi = float(i);
  vec3 s = hash33(vec3(fi * 1.317, fi * 2.713 + 5.0, fi * 0.971 + 11.0));

  // ---- 三軸獨立三角波(漂浮速率,比 10_704_swarm 慢 10 倍)----
  vec3 rate  = vec3(0.002, 0.0017, 0.002) + s * vec3(0.0033, 0.003, 0.0033);
  vec3 phase = s * 100.0;
  vec3 tri   = abs(2.0 * fract(u_time * rate + phase) - 1.0);
  vec3 P3    = mix(BMIN, BMAX, tri);

  // ---- 從 eye 看 ----
  vec3 d_eP = P3 - EYE;
  float dist = length(d_eP);
  // 軟淡入(不再硬切):dist 從 CULL_NEAR → NEAR_FADE 由 0 漸亮到 1
  float nearFade = smoothstep(CULL_NEAR, NEAR_FADE, dist);
  if (nearFade <= 0.001) continue;   // 完全看不見才略過
  vec3 dirP = d_eP / dist;

  // ---- 局部點擊顫抖:偵測半徑 ∝ 1/dist(九宮格範圍)----
  // 視覺半寬 ≈ 0.138/dist(對應 |p.x|<1.05 的角度)
  float angHalfWidth = (1.05 * TEXT_SIZE) / (1.9 * dist);
  float detectRadius = angHalfWidth * SHAKE_RADIUS_MULT;
  float shakeAmp = 0.0;
  for (int j = 0; j < 32; j++) {
    if (j >= u_clickCount) break;
    vec4 c = u_clicks[j];
    float age = u_time - c.w;
    if (age < 0.0 || age >= 2.0) continue;
    float angDist  = acos(clamp(dot(dirP, c.xyz), -1.0, 1.0));
    float spatial  = 1.0 - smoothstep(detectRadius * 0.6, detectRadius, angDist);
    float temporal = exp(-age * 2.2);
    shakeAmp = max(shakeAmp, spatial * temporal);
  }
  if (shakeAmp > 0.001) {
    vec3 jitter = vec3(
      sin(u_time * 38.0 + fi * 17.3),
      cos(u_time * 44.0 + fi * 23.7),
      sin(u_time * 35.0 + fi * 11.1)
    );
    P3   += jitter * 0.07 * shakeAmp;
    // P3 變了 → 重算 dirP / dist,後面投影才正確
    d_eP = P3 - EYE;
    dist = length(d_eP);
    nearFade = smoothstep(CULL_NEAR, NEAR_FADE, dist);
    if (nearFade <= 0.001) continue;
    dirP = d_eP / dist;
  }

  float dotDP = dot(dir, dirP);
  if (dotDP < DOT_CULL) continue;

  // ---- 切平面標架 + gnomonic 投影 ----
  float poleD = sqrt(max(1.0 - dirP.y * dirP.y, 0.0001));
  vec3 right = vec3(dirP.z, 0.0, -dirP.x) / poleD;
  vec3 up    = cross(dirP, right);

  vec3 dirLocal = dir / dotDP;
  float u_t = dot(dirLocal, right);
  float v_t = dot(dirLocal, up);

  float scale = 1.9 * dist / TEXT_SIZE;
  vec2 p = vec2(u_t, v_t) * scale;

  if (abs(p.x) > 1.05 || abs(p.y) > 0.6) continue;

  // ---- 704 SDF ----
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

  // ---- 累加:遠處全亮(無深度淡出),近處用 nearFade 軟收 ----
  float aPix = (1.0 - smoothstep(0.0, 0.04, d));
  float glow = exp(-max(d, 0.0) * 16.0) * 0.15;
  total = max(total, (aPix + glow) * nearFade);
}

return vec3(total);
