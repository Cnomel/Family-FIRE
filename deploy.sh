#!/bin/bash
# ============================================================
# Family Fire - 一键部署脚本
# 支持公网部署和内网部署
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
NGINX_DIR="$PROJECT_DIR/nginx"
DOWNLOADS_DIR="$PROJECT_DIR/downloads"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helper Functions
# ============================================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            🔥 Family Fire - 一键部署脚本 🔥              ║${NC}"
    echo -e "${CYAN}║         家庭资产管理系统 · FIRE财务独立                    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ! $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

# ============================================================
# Step 1: Check Dependencies
# ============================================================

check_dependencies() {
    print_step "[1/8] 检查依赖环境"
    
    local missing=0
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    else
        print_error "Docker 未安装"
        missing=$((missing+1))
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        print_success "Docker Compose $(docker compose version --short)"
    elif command -v docker-compose &> /dev/null; then
        print_success "Docker Compose $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    else
        print_error "Docker Compose 未安装"
        missing=$((missing+1))
    fi
    
    # Check Flutter (optional, for APK building)
    if command -v flutter &> /dev/null; then
        print_success "Flutter $(flutter --version | head -1 | cut -d' ' -f2)"
    else
        print_warning "Flutter 未安装 (将跳过APK构建)"
    fi
    
    # Check uv (optional, for local backend development)
    if command -v uv &> /dev/null; then
        print_success "uv $(uv --version | cut -d' ' -f2)"
    else
        print_warning "uv 未安装 (将使用Docker运行后端)"
    fi
    
    if [ $missing -gt 0 ]; then
        echo ""
        print_error "缺少必要依赖，请先安装上述软件"
        exit 1
    fi
}

# ============================================================
# Step 2: Configure Deployment Type
# ============================================================

configure_deployment() {
    print_step "[2/8] 配置部署类型"
    
    echo ""
    echo -e "  请选择部署类型:"
    echo -e "    ${GREEN}1)${NC} 内网部署 (局域网访问)"
    echo -e "    ${GREEN}2)${NC} 公网部署 (需要域名和SSL证书)"
    echo ""
    read -p "  请输入选择 [1/2]: " deploy_type
    
    case $deploy_type in
        1)
            DEPLOY_MODE="internal"
            echo ""
            read -p "  请输入服务器IP地址 (默认: localhost): " SERVER_HOST
            SERVER_HOST=${SERVER_HOST:-localhost}
            DOMAIN="$SERVER_HOST"
            USE_SSL=false
            ;;
        2)
            DEPLOY_MODE="public"
            echo ""
            read -p "  请输入域名 (如: example.com): " DOMAIN
            if [ -z "$DOMAIN" ]; then
                print_error "公网部署必须输入域名"
                exit 1
            fi
            SERVER_HOST="$DOMAIN"
            echo ""
            read -p "  是否配置SSL证书? (y/N): " ssl_choice
            if [ "$ssl_choice" = "y" ] || [ "$ssl_choice" = "Y" ]; then
                USE_SSL=true
            else
                USE_SSL=false
            fi
            ;;
        *)
            print_error "无效选择"
            exit 1
            ;;
    esac
    
    echo ""
    read -p "  请输入API端口 (默认: 8000): " API_PORT
    API_PORT=${API_PORT:-8000}
    
    read -p "  请输入HTTP端口 (默认: 80): " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-80}
    
    if [ "$USE_SSL" = true ]; then
        read -p "  请输入HTTPS端口 (默认: 443): " HTTPS_PORT
        HTTPS_PORT=${HTTPS_PORT:-443}
    fi
    
    # Set BASE_URL
    if [ "$USE_SSL" = true ]; then
        BASE_URL="https://${DOMAIN}"
    else
        if [ "$HTTP_PORT" = "80" ]; then
            BASE_URL="http://${SERVER_HOST}"
        else
            BASE_URL="http://${SERVER_HOST}:${HTTP_PORT}"
        fi
    fi
    
    print_success "部署模式: $DEPLOY_MODE"
    print_success "服务器地址: $SERVER_HOST"
    print_success "API端口: $API_PORT"
    print_success "基础URL: $BASE_URL"
}

