# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Phase 1 — Core Backend (Completed)

#### Added
- **T1: Project Initialization** — FastAPI skeleton, Docker Compose (PostgreSQL/Redis/MinIO), CI/CD, test framework
- **T2: Database Schema** — 26 tables, multi-dimensional asset classification, standard Chinese categories, seed data
- **T3: Authentication** — JWT (access+refresh), bcrypt, username+email login, RBAC (Admin/FamilyAdmin/Member), login lockout
- **T4: Family Management** — Family CRUD, invite codes (6-char, 7-day expiry), member management, family creation limits
- **T5: Asset Core** — Multi-dimensional classification (nature/utility/ownership/liquidity), tags, full-text search, bulk actions, duplicate detection
- **T6: Asset Lifecycle** — 6 trajectory calculators (depreciating/consumable/expiring/volatile/appreciating/stable), 10 relationship types, insurance gap analysis
- **T7: Finance** — Liability management (mortgage/auto loan/credit card), income/expense tracking, investment transactions, cost basis (FIFO/LIFO/average), price providers (AlphaVantage/CoinGecko/Yahoo)
- **T8: Documents** — MinIO upload (PDF/JPG/PNG/HEIC), thumbnails, presigned URLs, expiry tracking
- **T9: Notifications** — Family collaboration notifications, unread count, mark read, preferences
- **T10: FIRE Engine** — Net worth, savings rate, FIRE number, FI ratio, Monte Carlo simulation (1000 runs), passive income estimation

### Phase 1 — Flutter (Completed)

#### Added
- **T11: Flutter Foundation** — Riverpod, GoRouter, Dio client, theme (Material 3, blue #1677FF), i18n (zh/en), currency formatter (¥/万/亿)
- **T12: Auth Pages** — Login page, register page with password strength indicator
- **T13-T15: Feature Pages** — Asset list with filters, FIRE dashboard with charts (fl_chart), income/expense tracking with bar charts

### Phase 1 — Infrastructure (Completed)

#### Added
- **T16: Production** — README, CI/CD skeleton, Docker configuration, 158 tests passing

### Stats
- Backend: ~5000 lines, 50+ API endpoints, 26 database tables
- Tests: 158 passing (integration + unit + schema)
- Flutter: 6 pages with charts and i18n
