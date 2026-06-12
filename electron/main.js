const path = require('node:path');
const fs = require('node:fs');
const { app, BrowserWindow, Menu, ipcMain, screen } = require('electron');
const osc = require('osc');

let controllerWindow = null;
let projectorWindow = null;

const OSC_PORT = 9000;
let oscPort = null;
let oscStatus = { listening: false, port: OSC_PORT, msgCount: 0, lastAddress: '', lastError: '' };

const indexPath = path.join(__dirname, '..', 'index.html');
const preloadPath = path.join(__dirname, 'preload.js');

function sendProjectorState() {
  if (!controllerWindow || controllerWindow.isDestroyed()) return;
  controllerWindow.webContents.send('projector:state', !!(projectorWindow && !projectorWindow.isDestroyed()));
}

function sendOSCStatus() {
  if (!controllerWindow || controllerWindow.isDestroyed()) return;
  controllerWindow.webContents.send('osc:status', { ...oscStatus });
}

function startOSC() {
  if (oscPort) return;
  oscPort = new osc.UDPPort({
    localAddress: '0.0.0.0',
    localPort: OSC_PORT,
    metadata: false,
  });
  oscPort.on('ready', () => {
    oscStatus.listening = true;
    oscStatus.lastError = '';
    console.log('[OSC] listening on udp://0.0.0.0:' + OSC_PORT);
    sendOSCStatus();
  });
  oscPort.on('message', (oscMsg) => {
    oscStatus.msgCount++;
    oscStatus.lastAddress = oscMsg.address;
    console.log('[OSC] <-', oscMsg.address, JSON.stringify(oscMsg.args || []));
    if (controllerWindow && !controllerWindow.isDestroyed()) {
      controllerWindow.webContents.send('osc:message', {
        address: oscMsg.address,
        args: oscMsg.args || [],
      });
    }
    sendOSCStatus();
  });
  oscPort.on('error', (err) => {
    oscStatus.listening = false;
    oscStatus.lastError = String(err && err.message ? err.message : err);
    console.error('[OSC] error:', err);
    sendOSCStatus();
  });
  try {
    oscPort.open();
  } catch (e) {
    oscStatus.lastError = String(e && e.message ? e.message : e);
    console.error('[OSC] open() failed:', e);
    sendOSCStatus();
  }
}

function createControllerWindow() {
  controllerWindow = new BrowserWindow({
    width: 1440,
    height: 1000,
    minWidth: 1024,
    minHeight: 720,
    backgroundColor: '#05060a',
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: preloadPath,
    },
  });

  controllerWindow.loadFile(indexPath);

  // Mirror renderer console to main stdout so seed/OSC logs are visible in
  // app.log during dev. Drop verbose / spammy messages if needed.
  controllerWindow.webContents.on('console-message', (_event, level, message, line, sourceId) => {
    if (/^\[(seed|osc|sync|migrate|reorder)\]/i.test(message)) {
      console.log('[renderer]', message);
    } else if (level >= 2) {
      // 2 = warning, 3 = error in Electron's console-message API
      console.log('[renderer][err]', message, '@', sourceId + ':' + line);
    }
  });

  controllerWindow.on('closed', () => {
    controllerWindow = null;
    if (projectorWindow && !projectorWindow.isDestroyed()) {
      projectorWindow.close();
    }
  });

  return controllerWindow;
}

function getDefaultProjectorDisplay() {
  const displays = screen.getAllDisplays();
  const primary = screen.getPrimaryDisplay();
  return displays.find(display => display.id !== primary.id) || primary;
}

function listDisplayInfos() {
  const primary = screen.getPrimaryDisplay();
  return screen.getAllDisplays().map((d, i) => ({
    id: d.id,
    label: d.label || ('Display ' + (i + 1)),
    bounds: d.bounds,
    workArea: d.workArea,
    size: d.size,
    scaleFactor: d.scaleFactor,
    isPrimary: d.id === primary.id,
  }));
}

function resolveDisplay(displayId) {
  if (displayId != null) {
    const match = screen.getAllDisplays().find(d => d.id === displayId);
    if (match) return match;
  }
  return getDefaultProjectorDisplay();
}