# ============================================================
# Step 3: Configure Database
# ============================================================

configure_database() {
    print_step "[3/8] 配置数据库"
    
    # 检查是否已有 .env.prod 文件
    if [ -f "$PROJECT_DIR/.env.prod" ]; then
        source "$PROJECT_DIR/.env.prod"
        print_success "检测到现有配置，使用已有密码"
        print_success "数据库用户: ${DB_USER:-postgres}"
        return
    fi
    
    echo ""
    read -p "  数据库用户名 (默认: postgres): " DB_USER
    DB_USER=${DB_USER:-postgres}
    
    read -p "  数据库密码 (默认: 自动生成): " DB_PASSWORD
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        print_success "已生成数据库密码: $DB_PASSWORD"
    fi
    
    read -p "  数据库端口 (默认: 5432): " DB_PORT
    DB_PORT=${DB_PORT:-5432}
    
    print_success "数据库配置完成"
}

# ============================================================
# Step 4: Configure Redis
# ============================================================

configure_redis() {
    print_step "[4/8] 配置Redis"
    
    # 如果已有配置，跳过
    if [ -f "$PROJECT_DIR/.env.prod" ] && [ -n "$REDIS_PASSWORD" ]; then
        print_success "使用已有Redis配置"
        return
    fi
    
    echo ""
    read -p "  Redis密码 (默认: 自动生成): " REDIS_PASSWORD
    if [ -z "$REDIS_PASSWORD" ]; then
        REDIS_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        print_success "已生成Redis密码: $REDIS_PASSWORD"
    fi
    
    read -p "  Redis端口 (默认: 6379): " REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-6379}
    
    print_success "Redis配置完成"
}

# ============================================================
# Step 5: Configure MinIO
# ============================================================

configure_minio() {
    print_step "[5/8] 配置MinIO对象存储"
    
    # 如果已有配置，跳过
    if [ -f "$PROJECT_DIR/.env.prod" ] && [ -n "$MINIO_PASSWORD" ]; then
        print_success "使用已有MinIO配置"
        return
    fi
    
    echo ""
    read -p "  MinIO用户名 (默认: minioadmin): " MINIO_USER
    MINIO_USER=${MINIO_USER:-minioadmin}
    
    read -p "  MinIO密码 (默认: 自动生成): " MINIO_PASSWORD
    if [ -z "$MINIO_PASSWORD" ]; then
        MINIO_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        print_success "已生成MinIO密码: $MINIO_PASSWORD"
    fi
    
    read -p "  MinIO API端口 (默认: 9000): " MINIO_PORT
    MINIO_PORT=${MINIO_PORT:-9000}
    
    read -p "  MinIO控制台端口 (默认: 9001): " MINIO_CONSOLE_PORT
    MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-9001}
    
    print_success "MinIO配置完成"
}

# ============================================================
# Step 6: Generate Configuration Files
# ============================================================

