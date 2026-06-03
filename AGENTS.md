# AGENTS.md — Family Fire 开发指南

## 项目概述

Family Fire 是一个家庭资产管理系统，帮助用户实现 FIRE（财务独立/提前退休）。

## 技术栈

- **后端**: Python 3.12 + FastAPI + SQLModel + PostgreSQL + Redis + MinIO
- **前端**: Flutter 3.x + Riverpod + fl_chart
- **包管理**: uv (Python), pub (Flutter)
- **容器化**: Docker + Docker Compose

## 开发命令

### 后端

```bash
cd backend

# 安装依赖
uv sync --all-extras

# 初始化数据库（幂等，可重复运行）
uv run python scripts/init_db.py

# 启动开发服务器
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 运行测试
uv run pytest tests/ -v

# 代码检查
uv run ruff check app/ tests/
uv run ruff format app/ tests/
```

### Flutter

```bash
cd frontend

# 安装依赖
flutter pub get

# 代码分析
flutter analyze

# 运行测试
flutter test

# 运行应用
flutter run

# 构建APK
flutter build apk --release
```

### Docker

```bash
# 启动开发环境
docker-compose up -d postgres redis minio

# 启动生产环境
docker-compose -f docker-compose.prod.yml up -d

# 一键部署（推荐）
./deploy.sh

# 查看日志
docker-compose logs -f backend

# 停止服务
docker-compose down
```

## 代码规范

### Python
- 使用 `ruff` 进行代码检查和格式化
- 所有函数需要类型注解
- 使用 `datetime.now(UTC)` 获取当前时间（不要用 `datetime.utcnow()`）
- 中文注释和错误消息

### Flutter
- 使用 `dart format` 格式化代码
- 遵循 Flutter 官方风格指南
- 使用 Riverpod 进行状态管理

## 国内化注意事项

- **颜色**: 红色=盈利/涨，绿色=亏损/跌（与西方相反）
- **货币**: ¥前缀，万/亿大数单位
- **日期**: 2024年1月15日 星期一
- **分类**: 参考支付宝/随手记标准分类

## 测试

- 后端测试: 182个，使用 SQLite 内存数据库
- 测试命令: `uv run pytest tests/ -v`
- 覆盖率: `uv run pytest tests/ --cov=app`

## 部署

### 一键部署（推荐）

```bash
./deploy.sh
```

支持内网部署和公网部署，自动配置数据库、Redis、MinIO、Nginx。

### 手动部署

1. 配置 `.env` 文件
2. 运行 `./scripts/setup.sh`
3. 启动后端: `uv run uvicorn app.main:app`
4. 配置 Nginx 反向代理
5. 配置 SSL 证书

详细部署文档请参考 [DEPLOY.md](DEPLOY.md)

## 常见问题

### Q: 如何重置数据库？
```bash
cd backend
uv run python scripts/init_db.py
```

### Q: 如何添加新的资产类型？
1. 在 `backend/app/assets/models.py` 添加元数据表
2. 在 `backend/app/assets/service.py` 添加 METADATA_MODELS 映射
3. 运行 `uv run alembic revision --autogenerate` 生成迁移

### Q: 如何添加新的通知类型？
1. 在 `backend/app/notifications/service.py` 添加通知逻辑
2. 在 `backend/app/tasks/` 添加定时任务（如需要）

### Q: 如何初始化收支模板？
```bash
cd backend
# 初始化数据库（包含新表）
uv run python scripts/init_db.py

# 为现有家庭创建系统预设收支模板
uv run python scripts/seed_budget_templates.py
```
