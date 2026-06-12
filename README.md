# 704_GenerativeArt
if u want to design generative art in 704，use this. GLSL and p5.js supported.

## Web version

Open `index.html` directly in Chrome, or serve this folder with a local web server.

## EXE version

Install dependencies once:

```powershell
npm install
```

Run the Electron app for testing:

```powershell
npm start
```

Build a portable Windows exe:

```powershell
npm run dist
```

The built exe is written to `dist/704-Generative-Art.exe`.

## OSC control (TouchOSC etc.)

The Electron app (not the web version) listens for OSC on **UDP 9000** while
running. Send to `<host>:9000` from TouchOSC / any OSC client:

| Address | Arg | Action |
|---|---|---|
| `/704/shader` | int N | Activate dock entry at position N (0-based). 0 = Aurora, 1+ = saved favorites, last = Custom. |
| `/704/shader/select` | int N | Same as above. |
| `/704/shader/next` | (any, ≥1 = trigger) | Cycle forward in the dock. |
| `/704/shader/prev` | (any, ≥1 = trigger) | Cycle backward. |

### Dock layout & OSC index mapping

The dock is the source of truth for OSC indices. Default layout on a fresh
install:

| Index | Tile | Notes |
|---|---|---|
| 0 | Aurora | Built-in, pinned leftmost |
| 1..N | Your saved favorites | In the order shown in the dock |
| N+1 | Custom | Built-in, pinned rightmost |

Workflow for adding a new effect:

1. Open the code panel (`< >` icon or click the Custom tile).
2. Paste/write GLSL (or p5) in the editor. Press **Apply** to preview.
3. Click **★ Save current…** → name it. The new tile lands just before Custom.
4. The new OSC index = its position in the dock from the left (count Aurora
   as 0). Send that integer via `/704/shader`.

**Every dock tile shows its current OSC index** as a small badge in the
bottom-right corner. Send that integer via `/704/shader` and it triggers the
tile underneath.

**Reorder by dragging** any tile in the dock onto another — they swap
positions and every badge updates instantly. Aurora and Custom are also
draggable (right-click still hides them from the dock if you want them gone).
Saved order persists across launches in `dockOrder.v1`.

The `glsl_snippets/` folder ships with the .exe as a reference library — copy
any file's contents into the editor when you want to start from one of those
examples.

The top-right sys-pill shows `osc · 9000 · <msg-count>` so you can confirm
messages are arriving. Hover for last-received address.

For deeper visibility, the dock has an **OSC monitor button** (wave icon)
that opens a panel with:

- Live status (listening / error)
- Scrolling log of recent messages (last 60), including ones with unknown
  addresses — useful for catching TouchOSC typos
- `[↻ 重設 dock 順序]` — restore the default order without touching favorites
- **Playlist editor** — manually assign which effects sit at which OSC slot.
  When `Use playlist` is ticked, `/704/shader N` looks up slot N in the
  playlist instead of dock position N. Each slot is a dropdown listing all
  available effects plus `— Empty —` (empty slots are no-ops). `+ Add slot`
  appends a new slot; `📋 Copy from dock` snapshots the current dock order
  into the playlist. Dock tiles whose effect is NOT in the active playlist
  show a dim `—` badge — useful for spotting which effects TouchOSC can't
  reach right now.
- Address reference card

The code editor's footer has three buttons:

- **Clear** — empties the textarea so you can write from scratch. Doesn't
  compile, so the venue keeps showing the previous shader while you type.
- **Reset** — loads the default example body for the current mode (GLSL or p5).
- **Apply** — compiles and applies whatever's in the textarea (Ctrl/Cmd+Enter).

When TouchOSC and the app are on **different machines**, allow UDP 9000 through
Windows Firewall and point TouchOSC at the PC's LAN IP. Same machine = use
`127.0.0.1`. To control both this app and Resolume Arena from one button,
add two OSC connections in TouchOSC (Arena defaults to 7000, this app uses
9000) and target both addresses from the same control.

For Arena to receive the visual, you have two options:

**A. Fullscreen on a dedicated display** — broadcast button → click → pick a
monitor. The projector window covers that monitor edge-to-edge. Add an Arena
Screen Capture source pointing at that display. Won't work if that monitor is
already feeding Arena's output to the LED rig (display conflict).

**B. Windowed mode + NDI Screen Capture HX** — broadcast button → click →
pick `🪟 Windowed mode`. The projector opens as a small movable resizable
window titled `704 Projector — capture this window`. Run NDI Screen Capture
HX (from NDI Tools) and have it capture that specific window. Arena receives
via NDI. Keeps your physical display 2 free for Arena's own output to LED.
