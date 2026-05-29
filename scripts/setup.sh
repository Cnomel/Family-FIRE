#!/bin/bash
# Family Fire - One-click Setup Script
# Usage: ./scripts/setup.sh

set -e

echo "🔥 Family Fire Setup"
echo "===================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        echo "  Install: $2"
        return 1
    else
        echo -e "${GREEN}✓ $1 found${NC}"
        return 0
    fi
}

echo "Checking dependencies..."
MISSING=0

check_dependency "docker" "https://docs.docker.com/get-docker/" || MISSING=$((MISSING+1))
check_dependency "docker-compose" "https://docs.docker.com/compose/install/" || MISSING=$((MISSING+1))

if [ $MISSING -gt 0 ]; then
    echo -e "${RED}$MISSING dependency(ies) missing. Please install them first.${NC}"
    exit 1
fi

echo ""
echo "All dependencies found!"
echo ""

# Generate .env if not exists
if [ ! -f .env ]; then
    echo "Generating .env from .env.example..."
    cp .env.example .env

    # Generate secure JWT secret
    JWT_SECRET=$(openssl rand -hex 32)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/JWT_SECRET_KEY=change-me-in-production-use-openssl-rand-hex-32/JWT_SECRET_KEY=${JWT_SECRET}/" .env
    else
        sed -i "s/JWT_SECRET_KEY=change-me-in-production-use-openssl-rand-hex-32/JWT_SECRET_KEY=${JWT_SECRET}/" .env
    fi

    echo -e "${GREEN}✓ .env generated with secure JWT secret${NC}"
else
    echo -e "${YELLOW}⚠ .env already exists, skipping${NC}"
fi

echo ""

# Start services
echo "Starting Docker services..."
docker-compose up -d postgres redis minio

echo ""
echo "Waiting for services to be ready..."
sleep 5

# Install backend dependencies
echo "Installing backend dependencies..."
cd backend

if command -v uv &> /dev/null; then
    uv sync --all-extras
else
    echo -e "${YELLOW}uv not found. Installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    uv sync --all-extras
fi

echo ""

# Run migrations
echo "Running database migrations..."
uv run alembic upgrade head 2>/dev/null || echo -e "${YELLOW}⚠ No migrations yet. Run 'uv run alembic revision --autogenerate' first.${NC}"

echo ""

# Run tests
echo "Running tests..."
uv run pytest tests/ -v --tb=short

echo ""

# Create admin user
echo "Creating default admin user..."
uv run python -c "
import asyncio
from app.common.seed import seed_all
from app.database import async_session_factory

async def main():
    async with async_session_factory() as session:
        await seed_all(session)
        print('✓ Admin user created (username: admin, password: Admin@123456)')

asyncio.run(main())
" 2>/dev/null || echo -e "${YELLOW}⚠ Admin user creation skipped (run manually if needed)${NC}"

cd ..

echo ""
echo "============================="
echo -e "${GREEN}🔥 Family Fire is ready!${NC}"
echo "============================="
echo ""
echo "Start the backend:"
echo "  cd backend && uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "API Documentation:"
echo "  http://localhost:8000/docs"
echo ""
echo "Default admin:"
echo "  Username: admin"
echo "  Password: Admin@123456"
echo ""
echo "MinIO Console:"
echo "  http://localhost:9001"
echo "  User: minioadmin / minioadmin"
echo ""
