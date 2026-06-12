# 美術互動程式遷移指南（給接手的 AI 助手）

> **這份文件的讀者是你——負責改造美術互動程式的 AI 助手。**
> 你的使用者是非程式背景的美術人員，他的程式是「HTML 打包成 exe」的互動應用
> （Electron / NW.js / WebView 類，下稱「美術程式」）。
> 本文件完全自包含：你不需要存取我們的 repo，所有協議細節都內嵌在這裡。
> 請完整讀完再動工，文末有驗收 checklist。
>
> **部署現況（2026-06-11）**：TouchService 已部署在 704 現場電腦並驗證通過
> （踩下→變色實測約 0.1 秒）。你開發的程式如果跑在同一台機器，直接連
> `ws://127.0.0.1:20111/` 即可，不需要安裝任何東西；瀏覽器開
> `http://127.0.0.1:20111/` 是現成的監控頁，可即時對照你收到的觸控是否正確。

---

## 1. 發生了什麼事（架構變更）

### 舊架構（你的程式現在的樣子）

```
[CyberCube 地板硬體] → UDP → [南港專案 Unity 程式]
                                  │ 模擬 OS 滑鼠點擊（PostMessage / SendInput）
                                  ▼
                          [美術程式（你負責的 HTML exe）]
                            └─ 透過 click / mousedown 事件收到「觸控」
```

美術程式現在收到的「觸控」**其實是南港專案幫忙模擬出來的滑鼠點擊**。
這就是為什麼它必須先開南港專案才能動。這個架構有四個硬傷：

1. **單點**：OS 滑鼠只有一顆游標，永遠不可能多點觸控
2. **全場 1 秒冷卻**：模擬層有全域冷卻，任何一格被踩後 1 秒內全場其他點擊都被吞掉
3. **高延遲**：訊號要繞過 Unity 的手勢判定 + 點擊模擬，體感延遲 300ms+
4. **綁定依賴**：南港專案不開、或視窗 z-order 不對，美術程式就收不到輸入

### 新架構（你要改成的樣子）

```
[CyberCube 地板硬體] → UDP → [TouchService（獨立常駐 exe）]
                                  │ WebSocket（JSON 觸控事件，多點、低延遲）
                                  ▼
                          [美術程式] ←─ 你要加的就是這個 WebSocket client
```

- 美術程式**不再需要南港專案**，只要 TouchService 在跑
- 原生多點（實測 60 點併發）、無冷卻、踩下到事件送達 < 5ms
- HTML 環境原生支援 WebSocket，**不需要安裝任何依賴**

---

## 2. 你的改造任務

1. **盤點現有輸入路徑**：找出程式裡所有 `click` / `mousedown` / `pointerdown` /
   `touchstart` 監聽器——這些是舊的「模擬點擊」入口。
2. **加入 WebSocket client**（§4 有可直接使用的完整 class），連到
   `ws://127.0.0.1:20111/`（TouchService 跟美術程式在同一台機器時；
   不同機器則用該機 IP，port 預設 20111）。
3. **把輸入模型從「單游標」改成「多點 Map」**：用 `Map<touchId, touch>` 管理
   活躍觸點。原本「一次只有一個點擊位置」的邏輯（全域變數、單一游標狀態）
   都要改掉。
4. **座標換算**（§5）。
5. **滑鼠路徑建議保留**作為開發時的滑鼠測試 fallback，但要能共存
   （滑鼠事件轉成假 touch 餵同一套處理函式，是最乾淨的做法）。
6. **加斷線重連**（§4 的 class 已內建）：TouchService 重啟時美術程式要能自動恢復。

---

## 3. 協議規格（完整內嵌）

### 連線

- 端點：`ws://<host>:20111/`（純 WebSocket text frame，JSON）
- 連上後**第一包是 hello**（帶 `"type":"hello"` 欄位；一般 frame 沒有 `type`）：

```json
{
  "type": "hello", "v": 1, "venue": "704",
  "canvas": { "w": 2688, "h": 3840 },
  "releaseTimeoutMs": 170,
  "faces": [
    { "index": 0, "name": "Wall Left", "originX": 0, "originY": 640,
      "width": 640, "height": 2048, "cols": 20, "rows": 128, "cellW": 32, "cellH": 16 }
  ]
}
```

