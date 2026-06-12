// === Pickleball Trail Sea 皮克球軌跡海 ===
  // 在 CAVE 內 N 顆 optic-yellow 皮克球 3D 漂浮，每顆都拖著發光殘影軌跡。
  // 接口同其他 snippet：貼到 Custom 編輯器 (GLSL) → Apply。
  //
  // 注意：球與球的真實剛體碰撞，fragment shader 不能做（沒 state buffer）。
  // 這版用獨立軌跡 + 殘影視覺，重疊時 max-blend 看起來像穿梭碰撞。

  const float PI = 3.14159265;
  const vec3 EYE = vec3(0.0, 1.6, 0.0);

  // ---- CAVE 內漂浮箱形範圍 ----
  const vec3 BMIN = vec3(-2.2, 0.4, -3.6);
  const vec3 BMAX = vec3(+2.2, 2.2, +3.6);

  // ---- 球參數 ----
  const float BALL_SIZE  = 0.10;   // 直徑 10 cm
  const float TRAIL_SECS = 1.4;    // 殘影往回看的時間長度（秒）

  // optic yellow（接近真實皮克球色）
  const vec3 BALL_BODY = vec3(0.93, 0.95, 0.27);
  const vec3 BALL_CORE = vec3(1.00, 1.00, 0.85);

  float coreA  = 0.0;
  float haloA  = 0.0;
  float trailA = 0.0;

  for (int i = 0; i < 40; i++) {
    float fi = float(i);
    vec3 s = hash33(vec3(fi * 1.317, fi * 2.713 + 5.0, fi * 0.971 + 11.0));

    // 各球獨立速率 & 相位（不同方向、節奏）
    vec3 rate  = vec3(0.04, 0.035, 0.04) + s * vec3(0.06, 0.05, 0.06);
    vec3 phase = s * 100.0;

    // ---- 當前位置：球體本身 ----
    vec3 tri0 = abs(2.0 * fract(u_time * rate + phase) - 1.0);
    vec3 P3   = mix(BMIN, BMAX, tri0);

    vec3 d_eP = P3 - EYE;
    float dist = length(d_eP);
    if (dist > 0.5) {
      vec3 dirP = d_eP / dist;
      float dotDP = dot(dir, dirP);
      if (dotDP > 0.97) {
        float ang  = acos(clamp(dotDP, -1.0, 1.0));
        float angR = BALL_SIZE / dist;
        float halo = exp(-pow(ang / (angR * 1.7), 2.0));
        float core = 1.0 - smoothstep(angR * 0.55, angR * 0.85, ang);
        haloA = max(haloA, halo);
        coreA = max(coreA, core);
      }
    }

    // ---- 殘影：往回採樣 6 點 ----
    for (int j = 1; j <= 6; j++) {
      float fj = float(j) / 6.0;
      float pastT = u_time - fj * TRAIL_SECS;
      vec3 triP = abs(2.0 * fract(pastT * rate + phase) - 1.0);
      vec3 P3p  = mix(BMIN, BMAX, triP);
      vec3 d_eP2 = P3p - EYE;
      float dist2 = length(d_eP2);
      if (dist2 < 0.5) continue;
      vec3 dirP2 = d_eP2 / dist2;
      float dot2 = dot(dir, dirP2);
      if (dot2 < 0.97) continue;
      float ang2  = acos(clamp(dot2, -1.0, 1.0));
      float angR2 = (BALL_SIZE / dist2) * (1.0 - fj * 0.45);
      float k = exp(-pow(ang2 / (angR2 * 1.4), 2.0)) * (1.0 - fj);
      trailA = max(trailA, k);
    }
  }

  // ---- 合成 ----
  vec3 col = vec3(0.0);
  col += BALL_BODY * (haloA  * 0.75);
  col += BALL_BODY * (trailA * 0.55);
  col  = mix(col, BALL_CORE, coreA);

  // ---- 點擊：爆出亮環反饋 ----
  float ring = clickRing(dir, 0.9);
  col += BALL_CORE * ring * 0.6;

  return col;