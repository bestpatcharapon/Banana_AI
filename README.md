<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.4.1-red?logo=ruby&logoColor=white" alt="Ruby">
  <img src="https://img.shields.io/badge/Rails-8.1-red?logo=ruby-on-rails&logoColor=white" alt="Rails">
  <img src="https://img.shields.io/badge/AI-Groq%20Llama%203-orange?logo=meta&logoColor=white" alt="AI">
  <img src="https://img.shields.io/badge/Protocol-MCP-blue" alt="MCP">
  <img src="https://img.shields.io/badge/Deploy-Render-purple?logo=render&logoColor=white" alt="Render">
</p>

# 🍌 Banana AI Assistant

**AI-Powered Project Management Assistant** ที่ช่วยบริหารจัดการงานใน **Azure DevOps** ผ่านการพูดคุยเป็นภาษาไทย

ขับเคลื่อนด้วย **Groq (Llama 3)** และใช้มาตรฐาน **MCP (Model Context Protocol)** เพื่อเชื่อมต่อ AI กับเครื่องมือต่างๆ อย่างชาญฉลาด

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 💬 **Thai Chat Interface** | คุยกับ AI เป็นภาษาไทยได้ 100% ถาม-ตอบเรื่องงานได้ทันที |
| 🔗 **Azure DevOps Integration** | ดึง Work Items, Sprints, Pipelines, Repositories จาก Azure DevOps |
| 📋 **My Tasks Dashboard** | หน้าจอสรุปงานของตัวเองแบบ One-Click |
| 🔐 **Microsoft 365 SSO** | Login ด้วยบัญชี Microsoft 365 ระบบดึงงานของคุณอัตโนมัติ |
| 🤖 **MCP Protocol** | ใช้มาตรฐาน Model Context Protocol สำหรับ Tool Calling |

---

## 🛠️ Tech Stack

- **Backend:** Ruby on Rails 8.1 (API Mode)
- **AI Engine:** Groq API (Llama 3)
- **Protocol:** MCP (Model Context Protocol)
- **Auth:** OmniAuth (Azure Active Directory v2)
- **Database:** PostgreSQL / SQLite
- **Deploy:** Docker, Render

---

## 🔧 Azure DevOps Tools

ระบบมี MCP Tools สำหรับเชื่อมต่อกับ Azure DevOps API:

| Tool | Description |
|------|-------------|
| `work_items` | ดึงรายการงาน, กรองตามสถานะ, ค้นหางานของแต่ละคน |
| `sprints` | ดู Current Sprint, Sprint Timeline |
| `projects` | ดึงรายการโปรเจกต์ทั้งหมด |
| `pipelines` | ดูสถานะ CI/CD Pipelines |
| `repositories` | ดึงรายการ Git Repos |
| `test_plans` | ดู Test Plans และ Test Cases |

---

## 🚀 Quick Start

### 1. Clone & Install

```bash
git clone git@github.com:bestpatcharapon/Banana_Ai_Assistant.git
cd Banana_Ai_Assistant
bundle install
```

### 2. Configure Environment

สร้างไฟล์ `.env` ที่ root folder:

```env
# AI
GROQ_API_KEY=gsk_xxxxxxxxxxxxx

# Azure DevOps
AZURE_DEVOPS_ORGANIZATION=your-org
AZURE_DEVOPS_PAT=your-pat-token

# Microsoft OAuth (Azure AD)
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_SECRET=xxxxxxxxxxxxx
```

### 3. Run Server

```bash
bin/dev
```

Server จะรันที่ **http://localhost:3000**

---

## 📱 Usage

| Mode | URL | Description |
|------|-----|-------------|
| 🤖 Chat | `/chat` | พูดคุยกับ AI เช่น "สรุปงานสัปดาห์นี้" |
| 📋 My Tasks | `/my_tasks.html` | ดูงานของตัวเอง (ต้อง Login) |
| 🔌 MCP Endpoint | `/mcp` | สำหรับ MCP Client เชื่อมต่อ |

---

## 🔐 Microsoft OAuth Setup

1. ไปที่ [Azure Portal](https://portal.azure.com) > **App registrations**
2. สร้าง App ใหม่
3. ตั้ง Redirect URI: `https://your-domain/auth/azure_activedirectory_v2/callback`
4. Copy **Client ID**, **Tenant ID**, **Client Secret** ไปใส่ใน `.env`

---

## 🐳 Deploy with Docker

```bash
docker build -t banana-ai .
docker run -p 3000:3000 --env-file .env banana-ai
```

หรือ Deploy บน **Render** โดยใช้ `render.yaml` ที่มีอยู่แล้ว

---

## 📁 Project Structure

```
├── app/
│   ├── controllers/     # API Controllers
│   ├── tools/           # MCP Tools (Azure DevOps, Groq, etc.)
│   └── views/           # HTML Templates
├── lib/generators/      # Custom Generators
├── public/              # Static Files (my_tasks.html)
├── prompts/             # AI System Prompts
└── config/              # Rails Config
```

---

## 📄 License

MIT License

---

<p align="center">
  Developed with ❤️ by <strong>Banana Coding Team</strong> 🍌
</p>
