#!/bin/bash
# ============================================================
# Family Fire - 数据恢复脚本
# 从备份恢复 PostgreSQL 和 MinIO 数据
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

print_warning() {
    echo -e "${YELLOW}  ! $1${NC}"
}

# ============================================================
# 列出可用备份
# ============================================================

list_backups() {
    print_step "可用的备份文件"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "备份目录不存在: $BACKUP_DIR"
        exit 1
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/family-fire-backup-*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_error "没有找到备份文件"
        exit 1
    fi
    
    echo ""
    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        local size=$(du -h "${backups[$i]}" | cut -f1)
        local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "${backups[$i]}")
        echo -e "  ${GREEN}$((i+1)))${NC} $filename ($size) - $date"
    done
    echo ""
}

# ============================================================
# 解压备份
# ============================================================

extract_backup() {
    local backup_file=$1
    local extract_dir="$BACKUP_DIR/temp_restore"
    
    print_step "解压备份文件"
    
    # 清理临时目录
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    
    tar -xzf "$backup_file" -C "$extract_dir"
    
    # 查找解压后的目录
    RESTORE_PATH=$(find "$extract_dir" -maxdepth 1 -type d | tail -1)
    
    print_success "解压完成: $RESTORE_PATH"
}

# ============================================================
# 恢复 PostgreSQL
# ============================================================

restore_postgres() {
    print_step "恢复 PostgreSQL 数据库"
    
    # 检查容器是否运行
    if ! docker ps --filter "name=family-fire-db" --filter "status=running" | grep -q family-fire-db; then
        print_error "PostgreSQL 容器未运行"
        return 1
    fi
    
    if [ ! -f "$RESTORE_PATH/database.dump" ]; then
        print_error "数据库备份文件不存在"
        return 1
    fi
    
    # 确认恢复
    echo ""
    print_warning "⚠️  这将覆盖现有数据库！"
    read -p "  确认恢复数据库? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "跳过数据库恢复"
        return 0
    fi
    
    # 停止后端服务
    print_warning "停止后端服务..."
    docker compose -f "$PROJECT_DIR/docker-compose.prod.yml" stop backend celery-worker celery-beat 2>/dev/null || true
    
    # 删除并重建数据库
    print_warning "重建数据库..."
    docker exec family-fire-db psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS family_fire;" postgres
    docker exec family-fire-db psql -U "$DB_USER" -c "CREATE DATABASE family_fire;" postgres
    
    # 恢复数据
    print_warning "恢复数据..."
    docker exec -i family-fire-db pg_restore \
        -U "$DB_USER" \
        -d family_fire \
        --clean \
        --if-exists \
        < "$RESTORE_PATH/database.dump"
    
    # 重启后端服务
    print_warning "重启后端服务..."
    docker compose -f "$PROJECT_DIR/docker-compose.prod.yml" start backend celery-worker celery-beat
    
    print_success "数据库恢复完成"
}

# ============================================================
# 恢复 MinIO
# ============================================================

restore_minio() {
    print_step "恢复 MinIO 文件数据"
    
    if [ ! -d "$RESTORE_PATH/minio/minio_data" ]; then
        print_warning "MinIO 备份不存在，跳过"
        return 0
    fi
    
    # 确认恢复
    echo ""
    print_warning "⚠️  这将覆盖现有文件！"
    read -p "  确认恢复 MinIO 数据? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "跳过 MinIO 恢复"
        return 0
    fi
    
    # 停止 MinIO
    print_warning "停止 MinIO..."
    docker compose -f "$PROJECT_DIR/docker-compose.prod.yml" stop minio 2>/dev/null || true
    
    # 恢复数据
    if [ -d "$PROJECT_DIR/minio_data" ]; then
        rm -rf "$PROJECT_DIR/minio_data.bak"
        mv "$PROJECT_DIR/minio_data" "$PROJECT_DIR/minio_data.bak"
    fi
    
    cp -r "$RESTORE_PATH/minio/minio_data" "$PROJECT_DIR/minio_data"
    
    # 重启 MinIO
    print_warning "重启 MinIO..."
    docker compose -f "$PROJECT_DIR/docker-compose.prod.yml" start minio
    
    print_success "MinIO 恢复完成"
}

# ============================================================
# 恢复配置文件
# ============================================================

restore_configs() {
    print_step "恢复配置文件"
    
    if [ ! -d "$RESTORE_PATH/configs" ]; then
        print_warning "配置文件备份不存在，跳过"
        return 0
    fi
    
    # 确认恢复
    echo ""
    read -p "  确认恢复配置文件? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "跳过配置文件恢复"
        return 0
    fi
    
    # 恢复 .env.prod
    if [ -f "$RESTORE_PATH/configs/.env.prod" ]; then
        cp "$RESTORE_PATH/configs/.env.prod" "$PROJECT_DIR/.env.prod"
        print_success "恢复 .env.prod"
    fi
    
    print_success "配置文件恢复完成"
}

# ============================================================
# 清理临时文件
# ============================================================

cleanup() {
    print_step "清理临时文件"
    rm -rf "$BACKUP_DIR/temp_restore"
    print_success "清理完成"
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🔥 Family Fire - 数据恢复脚本 🔥               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    # 列出备份
    list_backups
    
    # 选择备份文件
    local backups=($(ls -t "$BACKUP_DIR"/family-fire-backup-*.tar.gz 2>/dev/null))
    read -p "  选择备份文件编号 [1]: " choice
    choice=${choice:-1}
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        print_error "无效选择"
        exit 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    print_success "已选择: $(basename $selected_backup)"
    
    # 解压备份
    extract_backup "$selected_backup"
    
    # 恢复数据
    restore_postgres
    restore_minio
    restore_configs
    
    # 清理
    cleanup
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   🎉 恢复完成! 🎉                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 运行主函数
main
