// === Circle Packing 圓形堆疊 ===
// 隨機大小的圓形漂浮在空間中，互相不重疊（近似），會跟著呼吸。

// 取多個尺度的 voronoi-like 圓
vec3 col = vec3(0.02, 0.03, 0.06);

float scales[4];
scales[0] = 1.8;
scales[1] = 3.6;
scales[2] = 6.4;
scales[3] = 11.0;

for (int s = 0; s < 4; s++) {
  float sc = scales[s];
  vec3 p = dir * sc + vec3(u_time * 0.04 * float(s+1), 0.0, u_time * 0.03);
  vec3 ip = floor(p);
  vec3 fp = fract(p) - 0.5;

  float best = 1e9;
  vec3 bestId = vec3(0.0);
  for (int z = -1; z <= 1; z++)
  for (int y = -1; y <= 1; y++)
  for (int x = -1; x <= 1; x++) {
    vec3 g = vec3(float(x), float(y), float(z));
    vec3 h = hash33(ip + g);
    vec3 o = g + (h - 0.5) * 0.8;
    float d = length(o - fp);
    if (d < best) { best = d; bestId = ip + g; }
  }

  // 每個 site 自己的半徑 + 呼吸頻率
  float seed = hash13(bestId);
  float radius = 0.22 + 0.18 * seed;
  float breath = 0.5 + 0.5 * sin(u_time * (0.8 + seed * 2.0) + seed * 30.0);
  radius *= 0.7 + 0.6 * breath;

  // 圓的填色 + 邊緣
  float edge = smoothstep(radius, radius - 0.04, best);
  float ring = smoothstep(radius + 0.02, radius, best) - smoothstep(radius, radius - 0.02, best);

  vec3 cFill = paletteAurora(seed + float(s) * 0.13 + u_time * 0.02);
  col = mix(col, cFill * (0.4 + 0.5 * breath), edge * (0.4 - 0.07 * float(s)));
  col += ring * cFill * 0.6;
}

// 點擊讓圓集體脈動
float ripple = clickRipple(dir, 10.0, 1.5, 6.0);
col += abs(ripple) * vec3(1.0, 0.8, 0.5) * 0.6;

// 滑鼠光暈
float md = acos(clamp(dot(dir, u_mouseDir), -1.0, 1.0));
col += exp(-md * 4.0) * 0.18 * vec3(0.7, 0.9, 1.0) * u_mouseValid;

return col;