generate_configs() {
    print_step "[6/8] 生成配置文件"
    
    # 检查是否已有 .env.prod，保留 JWT_SECRET_KEY
    if [ -f "$PROJECT_DIR/.env.prod" ]; then
        source "$PROJECT_DIR/.env.prod"
        print_success "保留现有 JWT_SECRET_KEY"
    else
        # Generate JWT secret
        JWT_SECRET_KEY=$(openssl rand -hex 32)
    fi
    
    # Create .env file for docker-compose
    cat > "$PROJECT_DIR/.env.prod" << EOF
# === Database ===
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_PORT=$DB_PORT

# === Redis ===
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=$REDIS_PORT

# === MinIO ===
MINIO_USER=$MINIO_USER
MINIO_PASSWORD=$MINIO_PASSWORD
MINIO_PORT=$MINIO_PORT
MINIO_CONSOLE_PORT=$MINIO_CONSOLE_PORT

# === API ===
API_PORT=$API_PORT
HTTP_PORT=$HTTP_PORT
HTTPS_PORT=${HTTPS_PORT:-443}

# === App ===
JWT_SECRET_KEY=$JWT_SECRET_KEY
BASE_URL=$BASE_URL
EOF
    
    print_success ".env.prod 配置文件已生成"
    
    # Update nginx config with domain
    sed "s/_DOMAIN_/$DOMAIN/g" "$NGINX_DIR/nginx.prod.conf" > "$NGINX_DIR/nginx.prod.conf.tmp"
    mv "$NGINX_DIR/nginx.prod.conf.tmp" "$NGINX_DIR/nginx.prod.conf"
    
    # For internal deployment, disable SSL redirect
    if [ "$DEPLOY_MODE" = "internal" ]; then
        sed -i.bak 's/# server {/server {/g; s/#     listen 80;/    listen 80;/g; s/#     server_name _DOMAIN_;/    server_name _DOMAIN_;/g; s/#     return 301/#     return 301/g' "$NGINX_DIR/nginx.prod.conf"
    fi
    
    print_success "Nginx配置已更新"
    
    # Create downloads directory
    mkdir -p "$DOWNLOADS_DIR"
    print_success "下载目录已创建: $DOWNLOADS_DIR"
}

# ============================================================
# Step 7: Build APK (Optional)
# ============================================================

