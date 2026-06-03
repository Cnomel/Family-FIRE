#!/bin/bash
# ============================================================
# Family Fire - APK构建脚本
# 构建Flutter APK并放到下载目录
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_DIR/frontend"
DOWNLOADS_DIR="$PROJECT_DIR/downloads"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🔥 Family Fire - APK构建脚本 🔥                ║${NC}"
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
# Step 1: Check Flutter
# ============================================================

check_flutter() {
    print_step "[1/5] 检查Flutter环境"
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter未安装"
        echo ""
        echo "  请先安装Flutter: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    
    FLUTTER_VERSION=$(flutter --version | head -1 | cut -d' ' -f2)
    print_success "Flutter $FLUTTER_VERSION"
}

# ============================================================
# Step 2: Configure API Endpoint
# ============================================================

configure_api() {
    print_step "[2/5] 配置API地址"
    
    echo ""
    echo -e "  请输入后端API地址:"
    echo -e "  (例如: http://family.cnomel.cn 或 https://api.example.com)"
    echo ""
    read -p "  API地址: " API_URL
    
    if [ -z "$API_URL" ]; then
        print_error "API地址不能为空"
        exit 1
    fi
    
    # Remove trailing slash
    API_URL=${API_URL%/}
    
    # Generate ws url
    WS_URL=${API_URL/http/ws}
    
    print_success "API地址已配置: $API_URL"
}

# ============================================================
# Step 3: Get Dependencies
# ============================================================

get_dependencies() {
    print_step "[3/5] 获取依赖"
    
    cd "$FRONTEND_DIR"
    
    echo ""
    print_warning "正在获取Flutter依赖..."
    flutter pub get
    
    print_success "依赖获取完成"
}

# ============================================================
# Step 4: Build APK
# ============================================================

build_apk() {
    print_step "[4/5] 构建APK"
    
    cd "$FRONTEND_DIR"
    
    echo ""
    print_warning "正在构建APK，请稍候..."
    
    flutter build apk --release \
        --dart-define=API_BASE_URL=$API_URL \
        --dart-define=WS_URL=$WS_URL
    
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    BUILD_TYPE="release"
    
    if [ ! -f "$FRONTEND_DIR/$APK_PATH" ]; then
        print_error "APK构建失败"
        exit 1
    fi
    
    print_success "APK构建完成"
}

# ============================================================
# Step 5: Copy to Downloads
# ============================================================

copy_apk() {
    print_step "[5/5] 复制到下载目录"
    
    mkdir -p "$DOWNLOADS_DIR"
    
    # Get version from pubspec.yaml
    VERSION=$(grep 'version:' "$FRONTEND_DIR/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)
    
    APK_NAME="family-fire-v${VERSION}.apk"
    cp "$FRONTEND_DIR/$APK_PATH" "$DOWNLOADS_DIR/$APK_NAME"
    
    # Create latest symlink
    cd "$DOWNLOADS_DIR"
    ln -sf "$APK_NAME" "family-fire-latest.apk"
    
    APK_SIZE=$(du -h "$DOWNLOADS_DIR/$APK_NAME" | cut -f1)
    
    print_success "APK已复制到: $DOWNLOADS_DIR/$APK_NAME"
    print_success "文件大小: $APK_SIZE"
    print_success "最新版本链接: $DOWNLOADS_DIR/family-fire-latest.apk"
}

# ============================================================
# Print Summary
# ============================================================

print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   🎉 构建完成! 🎉                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}APK文件:${NC}"
    echo -e "    路径: ${BLUE}$DOWNLOADS_DIR/$APK_NAME${NC}"
    echo -e "    大小: ${YELLOW}$APK_SIZE${NC}"
    echo -e "    API: ${BLUE}$API_URL${NC}"
    echo ""
    echo -e "  ${GREEN}分发方式:${NC}"
    echo -e "    1. 直接将APK文件发送给用户安装"
    echo -e "    2. 部署到Web服务器提供下载链接"
    echo -e "       下载地址: ${BLUE}$API_URL/downloads/$APK_NAME${NC}"
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    print_banner
    check_flutter
    configure_api
    get_dependencies
    build_apk
    copy_apk
    print_summary
}

# Run main function
main
