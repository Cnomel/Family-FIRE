#!/bin/bash
# ============================================================
# Family Fire - 配置定时备份
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         🔥 Family Fire - 配置定时备份 🔥                 ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "  ${BLUE}请选择备份频率:${NC}"
echo -e "    ${GREEN}1)${NC} 每天凌晨 2 点"
echo -e "    ${GREEN}2)${NC} 每天凌晨 3 点"
echo -e "    ${GREEN}3)${NC} 每周日凌晨 2 点"
echo -e "    ${GREEN}4)${NC} 自定义"
echo ""
read -p "  请输入选择 [1]: " choice
choice=${choice:-1}

BACKUP_SCRIPT="$PROJECT_DIR/scripts/backup.sh"
LOG_FILE="$PROJECT_DIR/backups/backup.log"

case $choice in
    1)
        CRON_SCHEDULE="0 2 * * *"
        DESCRIPTION="每天凌晨 2 点"
        ;;
    2)
        CRON_SCHEDULE="0 3 * * *"
        DESCRIPTION="每天凌晨 3 点"
        ;;
    3)
        CRON_SCHEDULE="0 2 * * 0"
        DESCRIPTION="每周日凌晨 2 点"
        ;;
    4)
        read -p "  请输入 cron 表达式 (如: 0 2 * * *): " CRON_SCHEDULE
        DESCRIPTION="自定义: $CRON_SCHEDULE"
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac

# 确保备份脚本可执行
chmod +x "$BACKUP_SCRIPT"

# 创建备份目录
mkdir -p "$PROJECT_DIR/backups"

# 添加 crontab
CRON_JOB="$CRON_SCHEDULE $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

# 检查是否已存在
if crontab -l 2>/dev/null | grep -q "family-fire.*backup"; then
    echo ""
    read -p "  已存在备份任务，是否替换? (y/N): " replace
    if [ "$replace" = "y" ] || [ "$replace" = "Y" ]; then
        crontab -l 2>/dev/null | grep -v "family-fire.*backup" | crontab -
    else
        echo "  保持现有配置"
        exit 0
    fi
fi

# 添加新的 crontab
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo ""
echo -e "${GREEN}  ✓ 定时备份配置完成${NC}"
echo ""
echo -e "  ${BLUE}备份频率:${NC} $DESCRIPTION"
echo -e "  ${BLUE}备份脚本:${NC} $BACKUP_SCRIPT"
echo -e "  ${BLUE}日志文件:${NC} $LOG_FILE"
echo ""
echo -e "  ${YELLOW}查看定时任务: crontab -l${NC}"
echo -e "  ${YELLOW}手动执行备份: $BACKUP_SCRIPT${NC}"
echo ""
