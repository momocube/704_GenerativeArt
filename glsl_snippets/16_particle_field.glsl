// === Particle Field 粒子流場 ===
// 配對 14_cell_grid:cell_grid 是「字符鎖在格內變動」,這個是「粒子穿越空間流動」。
// 32 顆 brand 色粒子分布在球面上,依 sin/cos 漂移軌道,軌跡像極光絲。
// click → 該位置注入「擾動波」,附近粒子被推遠後逐漸回流。
// drag → 留下亮藍色光跡尾巴。

vec3 col = vec3(0.005, 0.008, 0.020);   // 近黑底

// ---- 32 顆粒子掃描 ----
// 每顆粒子有:基底方向(hash 給) + 軌跡軸(hash 給) + 漂移週期
float bestFalloff = 0.0;
vec3  bestColor   = vec3(0.0);

for (int i = 0; i < 32; i++) {
  float fi = float(i);

  // 基底方向(隨機分布球面)
  vec3 baseDir = normalize(vec3(
    hash13(vec3(fi, 0.5, 0.0)) - 0.5,
    hash13(vec3(fi, 1.7, 0.0)) - 0.5,
    hash13(vec3(fi, 2.9, 0.0)) - 0.5
  ));

  // 漂移軸(讓粒子繞 baseDir 畫小弧)
  vec3 driftAxis = normalize(vec3(
    hash13(vec3(fi, 3.1, 0.0)) - 0.5,
    hash13(vec3(fi, 4.3, 0.0)) - 0.5,
    hash13(vec3(fi, 5.7, 0.0)) - 0.5
  ));

  float phase  = hash13(vec3(fi, 6.9, 0.0)) * 6.2832;
  float speed  = 0.20 + hash13(vec3(fi, 7.1, 0.0)) * 0.45;
  float amp    = 0.25 + hash13(vec3(fi, 8.3, 0.0)) * 0.35;

  // click 推開:距離 click 越近、age 越小,推力越強
  vec3 pushOff = vec3(0.0);
  for (int j = 0; j < 32; j++) {
    if (j >= u_clickCount) break;
    vec4 cc = u_clicks[j];
    float age = u_time - cc.w;
    if (age < 0.0 || age > 1.2) continue;
    float ang = acos(clamp(dot(baseDir, cc.xyz), -1.0, 1.0));
    float push = exp(-ang * 4.0) * exp(-age * 2.0);
    pushOff += normalize(baseDir - cc.xyz * dot(baseDir, cc.xyz)) * push * 0.5;
  }

  // 粒子當前方向 = base + 軌道 + 擾動
  vec3 pDir = normalize(baseDir + driftAxis * sin(u_time * speed + phase) * amp + pushOff);

  // 與本 pixel 的角距離
  float ang = acos(clamp(dot(dir, pDir), -1.0, 1.0));

  // 粒子顏色(從 5 色 brand 取)
  float pickF = fract(hash13(vec3(fi, 9.5, 0.0)) * 5.0);
  vec3 pTint;
  if      (pickF < 0.20) pTint = vec3(0.024, 0.831, 1.000);  // 亮青 #06D4FF
  else if (pickF < 0.40) pTint = vec3(0.145, 0.388, 0.922);  // 寶藍 #2563EB
  else if (pickF < 0.60) pTint = vec3(0.133, 0.773, 0.369);  // 翡綠 #22C55E
  else if (pickF < 0.80) pTint = vec3(0.980, 0.800, 0.082);  // 琥珀 #FACC15
  else                   pTint = vec3(0.937, 0.267, 0.267);  // 緋紅 #EF4444

  // 粒子光暈:中心 hot,邊緣 soft falloff
  float core    = exp(-ang * 70.0);          // 緊縮 hot 核心
  float halo    = exp(-ang * 18.0) * 0.45;   // 寬鬆光暈
  float falloff = core + halo;

  // 用 additive 疊上去(粒子重疊處更亮)
  col += pTint * falloff * 0.95;

  // 找最強粒子(用來補充核心亮度,讓粒子看起來不會被背景吃掉)
  if (core > bestFalloff) {
    bestFalloff = core;
    bestColor   = pTint;
  }
}

// 最近粒子的 hot 核心再壓白(中心高光)
col += vec3(1.0) * bestFalloff * 0.4;

// ---- 微微 ambient noise(讓黑底有點呼吸感,非死黑) ----
float ambient = fbm3(dir * 0.8 + vec3(0.0, u_time * 0.05, 0.0));
col += vec3(0.020, 0.035, 0.060) * (ambient * 0.6 + 0.3);

// ---- drag 軌跡(亮青光跡) ----
for (int i = 0; i < 32; i++) {
  if (i >= u_dragCount) break;
  vec4 d = u_drags[i];
  float age = u_time - d.w;
  if (age < 0.0 || age > 1.0) continue;
  float ang = acos(clamp(dot(dir, d.xyz), -1.0, 1.0));
  float trail = exp(-pow(ang * 50.0, 2.0)) * (1.0 - age);
  col += vec3(0.7, 0.95, 1.0) * trail * 0.9;
}

return col;
