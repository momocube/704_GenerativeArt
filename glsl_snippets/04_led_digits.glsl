// === LED Digits 七段顯示器陣列 ===
// 0–9 七段數字陣列，各格獨立跳動。
// 接縫處理：36 欄整數環繞，hash 用 mod 36。

const float TAU  = 6.2831853;
const float NCOL = 36.0;

float lon = atan(dir.z, dir.x);
float lat = asin(clamp(dir.y, -1.0, 1.0));

vec2 uv = vec2(lon * NCOL / TAU, lat * 6.0);

float cx = floor(uv.x);
float cy = floor(uv.y);
vec2 cellUV = fract(uv);

float cx_mod = mod(cx, NCOL);

float rate = 1.0 + hash13(vec3(cx_mod, cy, 0.0)) * 6.0;
float n    = floor(u_time * rate + hash13(vec3(cx_mod, cy, 3.7)) * 10.0);
float digit = mod(n, 10.0);

// x 軸加負號 → 修正 CAVE 內視角下的鏡像
vec2 p = (cellUV - 0.5) * vec2(-2.4, 1.3);

float segW = 0.07;
float segH = 0.40;
float segL = 0.28;

vec2 da = abs(p - vec2( 0.0,  segH + segW)) - vec2(segL, segW);
float sa = length(max(da, 0.0)) + min(max(da.x, da.y), 0.0);

vec2 dg = abs(p - vec2( 0.0, 0.0)) - vec2(segL, segW);
float sg = length(max(dg, 0.0)) + min(max(dg.x, dg.y), 0.0);

vec2 dd = abs(p - vec2( 0.0, -segH - segW)) - vec2(segL, segW);
float sd = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0);

vec2 db = abs(p - vec2( segL + segW,  segH * 0.5)) - vec2(segW, segH * 0.5);
float sb = length(max(db, 0.0)) + min(max(db.x, db.y), 0.0);

vec2 dc = abs(p - vec2( segL + segW, -segH * 0.5)) - vec2(segW, segH * 0.5);
float sc = length(max(dc, 0.0)) + min(max(dc.x, dc.y), 0.0);

vec2 df = abs(p - vec2(-segL - segW,  segH * 0.5)) - vec2(segW, segH * 0.5);
float sf = length(max(df, 0.0)) + min(max(df.x, df.y), 0.0);

vec2 de = abs(p - vec2(-segL - segW, -segH * 0.5)) - vec2(segW, segH * 0.5);
float se = length(max(de, 0.0)) + min(max(de.x, de.y), 0.0);

float A=0.,B=0.,C=0.,D=0.,E=0.,F=0.,G=0.;
if (digit < 0.5)      { A=1.;B=1.;C=1.;D=1.;E=1.;F=1.;G=0.; }
else if (digit < 1.5) { B=1.;C=1.; }
else if (digit < 2.5) { A=1.;B=1.;D=1.;E=1.;G=1.; }
else if (digit < 3.5) { A=1.;B=1.;C=1.;D=1.;G=1.; }
else if (digit < 4.5) { B=1.;C=1.;F=1.;G=1.; }
else if (digit < 5.5) { A=1.;C=1.;D=1.;F=1.;G=1.; }
else if (digit < 6.5) { A=1.;C=1.;D=1.;E=1.;F=1.;G=1.; }
else if (digit < 7.5) { A=1.;B=1.;C=1.; }
else if (digit < 8.5) { A=1.;B=1.;C=1.;D=1.;E=1.;F=1.;G=1.; }
else                  { A=1.;B=1.;C=1.;D=1.;F=1.;G=1.; }

float BIG = 1e3;
float dist = min(
  min(min(mix(BIG, sa, A), mix(BIG, sb, B)), min(mix(BIG, sc, C), mix(BIG, sd, D))),
  min(min(mix(BIG, se, E), mix(BIG, sf, F)),     mix(BIG, sg, G)));
float ghostDist = min(min(min(sa, sb), min(sc, sd)), min(min(se, sf), sg));

float lit   = 1.0 - smoothstep(-0.01, 0.01, dist);
float ghost = 1.0 - smoothstep(-0.005, 0.025, ghostDist);

vec3 colLit   = vec3(1.0, 0.20, 0.05);
vec3 colGhost = vec3(0.12, 0.02, 0.01);
vec3 colBg    = vec3(0.01, 0.005, 0.0);

vec3 col = colBg;
col = mix(col, colGhost, ghost * 0.7);
col = mix(col, colLit, lit);
col += vec3(1.0, 0.35, 0.12) * lit * 0.3;

float ripple = clickRipple(dir, 12.0, 2.0, 5.0);
col = mix(col, vec3(0.2, 1.0, 0.4) * lit, clamp(abs(ripple) * 3.0, 0.0, 1.0));

return col;
