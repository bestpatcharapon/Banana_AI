# 🍌 Banana AI Assistant - Desktop App

แอปพลิเคชัน Desktop ที่สร้างด้วย **Electron** + **Angular**

## 🚀 Quick Start

### 1. ติดตั้ง Dependencies
```bash
npm install
```

### 2. รัน Development Mode
```bash
npm run electron:dev
```
คำสั่งนี้จะ:
- เริ่ม Angular dev server บน port 4200
- เปิด Electron app ที่โหลดจาก dev server
- เปิด DevTools อัตโนมัติ

### 3. Build สำหรับ Production

#### Windows (.exe)
```bash
npm run electron:build:win
```

#### macOS (.dmg)
```bash
npm run electron:build:mac
```

#### Linux (.AppImage)
```bash
npm run electron:build:linux
```

#### ทุก Platform
```bash
npm run electron:build
```

ไฟล์ที่ build จะอยู่ใน folder `release/`

## 📁 โครงสร้างไฟล์

```
frontend/
├── electron/
│   ├── main.js          # Entry point ของ Electron
│   ├── preload.js       # Security bridge
│   └── assets/          # Icons และ resources
│       ├── icon.png     # App icon (256x256)
│       ├── icon.ico     # Windows icon
│       └── icon.icns    # macOS icon
├── electron-builder.json # Build configuration
├── src/                  # Angular source code
└── dist/                 # Built Angular app
```

## 🎨 Icons

### สร้าง Icons ที่ต้องการ:

1. **icon.png** - ภาพ 256x256 หรือใหญ่กว่า (PNG)
2. **icon.ico** - สำหรับ Windows (ใช้เครื่องมือแปลง)
3. **icon.icns** - สำหรับ macOS (ใช้เครื่องมือแปลง)
4. **tray-icon.png** - 32x32 สำหรับ system tray

### เครื่องมือสร้าง Icons:
- [Electron Icon Maker](https://www.electron.build/icons)
- [iConvert Icons](https://iconverticons.com/online/)
- [png2ico](https://www.npmjs.com/package/png-to-ico)

## ⚙️ Configuration

### Backend API URL
แก้ไขใน `electron/main.js`:
```javascript
const API_URL = process.env.API_URL || 'http://localhost:3000';
```

### Window Settings
แก้ไขขนาดหน้าต่างเริ่มต้นใน `electron/main.js`:
```javascript
mainWindow = new BrowserWindow({
  width: 1400,
  height: 900,
  minWidth: 800,
  minHeight: 600,
  // ...
});
```

## 🔧 Scripts ที่มีให้

| Script | Description |
|--------|-------------|
| `npm run dev` | รัน Angular dev server |
| `npm run build` | Build Angular สำหรับ production |
| `npm run electron:dev` | รัน Electron + Angular dev |
| `npm run electron:run` | รัน Electron จาก built files |
| `npm run electron:build` | Build installer สำหรับทุก platform |
| `npm run electron:build:win` | Build เฉพาะ Windows (.exe) |
| `npm run electron:build:mac` | Build เฉพาะ macOS (.dmg) |
| `npm run electron:build:linux` | Build เฉพาะ Linux (.AppImage) |

## 📝 Notes

- **Windows**: ต้องรันบน Windows เพื่อ build .exe ที่สมบูรณ์
- **macOS**: ต้อง sign app ด้วย Apple Developer Certificate สำหรับ distribution
- **Linux**: รองรับ AppImage, deb, rpm

## 🐛 Troubleshooting

### Error: Cannot find module 'electron'
```bash
npm install electron --save-dev
```

### Error: electron-builder not found
```bash
npm install electron-builder --save-dev
```

### White screen on startup
ตรวจสอบว่า Angular build สำเร็จ:
```bash
npm run build
ls dist/frontend/browser/
```

### DevTools ไม่เปิด
ตรวจสอบว่า `NODE_ENV=development` ถูกตั้งค่าแล้ว