function createProjectorWindow(displayId, opts) {
  if (projectorWindow && !projectorWindow.isDestroyed()) return projectorWindow;

  const windowed = !!(opts && opts.windowed);
  // Default size for windowed mode — keeps venue aspect (2688:3840 = 7:10)
  // at a friendly size that fits in the corner of a 1080p display, while
  // still giving NDI Screen Capture HX enough resolution to forward to Arena.
  const winW = 560;
  const winH = 800;

  if (windowed) {
    const primary = screen.getPrimaryDisplay();
    projectorWindow = new BrowserWindow({
      x: primary.bounds.x + primary.bounds.width - winW - 40,
      y: primary.bounds.y + 40,
      width: winW,
      height: winH,
      minWidth: 280,
      minHeight: 400,
      resizable: true,
      frame: true,
      title: '704 Projector — capture this window',
      backgroundColor: '#000000',
      autoHideMenuBar: true,
      show: false,
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
      },
    });
  } else {
    const display = resolveDisplay(displayId);
    projectorWindow = new BrowserWindow({
      x: display.bounds.x,
      y: display.bounds.y,
      width: display.bounds.width,
      height: display.bounds.height,
      fullscreen: true,
      frame: false,
      backgroundColor: '#000000',
      autoHideMenuBar: true,
      show: false,
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
      },
    });
  }

  projectorWindow.loadFile(indexPath, {
    query: {
      broadcast: '1',
      electron: '1',
      q: '1',
      overlay: '0',
      windowed: windowed ? '1' : '0',
    },
  });

  projectorWindow.webContents.on('before-input-event', (event, input) => {
    if (input.key === 'Escape' && input.type === 'keyDown') {
      event.preventDefault();
      if (projectorWindow && !projectorWindow.isDestroyed()) projectorWindow.close();
    }
  });

  projectorWindow.once('ready-to-show', () => {
    if (!projectorWindow || projectorWindow.isDestroyed()) return;
    projectorWindow.show();
    if (!windowed) projectorWindow.setFullScreen(true);
  });

  projectorWindow.on('closed', () => {
    projectorWindow = null;
    sendProjectorState();
  });

  sendProjectorState();

  return projectorWindow;
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);

  ipcMain.handle('projector:toggle', () => {
    if (projectorWindow && !projectorWindow.isDestroyed()) {
      projectorWindow.close();
      return false;
    }
    createProjectorWindow();
    return true;
  });

  ipcMain.handle('projector:close', () => {
    if (projectorWindow && !projectorWindow.isDestroyed()) {
      projectorWindow.close();
    }
    return false;
  });

  ipcMain.handle('projector:is-open', () => !!(projectorWindow && !projectorWindow.isDestroyed()));

  ipcMain.handle('displays:list', () => listDisplayInfos());

  ipcMain.handle('projector:open', (_event, displayId) => {
    if (projectorWindow && !projectorWindow.isDestroyed()) {
      projectorWindow.close();
    }
    createProjectorWindow(displayId);
    return true;
  });

  ipcMain.handle('projector:openWindowed', () => {
    if (projectorWindow && !projectorWindow.isDestroyed()) {
      projectorWindow.close();
    }
    createProjectorWindow(null, { windowed: true });
    return true;
  });

  ipcMain.handle('osc:status', () => ({ ...oscStatus }));

  // Bundled glsl snippets — used to seed favorites on first run so OSC index
  // maps to a real dock entry from the start. The renderer only seeds when
  // its localStorage favorites list is empty; subsequent edits are user-owned.
  ipcMain.handle('snippets:list', () => {
    const dirs = [
      path.join(__dirname, '..', 'glsl_snippets'),
      path.join(process.resourcesPath || '', 'glsl_snippets'),
    ];
    for (const dir of dirs) {
      if (!dir || !fs.existsSync(dir)) continue;
      try {
        const files = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.glsl')).sort();
        return files.map(f => {
          const body = fs.readFileSync(path.join(dir, f), 'utf8');
          const m = body.match(/^\/\/\s*===\s*(.+?)\s*===/m);
          const name = m ? m[1].trim() : f.replace(/\.glsl$/i, '');
          return { file: f, name, body, mode: 'glsl' };
        });
      } catch (e) {
        console.warn('[snippets] read failed for', dir, e);
      }
    }
    return [];
  });

  startOSC();

  createControllerWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createControllerWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (oscPort) {
    try { oscPort.close(); } catch (e) { /* ignore */ }
    oscPort = null;
  }
  if (process.platform !== 'darwin') app.quit();
});
