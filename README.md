# Family Fire — 家庭资产管理系统

> 通过资产关系管理、日常支出追踪、投资分析，帮助家庭实现 FIRE（财务独立/提前退休）

## 技术栈

| 层级 | 技术 |
|------|------|
| 后端框架 | FastAPI + Uvicorn |
| ORM | SQLModel (SQLAlchemy + Pydantic) |
| 数据库 | PostgreSQL 16 |
| 缓存 | Redis 7 |
| 对象存储 | MinIO (S3兼容) |
| 包管理 | uv |
| Python | 3.12 |
| 前端 | Flutter 3.x |
| 任务队列 | Celery + Redis |

## 快速开始

### 前置条件
- Python 3.12+
- uv (包管理器)
- Docker & Docker Compose

### 启动开发环境

```bash
# 1. 克隆仓库
git clone https://github.com/your-repo/family-fire.git
cd family-fire

# 2. 启动基础设施
docker-compose up -d postgres redis minio

# 3. 安装后端依赖
cd backend
uv sync

# 4. 配置环境变量
cp ../.env.example .env
# 编辑 .env 文件

# 5. 运行数据库迁移
uv run alembic upgrade head

# 6. 启动后端
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 7. 访问 API 文档
open http://localhost:8000/docs
```

### 运行测试

```bash
cd backend
uv run pytest -v
```

## 项目结构

```
family-fire/
├── backend/                # FastAPI 后端
│   ├── app/
│   │   ├── common/         # 公共模块（日志、异常、中间件、安全）
│   │   ├── auth/           # 认证模块
│   │   ├── users/          # 用户模块
│   │   ├── families/       # 家庭模块
│   │   ├── assets/         # 资产模块（含生命周期、关系）
│   │   ├── finance/        # 财务模块（收支、投资、FIRE）
│   │   ├── documents/      # 文档模块
│   │   └── notifications/  # 通知模块
│   ├── alembic/            # 数据库迁移
│   └── tests/              # 测试
├── mobile/                 # Flutter 前端
├── tasks/                  # 任务定义（16个task.json）
├── docs/                   # 文档
├── docker-compose.yml      # 开发环境
└── .github/workflows/      # CI/CD
```

## 核心功能

- **多维度资产分类**：性质、用途、持有方式、流动性四维度
- **生命周期管理**：折旧、消耗、到期、增值、波动六种轨迹
- **资产关系图谱**：10种关系类型，支持可视化
- **FIRE计算引擎**：净资产、储蓄率、FIRE数字、蒙特卡洛模拟
- **投资追踪**：A股+美股+加密货币+基金，实时价格
- **负债管理**：房贷、车贷、信用卡、消费贷
- **家庭协作**：多人共同管理资产，防重复提醒
- **文档管理**：说明书、保修书在线预览
- **通知系统**：到期提醒、变动通知

## 国内化特性

- 红涨绿跌（红色=盈利，绿色=亏损）
- ¥货币格式 + 万/亿大数单位
- 标准中文支出/收入分类
- 用户名+邮箱登录
- 隐私模式（默认隐藏金额）

## 许可证

MIT License
