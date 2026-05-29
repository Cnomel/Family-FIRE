#!/bin/bash
# Family Fire - Complete Setup Script
# Handles: .env, Docker, database, seed data
# Safe to run multiple times

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"

echo ""
echo "=========================================="
echo "  Family Fire - Setup"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check dependencies
echo "[1/6] Checking dependencies..."
MISSING=0

if ! command -v docker &> /dev/null; then
    echo -e "${RED}  ✗ docker not found${NC}"
    MISSING=$((MISSING+1))
else
    echo -e "${GREEN}  ✓ docker${NC}"
fi

if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}  ! uv not found, installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
echo -e "${GREEN}  ✓ uv${NC}"

if [ $MISSING -gt 0 ]; then
    echo -e "${RED}Missing dependencies. Please install them first.${NC}"
    exit 1
fi

# Step 2: Create .env if not exists
echo ""
echo "[2/6] Configuring environment..."
if [ ! -f "$BACKEND_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env.example" "$BACKEND_DIR/.env"
    # Generate secure JWT secret
    JWT_SECRET=$(openssl rand -hex 32)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/JWT_SECRET_KEY=change-me-in-production-use-openssl-rand-hex-32/JWT_SECRET_KEY=${JWT_SECRET}/" "$BACKEND_DIR/.env"
    else
        sed -i "s/JWT_SECRET_KEY=change-me-in-production-use-openssl-rand-hex-32/JWT_SECRET_KEY=${JWT_SECRET}/" "$BACKEND_DIR/.env"
    fi
    echo -e "${GREEN}  ✓ .env created with secure JWT secret${NC}"
else
    echo -e "${YELLOW}  ! .env already exists, skipping${NC}"
fi

# Step 3: Start Docker services
echo ""
echo "[3/6] Starting Docker services..."
cd "$PROJECT_DIR"
docker-compose up -d postgres redis minio

echo "  Waiting for services..."
sleep 5

# Check health
if docker ps --filter "name=family-fire-db" --filter "status=running" | grep -q family-fire-db; then
    echo -e "${GREEN}  ✓ PostgreSQL running${NC}"
else
    echo -e "${RED}  ✗ PostgreSQL failed to start${NC}"
    exit 1
fi

if docker ps --filter "name=family-fire-redis" --filter "status=running" | grep -q family-fire-redis; then
    echo -e "${GREEN}  ✓ Redis running${NC}"
else
    echo -e "${RED}  ✗ Redis failed to start${NC}"
    exit 1
fi

# Step 4: Install Python dependencies
echo ""
echo "[4/6] Installing Python dependencies..."
cd "$BACKEND_DIR"
uv sync --all-extras
echo -e "${GREEN}  ✓ Dependencies installed${NC}"

# Step 5: Initialize database
echo ""
echo "[5/6] Initializing database..."
uv run python scripts/init_db.py

# Step 6: Verify
echo ""
echo "[6/6] Verifying installation..."
uv run python -c "
import asyncio
from app.database import engine
from sqlalchemy import text

async def check():
    async with engine.begin() as conn:
        result = await conn.execute(text('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = \\'public\\''))
        count = result.scalar()
        print(f'  Tables: {count}')

asyncio.run(check())
"

echo ""
echo "=========================================="
echo -e "${GREEN}  Setup complete!${NC}"
echo "=========================================="
echo ""
echo "Start the backend:"
echo "  cd backend"
echo "  uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "API Documentation:"
echo "  http://localhost:8000/docs"
echo ""
echo "Default admin:"
echo "  Username: admin"
echo "  Password: Admin@123456"
echo ""
