// === Voronoi Cells 細胞分割 ===
// 3D Voronoi 直接作用在球面上 → 跨面無縫。
// 每個 cell 有自己的相位與顏色，點擊讓細胞依序亮起。

vec3 p = dir * 6.0 + vec3(u_time * 0.10, 0.0, u_time * 0.07);
vec3 ip = floor(p);
vec3 fp = fract(p);

float d1 = 1e9;          // 到最近 site 的距離
float d2 = 1e9;          // 第二近 → 用來畫邊界
vec3 nearest = vec3(0.0);

for (int z = -1; z <= 1; z++)
for (int y = -1; y <= 1; y++)
for (int x = -1; x <= 1; x++) {
  vec3 g = vec3(float(x), float(y), float(z));
  vec3 h = hash33(ip + g);
  vec3 o = g + 0.5 + 0.45 * sin(u_time * 0.6 + h * 6.2831);
  float d = length(o - fp);
  if (d < d1) { d2 = d1; d1 = d; nearest = ip + g; }
  else if (d < d2) { d2 = d; }
}

// 邊界 (兩個最近距離差很小 = 邊)
float edge = smoothstep(0.0, 0.06, d2 - d1);

// 每個 cell 一個顏色 + 脈動
float seed = hash13(nearest);
float pulse = 0.5 + 0.5 * sin(u_time * 0.8 + seed * 30.0);
vec3 cellCol = paletteAurora(seed + u_time * 0.03);

// 點擊在球面上引發環狀波，掃過 cell 中心 → 亮
float ring = clickRing(dir, 0.9);

vec3 col = cellCol * (0.15 + 0.55 * pulse);
col *= mix(0.2, 1.0, edge);  // 邊界暗一點，分隔清楚
col += ring * vec3(1.0, 0.8, 0.5) * 1.2;

// 滑鼠所在 cell 微微發光
float md = acos(clamp(dot(dir, u_mouseDir), -1.0, 1.0));
col += exp(-md * 4.0) * 0.25 * cellCol * u_mouseValid;

return col;
