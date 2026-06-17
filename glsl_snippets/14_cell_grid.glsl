// === Cell Grid 閃動格子 (CyberCube + Matrix 字流) ===
// CAVE 5.5(寬) × 8(深) × 2.5(高) m, 視點 EYE_H = 1.6m (站立人眼高度,NOT 中心)。
// 用 ray-box intersection 取代 cubemap 投影,讓地板/牆角精準對齊物理稜邊。
//
// 物理(eye frame, eye 在 (0, 0, 0)):
//   floor   y = -EYE_H = -1.6     (地板距視點 1.6m 下方)
//   ceiling y = WALL_H - EYE_H = +0.9  (天花板距視點 0.9m 上方)
//   ±X 長牆 x = ±ROOM_W/2 = ±2.75
//   ±Z 短牆 z = ±ROOM_D/2 = ±4
// Y 軸不對稱! 必須分開算 floor/ceiling 的 t (之前統一用 HALF.y = 1.25 是錯的)
//
// per-face cell count (cells = 0.25m physical):
//   ±X 長牆 (8m × 2.5m)    → Nface = (32, 10)
//   ±Y 地/天 (5.5m × 8m)   → Nface = (22, 32)
//   ±Z 短牆 (5.5m × 2.5m)  → Nface = (22, 10)
//
// Matrix 字流:每格獨立 tick (0.15-0.5 Hz) 重抽 glyph。
//   30 種狀態:9 個 glyph (c y b e r u 0 4 7) + 21 個 empty → 30% 亮 70% 暗
//   tick 變動瞬間亮閃 → 模擬「字流換頁」感
// 每格從 5 色 Abyss Mirror 調色盤隨機取色 (tint 不變,只 glyph 變)。
// 踩到格子(click)→ 該格白熱亮 + 鄰格漣漪以 cell-grid Chebyshev 距離外擴 2.5 秒。
//
// 配色 Abyss Mirror 深淵鏡風格(取樣自閃動格子內部 SOP 視覺):
//   近黑底 + 亮青/寶藍/翡綠/琥珀/緋紅 五色高彩 lit 格 + 暗青格線

// ---- Venue dimensions (公尺) ----
const float ROOM_W = 5.5;       // X 軸寬
const float ROOM_D = 8.0;       // Z 軸深
const float WALL_H = 2.5;       // Y 軸高
const float EYE_H  = 1.6;       // 視點距地板高度

// ---- Ray-box intersection: dir → (face, uv∈[-1,1]) ----
// X / Z 對稱 (視點水平居中),Y 不對稱 (站立視點偏上)
float tX = (ROOM_W * 0.5) / max(abs(dir.x), 1e-6);
float tZ = (ROOM_D * 0.5) / max(abs(dir.z), 1e-6);
float tY = (dir.y >  1e-6) ? ((WALL_H - EYE_H) / dir.y) :       // 往上看天花板
           (dir.y < -1e-6) ? (EYE_H / -dir.y)            : 1e9; // 往下看地板

float t = min(min(tX, tY), tZ);
vec3 hit = dir * t;          // 命中物理座標 (eye frame, 以視點為原點)

float face;
vec2 uv;
// 牆面 uv.y 對齊牆的物理範圍 y ∈ [-EYE_H, WALL_H-EYE_H] → [-1, +1]
//   uv.y = (hit.y + EYE_H) * 2 / WALL_H - 1
if (tX <= tY && tX <= tZ) {
  if (dir.x > 0.0) { face = 0.0; uv = vec2(-hit.z * 2.0 / ROOM_D, (hit.y + EYE_H) * 2.0 / WALL_H - 1.0); }  // +X 右(長)牆
  else             { face = 1.0; uv = vec2( hit.z * 2.0 / ROOM_D, (hit.y + EYE_H) * 2.0 / WALL_H - 1.0); }  // -X 左(長)牆
} else if (tY <= tZ) {
  if (dir.y > 0.0) { face = 2.0; uv = vec2( hit.x * 2.0 / ROOM_W, -hit.z * 2.0 / ROOM_D); } // +Y 天
  else             { face = 3.0; uv = vec2( hit.x * 2.0 / ROOM_W,  hit.z * 2.0 / ROOM_D); } // -Y 地
} else {
  if (dir.z > 0.0) { face = 4.0; uv = vec2( hit.x * 2.0 / ROOM_W, (hit.y + EYE_H) * 2.0 / WALL_H - 1.0); }  // +Z 前(短)牆
  else             { face = 5.0; uv = vec2(-hit.x * 2.0 / ROOM_W, (hit.y + EYE_H) * 2.0 / WALL_H - 1.0); }  // -Z 後(短)牆
}

