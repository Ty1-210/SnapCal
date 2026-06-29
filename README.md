# SnapCal

> 📅 粘贴即添加 —— macOS 菜单栏日历助手

从邮件、聊天、网页中复制活动信息，AI 自动提取并一键添加到系统日历。

[![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](https://github.com/Ty1-210/SnapCal)
[![swift](https://img.shields.io/badge/swift-5.9-orange)](https://github.com/Ty1-210/SnapCal)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

---

## 📥 安装

### 直接下载（推荐）

从 [Releases](https://github.com/Ty1-210/SnapCal/releases) 下载 `SnapCal-v1.0.zip`，解压后双击运行。

> 首次打开：Finder 中右键 SnapCal.app → 打开，确认安全提示。

### 从源码编译

```bash
git clone git@github.com:Ty1-210/SnapCal.git
cd SnapCal
swift build -c release
```

## ⚙️ 配置

1. 菜单栏点击 🗓 > **设置**
2. 填入 [DeepSeek API Key](https://platform.deepseek.com/api_keys)
3. 端点：`https://api.deepseek.com/v1/chat/completions`
4. 模型：`deepseek-chat`
5. 添加事件时允许日历权限

> 兼容任何 OpenAI 格式的 API（修改端点和模型即可）。

## 🎯 使用

1. **复制** 活动文本（⌘C）
2. 菜单栏点击 🗓 > **打开面板**
3. 文本自动粘贴，点击 **识别**（⌘↩）
4. 确认后点 **添加到日历**（↩）

**历史记录**：已添加的事件显示在面板下方，点击可重新编辑。

## 📦 项目结构

```
Sources/SnapCal/
├── main.swift                 # 入口
├── AppDelegate.swift          # 菜单栏
├── Models/CalendarEvent.swift
├── Services/
│   ├── LLMService.swift       # AI 事件提取
│   ├── CalendarService.swift  # 系统日历
│   └── HistoryStore.swift     # 历史记录
└── Views/
    ├── CommandPanel.swift     # 主面板
    └── SettingsWindow.swift   # 设置窗口
```


## 🔄 更新日志

### v1.1
- **修复时间识别**：DeepSeek 返回的 ISO8601 时间字符串无时区偏移时，改用系统时区解析，不再被当成 UTC 导致时间偏移
- **手动设定时间**：AI 无法识别时间时，显示日期时间选择器供手动设定
- **优化 AI 提示词**：提供本地时间上下文，明确时间默认规则（晚上→19:00，未指定→09:00，禁止随意设为深夜）

### v1.0
- 初始版本

## 📝 许可证

MIT
