// === Mirror Pool 鏡映水波 ===
// 配對 14_cell_grid:cell_grid 是「資料感」,這個是「液態鏡面」。
// 地板 = 暗池水面,click 像丟石頭進去,漣漪以同心圓擴張且互相干涉。
// 天花板 = 地板的鏡像(同步反射,稍暗,呼應「深淵鏡」品牌名)。
// 牆面 = 水位線 + 漣漪打到牆上的折射光暈。
// drag = 手指劃過水面的連續尾波。

// ---- venue dimensions (eye frame, eye at origin) ----
const float ROOM_W = 5.5;
const float ROOM_D = 8.0;
const float WALL_H = 2.5;
const float EYE_H  = 1.6;

// 漣漪參數
const float WAVE_SPEED = 2.5;
const float WAVE_FREQ  = 3.5;
const float WAVE_LIFE  = 4.5;

// ---- 本 pixel 的 ray-box → faceType + 水面投影座標 ----
float tX = (ROOM_W * 0.5) / max(abs(dir.x), 1e-6);
float tZ = (ROOM_D * 0.5) / max(abs(dir.z), 1e-6);
float tY = (dir.y >  1e-6) ? ((WALL_H - EYE_H) / dir.y) :
           (dir.y < -1e-6) ? (EYE_H / -dir.y)            : 1e9;
float tt = min(min(tX, tY), tZ);
vec3 hit = dir * tt;

int faceType = 2;                    // 0=floor, 1=ceiling, 2=wall
if (tY <= tX && tY <= tZ) faceType = (dir.y > 0.0) ? 1 : 0;

vec2 wPos = vec2(hit.x, hit.z);      // 水面座標(米)

// ---- 掃 u_clicks:每個 click 的水面位置 + 漣漪疊加 ----
float waveSum = 0.0;
for (int i = 0; i < 32; i++) {
  if (i >= u_clickCount) break;
  vec4 c = u_clicks[i];
  float age = u_time - c.w;
  if (age < 0.0 || age >= WAVE_LIFE) continue;

  // INLINE: ray-box click → 地板水面位置
  vec3 cdir = c.xyz;
  float ctY = (cdir.y < -1e-6) ? (EYE_H / -cdir.y) : 1e9;
  float ctX = (ROOM_W * 0.5) / max(abs(cdir.x), 1e-6);
  float ctZ = (ROOM_D * 0.5) / max(abs(cdir.z), 1e-6);
  float ctt = min(min(ctX, ctY), ctZ);
  vec3 chit = cdir * ctt;
  vec2 src  = vec2(chit.x, chit.z);

  // INLINE: 漣漪 sin 波 + 振幅淡化(env 收緊讓環變細)
  float r     = length(wPos - src);
  float ringR = age * WAVE_SPEED;
  float wave  = sin((r - ringR) * WAVE_FREQ);
  float env   = exp(-abs(r - ringR) * 2.0) * exp(-age * 0.55);
  waveSum += wave * env;
}

// drag 連續細波
for (int i = 0; i < 32; i++) {
  if (i >= u_dragCount) break;
  vec4 d = u_drags[i];
  float age = u_time - d.w;
  if (age < 0.0 || age >= 1.2) continue;

  vec3 ddir = d.xyz;
  float dtY = (ddir.y < -1e-6) ? (EYE_H / -ddir.y) : 1e9;
  float dtX = (ROOM_W * 0.5) / max(abs(ddir.x), 1e-6);
  float dtZ = (ROOM_D * 0.5) / max(abs(ddir.z), 1e-6);
  float dtt = min(min(dtX, dtY), dtZ);
  vec3 dhit = ddir * dtt;
  vec2 dsrc = vec2(dhit.x, dhit.z);

  float r = length(wPos - dsrc);
  waveSum += sin(r * WAVE_FREQ * 1.8) * exp(-r * 3.5) * (1.0 - age / 1.2) * 0.25;
}

// ---- 顏色合成 ----
vec3 cBg     = vec3(0.005, 0.010, 0.025);   // 深淵底
vec3 cCrest  = vec3(0.024, 0.831, 1.000);   // 波峰亮青 #06D4FF
vec3 cTrough = vec3(0.075, 0.180, 0.420);   // 波谷深藍

