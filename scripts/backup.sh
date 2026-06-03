#!/bin/bash
# ============================================================
# Family Fire - 数据库备份脚本
# 支持 PostgreSQL 和 MinIO 数据备份
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"

# 加载环境变量
if [ -f "$PROJECT_DIR/.env.prod" ]; then
    source "$PROJECT_DIR/.env.prod"
elif [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# 默认值
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-postgres}
DB_PORT=${DB_PORT:-5432}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

# ============================================================
# 创建备份目录
# ============================================================

create_backup_dir() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"
    echo "$BACKUP_PATH"
}

# ============================================================
# 备份 PostgreSQL
# ============================================================

backup_postgres() {
    local backup_path=$1
    print_step "备份 PostgreSQL 数据库"
    
    # 检查容器是否运行
    if ! docker ps --filter "name=family-fire-db" --filter "status=running" | grep -q family-fire-db; then
        print_error "PostgreSQL 容器未运行"
        return 1
    fi
    
    # 使用 pg_dump 备份
    docker exec family-fire-db pg_dump \
        -U "$DB_USER" \
        -d family_fire \
        --format=custom \
        --compress=9 \
        > "$backup_path/database.dump"
    
    # 同时备份 SQL 格式（便于查看）
    docker exec family-fire-db pg_dump \
        -U "$DB_USER" \
        -d family_fire \
        --format=plain \
        > "$backup_path/database.sql"
    
    local size=$(du -h "$backup_path/database.dump" | cut -f1)
    print_success "数据库备份完成: $size"
}

# ============================================================
# 备份 MinIO 数据
# ============================================================

backup_minio() {
    local backup_path=$1
    print_step "备份 MinIO 文件数据"
    
    # 检查容器是否运行
    if ! docker ps --filter "name=family-fire-minio" --filter "status=running" | grep -q family-fire-minio; then
        print_error "MinIO 容器未运行"
        return 1
    fi
    
    # 创建 MinIO 备份目录
    mkdir -p "$backup_path/minio"
    
    # 使用 docker cp 复制数据
    # 注意：这需要 MinIO 数据卷挂载
    if [ -d "$PROJECT_DIR/minio_data" ]; then
        cp -r "$PROJECT_DIR/minio_data" "$backup_path/minio/"
        local size=$(du -sh "$backup_path/minio" | cut -f1)
        print_success "MinIO 备份完成: $size"
    else
        print_error "MinIO 数据目录不存在，跳过"
    fi
}

# ============================================================
# 备份配置文件
# ============================================================

backup_configs() {
    local backup_path=$1
    print_step "备份配置文件"
    
    mkdir -p "$backup_path/configs"
    
    # 备份 .env.prod
    if [ -f "$PROJECT_DIR/.env.prod" ]; then
        cp "$PROJECT_DIR/.env.prod" "$backup_path/configs/"
    fi
    
    # 备份 docker-compose
    cp "$PROJECT_DIR/docker-compose.prod.yml" "$backup_path/configs/"
    
    # 备份 nginx 配置
    if [ -d "$PROJECT_DIR/nginx" ]; then
        cp -r "$PROJECT_DIR/nginx" "$backup_path/configs/"
    fi
    
    print_success "配置文件备份完成"
}

# ============================================================
# 压缩备份
# ============================================================

compress_backup() {
    local backup_path=$1
    print_step "压缩备份文件"
    
    local archive_name="family-fire-backup-$(basename $backup_path).tar.gz"
    cd "$BACKUP_DIR"
    tar -czf "$archive_name" "$(basename $backup_path)"
    
    # 删除临时目录
    rm -rf "$backup_path"
    
    local size=$(du -h "$BACKUP_DIR/$archive_name" | cut -f1)
    print_success "压缩完成: $BACKUP_DIR/$archive_name ($size)"
}

# ============================================================
# 清理旧备份
# ============================================================

cleanup_old_backups() {
    print_step "清理 ${BACKUP_RETENTION_DAYS} 天前的备份"
    
    local count=$(find "$BACKUP_DIR" -name "family-fire-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS | wc -l)
    
    if [ "$count" -gt 0 ]; then
        find "$BACKUP_DIR" -name "family-fire-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
        print_success "已删除 $count 个旧备份"
    else
        print_success "没有需要清理的旧备份"
    fi
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🔥 Family Fire - 数据备份脚本 🔥               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    # 创建备份目录
    BACKUP_PATH=$(create_backup_dir)
    print_success "备份目录: $BACKUP_PATH"
    
    # 执行备份
    backup_postgres "$BACKUP_PATH"
    backup_minio "$BACKUP_PATH"
    backup_configs "$BACKUP_PATH"
    
    # 压缩备份
    compress_backup "$BACKUP_PATH"
    
    # 清理旧备份
    cleanup_old_backups
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   🎉 备份完成! 🎉                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}备份文件:${NC}"
    echo -e "    ${BLUE}$BACKUP_DIR/family-fire-backup-$TIMESTAMP.tar.gz${NC}"
    echo ""
}

# 运行主函数
main
