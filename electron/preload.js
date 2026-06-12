const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron704', {
  toggleProjector: () => ipcRenderer.invoke('projector:toggle'),
  closeProjector: () => ipcRenderer.invoke('projector:close'),
  isProjectorOpen: () => ipcRenderer.invoke('projector:is-open'),
  listDisplays: () => ipcRenderer.invoke('displays:list'),
  openProjectorOn: (displayId) => ipcRenderer.invoke('projector:open', displayId),
  openWindowedProjector: () => ipcRenderer.invoke('projector:openWindowed'),
  onProjectorState: (callback) => {
    ipcRenderer.on('projector:state', (_event, isOpen) => callback(!!isOpen));
  },
  onOSC: (callback) => {
    ipcRenderer.on('osc:message', (_event, msg) => callback(msg));
  },
  onOSCStatus: (callback) => {
    ipcRenderer.on('osc:status', (_event, status) => callback(status));
  },
  getOSCStatus: () => ipcRenderer.invoke('osc:status'),
  listSnippets: () => ipcRenderer.invoke('snippets:list'),
});