vec3 col = cBg;

if (faceType == 0) {
  // 地板:完整水池,波峰亮、波谷暗
  col += cCrest  * max(waveSum, 0.0)  * 0.45;
  col += cTrough * max(-waveSum, 0.0) * 0.22;
  col += cCrest  * abs(waveSum)       * 0.04;
} else if (faceType == 1) {
  // 天花板:鏡映亮度更低(Cross 沒有 ceiling 面板,但 cubemap 還是計算)
  col += cCrest  * max(waveSum, 0.0)  * 0.22;
  col += cTrough * max(-waveSum, 0.0) * 0.12;
} else {
  // 牆面:水位線維持原本亮度(地板在 eye frame y = -EYE_H)
  float distFromWaterline = hit.y - (-EYE_H);
  float waterlineGlow = exp(-distFromWaterline * 3.5);
  col += cCrest * waterlineGlow * 0.55;
  // 地板漣漪折射到牆面(波峰餘光)
  float interactiveGlow = exp(-distFromWaterline * 6.5);
  col += cCrest * max(waveSum, 0.0) * interactiveGlow * 0.25;

  // ---- 牆面專屬 click 互動:brand 色同心擴張環(2D 物理距離) ----
  // 判斷本 pixel 在哪面牆
  int wallSide;
  if (tX <= tZ) wallSide = (dir.x > 0.0) ? 0 : 1;   // ±X 長牆
  else          wallSide = (dir.z > 0.0) ? 4 : 5;   // ±Z 短牆

  // pixel 在牆面的 2D 物理座標(水平 x 垂直,以地板為 y=0)
  vec2 pixel2D = (wallSide < 2)
    ? vec2(hit.z, hit.y + EYE_H)    // ±X 牆:(深度, 高度)
    : vec2(hit.x, hit.y + EYE_H);   // ±Z 牆:(寬度, 高度)

  float wallHit  = 0.0;
  vec3  wallCol  = vec3(0.0);

  for (int i = 0; i < 32; i++) {
    if (i >= u_clickCount) break;
    vec4 cc = u_clicks[i];
    float age = u_time - cc.w;
    if (age < 0.0 || age >= 3.0) continue;

    // Ray-box click,找 click 所在面
    vec3 cdir = cc.xyz;
    float ctX = (ROOM_W * 0.5) / max(abs(cdir.x), 1e-6);
    float ctZ = (ROOM_D * 0.5) / max(abs(cdir.z), 1e-6);
    float ctY = (cdir.y >  1e-6) ? ((WALL_H - EYE_H) / cdir.y) :
                (cdir.y < -1e-6) ? (EYE_H / -cdir.y) : 1e9;
    float ctt = min(min(ctX, ctY), ctZ);
    vec3 chit = cdir * ctt;

    // click 必須在「本 pixel 同一面牆」
    int clickSide = -1;
    if (ctY <= ctX && ctY <= ctZ) continue;        // click 在地板/天花板,跳過
    if (ctX <= ctZ) clickSide = (cdir.x > 0.0) ? 0 : 1;
    else            clickSide = (cdir.z > 0.0) ? 4 : 5;
    if (clickSide != wallSide) continue;            // 不是同一面牆

    // click 在牆面的 2D 物理座標
    vec2 click2D = (wallSide < 2)
      ? vec2(chit.z, chit.y + EYE_H)
      : vec2(chit.x, chit.y + EYE_H);

    // 同心環:r 是 pixel 到 click 的物理米距離
    float r       = length(pixel2D - click2D);
    float ringR   = age * 1.4;                      // 1.4 m/s 擴張
    float thick   = 0.18 + age * 0.07;              // 環隨時間變厚
    float ring    = exp(-pow((r - ringR) / thick, 2.0) * 1.8);
    float fade    = (age < 0.12) ? 1.0 : exp(-(age - 0.12) * 0.9);

    // 每個 click 自己的 brand 色
    float pickF = fract(cc.w * 11.3);
    vec3 cTint;
    if      (pickF < 0.20) cTint = vec3(0.024, 0.831, 1.000);  // 亮青
    else if (pickF < 0.40) cTint = vec3(0.145, 0.388, 0.922);  // 寶藍
    else if (pickF < 0.60) cTint = vec3(0.133, 0.773, 0.369);  // 翡綠
    else if (pickF < 0.80) cTint = vec3(0.980, 0.800, 0.082);  // 琥珀
    else                   cTint = vec3(0.937, 0.267, 0.267);  // 緋紅

    float intensity = ring * fade;
    if (intensity > wallHit) {
      wallHit = intensity;
      wallCol = cTint;
    }
  }
  col += wallCol * wallHit * 0.75;

  // ---- 牆面 drag:亮點不擴張環 ----
  for (int i = 0; i < 32; i++) {
    if (i >= u_dragCount) break;
    vec4 dd = u_drags[i];
    float dgAge = u_time - dd.w;
    if (dgAge < 0.0 || dgAge >= 0.8) continue;

    vec3 ddir = dd.xyz;
    float dgtX = (ROOM_W * 0.5) / max(abs(ddir.x), 1e-6);
    float dgtZ = (ROOM_D * 0.5) / max(abs(ddir.z), 1e-6);
    float dgtY = (ddir.y >  1e-6) ? ((WALL_H - EYE_H) / ddir.y) :
                 (ddir.y < -1e-6) ? (EYE_H / -ddir.y) : 1e9;
    float dgtt = min(min(dgtX, dgtY), dgtZ);
    vec3 dghit = ddir * dgtt;

    int dgSide = -1;
    if (dgtY <= dgtX && dgtY <= dgtZ) continue;     // 不在牆上
    if (dgtX <= dgtZ) dgSide = (ddir.x > 0.0) ? 0 : 1;
    else              dgSide = (ddir.z > 0.0) ? 4 : 5;
    if (dgSide != wallSide) continue;

    vec2 dg2D = (wallSide < 2)
      ? vec2(dghit.z, dghit.y + EYE_H)
      : vec2(dghit.x, dghit.y + EYE_H);

    float dgR = length(pixel2D - dg2D);
    float dgDot = exp(-dgR * 18.0) * (1.0 - dgAge / 0.8);
    col += vec3(0.85, 0.95, 1.0) * dgDot * 0.85;
  }
}

