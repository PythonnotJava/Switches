# 工作计划
> 最后更新: 2026-07-12 12:53

## 🔴 P0 - 紧急

## 🟡 P1 - 重要

## 🟢 P2 - 一般

## ✅ 已完成
- [x] 应用图标资源 — 生成各平台app icon — 2026-07-12 完成 (生成1024/512/192各尺寸PNG图标，PWA maskable图标，favicon，更新manifest和index.html)
- [x] 请求体日志（调试模式） — 开关控制是否记录请求/响应body — 2026-07-12 完成 (AppConfig增加debugMode开关，设置页面增加调试模式开关，true时日志记录请求/响应body)
- [x] 仪表盘增强 — 吞吐量统计、请求成功/失败率、模型使用排行 — 2026-07-12 完成 (仪表盘新增总请求/成功率/失败数统计卡片+模型使用排行条形图)
- [x] 服务商卡片增加连接状态指示 — 实时显示API连通性，上次检测时间 — 2026-07-12 完成 (连接状态圆点+测速按钮+SnackBar结果反馈)
- [x] 模型库搜索筛选 + 视图切换 — 卡片/列表视图，按服务商/能力筛选，搜索模型名 — 2026-07-12 完成 (搜索框+服务商FilterChip+能力FilterChip+卡片/列表视图切换)
- [x] 请求日志持久化 + 日志查看器增强 — 写入Hive，仪表盘增加搜索过滤 — 2026-07-12 完成 (Hive持久化日志、启动时恢复统计、Dashboard新增搜索过滤/成功率/模型使用排行)
- [x] 请求代理增加超时+重试机制 — 防止上游服务商超时挂起代理 — 2026-07-12 完成 (三个代理方法均添加120s连接超时和读取超时，捕获TimeoutException返回504)
- [x] 修复Gemini流式请求URL — streamGenerateContent端点格式修正 — 当前URL格式可能不适用于Gemini v1beta API — 2026-07-12 完成 (已验证URL格式正确，额外修复了API Key URL编码和超时处理)
- [x] 修复IP检测安全漏洞 — _getClientIp从Host header取IP，外网请求全部被识别为127.0.0.1 — shelf不直接暴露连接IP，需要从X-Forwarded-For/connectionInfo获取 — 2026-07-12 完成 (_getClientIp 使用 request.context['shelf.io.connection_info'] 获取真实连接IP，X-Forwarded-For 优先)
- [x] 主题与UI优化 + Web端适配 — 深色/浅色主题，Web构建配置 — 2026-07-12 完成 (深色/浅色主题，响应式布局，Web PWA配置，Android/iOS配置)
- [x] PC端系统托盘与最小化 — 退出提问，最小化到托盘，最小尺寸800x600 — 2026-07-12 完成 (WindowListener集成，关闭时最小化到托盘，system_tray菜单)
- [x] 主界面UI框架（响应式布局） — NavigationRail/BottomNav，手机/PC/Web适配 — 2026-07-12 完成 (响应式布局（NavigationRail+BottomNav），5个页面全部完成)
- [x] 协议转换核心（OpenAI/Gemini/Claude互转） — 请求/响应格式转换，流式支持 — 2026-07-12 完成 (OpenAI↔Gemini↔Claude双向转换，流式SSE支持)
- [x] 本地HTTP服务器（端口9998） — shelf服务器，IP验证，模型路由 — 2026-07-12 完成 (shelf服务器，端口9998，IP验证，模型路由，请求日志)
- [x] IP白名单管理模块 — IP CRUD，模型分配，默认全给 — 2026-07-12 完成 (IP增删改查，模型分配，CIDR支持)
- [x] 模型管理模块UI（卡片添加/检测/能力展示） — 服务商CRUD，自动检测模型，logo显示能力 — 2026-07-12 完成 (服务商卡片式管理，模型自动检测获取，能力图标展示)
- [x] 本地存储层实现 — 使用Hive或SQLite持久化所有配置 — 2026-07-12 完成 (Hive存储层，支持服务商/模型/IP规则/配置的CRUD)
- [x] 数据模型定义（服务商/模型/IP规则/配置） — Dart class定义，JSON序列化 — 2026-07-12 完成 (LLMProvider/ModelInfo/IpRule/AppConfig 四个核心模型，含JSON序列化)
- [x] 初始化Flutter项目 + 目录结构设计 — flutter create, 规划目录结构，添加核心依赖 — 2026-07-12 完成 (项目创建完成，目录结构搭建完毕，依赖安装成功)
