# Banana AI Assistant 🍌

**Banana AI Assistant** คือระบบผู้ช่วย AI อัจฉริยะที่ช่วยให้คุณบริหารจัดการและติดตามงานใน **Azure DevOps** ได้ง่ายๆ ผ่านการพูดคุย (Chat) หรือผ่าน **Personal Dashboard** ส่วนตัว

ประมวลผลด้วย **Ruby on Rails 8.1** และใช้มาตรฐาน **MCP (Model Context Protocol)** ขับเคลื่อนด้วยสมองของ **Groq (Llama 3)** ที่ถูกจูนให้เป็น Senior Project Manager มืออาชีพ

---

## ✨ ฟีเจอร์หลัก (Features)

### 1. 💬 Web Chat UI
*   หน้าจอแชทที่ใช้งานง่าย คุยเป็นภาษาไทยได้ 100%
*   ถาม-ตอบ เรื่องงานในโปรเจกต์ต่างๆ ได้ทันที

### 2. 🤖 Azure DevOps Integration
*   ดึงรายการงาน (Work Items) แยกตามโปรเจกต์
*   ดูสถานะงาน (Active, Closed, New)
*   เช็ค **Current Sprint** ได้อัตโนมัติ
*   วิเคราะห์ Workload ของแต่ละคนในทีม

### 3. 📋 My Tasks Dashboard (ใหม่! 🔥)
*   **One-Click Access:** หน้าจอพิเศษสำหรับดู "งานที่ต้องทำ" ของตัวเองโดยเฉพาะ
*   เข้าถึงได้ที่ `/my_tasks.html`
*   แสดงงาน Active, Sprint ที่ต้องส่ง, และงานสำคัญ (Critical Tasks) แบบสรุปจบในหน้าเดียว

### 4. 🔐 Microsoft 365 Authentication (ใหม่! 🔥)
*   ไม่ต้องพิมพ์ชื่อตัวเองเพื่อดึงงานอีกต่อไป
*   **Single Sign-On (SSO):** Login ด้วยบัญชี Microsoft 365 (Email บริษัท)
*   ระบบจะรู้ทันทีว่าคุณคือใคร และดึงงานของคุณมาให้อัตโนมัติ

---

## 🛠️ สิ่งที่ต้องมีเบื้องต้น (Requirements)

*   **Ruby:** 3.4.7
*   **PostgreSQL:** 13+ (หรือ SQLite ตาม Config)
*   **Keys & Tokens:**
    *   **Groq API Key:** สำหรับสมอง AI ([ขอฟรีที่นี่](https://console.groq.com/))
    *   **Azure DevOps PAT:** สำหรับดึงข้อมูลงาน
    *   **Azure AD App Registration:** สำหรับระบบ Login (Client ID & Secret)

---

## 🚀 วิธีติดตั้งและเริ่มต้นใช้งาน (Setup Guide)

### 1. Clone Project
```bash
git clone git@github.com:bestpatcharapon/Banana_Ai_Assistant.git
cd Banana_Ai_Assistant
```

### 2. ติดตั้ง Dependencies
```bash
bundle install
```

### 3. ตั้งค่า Environment Variables (สำคัญมาก ⚠️)
สร้างไฟล์ `.env` ที่ root folder และใส่ค่าตามนี้:

```env
# --- AI Configuration ---
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxx

# --- Azure DevOps Configuration ---
# ชื่อ Organization ใน Azure DevOps URL
AZURE_DEVOPS_ORGANIZATION=bananacoding
# Personal Access Token (Full Access หรือ Read Work Items)
AZURE_DEVOPS_PAT=วางTokenAccessยาวๆที่นี่

# --- Microsoft 365 OAuth (Azure Active Directory) ---
# ดูได้จาก Azure Portal > App registrations
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> **วิธีหาค่า Azure Oauth:** 
> 1. ไปที่ [Azure Portal](https://portal.azure.com)
> 2. Register App ใหม่ใน "App registrations"
> 3. กำหนด Redirect URI เป็น `http://your-app-url/auth/azure_activedirectory_v2/callback` (หรือ `http://localhost:3000/...` สำหรับ dev)

### 4. เตรียม Database (ถ้าใช้ active record)
```bash
bin/rails db:prepare
```

---

## ▶️ วิธีรันโปรแกรม (Usage)

### 1. Start Server
```bash
bin/dev
# หรือ
bin/rails s
```
*Server จะรันที่ http://localhost:3000*

### 2. เลือกการใช้งาน

*   **🤖 Chat Mode (คุยกับ AI):**
    *   ไปที่ **[http://localhost:3000/chat](http://localhost:3000/chat)**
    *   พิมพ์ถามได้เลย เช่น *"สรุปงานของสัปดาห์นี้ให้หน่อย"*

*   **📋 My Tasks Mode (ดูงานตัวเอง):**
    *   ไปที่ **[http://localhost:3000/my_tasks.html](http://localhost:3000/my_tasks.html)**
    *   กดปุ่ม **"Login ด้วย Microsoft 365"**
    *   ระบบจะดึงงานของคุณมาแสดงทันที!

---

## 🏗️ Tech Stack

*   **Framework:** Ruby on Rails 8.1 (API Mode + Custom Views)
*   **Frontend:** Vanilla JS + HTML5 (Responsive)
*   **Authentication:** OmniAuth (Azure Active Directory v2)
*   **AI Model:** Llama-3 (via Groq API)
*   **Infrastructure:** รองรับการ Deploy บน Docker / Cloud Platform ทั่วไป

---

Developed with ❤️ by **Banana Coding Team** 🍌
