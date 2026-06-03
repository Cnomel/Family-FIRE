# 🔥 Family Fire

[![CI](https://github.com/cnomel/family-fire/actions/workflows/ci.yml/badge.svg)](https://github.com/cnomel/family-fire/actions)
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
| **资产分类** | 四维度分类（性质/用途/持有/流动性）+ 自由标签 + 自定义分类 |
| **生命周期** | 六种轨迹：折旧/消耗/到期/增值/波动/稳定 |
| **资产关系** | 10种关系类型，可视化关系图谱 |
| **FIRE引擎** | 净资产/储蓄率/FIRE数字/蒙特卡洛模拟 |
| **投资追踪** | A股+美股+加密货币+基金，实时价格 |
| **负债管理** | 房贷/车贷/信用卡/消费贷，月供计算 |
| **收支管理** | 月度预算/年度统计/收支模板 |
| **家庭协作** | 邀请码加入，防重复提醒，权限管理 |
| **文档管理** | 说明书/保修书在线预览 |
| **通知系统** | 到期提醒/变动通知/实时推送 |

### 快速开始

#### 方式一：一键部署（推荐）

```bash
git clone https://github.com/cnomel/family-fire.git
cd family-fire
chmod +x deploy.sh
./deploy.sh
```

脚本支持：
- 内网部署（局域网访问）
- 公网部署（域名+SSL）
- 自动配置数据库、Redis、MinIO
- 自动构建APK

#### 方式二：开发环境

```bash
# 后端
cd backend
uv sync --all-extras
uv run python scripts/init_db.py
uv run uvicorn app.main:app --reload

# 前端
cd frontend
flutter pub get
flutter run
```

#### 方式三：Docker Compose

```bash
docker-compose up -d
```

部署完成后访问：
- API 文档: http://localhost:8000/docs
- 默认管理员: admin / Admin@123456
- APK下载: http://localhost/downloads/family-fire-latest.apk

### 技术栈

| 层级 | 技术 |
|------|------|
| 后端 | FastAPI + SQLModel + PostgreSQL + Redis + MinIO |
| 前端 | Flutter 3.x + Riverpod + fl_chart |
| 任务队列 | Celery + Redis |
| 包管理 | uv (Python), pub (Flutter) |
| 容器化 | Docker + Docker Compose |
| 反向代理 | Nginx |

### 项目结构

```
family-fire/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── auth/           # 认证 (JWT/RBAC)
│   │   ├── users/          # 用户管理
│   │   ├── families/       # 家庭管理
│   │   ├── assets/         # 资产管理 (含生命周期/关系/分类)
│   │   ├── finance/        # 财务 (收支/投资/FIRE/预算)
│   │   ├── documents/      # 文档管理
│   │   └── notifications/  # 通知系统
│   ├── scripts/            # 初始化脚本
│   └── tests/              # 182+ 测试
├── frontend/                # Flutter 前端
│   └── lib/
│       ├── features/       # 功能模块
│       │   ├── assets/     # 资产管理
│       │   ├── finance/    # 财务管理
│       │   ├── home/       # 首页仪表盘
│       │   └── settings/   # 设置
│       └── shared/         # 共享组件
├── nginx/                   # Nginx配置
├── scripts/                 # 部署脚本
├── downloads/               # APK下载目录
├── deploy.sh               # 一键部署脚本
├── docker-compose.yml      # 开发环境
└── docker-compose.prod.yml # 生产环境
```

### 国内化特性

- 🔴 红涨绿跌（红色=盈利，绿色=亏损）
- 💰 ¥货币格式 + 万/亿大数单位
- 📋 标准中文支出/收入分类（参考支付宝/随手记）
- 👤 用户名+邮箱双登录
- 🔒 隐私模式（默认隐藏金额）

### APP配置

构建APK前，需要配置后端API地址。编辑 `frontend/lib/config/env.dart`：

```dart
class EnvConfig {
  // 生产环境：填入你的域名或IP
  static const String apiBaseUrl = 'http://your-domain.com';
  static const String wsUrl = 'ws://your-domain.com';
}
```

| 场景 | apiBaseUrl |
|------|------------|
| 生产环境 | `http://your-domain.com` |
| Android模拟器 | `http://10.0.2.2:8000` |
| iOS模拟器 | `http://localhost:8000` |
| 真机调试 | `http://<电脑IP>:8000` |

构建APK：

```bash
cd frontend
flutter build apk --release
```

### 部署指南

详细部署文档请参考 [DEPLOY.md](DEPLOY.md)

#### 生产环境部署

```bash
# 一键部署
./deploy.sh

# 单独构建APK
./scripts/build_apk.sh
```

#### 服务管理

```bash
# 查看服务状态
docker compose -f docker-compose.prod.yml ps

# 查看日志
docker compose -f docker-compose.prod.yml logs -f

# 停止服务
docker compose -f docker-compose.prod.yml down

# 重启服务
docker compose -f docker-compose.prod.yml restart
```

### 贡献

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 协议

本项目基于 [MIT 协议](LICENSE) 开源。

---

## English

### Features

| Module | Features |
|--------|----------|
| **Asset Classification** | 4-dimension classification + free tags + custom categories |
| **Lifecycle** | 6 trajectories: depreciating/consumable/expiring/appreciating/volatile/stable |
| **Relationships** | 10 relationship types, visual graph |
| **FIRE Engine** | Net worth/savings rate/FIRE number/Monte Carlo simulation |
| **Investment** | A-shares + US stocks + crypto + funds, real-time prices |
| **Liabilities** | Mortgage/auto loan/credit card/consumer loan |
| **Budget** | Monthly budget / yearly stats / budget templates |
| **Family** | Invite codes, duplicate alerts, permission management |
| **Documents** | Online preview for manuals/warranties |
| **Notifications** | Expiry reminders, change alerts, real-time push |

### Quick Start

#### Option 1: One-Click Deploy (Recommended)

```bash
git clone https://github.com/cnomel/family-fire.git
cd family-fire
chmod +x deploy.sh
./deploy.sh
```

The script supports:
- Internal network deployment (LAN access)
- Public network deployment (domain + SSL)
- Auto-configure database, Redis, MinIO
- Auto-build APK

#### Option 2: Development Environment

```bash
# Backend
cd backend
uv sync --all-extras
uv run python scripts/init_db.py
uv run uvicorn app.main:app --reload

# Frontend
cd frontend
flutter pub get
flutter run
```

#### Option 3: Docker Compose

```bash
docker-compose up -d
```

After deployment:
- API Docs: http://localhost:8000/docs
- Default Admin: admin / Admin@123456
- APK Download: http://localhost/downloads/family-fire-latest.apk

### Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | FastAPI + SQLModel + PostgreSQL + Redis + MinIO |
| Frontend | Flutter 3.x + Riverpod + fl_chart |
| Task Queue | Celery + Redis |
| Package Manager | uv (Python), pub (Flutter) |
| Containerization | Docker + Docker Compose |
| Reverse Proxy | Nginx |

### Deployment Guide

For detailed deployment instructions, see [DEPLOY.md](DEPLOY.md)

#### Production Deployment

```bash
# One-click deploy
./deploy.sh

# Build APK separately
./scripts/build_apk.sh
```

#### Service Management

```bash
# Check service status
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop services
docker compose -f docker-compose.prod.yml down

# Restart services
docker compose -f docker-compose.prod.yml restart
```

### Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md).

### License

This project is licensed under the [MIT License](LICENSE).
