# GLSL Snippets — 數字 / 幾何效果集

每個 `.glsl` 檔案都是一段可直接貼到 **Custom 編輯器** 的 `shaderCustom(vec3 dir)` 函式本體。
**所有效果都已調整為 360° 環繞無縫**（lon=±π 接縫處不會看到斷線）。

## 用法

1. 開啟 `index.html`，dock 上點 **Custom** tile (或點 `< >` 圖示)
2. 編輯器切到 **GLSL** 分頁
3. 把 `.glsl` 檔案內容整個複製貼上 → 蓋掉原本的內容
4. 按 **Apply** (或 ⌘/Ctrl+Enter) 套用
5. 喜歡的話按 **★ Save current…** 存進收藏，dock 上會多一個 tile

## 內容清單

| 檔案 | 名稱 | 特徵 | 接縫處理方式 |
|------|------|------|------|
| `01_hex_grid.glsl`           | Hex Grid Pulse 六邊形脈動 | 六邊形磁磚 + 點擊波紋 | 12 整數欄環繞，hash mod 12 |
| `02_binary_rain.glsl`        | Binary Rain 二進位降雨 | 0/1 直落，駭客風 | 36 整數欄環繞，hash mod 36 |
| `03_voronoi_cells.glsl`      | Voronoi Cells 細胞分割 | 3D Voronoi + 點擊環掃 | 直接用 3D dir，天生無縫 |
| `04_led_digits.glsl`         | LED Digits 七段顯示器 | 0–9 數字陣列 | 36 整數欄環繞，hash mod 36 |
| `05_triangle_lattice.glsl`   | Triangle Lattice 三角晶格 | 等邊三角形翻面 | 16 整數欄環繞，hash mod 16 |
| `06_concentric_polygons.glsl`| Concentric Polygons 同心多邊形 | 從滑鼠擴張多邊形環 | tangent plane 對稱，天生無縫 |
| `07_grid_counter.glsl`       | Grid Counter 數字計數網格 | 二進位計分板 | 16 整數欄環繞 |
| `08_circle_packing.glsl`     | Circle Packing 圓形堆疊 | 多尺度呼吸圓 | 直接用 3D dir，天生無縫 |
| `09_704_bounce.glsl`         | 704 Bounce 數字彈跳 | 巨型白色「704」場域彈跳，點擊抖動 | lon 環繞用 `mod`，文字本地座標連續 |
| `10_704_swarm.glsl`          | 704 Swarm 小數字漂浮 | 100 個小「704」3D 漂浮，重疊時 SDF 融合 | gnomonic 投影，遠近自動縮放 |
| `14_cell_grid.glsl`          | Cell Grid 閃動格子 (CyberCube) | 五面 0.25m 物理格 + Matrix 字流 (c y b e r u 0 4 7) + 5 色 Abyss Mirror 配色 + click/drag 雙通道 | ray-box(用實際 5.5×8×2.5m + EYE_H=1.6 算)|
| `15_mirror_pool.glsl`        | Mirror Pool 鏡映水波 | 地板暗池漣漪 + 天花板鏡映 + 牆面水位線發光,click 像扔石頭,drag 連續波 | ray-box 投影水面位置,天/地對稱 |
| `16_particle_field.glsl`     | Particle Field 粒子流場 | 32 顆 brand 色粒子沿弧線漂浮,click 推開附近粒子,drag 留亮青光跡 | 3D dir 球面分布,天生無縫 |
| `17_sonar_sweep.glsl`        | Sonar Sweep 雷達掃描 | 中央 4 秒週期掃描環 + 每個 click 變獨立 ping 源(brand 色) + lat/lon 雷達盤格線 + vignette | 整數環繞 lat 8 / lon 16 |
| `18_night_city.glsl`         | Night City 夜之城天際線 | 360° 摩天樓剪影 + 黃 / 青 / 粉窗光 + 漂浮霓虹招牌 + 紫粉天空，點擊閃電、拖曳桃紫光跡 | 48 整數欄環繞 + 3D hash 窗 |

## 無縫原理速記