// ---- 繁星(dir.y > 0 的「天空」區域) ----
// 高密度細網格 + sCenter 夾範圍確保星完整在格內不被裁
if (dir.y > 0.0) {
  float skyMask = smoothstep(0.0, 0.30, dir.y);   // 越往上越多星

  vec3 sDir  = dir * 24.0;                         // 24³ = 13824 格(上半球 ~6900)
  vec3 sCell = floor(sDir);
  vec3 sFrac = sDir - sCell;
  float sHash = hash13(sCell);
  if (sHash > 0.65) {                              // 35% → ~2400 顆星(上半球)
    // sCenter 夾 [0.25, 0.75],搭配 smoothstep 終點 0.18 → 永不碰格邊
    vec3 sCenter = vec3(0.25, 0.25, 0.25) + vec3(
      hash13(sCell + vec3(1.7, 0.0, 0.0)),
      hash13(sCell + vec3(0.0, 2.3, 0.0)),
      hash13(sCell + vec3(0.0, 0.0, 3.1))
    ) * 0.5;
    float sd = length(sFrac - sCenter);
    // 銳利點:full bright sd<0.13,過渡到 0.18,外面全黑
    float dot1 = 1.0 - smoothstep(0.13, 0.18, sd);
    // 自然亮度分布:pow^2 比 pow^4 更平均 → 多數中等亮度而不是全暗一兩顆亮
    float brightness = pow(hash13(sCell + vec3(7.7, 0.0, 0.0)), 2.0);
    float starBright = 0.4 + 2.4 * brightness;     // 範圍 0.4 ~ 2.8
    // 閃爍
    float twinkle = 0.6 + 0.4 * sin(u_time * (1.0 + sHash * 2.5) + sHash * 30.0);
    // 色溫變化
    float warmth = hash13(sCell + vec3(13.3, 0.0, 0.0));
    vec3 starCol = mix(vec3(0.85, 0.90, 1.0), vec3(1.0, 0.94, 0.82), warmth);
    col += starCol * dot1 * starBright * twinkle * skyMask;
  }
}

return col;
