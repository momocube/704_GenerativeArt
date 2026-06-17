// === Sonar Sweep 雷達掃描 ===
// 配對 14_cell_grid:cell_grid 是「Matrix 字流」,這個是「SOP 設備儀器感」。
// 跟 Operations Briefing 海報語言一致 — 場域變成監控雷達室。
// 中央每 ~4 秒放射性掃描環 (從觀眾正前方擴出 hemispherical 環)。
// 每個 click → 變成獨立 ping 源,自己擴出環,brand 色隨機選。
// drag → 留下青色點光跡,模擬游標掃過螢光屏。
// 場域加細格線 (lat 8 / lon 16) 做雷達盤背景。

vec3 col = vec3(0.012, 0.025, 0.045);   // 深藍墨底

// ---- 雷達盤背景格線 ----
// lat 線:8 條水平
float lat = asin(clamp(dir.y, -1.0, 1.0));            // -π/2 ~ π/2
float latLine = abs(fract(lat * 8.0 / 3.14159 + 0.5) - 0.5);
float latGlow = smoothstep(0.04, 0.0, latLine) * 0.18;

// lon 線:16 條垂直(用整數環繞避免接縫)
float lon = atan(dir.z, dir.x);                        // -π ~ π
float lonLine = abs(fract(lon * 16.0 / 6.2832 + 0.5) - 0.5);
float lonGlow = smoothstep(0.03, 0.0, lonLine) * 0.18;

col += vec3(0.06, 0.18, 0.30) * (latGlow + lonGlow);

// 中央十字準星(z 軸方向)
vec3 centerDir = vec3(0.0, 0.0, 1.0);
float centerAng = acos(clamp(dot(dir, centerDir), -1.0, 1.0));
col += vec3(0.10, 0.50, 0.70) * exp(-centerAng * 30.0) * 0.5;

// ---- 中央定時掃描環 ----
const float CENTER_SWEEP_PERIOD = 4.0;
const float CENTER_SWEEP_THICK  = 0.10;
float sweepPhase = mod(u_time, CENTER_SWEEP_PERIOD) / CENTER_SWEEP_PERIOD;
float sweepR = sweepPhase * 3.14159;                   // 0 ~ π 弧度
float sweepThick = CENTER_SWEEP_THICK + sweepPhase * 0.06;
float sweepRing = 1.0 - smoothstep(0.0, sweepThick, abs(centerAng - sweepR));
sweepRing *= (1.0 - sweepPhase * 0.6);                 // 越擴越淡
col += vec3(0.024, 0.831, 1.000) * sweepRing * 0.55;   // 亮青掃描環

// ---- 每個 click = 獨立 ping 源 ----
const float PING_LIFE = 2.5;
for (int i = 0; i < 32; i++) {
  if (i >= u_clickCount) break;
  vec4 c = u_clicks[i];
  float age = u_time - c.w;
  if (age < 0.0 || age >= PING_LIFE) continue;

  // ping 環半徑:用比中央掃描更快的速率
  float pingR = age * 1.4;
  float pingThick = 0.08 + age * 0.08;
  float pingAng = acos(clamp(dot(dir, c.xyz), -1.0, 1.0));

  float ring = 1.0 - smoothstep(0.0, pingThick, abs(pingAng - pingR));
  float ringFade = (1.0 - age / PING_LIFE);
  ring *= ringFade * ringFade;

  // 每個 ping 自己的顏色(從 5 色取,用 click 時間做 seed)
  float pickF = fract(c.w * 11.3);
  vec3 pTint;
  if      (pickF < 0.20) pTint = vec3(0.024, 0.831, 1.000);  // 亮青
  else if (pickF < 0.40) pTint = vec3(0.145, 0.388, 0.922);  // 寶藍
  else if (pickF < 0.60) pTint = vec3(0.133, 0.773, 0.369);  // 翡綠
  else if (pickF < 0.80) pTint = vec3(0.980, 0.800, 0.082);  // 琥珀
  else                   pTint = vec3(0.937, 0.267, 0.267);  // 緋紅

  col += pTint * ring;

  // 中心點 hot spot(剛 click 時的「目標標記」)
  float centerHot = exp(-pingAng * 40.0) * exp(-age * 1.5);
  col += pTint * centerHot * 1.2;
}

// ---- drag 軌跡(綠色雷達拖痕) ----
for (int i = 0; i < 32; i++) {
  if (i >= u_dragCount) break;
  vec4 d = u_drags[i];
  float age = u_time - d.w;
  if (age < 0.0 || age >= 0.8) continue;
  float ang = acos(clamp(dot(dir, d.xyz), -1.0, 1.0));
  float trail = exp(-ang * 35.0) * (1.0 - age / 0.8);
  col += vec3(0.133, 0.773, 0.369) * trail * 0.9;  // 翡綠雷達光
}

// ---- vignette(往外圈微暗,儀器螢幕感) ----
float fromCenter = acos(clamp(dir.z, -1.0, 1.0));
float vignette = smoothstep(2.5, 1.0, fromCenter);
col *= (0.6 + 0.4 * vignette);

return col;