// ---- per-face cell count (each cell = 0.25m × 0.25m physical) ----
vec2 Nface;
if (face < 1.5) {
  Nface = vec2(32.0, 10.0);  // ±X 長牆: 8m × 2.5m
} else if (face < 3.5) {
  Nface = vec2(22.0, 32.0);  // ±Y 地/天: 5.5m × 8m
} else {
  Nface = vec2(22.0, 10.0);  // ±Z 短牆: 5.5m × 2.5m
}

vec2 g        = (uv * 0.5 + 0.5) * Nface;
vec2 cell     = floor(g);
vec2 cellFrac = g - cell;
vec2 p        = (cellFrac - 0.5) * 2.0;

float cellSeed = hash13(vec3(cell, face));

// ---- per-cell tint:5 色 Abyss Mirror 調色盤 等機率 ----
float tintPick = floor(fract(cellSeed * 17.3) * 5.0);
vec3 cellTint;
if (tintPick < 0.5)      cellTint = vec3(0.024, 0.831, 1.000);  // 亮青  #06D4FF
else if (tintPick < 1.5) cellTint = vec3(0.145, 0.388, 0.922);  // 寶藍  #2563EB
else if (tintPick < 2.5) cellTint = vec3(0.133, 0.773, 0.369);  // 翡綠  #22C55E
else if (tintPick < 3.5) cellTint = vec3(0.980, 0.800, 0.082);  // 琥珀  #FACC15
else                     cellTint = vec3(0.937, 0.267, 0.267);  // 緋紅  #EF4444

