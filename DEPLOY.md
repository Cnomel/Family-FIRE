# Family Fire 部署指南

## 快速部署

### 一键部署（推荐）

```bash
# 进入项目目录
cd family-fire

# 运行部署脚本
./deploy.sh
```

脚本会自动：
1. 检查依赖环境
2. 询问部署类型（内网/公网）
3. 配置数据库、Redis、MinIO
4. 生成配置文件
5. 构建APK（可选）
6. 启动所有服务
7. 初始化数据库（创建表和默认管理员）

### 单独构建APK

```bash
./scripts/build_apk.sh
```

## 部署类型

### 内网部署

适用于局域网环境，无需域名和SSL证书。

- 访问地址：`http://<服务器IP>:<端口>`
- 适合家庭或办公室使用

### 公网部署

适用于互联网访问，需要域名和SSL证书。

- 访问地址：`https://<域名>`
- 需要配置DNS解析
- 需要SSL证书（可使用Let's Encrypt免费获取）

## 服务端口

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| HTTP | 80 | Web访问 |
| HTTPS | 443 | SSL访问 |
| API | 8000 | 后端API |
| PostgreSQL | 5432 | 数据库 |
| Redis | 6379 | 缓存 |
| MinIO | 9000 | 对象存储 |
| MinIO Console | 9001 | MinIO控制台 |

## 配置文件

部署完成后，配置文件位于：

- 环境配置：`.env.prod`
- Nginx配置：`nginx/nginx.prod.conf`
- 下载目录：`downloads/`

## 服务管理

```bash
# 查看服务状态
docker compose -f docker-compose.prod.yml ps

# 查看日志
docker compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker compose -f docker-compose.prod.yml logs -f backend

# 停止服务
docker compose -f docker-compose.prod.yml down

# 重启服务
docker compose -f docker-compose.prod.yml restart

# 重新构建并启动
docker compose -f docker-compose.prod.yml up -d --build
```

## SSL证书配置

### 使用Let's Encrypt（免费）

```bash
# 安装certbot
apt install certbot

# 获取证书
certbot certonly --standalone -d your-domain.com

# 复制证书到项目目录
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/
cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/

# 重启Nginx
docker compose -f docker-compose.prod.yml restart nginx
```

### 自动续期

```bash
# 添加定时任务
echo "0 0 1 * * certbot renew --quiet && docker compose -f /path/to/family-fire/docker-compose.prod.yml restart nginx" | crontab -
```

## 数据备份

### 备份数据库

```bash
docker exec family-fire-db pg_dump -U postgres family_fire > backup_$(date +%Y%m%d).sql
```

### 恢复数据库

```bash
docker exec -i family-fire-db psql -U postgres family_fire < backup_20240101.sql
```

### 备份MinIO数据

```bash
docker cp family-fire-minio:/data ./minio_backup_$(date +%Y%m%d)
```

## 常见问题

### Q: APP显示"网络连接失败"怎么办？

1. **检查API地址配置**

   编辑 `frontend/lib/config/env.dart`，配置正确的服务器地址：

   ```dart
   class EnvConfig {
     // 生产环境：填入你的域名
     static const String apiBaseUrl = 'http://your-domain.com';
     static const String wsUrl = 'ws://your-domain.com';
   }
   ```

   | 环境 | apiBaseUrl |
   |------|------------|
   | 生产环境 | `http://your-domain.com` |
   | Android模拟器 | `http://10.0.2.2:8000` |
   | iOS模拟器 | `http://localhost:8000` |
   | 真机调试 | `http://<电脑IP>:8000` |

2. **重新构建APK**

   ```bash
   cd frontend
   flutter build apk --release
   ```

3. **确认服务器API可访问**

   ```bash
   curl http://your-domain.com/health
   ```

### Q: 如何修改管理员密码？

登录后在设置页面修改，或直接在数据库中更新。

### Q: 如何重置数据库？

```bash
# 停止服务并删除数据
docker compose -f docker-compose.prod.yml down -v

# 重新部署（会自动初始化数据库）
./deploy.sh
```

### Q: 如何手动初始化数据库？

```bash
docker exec -w /app family-fire-api uv run python scripts/init_db.py
```

### Q: 如何更新版本？

```bash
# 拉取最新代码
git pull

# 重新部署
./deploy.sh
```

### Q: 如何查看API文档？

访问 `http://<服务器地址>/docs`

### Q: 如何添加HTTPS？

1. 获取SSL证书
2. 将证书放到 `nginx/ssl/` 目录
3. 修改 `nginx/nginx.prod.conf`，取消SSL相关注释
4. 重启Nginx服务

## 目录结构

```
family-fire/
├── backend/              # 后端代码
├── frontend/             # 前端代码
├── nginx/                # Nginx配置
│   ├── nginx.conf       # 开发环境配置
│   ├── nginx.prod.conf  # 生产环境配置
│   └── ssl/             # SSL证书
├── scripts/              # 脚本
│   ├── setup.sh         # 开发环境初始化
│   └── build_apk.sh     # APK构建脚本
├── downloads/            # APK下载目录
├── deploy.sh             # 一键部署脚本
├── docker-compose.yml    # 开发环境Docker配置
└── docker-compose.prod.yml # 生产环境Docker配置
```
