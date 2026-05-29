"""Tests for lifecycle calculation engine and relationships."""

from datetime import UTC, datetime, timedelta

from app.assets.lifecycle.engine import (
    RELATIONSHIP_TYPES,
    compute_current_value,
    compute_value_history,
)

# ============================================================
# Depreciation Tests
# ============================================================

class TestDepreciationCalculation:
    def test_straight_line_basic(self):
        """Asset worth 10000, salvage 2000, 4 years life, after 2 years."""
        purchase_date = datetime.now(UTC) - timedelta(days=730)  # 2 years
        value = compute_current_value(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=purchase_date,
            config={"method": "straight_line", "rate": 0.15, "salvage_value": 2000, "useful_life_years": 4},
        )
        # Annual depreciation = (10000-2000)/4 = 2000/year
        # After 2 years: 10000 - 4000 = 6000
        assert 5900 <= value <= 6100

    def test_straight_line_floor_at_salvage(self):
        """Value should not go below salvage value."""
        purchase_date = datetime.now(UTC) - timedelta(days=3650)  # 10 years
        value = compute_current_value(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=purchase_date,
            config={"method": "straight_line", "salvage_value": 2000, "useful_life_years": 4},
        )
        assert value >= 2000

    def test_declining_balance(self):
        """Declining balance at 20% rate."""
        purchase_date = datetime.now(UTC) - timedelta(days=365)  # 1 year
        value = compute_current_value(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=purchase_date,
            config={"method": "declining_balance", "rate": 0.20},
        )
        # After 1 year: 10000 * 0.8 = 8000
        assert 7900 <= value <= 8100

    def test_no_purchase_date_returns_price(self):
        value = compute_current_value(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=None,
            config={"method": "straight_line"},
        )
        assert value == 10000


# ============================================================
# Consumable Tests
# ============================================================

class TestConsumableCalculation:
    def test_full_quantity(self):
        value = compute_current_value(
            trajectory="consumable",
            purchase_price=100,
            purchase_date=None,
            config=None,
            current_quantity=10,
            initial_quantity=10,
        )
        assert value == 100

    def test_half_quantity(self):
        value = compute_current_value(
            trajectory="consumable",
            purchase_price=100,
            purchase_date=None,
            config=None,
            current_quantity=5,
            initial_quantity=10,
        )
        assert value == 50

    def test_empty_quantity(self):
        value = compute_current_value(
            trajectory="consumable",
            purchase_price=100,
            purchase_date=None,
            config=None,
            current_quantity=0,
            initial_quantity=10,
        )
        assert value == 0

    def test_no_quantity_returns_price(self):
        value = compute_current_value(
            trajectory="consumable",
            purchase_price=100,
            purchase_date=None,
            config=None,
        )
        assert value == 100


# ============================================================
# Expiring Tests
# ============================================================

class TestExpiringCalculation:
    def test_half_remaining(self):
        end_date = datetime.now(UTC) + timedelta(days=182)
        value = compute_current_value(
            trajectory="expiring",
            purchase_price=0,
            purchase_date=None,
            config={
                "renewal_cost": 1000,
                "end_date": end_date.isoformat(),
                "total_days": 365,
            },
        )
        # ~50% remaining
        assert 450 <= value <= 550

    def test_expired_returns_zero(self):
        end_date = datetime.now(UTC) - timedelta(days=1)
        value = compute_current_value(
            trajectory="expiring",
            purchase_price=0,
            purchase_date=None,
            config={
                "renewal_cost": 1000,
                "end_date": end_date.isoformat(),
                "total_days": 365,
            },
        )
        assert value == 0


# ============================================================
# Volatile Tests
# ============================================================

class TestVolatileCalculation:
    def test_with_market_price(self):
        value = compute_current_value(
            trajectory="volatile",
            purchase_price=100,
            purchase_date=None,
            config=None,
            current_market_price=150,
            current_quantity=10,
        )
        assert value == 1500

    def test_no_market_price_returns_purchase(self):
        value = compute_current_value(
            trajectory="volatile",
            purchase_price=1000,
            purchase_date=None,
            config=None,
        )
        assert value == 1000


# ============================================================
# Appreciating Tests
# ============================================================

class TestAppreciatingCalculation:
    def test_fixed_rate_3_percent(self):
        purchase_date = datetime.now(UTC) - timedelta(days=365)  # 1 year
        value = compute_current_value(
            trajectory="appreciating",
            purchase_price=100000,
            purchase_date=purchase_date,
            config={"method": "fixed_rate", "annual_rate": 0.03},
        )
        # After 1 year: 100000 * 1.03 = 103000
        assert 102900 <= value <= 103100

    def test_manual_appraisal(self):
        value = compute_current_value(
            trajectory="appreciating",
            purchase_price=100000,
            purchase_date=None,
            config={"method": "manual", "last_appraisal_value": 120000},
        )
        assert value == 120000


# ============================================================
# Stable Tests
# ============================================================

class TestStableCalculation:
    def test_stable_returns_purchase_price(self):
        value = compute_current_value(
            trajectory="stable",
            purchase_price=5000,
            purchase_date=None,
            config=None,
        )
        assert value == 5000


# ============================================================
# Value History Tests
# ============================================================

class TestValueHistory:
    def test_depreciating_history(self):
        purchase_date = datetime.now(UTC) - timedelta(days=365)
        history = compute_value_history(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=purchase_date,
            config={"method": "straight_line", "salvage_value": 2000, "useful_life_years": 4},
            months=6,
        )
        assert len(history) > 0
        assert all("date" in h and "value" in h for h in history)

    def test_no_purchase_date_returns_empty(self):
        history = compute_value_history(
            trajectory="depreciating",
            purchase_price=10000,
            purchase_date=None,
            config={"method": "straight_line"},
            months=6,
        )
        assert history == []


# ============================================================
# Relationship Types Tests
# ============================================================

class TestRelationshipTypes:
    def test_all_10_types_defined(self):
        assert len(RELATIONSHIP_TYPES) == 10

    def test_required_types_present(self):
        required = ["component_of", "contains", "requires", "manages", "provides",
                     "protects", "funds", "secures", "accesses", "substitutes"]
        for rt in required:
            assert rt in RELATIONSHIP_TYPES

    def test_type_structure(self):
        for _key, info in RELATIONSHIP_TYPES.items():
            assert "label" in info
            assert "label_en" in info
            assert "direction" in info

    def test_chinese_labels(self):
        assert RELATIONSHIP_TYPES["protects"]["label"] == "保护"
        assert RELATIONSHIP_TYPES["manages"]["label"] == "管理"
        assert RELATIONSHIP_TYPES["substitutes"]["label"] == "替代"