- **接縫**只可能出現在 `lon = atan(dir.z, dir.x)` 的 ±π 分支切口（也就是左牆中央那條線）
- **解法 A：3D 採樣** — 用 `fbm3(dir)`、`hash33(dir*k)`、`Voronoi(dir*k)` 直接以 3D 方向取樣，永遠連續
- **解法 B：整數環繞** — 把 `lon * mult` 換成 `lon * N / 2π`，N 為整數欄數；hash 內用 `mod(cell_id, N)`，讓 ±π 接縫剛好落在 cell 邊界上
- **緯度極點**：等矩形映射下天頂 / 腳底正下方會有單點奇異，所有 lon 在那邊都重合 → cell 變細條狀但不會出現斷線

## 可用變數與函式 (BASE_FS 已提供)

- `dir` — 球面上的單位向量 (vec3)
- `u_time` — 從載入起的秒數
- `u_mouseDir`, `u_mouseValid` — 滑鼠投影到球面的方向 / 是否有效
- `u_clicks[32]`, `u_clickCount` — **觸碰**事件 (`down`)：每筆 xyz=方向, w=出現時間, 4 秒內參與運算
- `u_drags[32]`, `u_dragCount`  — **拖曳**樣本 (`move`)：每筆 xyz=方向, w=取樣時間, 1.2 秒內參與運算
- `fbm3(p)`, `vnoise3(p)`, `hash13(p)`, `hash33(p)` — 噪聲與雜湊
- `clickRipple(dir, freq, decayR, decaySpeed)` — 觸控波紋
- `clickRing(dir, speed)` — 觸控擴張環
- `dragTrail(dir, life, tightness)` — 拖曳光跡（小亮點 + 線性淡出，`life` 預設 1.0、`tightness` 預設 60.0）
- `paletteAurora(t)` — 內建調色盤

### 觸碰 vs 拖曳的視覺分工

來源都是同一條 TouchService WebSocket（`ws://127.0.0.1:20111/`），但分兩條視覺通道：

| 通道 | 觸發點 | 推薦視覺 | 範例 |
|------|--------|----------|------|
| **觸碰** `u_clicks` | 腳剛踩下的瞬間（一次性事件，存活 ~4s） | 環掃、波紋、爆破、變色 | `clickRipple()` / `clickRing()` |
| **拖曳** `u_drags`  | 腳移動中（連續取樣，存活 ~1.2s） | 光跡尾巴、軌跡描邊、磁場吸引子 | `dragTrail()` |

把 `dragTrail()` 加進自己的 shader 範例（在 `shaderCustom` 的結尾混色）：

```glsl
float dt = dragTrail(dir, 1.0, 60.0);          // 1 秒淡出、緊縮的點
col += dt * vec3(0.6, 0.95, 1.0) * 1.5;        // 冷色光跡疊上去
// 或拿來扭曲：
// dir = normalize(dir + dt * 0.1 * someAxis);
```

也可以自己跑 loop 從原始陣列拿資料，做你想要的視覺（例如連線、引力場）：

```glsl
for (int i = 0; i < 32; i++) {
  if (i >= u_dragCount) break;
  vec4 d = u_drags[i];                          // d.xyz = 方向、d.w = 時間
  float cd = acos(clamp(dot(dir, d.xyz), -1.0, 1.0));
  float age = u_time - d.w;
  // ... 自己定義視覺
}
```

> 預設只有 **Aurora** 已經套用 `dragTrail()` 當示範。`glsl_snippets/` 內既有 19 個檔案
> 暫未加入拖曳通道，可依需要自己加入上面的範例片段。

## 自己寫新效果時記得

- WebGL 1 (GLSL ES 1.0)：迴圈邊界要常數、無動態陣列索引、不能在函式內定義函式
- 凡用 `lon = atan(z, x)` 的 2D 圖案 → 欄數一定要設為整數，否則左牆中央會破
- 凡用 `dir * scale` 的 3D 圖案 → 不用特別處理，自動無縫
- 牆面實際渲染 2688 × 3840，避免太重的 per-fragment 計算
