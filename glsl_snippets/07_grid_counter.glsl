// === Grid Counter 數字計數網格 ===
// 整面牆是一塊巨型二進位計分板。
// 每列獨立計數，各自速率與起始偏移不同，看起來像同步又非同步的數位陣列。

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

// 切成 16 欄 × 24 列
vec2 uv = vec2((lon + 3.14159265) / 6.2831853, (0.5 - lat / 3.14159265));
vec2 grid = vec2(16.0, 24.0);
vec2 gid = floor(uv * grid);
vec2 gfr = fract(uv * grid);

// cell 中心方塊 SDF
vec2 p = gfr - 0.5;
float box = max(abs(p.x), abs(p.y));
float fill = 1.0 - smoothstep(0.30, 0.36, box);
float edge = (1.0 - smoothstep(0.38, 0.44, box)) * smoothstep(0.36, 0.42, box);

// 每列自己的速率 + 偏移
float rowSpeed  = 6.0 + hash13(vec3(gid.y, 0.0, 0.0)) * 12.0;
float rowOffset = hash13(vec3(gid.y, 7.0, 0.0)) * 1000.0;
float rowCounter = floor(u_time * rowSpeed + rowOffset);

// 該列只用低 16 位元 → 2^15 ≈ 32k，highp float 仍精準
float bitIdx = gid.x; // 0..15
float bit = mod(floor(rowCounter / pow(2.0, bitIdx)), 2.0);

// 點擊翻轉附近 bit
float ripple = clickRipple(dir, 14.0, 2.2, 4.0);
float flip = step(0.6, abs(ripple) * 3.0);
bit = mix(bit, 1.0 - bit, flip);

// 顏色 — 整面用同一藍綠調，亮 bit 才發光
vec3 cOn   = vec3(0.30, 1.00, 0.85);
vec3 cOff  = vec3(0.04, 0.08, 0.16);
vec3 cEdge = vec3(0.15, 0.30, 0.50);

vec3 cellCol = mix(cOff, cOn, bit);
vec3 col = vec3(0.01, 0.02, 0.04);
col = mix(col, cellCol, fill);
col += cEdge * edge * 0.8;
col += cOn * fill * bit * 0.4;  // 亮 bit 加輝光

// 行頭那一欄當 label 區（暗下來）
float labelCol = step(gid.x, 0.5);
col *= mix(1.0, 0.4, labelCol * (1.0 - bit));

return col;
