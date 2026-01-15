const { app, BrowserWindow, Menu, shell, Tray, nativeImage } = require('electron');
const path = require('path');
const url = require('url');

// Keep a global reference of the window object
let mainWindow;
let tray = null;

// Check if we're in development mode
const isDev = process.env.NODE_ENV === 'development';

// API URL for the backend
const API_URL = process.env.API_URL || 'https://banana-ai-assistant-o2r6.onrender.com';

function createWindow() {
  // Create the browser window
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    title: 'Banana AI Assistant',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true
    },
    // Modern look with rounded corners (Windows 11)
    backgroundColor: '#1a1a2e',
    show: false, // Don't show until ready
    autoHideMenuBar: false,
    frame: true,
    titleBarStyle: 'default'
  });

  // Load the Angular app
  if (isDev) {
    // In development, load from dev server
    mainWindow.loadURL('http://localhost:4200');
    // Open DevTools in development
    mainWindow.webContents.openDevTools();
  } else {
    // In production, load from built files
    const fs = require('fs');
    
    // Try multiple possible paths
    const possiblePaths = [
      path.join(__dirname, '..', 'dist', 'frontend', 'browser', 'index.html'),
      path.join(app.getAppPath(), 'dist', 'frontend', 'browser', 'index.html'),
      path.join(process.resourcesPath, 'app', 'dist', 'frontend', 'browser', 'index.html')
    ];
    
    let indexPath = null;
    for (const p of possiblePaths) {
      console.log('Checking path:', p, 'exists:', fs.existsSync(p));
      if (fs.existsSync(p)) {
        indexPath = p;
        break;
      }
    }
    
    if (indexPath) {
      // Use file:// URL with proper encoding
      const fileUrl = url.format({
        pathname: indexPath,
        protocol: 'file:',
        slashes: true
      });
      console.log('Loading URL:', fileUrl);
      mainWindow.loadURL(fileUrl);
    } else {
      console.error('Could not find index.html in any of:', possiblePaths);
      mainWindow.loadURL('data:text/html,<h1>Error: Could not find index.html</h1><p>Check console for details.</p>');
    }
  }

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    mainWindow.focus();
  });

  // Handle external links - window.open
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    // If it's an OAuth flow, open inside the app
    if (url.includes('/auth/microsoft') || url.includes('login.microsoftonline.com')) {
      console.log('Opening OAuth URL in internal auth window:', url);
      createAuthWindow(url);
      return { action: 'deny' };
    }
    
    console.log('Opening external URL:', url);
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Handle navigation to external URLs
  mainWindow.webContents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    
    // If navigating to our API server (for OAuth login/logout)
    if (navigationUrl.includes('localhost:3000') || 
        navigationUrl.includes('banana-ai-assistant-o2r6.onrender.com') ||
        navigationUrl.includes('/auth/microsoft') ||
        navigationUrl.includes('/auth/logout') || // Create separate window for logout too
        navigationUrl.includes('login.microsoftonline.com')) {
      console.log('Opening OAuth URL in internal auth window:', navigationUrl);
      event.preventDefault();
      createAuthWindow(navigationUrl);
    }
  });

  // Handle window close
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Create application menu
  createMenu();
  
  // Create system tray (optional)
  createTray();
}

let authWindow = null;

function createAuthWindow(authUrl) {
  if (authWindow) {
    authWindow.focus();
    authWindow.loadURL(authUrl);
    return;
  }

  authWindow = new BrowserWindow({
    width: 600,
    height: 700,
    title: 'Authentication',
    parent: mainWindow,
    modal: true, 
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      // Share session/cookies with main window so subsequent requests work
      session: mainWindow.webContents.session 
    }
  });

  authWindow.loadURL(authUrl);
  
  // Allow popups inside auth window to stay internal (or block them if not needed)
  authWindow.webContents.setWindowOpenHandler(({ url }) => {
     console.log('Auth Window tried to open:', url);
     // Allow if it's related to Microsoft login
     if (url.includes('microsoft') || url.includes('live')) {
       return { action: 'allow' };
     }
     return { action: 'deny' };
  });

  const handleAuthRedirect = (url) => {
    if (url.startsWith('banana-ai://')) {
      console.log('Intercepted deep link in Auth Window:', url);
      handleDeepLink(url);
      if (authWindow) {
        authWindow.destroy(); // Close window after success
        authWindow = null;
      }
      return true;
    }
    return false;
  };

  authWindow.webContents.on('will-navigate', (event, url) => {
    if (handleAuthRedirect(url)) {
      event.preventDefault();
    }
  });

  authWindow.webContents.on('will-redirect', (event, url) => {
    if (handleAuthRedirect(url)) {
      event.preventDefault();
    }
  });

  authWindow.on('closed', () => {
    authWindow = null;
  });
}

function createMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        {
          label: 'New Chat',
          accelerator: 'CmdOrCtrl+N',
          click: () => {
            mainWindow.webContents.send('new-chat');
          }
        },
        { type: 'separator' },
        {
          label: 'Settings',
          accelerator: 'CmdOrCtrl+,',
          click: () => {
            mainWindow.webContents.send('open-settings');
          }
        },
        { type: 'separator' },
        { role: 'quit' }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' }
      ]
    },
    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'forceReload' },
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
        { type: 'separator' },
        { role: 'toggleDevTools' }
      ]
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'close' }
      ]
    },
    {
      label: 'Help',
      submenu: [
        {
          label: 'About Banana AI Assistant',
          click: () => {
            const { dialog } = require('electron');
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'About Banana AI Assistant',
              message: 'Banana AI Assistant',
              detail: `Version: 1.0.0\nBuilt with Electron\n\nYour AI-powered productivity assistant for Azure DevOps and more.`
            });
          }
        },
        { type: 'separator' },
        {
          label: 'Documentation',
          click: () => {
            shell.openExternal('https://github.com/bestpatcharapon/Banana_Ai_Assistant');
          }
        }
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

function createTray() {
  // Create tray icon (optional - you can add an icon later)
  try {
    const iconPath = path.join(__dirname, 'assets', 'tray-icon.png');
    const icon = nativeImage.createFromPath(iconPath);
    tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon);
    
    const contextMenu = Menu.buildFromTemplate([
      {
        label: 'Show App',
        click: () => {
          if (mainWindow) {
            mainWindow.show();
            mainWindow.focus();
          }
        }
      },
      { type: 'separator' },
      {
        label: 'Quit',
        click: () => {
          app.quit();
        }
      }
    ]);
    
    tray.setToolTip('Banana AI Assistant');
    tray.setContextMenu(contextMenu);
    
    tray.on('click', () => {
      if (mainWindow) {
        if (mainWindow.isVisible()) {
          mainWindow.hide();
        } else {
          mainWindow.show();
          mainWindow.focus();
        }
      }
    });
  } catch (error) {
    console.log('Tray icon not available:', error.message);
  }
}

// Register custom protocol for deep linking (banana-ai://)
const PROTOCOL = 'banana-ai';

if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient(PROTOCOL, process.execPath, [path.resolve(process.argv[1])]);
  }
} else {
  app.setAsDefaultProtocolClient(PROTOCOL);
}

// Handle deep link on Windows/Linux
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', (event, commandLine) => {
    // Someone tried to run a second instance, focus our window
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
    
    // Handle deep link URL from command line (Windows)
    const deepLinkUrl = commandLine.find(arg => arg.startsWith(`${PROTOCOL}://`));
    if (deepLinkUrl) {
      handleDeepLink(deepLinkUrl);
    }
  });
}

// Handle deep link URL
function handleDeepLink(deepLinkUrl) {
  console.log('Received deep link:', deepLinkUrl);
  
  try {
    const parsedUrl = new URL(deepLinkUrl);
    const token = parsedUrl.searchParams.get('token');
    const name = parsedUrl.searchParams.get('name');
    const email = parsedUrl.searchParams.get('email');
    const loggedOut = parsedUrl.searchParams.get('logged_out');
    
    if (mainWindow) {
      if (token) {
        console.log('Auth callback received, setting token...');
        const redirectUrl = `file://${path.join(__dirname, '..', 'dist', 'frontend', 'browser', 'index.html')}?token=${token}&name=${encodeURIComponent(name || '')}&email=${encodeURIComponent(email || '')}`;
        mainWindow.loadURL(redirectUrl);
      } else if (loggedOut === 'true') {
        console.log('Logout callback received, clearing session...');
        const redirectUrl = `file://${path.join(__dirname, '..', 'dist', 'frontend', 'browser', 'index.html')}?logged_out=true`;
        mainWindow.loadURL(redirectUrl);
      }
      
      mainWindow.show();
      mainWindow.focus();
    }
  } catch (error) {
    console.error('Error handling deep link:', error);
  }
}

// Handle deep link on macOS
app.on('open-url', (event, url) => {
  event.preventDefault();
  handleDeepLink(url);
});

// App event handlers
app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    // On macOS, re-create window when dock icon is clicked
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// Quit when all windows are closed (except on macOS)
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Handle certificate errors (for development with self-signed certs)
app.on('certificate-error', (event, webContents, url, error, certificate, callback) => {
  if (isDev) {
    event.preventDefault();
    callback(true);
  } else {
    callback(false);
  }
});

// Security: Disable navigation to external sites
app.on('web-contents-created', (event, contents) => {
  contents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    
    // Allow OAuth flows to stay internal
    if (navigationUrl.includes('login.microsoftonline.com') || 
        navigationUrl.includes('live.com') ||
        navigationUrl.includes('microsoft.com')) {
      console.log('Allowing internal navigation to OAuth provider:', navigationUrl);
      return;
    }

    // Only allow navigation to our app URLs
    if (!parsedUrl.origin.includes('localhost') && 
        !parsedUrl.origin.includes('file://')) {
      event.preventDefault();
      shell.openExternal(navigationUrl);
    }
  });
});
