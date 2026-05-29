# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.2.0] - 2026-05-29

### Phase 2 — Open Source & Flutter Integration

#### Added
- **Open Source Infrastructure**: LICENSE (MIT), CONTRIBUTING.md, CODE_OF_CONDUCT.md, CHANGELOG.md
- **GitHub Templates**: Bug report, feature request, PR template
- **Deploy Scripts**: `scripts/setup.sh` (one-click setup), `scripts/backup.sh` (database backup)
- **Production Config**: nginx/nginx.conf, docker-compose.prod.yml, Dockerfile.prod, gunicorn.conf.py
- **Database Init**: `backend/scripts/init_db.py` (idempotent, safe to run multiple times)
- **Flutter API Client**: Dio with auth interceptor, token refresh, error handling
- **Flutter Auth**: Login/register pages connected to backend API
- **Flutter Family**: Family list, create, invite code, join family
- **Flutter Assets**: Asset list with filters, add/edit, detail, archive
- **Flutter FIRE**: Dashboard with net worth, metrics, pie chart, Monte Carlo
- **Flutter Notifications**: Notification list, grouped by date, mark read
- **Flutter Settings**: Theme/language selection, profile, logout
- **Celery Tasks**: Price updates (stocks/crypto/funds), lifecycle recalculation, expiry alerts
- **WebSocket**: Real-time notifications via Redis Pub/Sub

#### Fixed
- Timezone compatibility with PostgreSQL (asyncpg) — all datetime operations use timezone-aware UTC
- Removed deprecated `datetime.utcnow()` — now using `datetime.now(UTC)`
- 0 deprecation warnings

#### Stats
- 182 backend tests passing
- 0 deprecation warnings
- 212 files, 13,500+ lines of code

## [0.1.0] - 2026-05-29

### Phase 1 — Core Backend & Flutter Foundation

#### Added
- **T1: Project Init**: FastAPI skeleton, Docker Compose, CI/CD, test framework
- **T2: Database Schema**: 26 tables, multi-dimensional asset classification, standard Chinese categories
- **T3: Authentication**: JWT (access+refresh), bcrypt, username+email login, RBAC
- **T4: Family Management**: Family CRUD, invite codes, member management
- **T5: Asset Core**: Multi-dimensional classification, tags, search, bulk actions
- **T6: Asset Lifecycle**: 6 trajectory calculators, 10 relationship types
- **T7: Finance**: Liability management, income/expense, investment transactions, cost basis, price providers
- **T8: Documents**: MinIO upload, PDF preview, thumbnails
- **T9: Notifications**: Family collaboration notifications
- **T10: FIRE Engine**: Net worth, savings rate, FIRE number, Monte Carlo simulation
- **T11: Flutter Foundation**: Riverpod, GoRouter, theme, i18n, API client
- **T12: Flutter Auth**: Login/register pages
- **T13-T15: Flutter Pages**: Asset list, FIRE dashboard, income/expense
- **T16: Production**: README, CI/CD skeleton