`canvas` 是整個場域展開成 2D 平面後的總畫布尺寸（px）。`faces` 是 7 個感應面
在這個畫布上的位置與格子規格（地板、四面牆等，立體場域展開攤平）。

### 觸控 frame（hello 之後的每一包）

```json
{
  "v": 1,
  "seq": 1024,
  "t": 1765432100123,
  "venue": "704",
  "canvas": { "w": 2688, "h": 3840 },
  "events": [
    { "id": 42, "phase": "down", "face": 2,
      "cell": [7, 13], "px": [869, 850], "norm": [0.32329, 0.22135] }
  ],
  "alive": [42, 43]
}
```

| 欄位 | 說明 |
|---|---|
| `seq` | 嚴格遞增流水號（跳號 = 中間有 frame 沒收到，通常不用處理） |
| `t` | 發布時間（unix ms, UTC） |
| `events[].id` | touch ID，單調遞增、**永不重用**。同一隻腳從踩下到離開是同一個 ID |
| `events[].phase` | `down`（踩下，即時零等待）/ `move`（移動）/ `up`（離手） |
| `events[].face` | 感應面 index（0-6，對照 hello 的 faces） |
| `events[].cell` | 該面內的格子座標 `[col, row]` |
| `events[].px` | 畫布絕對像素座標 `[x, y]` |
| `events[].norm` | 正規化座標 `[0~1, 0~1]`（= px ÷ canvas） |
| `alive` | **當下所有活躍 touch ID 的全清單**（最重要的欄位，見下） |

### 三條你必須遵守的語意規則

1. **`alive` 是唯一真相源**：每包都帶。任何你手上的 touch ID 不在 `alive` 裡，
   就視為已離手並清掉——**即使你沒收到它的 `up` 事件**（網路丟包時 up 可能丟，
   alive 對帳保證不會殘留鬼點）。
2. **忽略未知欄位**：未來會新增欄位（相容性變更），你的 parser 不可因為多了
   欄位而報錯。`v` 變成 2 才是破壞性變更。
3. **`up` 天生比 `down` 慢 ~170ms**：硬體沒有「離手訊號」，只有重送停止，
   服務必須等 170ms 確認沒有後續訊號才發 `up`。這是物理限制不是 bug。
   `down` 則是零等待即時送達。遊戏邏輯請優先掛在 `down` 上。

### keepalive

無觸控時每 1 秒會收到一包 `events: []` 的空 frame（含 `alive` 對帳）。
超過 ~3 秒沒收到任何 frame = 連線已死，啟動重連。

---

## 4. 可直接使用的 client（複製即用）

```js
/**
 * TouchService WebSocket client
 * 用法：
 *   const tc = new TouchClient('ws://127.0.0.1:20111/', {
 *     onDown:  (t) => { ... },   // t = {id, face, cell, px, norm}
 *     onMove:  (t) => { ... },
 *     onUp:    (id) => { ... },
 *     onHello: (hello) => { ... }  // 取 canvas 尺寸、場域配置
 *   });
 *   tc.touches  // Map<id, touch> 隨時可查當下所有活躍觸點
 */
class TouchClient {
  constructor(url, handlers = {}) {
    this.url = url;
    this.h = handlers;
    this.touches = new Map();
    this.hello = null;
    this._lastMsg = 0;
    this._connect();
    // watchdog：3.5s 沒訊息就強制重連（涵蓋 1s keepalive 的 3 個週期）
    this._watchdog = setInterval(() => {
      if (this._lastMsg && Date.now() - this._lastMsg > 3500) {
        try { this._ws.close(); } catch (e) {}
      }
    }, 1000);
  }

  _connect() {
    this._ws = new WebSocket(this.url);
    this._ws.onmessage = (ev) => {
      this._lastMsg = Date.now();
      let msg;
      try { msg = JSON.parse(ev.data); } catch (e) { return; }
      if (msg.type === 'hello') {
        this.hello = msg;
        this.h.onHello && this.h.onHello(msg);
        return;
      }
      for (const e of (msg.events || [])) {
        if (e.phase === 'up') {
          this.touches.delete(e.id);
          this.h.onUp && this.h.onUp(e.id);
        } else {
          this.touches.set(e.id, e);
          if (e.phase === 'down') this.h.onDown && this.h.onDown(e);
          else this.h.onMove && this.h.onMove(e);
        }
      }
      // alive 對帳：清掉不在 alive 裡的殘留觸點（up 丟包防護）
      if (Array.isArray(msg.alive)) {
        const alive = new Set(msg.alive);
        for (const id of [...this.touches.keys()]) {
          if (!alive.has(id)) {
            this.touches.delete(id);
            this.h.onUp && this.h.onUp(id);
          }
        }
      }
    };
    this._ws.onclose = () => {
      // 斷線：清空所有觸點再重連（避免殘影），2 秒後重試
      for (const id of [...this.touches.keys()]) {
        this.touches.delete(id);
        this.h.onUp && this.h.onUp(id);
      }
      setTimeout(() => this._connect(), 2000);
    };
    this._ws.onerror = () => { try { this._ws.close(); } catch (e) {} };
  }
}
```

