const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // App info
  getAppVersion: () => ipcRenderer.invoke('get-app-version'),
  getPlatform: () => process.platform,
  
  // Window controls
  minimizeWindow: () => ipcRenderer.send('minimize-window'),
  maximizeWindow: () => ipcRenderer.send('maximize-window'),
  closeWindow: () => ipcRenderer.send('close-window'),
  
  // File system operations (optional)
  openFile: (options) => ipcRenderer.invoke('open-file', options),
  saveFile: (data, options) => ipcRenderer.invoke('save-file', data, options),
  
  // Notifications
  showNotification: (title, body) => {
    new Notification(title, { body });
  },
  
  // Event listeners from main process
  onNewChat: (callback) => ipcRenderer.on('new-chat', callback),
  onOpenSettings: (callback) => ipcRenderer.on('open-settings', callback),
  
  // Remove event listeners
  removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel),
  
  // Is Electron environment
  isElectron: true
});

// Add a flag to window object to detect Electron environment
window.isElectron = true;

console.log('Banana AI Assistant - Electron preload script loaded');
