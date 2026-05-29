# 🔥 Family Fire

[![CI](https://github.com/your-repo/family-fire/actions/workflows/ci.yml/badge.svg)](https://github.com/your-repo/family-fire/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.12](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)
[![Flutter 3.x](https://img.shields.io/badge/flutter-3.x-02569B.svg)](https://flutter.dev/)

> 通过资产关系管理、日常支出追踪、投资分析，帮助家庭实现 FIRE（财务独立/提前退休）

[English](#english) | [中文](#中文)

---

## 中文

### 功能特性

| 模块 | 功能 |
|------|------|
| **资产分类** | 四维度分类（性质/用途/持有/流动性）+ 自由标签 |
| **生命周期** | 六种轨迹：折旧/消耗/到期/增值/波动/稳定 |
| **资产关系** | 10种关系类型，可视化关系图谱 |
| **FIRE引擎** | 净资产/储蓄率/FIRE数字/蒙特卡洛模拟 |
| **投资追踪** | A股+美股+加密货币+基金，实时价格 |
| **负债管理** | 房贷/车贷/信用卡/消费贷，月供计算 |
| **家庭协作** | 邀请码加入，防重复提醒，权限管理 |
| **文档管理** | 说明书/保修书在线预览 |
| **通知系统** | 到期提醒/变动通知/实时推送 |

### 快速开始

```bash
# 一键部署
git clone https://github.com/your-repo/family-fire.git
cd family-fire
chmod +x scripts/setup.sh
./scripts/setup.sh
```

部署完成后访问：
- API 文档: http://localhost:8000/docs
- 默认管理员: admin / Admin@123456

### 技术栈

| 层级 | 技术 |
|------|------|
| 后端 | FastAPI + SQLModel + PostgreSQL + Redis + MinIO |
| 前端 | Flutter 3.x + Riverpod + fl_chart |
| 任务队列 | Celery + Redis |
| 包管理 | uv (Python), pub (Flutter) |
| 容器化 | Docker + Docker Compose |

### 项目结构

```
family-fire/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── auth/           # 认证 (JWT/RBAC)
│   │   ├── users/          # 用户管理
│   │   ├── families/       # 家庭管理
│   │   ├── assets/         # 资产管理 (含生命周期/关系)
│   │   ├── finance/        # 财务 (收支/投资/FIRE)
│   │   ├── documents/      # 文档管理
│   │   └── notifications/  # 通知系统
│   ├── scripts/            # 初始化脚本
│   └── tests/              # 182+ 测试
├── mobile/                  # Flutter 前端
├── scripts/                 # 部署脚本
├── tasks/                   # 任务定义
└── docker-compose.yml       # 开发环境
```

### 国内化特性

- 🔴 红涨绿跌（红色=盈利，绿色=亏损）
- 💰 ¥货币格式 + 万/亿大数单位
- 📋 标准中文支出/收入分类（参考支付宝/随手记）
- 👤 用户名+邮箱双登录
- 🔒 隐私模式（默认隐藏金额）

### 贡献

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 协议

本项目基于 [MIT 协议](LICENSE) 开源。

---

## English

### Features

| Module | Features |
|--------|----------|
| **Asset Classification** | 4-dimension classification + free tags |
| **Lifecycle** | 6 trajectories: depreciating/consumable/expiring/appreciating/volatile/stable |
| **Relationships** | 10 relationship types, visual graph |
| **FIRE Engine** | Net worth/savings rate/FIRE number/Monte Carlo simulation |
| **Investment** | A-shares + US stocks + crypto + funds, real-time prices |
| **Liabilities** | Mortgage/auto loan/credit card/consumer loan |
| **Family** | Invite codes, duplicate alerts, permission management |
| **Documents** | Online preview for manuals/warranties |
| **Notifications** | Expiry reminders, change alerts, real-time push |

### Quick Start

```bash
git clone https://github.com/your-repo/family-fire.git
cd family-fire
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### License

[MIT](LICENSE)
