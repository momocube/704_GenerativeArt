// === Concentric Polygons 同心多邊形 ===
// 從滑鼠 (或 0 軸) 為圓心，向外擴張的多邊形環。
// 邊數隨半徑變化：中心是三角形 → 四邊形 → 六邊形 → 圓。

// 圓心用滑鼠方向，沒滑鼠時用 +Y (天頂)
vec3 center = u_mouseValid > 0.5 ? u_mouseDir : vec3(0.0, 1.0, 0.0);

// 到圓心的角距離 (0..π)
float r = acos(clamp(dot(dir, center), -1.0, 1.0));

// 圓心切平面上的 2D 座標 — 用 Gram-Schmidt 取兩條切向量
vec3 up = abs(center.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
vec3 tx = normalize(cross(up, center));
vec3 ty = cross(center, tx);
float theta = atan(dot(dir, ty), dot(dir, tx));  // 切平面方位角

// 動態邊數：3 → 4 → 5 → 6 → ∞（圓），隨 r 變化
float sides = 3.0 + floor(r * 4.0);

// 正 N 邊形 SDF (在切平面 polar 座標)
float a = theta + u_time * (0.15 + 0.05 * sin(sides));
float n = sides;
float modAng = mod(a, 2.0 * 3.14159265 / n) - 3.14159265 / n;
float polyR  = r * cos(modAng) / cos(3.14159265 / n);

// 等間距環 (r-domain 中每 0.18 弧度一條)
float ringSpace = 0.18;
float rd = mod(polyR, ringSpace) - ringSpace * 0.5;
float ring = 1.0 - smoothstep(0.005, 0.018, abs(rd));

// 隨時間旋出新環
float wave = sin(polyR * 12.0 - u_time * 3.0);

// 顏色按環編號漸變
float ringIdx = floor(polyR / ringSpace);
vec3 c1 = paletteAurora(ringIdx * 0.07 + u_time * 0.04);
vec3 c2 = paletteAurora(ringIdx * 0.07 + u_time * 0.04 + 0.5);

vec3 col = vec3(0.02, 0.03, 0.06);
col += ring * mix(c1, c2, 0.5 + 0.5 * wave);

// 中央亮點
col += exp(-r * 6.0) * vec3(1.0, 0.9, 0.7) * 0.7;

// 點擊產生擴張環
float clickR = clickRing(dir, 0.8);
col += clickR * paletteAurora(u_time * 0.1) * 1.4;

return col;
