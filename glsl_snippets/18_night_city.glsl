// === Night City 夜之城天際線 ===
// 360° 摩天樓剪影 + 隨機窗光 + 漂浮霓虹招牌 + 紫粉天空。
// 點擊 = 天空閃電，拖曳 = 桃紫光跡飛過。
//
// 接縫處理：
//   - 天際線：N = 48 整數欄環繞，建築高度 hash 用 mod 48 對齊
//   - 窗格、霓虹招牌：直接 3D hash 採樣 dir → 天生無縫

const float TAU  = 6.2831853;
const float NCOL = 48.0;

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

// ---- 紫粉漸層天空 ----
vec3 skyTop = vec3(0.04, 0.02, 0.16);   // 天頂深紫
vec3 skyMid = vec3(0.32, 0.08, 0.42);   // 中段紫
vec3 skyHor = vec3(0.78, 0.32, 0.55);   // 地平線桃粉
float skyT  = smoothstep(0.0, 1.0, lat);
vec3 sky = mix(skyHor, mix(skyMid, skyTop, skyT), smoothstep(0.0, 0.6, lat));
// 雲層噪聲讓紫粉透氣 (降幅度避免過亮)
sky += fbm3(dir * 2.0 + vec3(0.0, u_time * 0.04, 0.0)) * vec3(0.07, 0.035, 0.14);

// ---- 天際線（48 整數欄環繞）----
float colPos = lon * NCOL / TAU;
float colId  = mod(floor(colPos), NCOL);
// 4 層樓型 → 多數矮樓鋪底 + 偶爾地標摩天樓，360 環境才有戲劇感
// 區域分群 (8 個 district) → 高樓集中在某些區，不平均散
//   65% 矮樓:    0.02 ~ 0.04   (~1.1°~2.3°)  ── 大多數
//   20% 中矮:    0.04 ~ 0.06   (~2.3°~3.4°)
//   10% 中高:    0.07 ~ 0.11   (~4.0°~6.3°)
//    5% 地標:    0.13 ~ 0.21   (~7.5°~12.0°)  ── 整個 360 約 2~3 棟
float h1 = hash13(vec3(colId,  7.3, 0.0));   // 該欄主高度
float t1 = hash13(vec3(colId, 13.7, 0.0));   // 樓型分類
float jt = hash13(vec3(colId, 27.0, 0.0));   // 微抖動

// 區域分群：每 6 欄為一個 district，downtown 機率提升高樓
float zoneId   = floor(colPos / 6.0);
float zoneT    = hash13(vec3(zoneId, 99.0, 0.0));   // 0=郊區、1=downtown
float tBiased  = t1 - smoothstep(0.5, 1.0, zoneT) * 0.15;   // downtown 整體往高 tier 偏

float bldgTop;
if      (tBiased < 0.65) bldgTop = mix(0.02, 0.04, h1);
else if (tBiased < 0.85) bldgTop = mix(0.04, 0.06, h1);
else if (tBiased < 0.95) bldgTop = mix(0.07, 0.11, h1);
else                     bldgTop = mix(0.13, 0.21, h1);
bldgTop += (jt - 0.5) * 0.018;  // ±0.5° 抖動破除等高線
// 城市材質遮罩：lat < bldgTop → 1（建築/街道），lat > bldgTop → 0（天空）
float bldgMask = 1.0 - smoothstep(0.0, 0.012, lat - bldgTop);

// ---- 窗光：3D hash 在球面上採樣 ----
vec3  winId   = floor(dir * 75.0);
float wHash   = hash13(winId);
float wLit    = step(0.62, wHash);
float wBlink  = 0.62 + 0.38 * sin(u_time * 1.7 + wHash * 47.0);
// 三色窗光：黃 / 青 / 粉
vec3 wColor;
if      (wHash < 0.78) wColor = vec3(1.0, 0.85, 0.45);   // 暖黃
else if (wHash < 0.92) wColor = vec3(0.45, 0.95, 1.0);   // 冷青
else                   wColor = vec3(1.0, 0.50, 0.88);   // 桃粉
// 窗點：cell 中心高斯（dot 收緊 + 強度降低 → 光暈變小）
vec3  wCenter = (winId + 0.5) / 75.0;
float wD = length(dir - wCenter);
float wDot = exp(-wD * 1100.0);
vec3 winLight = wColor * wLit * wBlink * wDot * 2.4;

