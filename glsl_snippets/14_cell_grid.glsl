// === Cell Grid 閃動格子 (CyberCube 多彩配色) ===
// CAVE 五面用 0.5m × 0.5m 物理格子(per-face N 依面距 D 調),
// 不再用統一 N 造成各面大小不一致。
//
// 場域 5.5(寬) × 8(深) × 2.5(高) m, 視點在中心(地板上 1.25m):
//   地板/天花板 D = 1.25 m  → N = 5   (cells = 2D/N = 0.5m)
//   長牆 (±X)   D = 2.75 m  → N = 11
//   短牆 (±Z)   D = 4    m  → N = 16
//
// ~1/3 隨機格子上有 c / y / b / e / r / u (六字母 等機率,線段 SDF)。
// 每格從 4 色 CyberCube 調色盤隨機取色,場域不再單一色。
// 踩到格子(click)→ 該格白熱亮 + 鄰格漣漪以 cell-grid Chebyshev 距離外擴 2.5 秒。
// 閒置時每格獨立相位輕微呼吸。
//
// 配色取樣自閃動格子官網(CyberCube):
//   黑底 #060815 / 熱粉 #ed2873 / 青藍 #2cd4b8 / 電紫 #9c47ff / 暖橙 #ff7a3d

// ---- cubemap projection: dir → (face_id, uv∈[-1,1]) ----
vec3 absD = abs(dir);
float face;
vec2 uv;
if (absD.x >= absD.y && absD.x >= absD.z) {
  if (dir.x > 0.0) { face = 0.0; uv = vec2(-dir.z, dir.y) / absD.x; }  // +X 右(長)牆
  else             { face = 1.0; uv = vec2( dir.z, dir.y) / absD.x; }  // -X 左(長)牆
} else if (absD.y >= absD.z) {
  if (dir.y > 0.0) { face = 2.0; uv = vec2( dir.x, -dir.z) / absD.y; } // +Y 天
  else             { face = 3.0; uv = vec2( dir.x,  dir.z) / absD.y; } // -Y 地
} else {
  if (dir.z > 0.0) { face = 4.0; uv = vec2( dir.x, dir.y) / absD.z; }  // +Z 前(短)牆
  else             { face = 5.0; uv = vec2(-dir.x, dir.y) / absD.z; }  // -Z 後(短)牆
}

// ---- per-face N (cells = 0.5m physical, N = 4 × face_distance) ----
float N;
if (face < 1.5)      N = 11.0;   // ±X 長牆 (D=2.75m)
else if (face < 3.5) N =  5.0;   // ±Y 地/天 (D=1.25m)
else                 N = 16.0;   // ±Z 短牆 (D=4m)

vec2 g        = (uv * 0.5 + 0.5) * N;
vec2 cell     = floor(g);
vec2 cellFrac = g - cell;
vec2 p        = (cellFrac - 0.5) * 2.0;

float cellSeed = hash13(vec3(cell, face));

// ---- per-cell tint:4 色 CyberCube 調色盤 等機率 ----
float tintPick = floor(fract(cellSeed * 17.3) * 4.0);
vec3 cellTint;
if (tintPick < 0.5)      cellTint = vec3(0.93, 0.16, 0.45);   // 熱粉 #ed2873
else if (tintPick < 1.5) cellTint = vec3(0.17, 0.83, 0.72);   // 青藍 #2cd4b8
else if (tintPick < 2.5) cellTint = vec3(0.61, 0.28, 1.00);   // 電紫 #9c47ff
else                     cellTint = vec3(1.00, 0.48, 0.24);   // 暖橙 #ff7a3d

// ---- 掃 u_clicks:本格 vs 點擊格 的 Chebyshev 距離 ----
float clickHit = 0.0;
float ripple   = 0.0;
for (int j = 0; j < 32; j++) {
  if (j >= u_clickCount) break;
  vec4 c = u_clicks[j];
  float age = u_time - c.w;
  if (age < 0.0 || age >= 2.5) continue;

  // 同一個 cubemap 投影:click dir → (cFace, cUv)
  vec3  cd  = c.xyz;
  vec3  acd = abs(cd);
  float cFace;
  vec2  cUv;
  if (acd.x >= acd.y && acd.x >= acd.z) {
    if (cd.x > 0.0) { cFace = 0.0; cUv = vec2(-cd.z, cd.y) / acd.x; }
    else            { cFace = 1.0; cUv = vec2( cd.z, cd.y) / acd.x; }
  } else if (acd.y >= acd.z) {
    if (cd.y > 0.0) { cFace = 2.0; cUv = vec2( cd.x, -cd.z) / acd.y; }
    else            { cFace = 3.0; cUv = vec2( cd.x,  cd.z) / acd.y; }
  } else {
    if (cd.z > 0.0) { cFace = 4.0; cUv = vec2( cd.x, cd.y) / acd.z; }
    else            { cFace = 5.0; cUv = vec2(-cd.x, cd.y) / acd.z; }
  }
  if (abs(cFace - face) > 0.5) continue;   // 點擊在別面 → 跳過(漣漪不跨稜)

  // 點擊與本格同一面,直接用本面的 N
  vec2  cCell    = floor((cUv * 0.5 + 0.5) * N);
  vec2  dCell    = abs(cell - cCell);
  float chebDist = max(dCell.x, dCell.y);

  float fade = exp(-age * 1.3);

  // 中心格直接亮起
  if (chebDist < 0.5) clickHit = max(clickHit, fade);

  // 漣漪:每秒往外擴 6 格,薄環,距離越遠越淡
  float r       = age * 6.0;
  float ring    = 1.0 - smoothstep(0.5, 1.5, abs(chebDist - r));
  float falloff = 1.0 / (1.0 + chebDist * 0.4);
  ripple = max(ripple, ring * fade * falloff);
}

