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
# 初始化数据库（包含所有种子数据）
uv run python scripts/init_db.py
```

初始化脚本包含：
- 系统设置
- 支出/收入分类（支付宝/随手记标准）
- 资产分类（家庭级别）
- 固定支出/收入模板（家庭级别）
- 管理员用户

### Q: Android 设备无法联网/请求发不出去？

**症状**: curl 测试正常，但 app 请求后端完全接收不到请求

**原因**: `AndroidManifest.xml` 缺少 `INTERNET` 权限

**检查清单**:
1. `frontend/android/app/src/main/AndroidManifest.xml` 必须包含：
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
2. `android:usesCleartextTraffic="true"` 允许 HTTP 明文流量
3. debug 版本有独立的 manifest，可能掩盖 release 版本的问题

**相关文件**:
- `frontend/android/app/src/main/AndroidManifest.xml` - 主 manifest
- `frontend/android/app/src/debug/AndroidManifest.xml` - debug manifest

### Q: Flutter 网络检查失败导致无法登录？

**症状**: 抛出 `NETWORK_UNREACHABLE` 或 `NETWORK_ERROR` 异常

**原因**: 前端健康检查端点与后端不一致

**检查清单**:
1. 后端健康检查端点是 `/health`（不是 `/api/health`）
2. `frontend/lib/core/network/network_service.dart` 中的检查路径必须匹配
3. 网络检查失败会阻止所有 API 请求

---

## 安全问题记录

> 审查日期: 2026-06-03

### 严重风险（P0）

| # | 风险 | 文件 | 描述 |
|---|------|------|------|
| 1 | JWT Secret 硬编码默认值 | `backend/app/config.py` | 生产环境如未更改，所有 Token 可被伪造 |
| 2 | SSL 默认关闭 | `nginx/nginx.prod.conf` | 公网部署时所有通信明文传输 |
| 3 | Token 黑名单未实现 | `backend/app/auth/router.py` | 登出后 Token 仍有效，需用 Redis 实现 |
| 4 | SSL 证书验证禁用 | `backend/app/finance/providers/price_service.py` | `ssl._create_unverified_context()` 易受 MITM 攻击 |

### 高风险（P1）

| # | 风险 | 描述 |
|---|------|------|
| 5 | 内存速率限制不支持多实例 | 生产环境多 worker 下形同虚设，需基于 Redis 实现 |
| 6 | 缺少用户账号删除功能 | 不符合隐私保护最佳实践 |
| 7 | Refresh Token 无失效机制 | 被泄露后可持续使用 |

### 中风险（P2）

| # | 风险 | 描述 |
|---|------|------|
| 8 | CORS 完全开放 | 生产环境应限制 `allow_origins` 来源 |
| 9 | API 文档生产环境可访问 | `/docs`、`/redoc` 暴露系统结构 |
| 10 | 缺少 CSP Header | XSS 防护不完整 |
| 11 | 家庭成员无细分权限 | 任何成员可操作所有文档 |
| 12 | MinIO 默认关闭 HTTPS | 文件传输明文 |

### 待实现功能

- [ ] 用户账号删除端点
- [ ] 用户数据导出功能
- [ ] 隐私政策/用户协议页面
- [ ] 审计日志（敏感操作记录）