vec3 bldg = vec3(0.015, 0.008, 0.03) + winLight;

vec3 res = mix(sky, bldg, bldgMask);

// ---- 閃爍星空 (天空區，3D hash 稀疏分布) ----
vec3  starId   = floor(dir * 160.0);
float sHash    = hash13(starId);
float starLit  = step(0.992, sHash);                            // 約 0.8% cells
vec3  sCenter  = (starId + 0.5) / 160.0;
float starD    = length(dir - sCenter);
float starDot  = exp(-starD * 1500.0);                          // 中心約 1~2 px
// 各星獨立速率 / 相位 → 不會同步閃
float twkRaw   = 0.5 + 0.5 * sin(u_time * (1.5 + fract(sHash * 31.0) * 5.0) + sHash * 89.0);
float twinkle  = 0.25 + 0.75 * pow(twkRaw, 2.0);                // pow 拉長暗區 → punchy
// 偏冷或偏暖
vec3  starCol  = mix(vec3(0.85, 0.95, 1.0), vec3(1.0, 0.95, 0.82), fract(sHash * 3.7));
// 只在天空 (非建築) 顯示，地平線附近淡化
float skyOnly  = (1.0 - bldgMask) * smoothstep(0.05, 0.20, lat);
res += starCol * starLit * starDot * twinkle * skyOnly * 2.0;

// ---- 漂浮霓虹招牌（6 顆，慢漂、彩虹色）----
// 光暈 5x 收緊：26 → 130（半衰角 ~1.5° → ~0.3°，約 1m 內淡化）
for (int i = 0; i < 6; i++) {
  float fi  = float(i);
  float aa0 = TAU * fract(hash13(vec3(fi, 1.3, 0.0)) + u_time * (0.004 + fract(fi * 0.13) * 0.006));
  float aa  = atan(sin(aa0), cos(aa0));                 // 收回 ±π，避免跨界跳動
  float bb  = mix(0.15, 0.55, hash13(vec3(fi, 2.7, 0.0)))
            + sin(u_time * 0.25 + fi * 2.1) * 0.025;    // 微微上下浮動
  vec3 sDir = vec3(cos(bb) * cos(aa), sin(bb), cos(bb) * sin(aa));
  float sD  = acos(clamp(dot(dir, sDir), -1.0, 1.0));
  vec3 sCol = paletteAurora(fi * 0.17 + u_time * 0.08);
  res += exp(-sD * 130.0) * sCol * 0.85;
}

// ---- 點擊閃電：inline 環掃，1 秒內完全消失，halo 5x 收緊 ----
float flash = 0.0;
for (int i = 0; i < 32; i++) {
  if (i >= u_clickCount) break;
  vec4 c = u_clicks[i];
  float cd = acos(clamp(dot(dir, c.xyz), -1.0, 1.0));
  float age = u_time - c.w;
  if (age >= 0.0 && age < 1.0) {
    float r = age * 1.8;
    // (1.0 - age) 線性淡出 → age=1.0 時為 0
    flash += exp(-pow((cd - r) * 40.0, 2.0)) * (1.0 - age);
  }
}
res += flash * vec3(1.0, 0.95, 1.2) * 0.5;

// ---- 拖曳光跡 (u_drags 通道，地板大光點) ----
float dt = dragTrail(dir, 1.0, 30.0);
res += dt * vec3(1.0, 0.55, 0.92) * 1.4;

// 輕度 gamma 收尾 → 整體柔和、亮的不爆掉
res = pow(max(res, 0.0), vec3(0.97));

return res;