// ---- 閒置:每格獨立相位呼吸,~0.8-2.2 Hz ----
float idleFlicker = 0.5 + 0.5 * sin(u_time * (0.8 + cellSeed * 1.4) + cellSeed * 14.0);
float idleBright  = 0.10 + 0.18 * idleFlicker;

// ---- 格框(Chebyshev 距離到中心)----
float edgeD      = max(abs(p.x), abs(p.y));   // 0 中心,1 格邊
float borderMask = smoothstep(0.86, 0.94, edgeD);

// ---- 字母 SDF:1/3 格子隨機帶 c / y / b / e / r / u ----
float hasDigit  = step(0.67, cellSeed);
float digitPick = floor(fract(cellSeed * 31.7) * 6.0);   // 0=c 1=y 2=b 3=e 4=r 5=u

float d = 1e9;
if (hasDigit > 0.5) {
  // dp = p / 1.4 → 字母 h=0.45 對應 p 約 ±0.63 → 約佔格子 63% 高
  vec2 dp = p / 1.4;
  const float thick = 0.10;
  const float h     = 0.45;

  if (digitPick < 0.5) {
    // c:上橫(右半) + 左豎 + 下橫(右半),開口朝右
    vec2 a = vec2(-0.10, +h); vec2 b = vec2(+0.22, +h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, +h - 0.05); b = vec2(-0.20, -h + 0.05);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.10, -h); b = vec2(+0.22, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else if (digitPick < 1.5) {
    // y:左上 + 右上 兩條斜線匯中,再往下豎一段
    vec2 a = vec2(-0.22, +h); vec2 b = vec2(0.0, 0.0);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.22, +h); b = vec2(0.0, 0.0);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(0.0, 0.0); b = vec2(0.0, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else if (digitPick < 2.5) {
    // b:左豎(全) + 上下橫 + 中橫 + 右側上下兩段豎(成兩個小框)
    vec2 a = vec2(-0.20, +h); vec2 b = vec2(-0.20, -h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, +h); b = vec2(+0.12, +h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.18, +h - 0.05); b = vec2(+0.18, +0.05);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, 0.0); b = vec2(+0.12, 0.0);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.18, -0.05); b = vec2(+0.18, -h + 0.05);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, -h); b = vec2(+0.12, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else if (digitPick < 3.5) {
    // e:左豎 + 上橫(長) + 中橫(短) + 下橫(長)
    vec2 a = vec2(-0.20, +h); vec2 b = vec2(-0.20, -h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, +h); b = vec2(+0.20, +h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, 0.0); b = vec2(+0.10, 0.0);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, -h); b = vec2(+0.20, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else if (digitPick < 4.5) {
    // r:左豎 + 上橫(短) + 右上豎(短) + 中橫(短) + 右下斜腳
    vec2 a = vec2(-0.20, +h); vec2 b = vec2(-0.20, -h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, +h); b = vec2(+0.12, +h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.18, +h - 0.05); b = vec2(+0.18, +0.05);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, 0.0); b = vec2(+0.15, 0.0);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(0.0, 0.0); b = vec2(+0.22, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else {
    // u:左豎 + 右豎 + 下橫(三段在底部夾角會合)
    vec2 a = vec2(-0.20, +h); vec2 b = vec2(-0.20, -h + 0.05);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.20, +h); b = vec2(+0.20, -h + 0.05);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, -h); b = vec2(+0.20, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  }
}
float digitMask = (hasDigit > 0.5) ? (1.0 - smoothstep(0.0, 0.04, d)) : 0.0;

// ---- 色彩合成 (CyberCube 多彩) ----
vec3 cBg     = vec3(0.024, 0.031, 0.082);   // #060815 接近黑(微藍)
vec3 cBorder = vec3(0.18, 0.14, 0.28);       // 統一暗紫格框
vec3 cHit    = vec3(1.0, 0.96, 0.98);        // 踩中熱白
vec3 cRipple = vec3(0.17, 0.83, 0.72);       // 漣漪青藍(統一)

vec3 col = cBg;

// 統一格框(idle 微亮)
col += cBorder * borderMask * idleBright * 2.5;

// 每格獨立 tint 的內部微光(讓 idle 時整面就有顏色)
col += cellTint * (1.0 - borderMask) * 0.10 * (0.4 + 0.6 * idleFlicker);

// 字母呼吸 — 用該格 tint
col += cellTint * digitMask * (0.45 + 0.40 * idleFlicker);

// 漣漪(整格瀰漫)
col += cRipple * ripple * 0.9;

// 命中格:整格染熱白,邊緣稍弱讓字母浮起來
col = mix(col, cHit, clickHit * (1.0 - borderMask * 0.4));

// 命中格的字母反白加亮(讓字在被踩時最搶眼)
col += cHit * digitMask * clickHit * 0.7;

return col;
