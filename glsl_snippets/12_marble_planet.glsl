// === Marble Sky 大理石天空 ===
// 水墨暈染風的木星條紋 — 奶白紙底上暈出深青/暖橘/磚紅三色墨,加 2 顆漂移風暴。
// 跟 Aurora 的差別:墨韻有大量留白、邊緣羽化、節奏較慢、低飽和。
//
// 接縫處理:
//   所有 lon 乘數固定為整數 → sin(整數×lon) 跨 ±π 自然繞回。
//   每個 lon 相關項再乘 cos(lat) → 極點 lon 影響→0,消除極點 moiré。
//   風暴用 3D 角距離 acos(dot(nrm,c)) → 與 lon/lat 脫鉤,seamless。

vec3  nrm = normalize(dir);
float lon = atan(nrm.z, nrm.x);
float lat = asin(clamp(nrm.y, -1.0, 1.0));

float t  = u_time * 0.06;           // 走墨的慢節奏
float pf = cos(lat);                 // pole factor:極點→0

// ---- 互動 ----
float md = u_mouseValid > 0.5
    ? acos(clamp(dot(nrm, u_mouseDir), -1.0, 1.0))
    : 10.0;
float mouseBleed = exp(-md * 2.0);
float rip = clickRipple(nrm, 6.0, 1.0, 2.2);

// ---- 主 warp:5 層整數諧波,× pf 抑制極點 ----
float warp = 0.0;
warp += pf * 0.55 * sin( 2.0 * lon + 4.0 * lat + t * 1.0);
warp += pf * 0.40 * sin( 3.0 * lon - 3.0 * lat + t * 1.3);
warp += pf * 0.28 * sin( 5.0 * lon + 6.0 * lat + t * 0.7);
warp += pf * 0.18 * sin( 7.0 * lon - 5.0 * lat + t * 1.9);
warp += pf * 0.12 * sin(11.0 * lon + 8.0 * lat + t * 2.3);

// ---- 風暴(2 顆漂移)— 球面 Gaussian ----
vec3 storm1C = normalize(vec3(cos(t * 0.4),        -0.30, sin(t * 0.4)));
vec3 storm2C = normalize(vec3(cos(-t * 0.3 + 2.1), +0.40, sin(-t * 0.3 + 2.1)));
float d1 = acos(clamp(dot(nrm, storm1C), -1.0, 1.0));
float d2 = acos(clamp(dot(nrm, storm2C), -1.0, 1.0));
float storm1 = exp(-d1 * d1 * 14.0);
float storm2 = exp(-d2 * d2 * 24.0);
warp += pf * storm1 * 1.5 * sin(6.0 * lon + t * 4.0);
warp += pf * storm2 * 1.0 * sin(9.0 * lon - t * 3.5);

warp += rip * 1.2;
warp += pf * mouseBleed * 0.5 * sin(6.0 * lon + t * 3.0);

// ---- 濃淡 mask:大尺度墨暈分布,造成留白 ----
float density = 0.5;
density += pf * 0.35 * sin(1.0 * lon + 2.0 * lat + t * 0.4);
density += pf * 0.25 * sin(2.0 * lon - 1.0 * lat + t * 0.6);
density = clamp(density, 0.0, 1.0);

// ---- 條紋(三角波取代 sin → 墨色「重-淡-重」節奏)----
float v = lat * 2.8 + warp;
v += pf * 0.4 * sin(3.0 * lon + v * 2.0 + t);

float tri  = abs(fract(v * 0.42) - 0.5) * 2.0;    // 0..1
float band = 1.0 - smoothstep(0.05, 0.55, tri);    // 帶中心=1,帶間=0

// ---- 三色墨輪選 ----
float bandIdx = floor(v * 0.42);
float pick    = fract(bandIdx * 0.27 + sin(bandIdx * 7.3) * 0.5);

vec3 inkTeal   = vec3(0.20, 0.50, 0.55);
vec3 inkSalmon = vec3(0.88, 0.45, 0.32);
vec3 inkBrick  = vec3(0.52, 0.18, 0.20);

vec3 ink;
if      (pick < 0.45) ink = inkTeal;
else if (pick < 0.78) ink = inkSalmon;
else                  ink = inkBrick;

// 紙底
vec3 paper = vec3(0.94, 0.89, 0.78);

// ---- 暈染合成 ----
float inkAmt = band * density;

// 帶緣羽化纖維:只在條紋邊緣可見
float edgeMask = smoothstep(0.05, 0.22, tri) * smoothstep(0.55, 0.30, tri);
float fiber    = 0.5 + 0.5 * sin(v * 9.0 + warp * 3.0);
inkAmt += edgeMask * fiber * 0.25 * density;

// 滑鼠處墨色加濃
inkAmt += mouseBleed * u_mouseValid * 0.12;
inkAmt  = clamp(inkAmt, 0.0, 1.0);

vec3 col = mix(paper, ink, inkAmt);

// 帶中心墨堆積(更深一階)
col = mix(col, ink * 0.65, band * density * 0.35);

// 極區褪色回紙
col = mix(col, paper, (1.0 - pf) * 0.45);

// 風暴中心略染
col = mix(col, inkSalmon,        storm1 * 0.50);
col = mix(col, inkBrick * 1.05,  storm2 * 0.35);

// ---- 互動反饋 ----
float ring = clickRing(nrm, 0.7);
col = mix(col, paper * 1.05, ring * 0.65);

col += vec3(0.25, 0.18, 0.08) * rip * 0.45;

return col;
