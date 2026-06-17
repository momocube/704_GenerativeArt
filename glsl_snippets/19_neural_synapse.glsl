// === Neural Synapse 神經突觸 ===
// Ghost in the Shell 風腦內視覺:3D fbm 拉出神經絲,亮點是突觸節點,
// 脈衝沿絲傳遞,整體呼吸式發光。沒有格子,純結構性。
// 接縫:全程 3D dir 採樣,天生無縫。
//
// 互動設計:
//   主場域維持原本青藍/紫/暖色調 → 觀眾踩踏時才出現「桃紅光暈」
//   click(踩下) + drag(連續踩) 都是桃紅,自寫迴圈精確控制 0.5 秒內完全消失

const float TAU = 6.2831853;

// === 神經絲:兩層 ridged fbm 疊出網絡感 ===
vec3 q1 = dir * 2.6 + vec3(0.0,            u_time * 0.10,  0.0);
vec3 q2 = dir * 5.1 + vec3(u_time * 0.07, -u_time * 0.05,  u_time * 0.06);

float n1 = fbm3(q1);
float n2 = fbm3(q2);

float ridge1 = 1.0 - abs(n1 - 0.5) * 3.5;
float ridge2 = 1.0 - abs(n2 - 0.5) * 6.0;
float thread1 = smoothstep(0.70, 0.98, ridge1);
float thread2 = smoothstep(0.82, 1.00, ridge2) * 0.5;

// === 突觸節點 ===
float nodeField = smoothstep(0.78, 1.0, ridge1) * smoothstep(0.78, 1.0, ridge2);
float node = pow(nodeField, 1.5);

// === 脈衝 ===
float pulse1Phase = u_time * 1.8;
float pulse1 = sin(n1 * 28.0 - pulse1Phase);
float pulseHit1 = smoothstep(0.88, 1.0, pulse1) * thread1;

float pulse2Phase = u_time * 2.5 + 1.7;
float pulse2 = sin(n2 * 40.0 - pulse2Phase);
float pulseHit2 = smoothstep(0.92, 1.0, pulse2) * thread2;

// === 整體呼吸 ===
vec3 breathQ = dir * 0.6 + vec3(0.0, u_time * 0.06, 0.0);
float breathe = 0.6 + 0.4 * fbm3(breathQ);

// === 調色 (原版) ===
vec3 cTeal = vec3(0.10, 0.95, 0.85);
vec3 cBlue = vec3(0.15, 0.55, 1.00);
vec3 cPurp = vec3(0.55, 0.20, 0.95);
vec3 cPink = vec3(1.00, 0.20, 0.60);
vec3 cWarm = vec3(1.00, 0.75, 0.40);

vec3 threadCol = mix(cTeal, cBlue, smoothstep(0.3, 0.7, n2));
vec3 nodeCol   = mix(cPurp, cPink, smoothstep(0.4, 0.8, n1));
vec3 pulseCol  = mix(cWarm, cPink, 0.5);

// === 深空底色 (原版) ===
vec3 bg = vec3(0.0, 0.005, 0.02);
bg += cPurp * 0.05 * n1;

// === 互動光暈 (桃紅薄漣漪,0.5s 內消失) ===============================
// 改成從踩踏點往外擴張的「薄環」:粗細比強光點小 5 倍,亮度降到 1/3
// click/drag 都用自寫迴圈精確控制 0.5s 完整消失
vec3 cStompPink = vec3(1.00, 0.22, 0.55);   // 踩踏專屬桃紅

// click(踩下):薄環從中心擴張,0.5s 內走完並消失
float clickRing_ = 0.0;
for (int i = 0; i < 32; i++) {
  if (i >= u_clickCount) break;
  vec4 cc = u_clicks[i];
  float age = u_time - cc.w;
  if (age < 0.0 || age >= 0.5) continue;

  float ang   = acos(clamp(dot(dir, cc.xyz), -1.0, 1.0));
  float ringR = age * 3.0;          // 0.5s 內擴張到 1.5 弧度(~86°)
  float thick = 0.025;              // 環厚度(原本 spot 半徑 ~0.13,薄 5 倍)
  float ring  = exp(-pow((ang - ringR) / thick, 2.0));
  float fade  = 1.0 - age / 0.5;    // 0.5s 線性消失
  clickRing_  = max(clickRing_, ring * fade);
}

// drag(連續踩):一樣薄環,同 0.5s
float dragRing = 0.0;
for (int i = 0; i < 32; i++) {
  if (i >= u_dragCount) break;
  vec4 dd = u_drags[i];
  float age = u_time - dd.w;
  if (age < 0.0 || age >= 0.5) continue;

  float ang   = acos(clamp(dot(dir, dd.xyz), -1.0, 1.0));
  float ringR = age * 3.0;
  float thick = 0.025;
  float ring  = exp(-pow((ang - ringR) / thick, 2.0));
  float fade  = 1.0 - age / 0.5;
  dragRing    = max(dragRing, ring * fade);
}
// =====================================================================

// === 組合 (主場景維持原樣) ===
vec3 col = bg;
col += threadCol * thread1 * breathe * 0.7;
col += threadCol * thread2 * 0.55;
col += pulseCol  * pulseHit1 * 1.4;
col += pulseCol  * pulseHit2 * 1.0;
col += nodeCol   * node * 1.6;

// 桃紅踩踏漣漪(唯一桃紅出現的地方,亮度降到原本 1/3)
col += cStompPink * (clickRing_ * 0.53 + dragRing * 0.30);

// === Bloom ===
vec3 bright = max(col - 0.6, 0.0);
col += bright * bright * 2.5;

col = pow(max(col, 0.0), vec3(0.85));
return col;