build_apk() {
    print_step "[7/8] 构建Flutter APK"
    
    if ! command -v flutter &> /dev/null; then
        print_warning "Flutter未安装，跳过APK构建"
        print_warning "请在本地构建APK后上传到: $DOWNLOADS_DIR"
        return
    fi
    
    echo ""
    echo -e "  是否构建APK? (需要较长时间)"
    read -p "  [y/N]: " build_choice
    
    if [ "$build_choice" != "y" ] && [ "$build_choice" != "Y" ]; then
        print_warning "跳过APK构建"
        return
    fi
    
    cd "$FRONTEND_DIR"
    
    # Update API endpoint in Flutter app
    echo ""
    print_warning "正在配置API地址: $BASE_URL"
    
    # Create/update environment config
    mkdir -p "$FRONTEND_DIR/lib/config"
    cat > "$FRONTEND_DIR/lib/config/env.dart" << EOF
/// 环境配置 - 由部署脚本自动生成
class EnvConfig {
  static const String apiBaseUrl = '$BASE_URL';
  static const String wsUrl = '${BASE_URL/http/ws}';
}
EOF
    
    print_success "API地址已配置"
    
    # Build APK
    echo ""
    print_warning "正在构建APK，请稍候..."
    flutter pub get
    flutter build apk --release
    
    # Copy APK to downloads
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        VERSION=$(grep 'version:' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
        APK_NAME="family-fire-v${VERSION}.apk"
        cp "build/app/outputs/flutter-apk/app-release.apk" "$DOWNLOADS_DIR/$APK_NAME"
        print_success "APK已生成: $DOWNLOADS_DIR/$APK_NAME"
        
        # Create latest symlink
        cd "$DOWNLOADS_DIR"
        ln -sf "$APK_NAME" "family-fire-latest.apk"
        print_success "已创建最新版本链接: family-fire-latest.apk"
    else
        print_error "APK构建失败"
    fi
    
    cd "$PROJECT_DIR"
}

# ============================================================
# Step 8: Start Services
# ============================================================

start_services() {
    print_step "[8/8] 启动服务"
    
    cd "$PROJECT_DIR"
    
    # Create SSL directory if needed
    if [ "$USE_SSL" = true ]; then
        mkdir -p "$NGINX_DIR/ssl"
        if [ ! -f "$NGINX_DIR/ssl/fullchain.pem" ] || [ ! -f "$NGINX_DIR/ssl/privkey.pem" ]; then
            echo ""
            print_warning "SSL证书未找到"
            print_warning "请将SSL证书放到以下目录:"
            print_warning "  - $NGINX_DIR/ssl/fullchain.pem"
            print_warning "  - $NGINX_DIR/ssl/privkey.pem"
            echo ""
            print_warning "可以使用 Let's Encrypt 获取免费证书:"
            print_warning "  apt install certbot"
            print_warning "  certbot certonly --standalone -d $DOMAIN"
            echo ""
            read -p "  是否继续部署 (不配置SSL)? [y/N]: " continue_choice
            if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
                exit 1
            fi
        fi
    fi
    
    # Stop existing services
    echo ""
    print_warning "停止现有服务..."
    docker compose -f docker-compose.prod.yml --env-file .env.prod down 2>/dev/null || true
    
    # Start services
    echo ""
    print_warning "启动服务..."
    docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
    
    # Wait for services
    echo ""
    print_warning "等待服务启动..."
    sleep 10
    
    # Check health
    echo ""
    print_warning "检查服务状态..."
    
    if docker ps --filter "name=family-fire-db" --filter "status=running" | grep -q family-fire-db; then
        print_success "PostgreSQL 运行中"
    else
        print_error "PostgreSQL 启动失败"
    fi
    
    if docker ps --filter "name=family-fire-redis" --filter "status=running" | grep -q family-fire-redis; then
        print_success "Redis 运行中"
    else
        print_error "Redis 启动失败"
    fi
    
    if docker ps --filter "name=family-fire-minio" --filter "status=running" | grep -q family-fire-minio; then
        print_success "MinIO 运行中"
    else
        print_error "MinIO 启动失败"
    fi
    
    if docker ps --filter "name=family-fire-api" --filter "status=running" | grep -q family-fire-api; then
        print_success "API服务 运行中"
    else
        print_error "API服务 启动失败"
    fi
    
    if docker ps --filter "name=family-fire-nginx" --filter "status=running" | grep -q family-fire-nginx; then
        print_success "Nginx 运行中"
    else
        print_error "Nginx 启动失败"
    fi
    
    # Initialize database
    echo ""
    print_warning "初始化数据库..."
    docker exec -w /app family-fire-api python scripts/init_db.py
    print_success "数据库初始化完成"
}

# ============================================================
# Print Summary
# ============================================================

print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   🎉 部署完成! 🎉                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}访问地址:${NC}"
    echo -e "    API文档: ${BLUE}$BASE_URL/docs${NC}"
    echo -e "    健康检查: ${BLUE}$BASE_URL/health${NC}"
    
    if [ -f "$DOWNLOADS_DIR/family-fire-latest.apk" ]; then
        echo -e "    APK下载: ${BLUE}$BASE_URL/downloads/family-fire-latest.apk${NC}"
    fi
    
    echo ""
    echo -e "  ${GREEN}默认管理员账号:${NC}"
    echo -e "    用户名: ${YELLOW}admin${NC}"
    echo -e "    密码: ${YELLOW}Admin@123456${NC}"
    
    echo ""
    echo -e "  ${GREEN}服务管理命令:${NC}"
    echo -e "    查看日志: ${CYAN}docker compose -f docker-compose.prod.yml logs -f${NC}"
    echo -e "    停止服务: ${CYAN}docker compose -f docker-compose.prod.yml down${NC}"
    echo -e "    重启服务: ${CYAN}docker compose -f docker-compose.prod.yml restart${NC}"
    
    echo ""
    echo -e "  ${GREEN}配置文件:${NC}"
    echo -e "    环境配置: ${CYAN}$PROJECT_DIR/.env.prod${NC}"
    echo -e "    Nginx配置: ${CYAN}$NGINX_DIR/nginx.prod.conf${NC}"
    echo -e "    下载目录: ${CYAN}$DOWNLOADS_DIR${NC}"
    
    if [ "$USE_SSL" = true ]; then
        echo ""
        echo -e "  ${YELLOW}注意: 请确保SSL证书已正确配置${NC}"
        echo -e "  证书位置: $NGINX_DIR/ssl/"
    fi
    
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    print_banner
    check_dependencies
    configure_deployment
    configure_database
    configure_redis
    configure_minio
    generate_configs
    build_apk
    start_services
    print_summary
}

# Run main function
main