---

## 5. 座標換算

事件同時給三種座標，選最適合你的：

| 你的情境 | 用哪個 | 換算 |
|---|---|---|
| 視窗就是投影輸出、解析度 = canvas（2688×3840） | `px` | 直接用 |
| 視窗尺寸跟 canvas 不同（最常見） | `norm` | `x = norm[0] * 視窗寬; y = norm[1] * 視窗高` |
| 玩法是「格子」邏輯（哪一格被踩） | `face` + `cell` | 對照 hello 的 faces 配置 |

注意：canvas 是**整個場域**（地板 + 牆面共 7 面）的展開圖。如果美術程式只投地板，
用 hello 裡 `faces` 中地板那一面的 `originX/Y` + `width/height` 把 px 轉成面內座標：
`xInFace = px[0] - face.originX`（再除以 `face.width` 得面內 0~1）。

---

## 6. 沒有硬體怎麼測（重要）

你不需要去現場。跟這份文件一起交接的還有 TouchService 資料夾，內含模擬器：

1. 啟動服務：`TouchService.exe`（同資料夾要有 `config.json` 和 `venues/704.json`）
2. 瀏覽器開 `http://127.0.0.1:20111/` = 內建測試頁（場域展開圖 + 即時觸點），
   **你的程式畫面應該跟測試頁顯示的觸點一致**——它就是你的對拍基準
3. 跑模擬器產生假觸控（在 TouchService 資料夾下）：
   - `SensorSimulator scenario scenarios/single-stomp.json` — 單點踩放
   - `SensorSimulator scenario scenarios/two-feet-cross.json` — 兩點交錯（驗 ID 不互換）
   - `SensorSimulator scenario scenarios/stress-60.json` — **60 點併發**（15 人 × 4 點，驗收必跑）

## 7. 驗收 checklist（全勾才算完成）

- [ ] 美術程式啟動**不需要**南港專案 Unity 程式開著
- [ ] `single-stomp` 場景：踩下立即反應（體感無延遲）、離手 ~170ms 後消失
- [ ] `two-feet-cross` 場景：兩個觸點交錯走過，各自 ID 與視覺不互換、不合併
- [ ] `stress-60` 場景：60 個觸點同時顯示、全程不掉點、不卡頓
- [ ] 把 TouchService 關掉再開：美術程式 5 秒內自動重連，且斷線瞬間清空所有觸點（無殘影）
- [ ] 觸點行為跟內建測試頁（`http://127.0.0.1:20111/`）並排對拍一致
- [ ] 舊的滑鼠監聽若保留，與 WS 觸控共存不衝突

## 8. FAQ（給 AI 的常見坑）

- **不要 polling**：所有資料都是 server 主動推，不要去輪詢 `/venue` 或任何端點。
- **不要用單游標思維**：`event.clientX` 式的「現在的位置」不存在，永遠以
  `touches` Map 為準。
- **`move` 只在座標真的變了才發**：同一格持續踩住不會一直收到 move，
  不要把「沒有 move」當成離手——離手只看 `up` / `alive`。
- **觸點視覺殘留**：99% 是沒做 alive 對帳，照 §4 的 class 做就不會發生。
- **Electron/打包環境**：`ws://127.0.0.1` 是明文連線，若有 CSP 設定需允許
  `connect-src ws://127.0.0.1:20111`；NW.js / WebView 同理。
- **效能**：60 點併發時 frame 速率約每秒數十包，JSON.parse 負載可忽略，
  但你的**渲染**要避免每包全量重繪 DOM——用 canvas 或只更新 delta。
- 協議完整版（含 release timeout 的實測依據、硬體封包格式）在交接資料夾的
  `docs/PROTOCOL.md`，有疑問以它為準。