// ---- 掃 u_clicks:本格 vs 點擊格 的 Chebyshev 距離 ----
float clickHit = 0.0;
float ripple   = 0.0;
for (int j = 0; j < 32; j++) {
  if (j >= u_clickCount) break;
  vec4 c = u_clicks[j];
  float age = u_time - c.w;
  if (age < 0.0 || age >= 3.0) continue;

  // 同一個 ray-box 投影:click dir → (cFace, cUv)(同上,Y 軸不對稱)
  vec3  cdir = c.xyz;
  float ctX  = (ROOM_W * 0.5) / max(abs(cdir.x), 1e-6);
  float ctZ  = (ROOM_D * 0.5) / max(abs(cdir.z), 1e-6);
  float ctY  = (cdir.y >  1e-6) ? ((WALL_H - EYE_H) / cdir.y) :
               (cdir.y < -1e-6) ? (EYE_H / -cdir.y)            : 1e9;
  float ct   = min(min(ctX, ctY), ctZ);
  vec3  chit = cdir * ct;

  float cFace;
  vec2  cUv;
  if (ctX <= ctY && ctX <= ctZ) {
    if (cdir.x > 0.0) { cFace = 0.0; cUv = vec2(-chit.z * 2.0 / ROOM_D, (chit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
    else              { cFace = 1.0; cUv = vec2( chit.z * 2.0 / ROOM_D, (chit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
  } else if (ctY <= ctZ) {
    if (cdir.y > 0.0) { cFace = 2.0; cUv = vec2( chit.x * 2.0 / ROOM_W, -chit.z * 2.0 / ROOM_D); }
    else              { cFace = 3.0; cUv = vec2( chit.x * 2.0 / ROOM_W,  chit.z * 2.0 / ROOM_D); }
  } else {
    if (cdir.z > 0.0) { cFace = 4.0; cUv = vec2( chit.x * 2.0 / ROOM_W, (chit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
    else              { cFace = 5.0; cUv = vec2(-chit.x * 2.0 / ROOM_W, (chit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
  }
  if (abs(cFace - face) > 0.5) continue;   // 點擊在別面 → 跳過(漣漪不跨稜)

  vec2  cCell    = floor((cUv * 0.5 + 0.5) * Nface);
  vec2  dCell    = abs(cell - cCell);
  float chebDist = max(dCell.x, dCell.y);

  // 保證 0.15s 內滿亮(即使 render frame 沒對齊 click 時刻也看得到),
  // 之後再 exp 慢慢衰減,尾巴比原本 1.3 慢
  float fade = (age < 0.15) ? 1.0 : exp(-(age - 0.15) * 1.0);

  if (chebDist < 0.5) clickHit = max(clickHit, fade);

  float r       = age * 6.0;
  float ring    = 1.0 - smoothstep(0.5, 1.5, abs(chebDist - r));
  float falloff = 1.0 / (1.0 + chebDist * 0.4);
  ripple = max(ripple, ring * fade * falloff);
}

// ---- 掃 u_drags:拖曳路徑上的格子也亮起(滑動時每個 cell 都會 fire) ----
// down 走 u_clicks 有 ripple, move 走 u_drags 只亮 cell 不發 ripple
// (避免高頻 move 樣本疊出來的漣漪互相覆蓋變糊)
for (int j = 0; j < 32; j++) {
  if (j >= u_dragCount) break;
  vec4 dd = u_drags[j];
  float dgAge = u_time - dd.w;
  if (dgAge < 0.0 || dgAge >= 0.6) continue;     // drag 樣本壽命 0.6s

  // 同樣 ray-box,找這個 drag 樣本撞到哪個物理 cell
  vec3 ddir = dd.xyz;
  float dgtX = (ROOM_W * 0.5) / max(abs(ddir.x), 1e-6);
  float dgtZ = (ROOM_D * 0.5) / max(abs(ddir.z), 1e-6);
  float dgtY = (ddir.y >  1e-6) ? ((WALL_H - EYE_H) / ddir.y) :
               (ddir.y < -1e-6) ? (EYE_H / -ddir.y)            : 1e9;
  float dgt  = min(min(dgtX, dgtY), dgtZ);
  vec3  dghit = ddir * dgt;

  float dgFace;
  vec2  dgUv;
  if (dgtX <= dgtY && dgtX <= dgtZ) {
    if (ddir.x > 0.0) { dgFace = 0.0; dgUv = vec2(-dghit.z * 2.0 / ROOM_D, (dghit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
    else              { dgFace = 1.0; dgUv = vec2( dghit.z * 2.0 / ROOM_D, (dghit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
  } else if (dgtY <= dgtZ) {
    if (ddir.y > 0.0) { dgFace = 2.0; dgUv = vec2( dghit.x * 2.0 / ROOM_W, -dghit.z * 2.0 / ROOM_D); }
    else              { dgFace = 3.0; dgUv = vec2( dghit.x * 2.0 / ROOM_W,  dghit.z * 2.0 / ROOM_D); }
  } else {
    if (ddir.z > 0.0) { dgFace = 4.0; dgUv = vec2( dghit.x * 2.0 / ROOM_W, (dghit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
    else              { dgFace = 5.0; dgUv = vec2(-dghit.x * 2.0 / ROOM_W, (dghit.y + EYE_H) * 2.0 / WALL_H - 1.0); }
  }
  if (abs(dgFace - face) > 0.5) continue;

  vec2  dgCellPos = floor((dgUv * 0.5 + 0.5) * Nface);
  vec2  dgDelta   = abs(cell - dgCellPos);
  float dgCheb    = max(dgDelta.x, dgDelta.y);

  // 只亮本格,不發漣漪(滑過 cell 該有的「掃光」感)
  if (dgCheb < 0.5) {
    float dgFade = (dgAge < 0.08) ? 1.0 : exp(-(dgAge - 0.08) * 2.5);
    clickHit = max(clickHit, dgFade);
  }
}

// ---- 閒置:每格獨立相位呼吸,~0.8-2.2 Hz ----
float idleFlicker = 0.5 + 0.5 * sin(u_time * (0.8 + cellSeed * 1.4) + cellSeed * 14.0);
float idleBright  = 0.10 + 0.18 * idleFlicker;

// ---- 格框 ----
float edgeD      = max(abs(p.x), abs(p.y));
float borderMask = smoothstep(0.86, 0.94, edgeD);

// ---- Matrix glyph:每格獨立 tick 重抽 + 變動瞬間亮閃 ----
// tick rate 0.15-0.5 Hz (每格約 2-6 秒換一次),比第一版慢 3 倍
float cellTickRate = 0.15 + 0.35 * cellSeed;
float cellTimeF    = u_time * cellTickRate + cellSeed * 100.0;
float cellTick     = floor(cellTimeF);
float tickPhase    = fract(cellTimeF);                       // 0 = 剛變, 1 = 即將再變

// 30 種狀態:0-5=c y b e r u, 6=0, 7=4, 8=7, 9-29=empty
// 多數格暗黑、少數亮起,符合 Abyss Mirror「黑底點點亮」的視覺
float glyphIdx  = floor(fract(hash13(vec3(cellTick, cellSeed * 100.0, face))) * 30.0);
float hasDigit  = (glyphIdx < 8.5) ? 1.0 : 0.0;          // 9/30 = 30% 亮
float digitPick = glyphIdx;

// 變動瞬間亮閃:tickPhase ∈ [0, 0.15] 拉高亮度
float changePulse = smoothstep(0.15, 0.0, tickPhase);

float d = 1e9;
if (hasDigit > 0.5) {
  vec2 dp = p / 1.4;
  const float thick = 0.10;
  const float h     = 0.45;

  if (digitPick < 0.5) {
    // c
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
    // y
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
    // b
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
    // e
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
    // r
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
  } else if (digitPick < 5.5) {
    // u
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
  } else if (digitPick < 6.5) {
    // 0:圓角矩形外減內
    vec2 dO = abs(dp) - vec2(0.22, 0.32);
    float outer = length(max(dO, 0.0)) + min(max(dO.x, dO.y), 0.0) - 0.12;
    vec2 dI = abs(dp) - vec2(0.22 - thick, 0.32 - thick);
    float inner = length(max(dI, 0.0)) + min(max(dI.x, dI.y), 0.0) - max(0.12 - thick, 0.0);
    d = min(d, max(outer, -inner));
  } else if (digitPick < 7.5) {
    // 4:右豎(全高) + 中橫 + 左上豎(半高)
    vec2 a = vec2(+0.20, -h); vec2 b = vec2(+0.20, +h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.22, 0.0); b = vec2(+0.22, 0.0);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(-0.20, 0.0); b = vec2(-0.20, +h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  } else {
    // 7:上橫 + 右上往左下斜
    vec2 a = vec2(-0.22, +h); vec2 b = vec2(+0.22, +h);
    vec2 ba = b - a;          vec2 pa = dp - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
    a = vec2(+0.18, +h); b = vec2(-0.08, -h);
    ba = b - a; pa = dp - a;
    t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    d = min(d, length(pa - t * ba) - thick);
  }
}
// 字緣抗鋸齒範圍從 0.04 → 0.07 (低密度 cell 也有平順邊)
float digitMask = (hasDigit > 0.5) ? (1.0 - smoothstep(0.0, 0.07, d)) : 0.0;

// ---- 色彩合成 (Abyss Mirror 深黑底 + 高彩 lit 格) ----
vec3 cBg     = vec3(0.005, 0.008, 0.020);    // 近純黑(微藍)
vec3 cBorder = vec3(0.04, 0.10, 0.16);        // 暗青格線(隱約見得到網格)
vec3 cHit    = vec3(1.0, 0.98, 0.95);         // 踩中熱白
vec3 cRipple = vec3(0.024, 0.831, 1.000);     // 漣漪亮青 #06D4FF(與調色盤同色系)

vec3 col = cBg;

// 暗青格線(idle 微亮,讓網格隱約浮現)
col += cBorder * borderMask * (0.6 + 0.4 * idleFlicker);

// Lit 格:整格實心發光 (cell 內部 fill + 邊緣 halo)
col += cellTint * (1.0 - borderMask) * hasDigit * (0.50 + 0.35 * idleFlicker);
col += cellTint * borderMask        * hasDigit * (0.35 + 0.30 * idleFlicker);

// 字母 SDF 在 lit 格上再壓深一點(讓字「鏤空」感)
col -= cellTint * digitMask * 0.25;

// Matrix 變動瞬間亮閃(lit 格才閃)
col += cellTint * hasDigit * changePulse * 0.6;

// 漣漪掃過(所有格都受影響)
col += cRipple * ripple * 1.0;

// 踩中:整格熱白爆
col = mix(col, cHit, clickHit * (1.0 - borderMask * 0.3));
col += cHit * digitMask * clickHit * 0.5;

return col;
