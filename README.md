<p align="center">
  <img src="snapshots/logo.png" width="160" alt="Switches Logo"/>
</p>

<h1 align="center">Switches — LLM 协议转换网关</h1>

<p align="center">
  <strong>一站式统一 OpenAI / Gemini / Claude 及兼容服务商</strong><br/>
  一个服务商搞定全部模型 · 局域网随时调用 · 桌面/移动/Web 三端通吃
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-blue?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/OpenAI%20API-green" alt="OpenAI API"/>
  <img src="https://img.shields.io/badge/Claude%20API-orange" alt="Claude API"/>
</p>

---

> 💡： Switches部分由[RemindAI](https://github.com/PythonnotJava/RemindAI)构建

## 🖼️ 截图

| IP限制                                    | 模型库 | 仪表盘（移动）                                 |
|-----------------------------------------|--------|-----------------------------------------|
| ![Mobile 1](snapshots/mobile_page1.jpg) | ![Mobile 2](snapshots/mobile_page2.jpg) | ![Mobile 3](snapshots/mobile_page3.jpg) |

| 设置 | 退出确认 |
|------|---------|
| ![Mobile 4](snapshots/mobile_page4.jpg) | ![PC Homepage](snapshots/pc_homepage.png) |

---

## 🚀 核心功能

### 1. 多协议网关（兼容 OpenAI / Claude 双入口）

| 入口协议 | 上游支持 | 格式栈 |
|----------|---------|--------|
| `/v1/chat/completions` (OpenAI) | OpenAI / Gemini / Claude | 请求 → OpenAI IR → 上游 → OpenAI 响应 |
| `/v1/messages` (Claude Messages) | OpenAI / Gemini / Claude | 请求 → Claude IR → OpenAI IR → 上游 → Claude 响应 |

**统一中转**：无论上游是 Gemini 还是 Claude，客户端永远用 OpenAI 格式（或 Claude 格式）调用，Switches 自动实时转换。

- ✅ 流式 SSE 双向转换
- ✅ Tool / Function Calling 全链路透传
- ✅ 多模态（图片 base64）自动适配
- ✅ 120s 超时 + 上游错误封装

### 2. 模型库管理

![Model Library](snapshots/mobile_page2.jpg)

- ✅ **卡片式服务商管理**：添加 OpenAI / Gemini / Claude 及任意 OpenAI 兼容服务商（DeepSeek、Qwen、GLM、Moonshot 等）
- ✅ **自动检测模型**：填写 API Key 后自动拉取服务商模型列表，无需手动录入
- ✅ **能力图标**：文本、图片输入/输出、音频输入/输出、视频输入、函数调用、流式、推理、JSON 模式 — 所有能力用图标清晰标识
- ✅ **搜索筛选**：按服务商、能力过滤，列表/卡片双视图
- ✅ **模型启用/禁用**：灵活控制哪些模型对外暴露
- ✅ **自定义图标**：服务商卡片支持自定义图标 URL，不设则显示首字

### 3. IP 白名单 & 模型分配

![IP Manager](snapshots/mobile_page3.jpg)

- ✅ 完整 CIDR 匹配（支持 IPv4 / IPv6）
- ✅ **逐 IP 分配模型**：可指定 IP 只能使用哪些模型
- ✅ **本机默认全通**：`127.0.0.1` 始终拥有全部权限
- ✅ **严格白名单模式**（推荐）：无规则时除本机外全部拒接
- ✅ **宽松白名单模式**：无规则时放行所有 IP
- ✅ **双模式可切换**：设置页一键切换

### 4. 访问密钥（`Authorization: Bearer`）

> 新增安全特性 — 防止未授权客户端接入

- ✅ 生成 `sk-switches-xxxxxxxx...` 格式密钥
- ✅ OpenAI 模式：`Authorization: Bearer sk-switches-xxx`
- ✅ Claude 模式：`x-api-key: sk-switches-xxx`
- ✅ 支持清空密钥（回退到纯 IP 白名单模式）

### 5. PC端

![Close Dialog](snapshots/pc_homepage.png)

- ✅ 窗口关闭时弹出三选项：最小化到托盘 / 退出 / 取消
- ✅ 可选「记住选择，下次不再询问」
- ✅ 设置页可随时恢复为「每次询问」
- ✅ 退出时全屏遮罩动画，避免关闭服务器卡顿

### 6. 仪表盘与日志

![Dashboard](snapshots/pc_homepage.png)

- ✅ 实时服务状态：启动/停止，端口显示
- ✅ 6 项统计卡片：服务商/模型/IP/请求数/成功率/失败数
- ✅ **模型使用排行**：条形图显示 Top 8 模型调用量
- ✅ **请求日志**：持久化 Hive，搜索过滤，HTTP 状态码着色
- ✅ 日志数量上限自动裁剪（最多 200 条）

### 7. 系统托盘（桌面端）

- ✅ 窗口关闭默认最小化到托盘（可选）
- ✅ 托盘菜单：显示窗口 / 启停服务 / 退出
- ✅ 托盘图标点击：恢复窗口

### 8. 深色模式 & 响应式 UI

- ✅ Material 3 设计，支持深色/浅色主题
- ✅ 响应式布局：宽屏 NavigationRail，窄屏 BottomNavigationBar
- ✅ 最小窗口尺寸 800×600
- ✅ 跨平台：Windows / macOS / Linux / Android / iOS / Web

---

## 🏗️ 架构概览

```
┌──────────────┐     ┌──────────────────────────────────────┐
│  UI (Flutter) │     │          HTTP Server (shelf)          │
│               │     │                                      │
│  · 仪表盘     │     │  GET  /v1/models         ─→ 模型列表  │
│  · 服务商管理  │     │  POST /v1/chat/completions ─→ Chat   │
│  · 模型库     │     │  POST /v1/messages       ─→ Messages │
│  · IP管理     │     │  GET  /health             ─→ 健康检查 │
│  · 设置       │     │                                      │
└──────┬───────┘     └──────────┬───────────────────────────┘
       │                        │
       ▼                        ▼
┌────────────────────────────────────────────────────────┐
│                    AppProvider                          │
│  · 服务商/模型/IP规则 CRUD  · 服务器启停 · 日志统计     │
└──────────┬───────────────────────────┬────────────────┘
           │                           │
           ▼                           ▼
┌──────────────────┐     ┌──────────────────────────────┐
│   ProviderService │     │     ProtocolConverter         │
│  · testConnection │     │                              │
│  · fetchModels    │     │  OpenAI ←→ Gemini            │
│  · 推断模型能力   │     │  OpenAI ←→ Claude            │
└──────────────────┘     │  Claude ←→ OpenAI (IR)        │
                          │  SSE 流双向转换               │
                          └──────────────────────────────┘
           │                           │
           ▼                           ▼
┌────────────────────────────────────────────────────────┐
│  StorageService (Hive)                                  │
│  · providers · models · ip_rules · logs · config       │
└────────────────────────────────────────────────────────┘
```

### 数据流

```
客户端 (OpenAI SDK)
     │ POST /v1/chat/completions { model: "gpt-4o", messages: [...] }
     ▼
Switches HTTP Server (端口 9998)
     │ 1. IP 白名单检查
     │ 2. 访问密钥校验
     │ 3. 模型存在性 & IP 模型权限
     │ 4. 找到归属服务商
     ▼
┌─ 分流 ─────────────────────────────────┐
│ OpenAI → 直通上游（透传）                │
│ Gemini → openaiToGemini 转换 → 上游     │
│ Claude → openaiToClaude 转换 → 上游     │
└────────────────────────────────────────┘
     │
     ▼
响应转换（Gemini/Claude → OpenAI 格式）
     │
     ▼
客户端收到标准 OpenAI 格式响应 🎉
```

---

## 📁 项目结构

```
lib/
├── main.dart                    # 入口：窗口管理 + 系统托盘 + Provider
├── app.dart                     # MaterialApp + 响应式导航 + 关闭对话框
├── config/
│   ├── constants.dart           # 常量：Box名/端口/能力枚举
│   └── theme.dart               # Material3 深色/浅色主题
├── models/
│   ├── provider_model.dart      # LLM服务商模型 (含 iconUrl)
│   ├── model_info.dart          # 模型模型 (含 exposedProtocol)
│   ├── ip_rule.dart             # IP规则 + CIDR匹配
│   └── app_config.dart          # 全局配置 (关闭行为/密钥/白名单模式)
├── providers/
│   └── app_provider.dart        # Provider 全局状态 (CRUD + 服务器 + 日志)
├── services/
│   ├── protocol_converter.dart  # OpenAI↔Gemini↔Claude 三向转换 + ClaudeSSEEncoder
│   ├── provider_service.dart    # 服务商API通信 + 模型能力推断
│   ├── server_service.dart      # shelf HTTP 服务 (双入口/权限/代理)
│   ├── storage_service.dart     # Hive 持久化 (5个Box)
│   └── tray_service.dart        # 系统托盘单例
└── ui/
    ├── pages/
    │   ├── home_page.dart       # 仪表盘 (统计/排行/日志)
    │   ├── providers_page.dart  # 服务商管理 (自动检测/自定义图标)
    │   ├── models_page.dart     # 模型库 (搜索/筛选/双视图)
    │   ├── ip_manager_page.dart # IP白名单 (CIDR/模型分配)
    │   └── settings_page.dart   # 设置 (端口/密钥/白名单/关闭行为)
    └── widgets/
        └── capability_icons.dart # 模型能力图标组件
```

---

## 💻 安装与构建

### 环境要求

- Flutter SDK >= 3.22
- Dart SDK >= 3.6
- 平台工具链：Windows (Visual Studio)、macOS (Xcode)、Linux (GCC)、Android (Android Studio)、iOS (Xcode)

### 运行调试

```bash
# 桌面端（Windows/macOS/Linux）
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d chrome

# 移动端
flutter run -d android
flutter run -d ios
```

### 构建发布

```bash
# Windows 桌面端
flutter build windows --release --tree-shake-icons --split-debug-info=./debug-info

# Android
flutter build apk --release --split-per-abi --obfuscate --tree-shake-icons --split-debug-info=build/debug_info

# macOS
flutter build macos --release

# Web
flutter build web --release
```

---

## 🔌 API 使用指南（对接客户端）

### 1. OpenAI 兼容 (Chat Completions)

**Base URL**: `http://你的IP:9998/v1`

```bash
curl http://localhost:9998/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-switches-your-key" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

### 2. Claude Messages 兼容

**Base URL**: `http://你的IP:9998`

```bash
curl http://localhost:9998/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: sk-switches-your-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 3. 模型列表

```bash
curl http://localhost:9998/v1/models
```

### 4. 健康检查

```bash
curl http://localhost:9998/health
```

### 对接技巧

| 客户端 | Base URL 设置 |
|--------|---------------|
| OpenAI Python SDK | `openai.base_url = "http://localhost:9998/v1"` |
| OpenAI JS SDK | `openai.baseURL = "http://localhost:9998/v1"` |
| One API / New API | `http://localhost:9998` |
| LobeChat | `http://localhost:9998/v1` |
| Claude SDK (JS) | `ANTHROPIC_BASE_URL="http://localhost:9998"` |

---

## ⚙️ 设置详解

| 设置项 | 位置 | 说明 |
|--------|------|------|
| 服务端口 | 设置→服务器 | 默认 9998，修改后重启服务生效 |
| 自动启动 | 设置→服务器 | 应用启动时自动开启 HTTP 服务 |
| 访问密钥 | 设置→服务器 | 生成 `sk-switches-xxx` 密钥，客户端需携带 |
| 白名单模式 | 设置→服务器 | 严格模式（推荐）/ 宽松模式 |
| 信任代理头 | 设置→服务器 | 仅在可信反代后开启 |
| 深色模式 | 设置→外观 | 切换 Material 3 深色/浅色 |
| 调试模式 | 设置→调试 | 记录请求/响应体到日志 |
| 关闭行为 | 设置→桌面端 | 每次询问/最小化/直接退出 |

---

## 🔒 安全说明

| 维度 | 措施 |
|------|------|
| IP 白名单 | 严格模式：无规则时除本机全部拒接；支持 CIDR |
| 请求头欺骗 | `trustProxyHeaders` 默认关闭，不信任 `X-Forwarded-For` |
| 访问密钥 | 可选 `Bearer` 或 `x-api-key` 两种方式 |
| 本地特权 | `127.0.0.1` / `::1` 始终拥有全部权限，不受白名单约束 |
| 错误不泄露 | `/health` 对未授权 IP 只返回最小状态 |

---

## 🧩 技术栈

| 组件 | 技术选型 |
|------|----------|
| 框架 | Flutter / Dart|
| 状态管理 | Provider (ChangeNotifier) |
| 本地存储 | Hive (NoSQL 键值存储) |
| HTTP 服务器 | shelf + shelf_router + shelf_cors_headers |
| HTTP 客户端 | dart:io HttpClient + http package |
| 桌面端 | window_manager + system_tray |
| UI 设计 | Material 3 + 响应式布局 |
| 图标 | Flutter Material Icons + 自定义 SVG |

---

## 📄 许可证

```
Copyright (c) 2026 Switches

MIT License
```

---
