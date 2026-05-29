"""Tests for finance management system."""

from datetime import UTC

import pytest

from app.finance.schemas import (
    CreateIncomeExpenseRequest,
    CreateLiabilityRequest,
    CreateTransactionRequest,
)
from app.finance.service import calculate_monthly_payment

# ============================================================
# Liability Schema Tests
# ============================================================

class TestLiabilitySchemas:
    def test_create_mortgage(self):
        data = CreateLiabilityRequest(
            name="房贷",
            type="mortgage",
            lender="招商银行",
            original_amount=1000000,
            current_balance=800000,
            interest_rate=4.5,
            monthly_payment=5066.85,
            payment_day=15,
        )
        assert data.type == "mortgage"
        assert data.original_amount == 1000000

    def test_create_auto_loan(self):
        data = CreateLiabilityRequest(
            name="车贷",
            type="auto_loan",
            original_amount=150000,
            current_balance=120000,
            interest_rate=3.5,
        )
        assert data.type == "auto_loan"

    def test_create_credit_card(self):
        data = CreateLiabilityRequest(
            name="招商银行信用卡",
            type="credit_card",
            original_amount=50000,
            current_balance=15000,
        )
        assert data.type == "credit_card"

    def test_invalid_type_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateLiabilityRequest(
                name="Test",
                type="invalid_type",
                original_amount=10000,
                current_balance=10000,
            )

    def test_negative_amount_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateLiabilityRequest(
                name="Test",
                type="mortgage",
                original_amount=-1000,
                current_balance=0,
            )


# ============================================================
# Income/Expense Schema Tests
# ============================================================

class TestIncomeExpenseSchemas:
    def test_create_expense(self):
        from datetime import datetime
        data = CreateIncomeExpenseRequest(
            type="expense",
            category_id="cat-123",
            amount=156.78,
            date=datetime.now(UTC),
            description="超市购物",
        )
        assert data.type == "expense"
        assert data.amount == 156.78

    def test_create_income(self):
        from datetime import datetime
        data = CreateIncomeExpenseRequest(
            type="income",
            amount=15000,
            date=datetime.now(UTC),
            description="工资",
        )
        assert data.type == "income"

    def test_invalid_type_fails(self):
        from datetime import datetime

        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateIncomeExpenseRequest(
                type="invalid",
                amount=100,
                date=datetime.now(UTC),
            )

    def test_zero_amount_fails(self):
        from datetime import datetime

        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateIncomeExpenseRequest(
                type="expense",
                amount=0,
                date=datetime.now(UTC),
            )


# ============================================================
# Transaction Schema Tests
# ============================================================

class TestTransactionSchemas:
    def test_create_buy_transaction(self):
        from datetime import datetime
        data = CreateTransactionRequest(
            asset_id="asset-123",
            type="buy",
            quantity=100,
            price=1888,
            total=188800,
            fees=5,
            date=datetime.now(UTC),
        )
        assert data.type == "buy"
        assert data.quantity == 100

    def test_create_sell_transaction(self):
        from datetime import datetime
        data = CreateTransactionRequest(
            asset_id="asset-123",
            type="sell",
            quantity=50,
            price=2000,
            total=100000,
            fees=5,
            date=datetime.now(UTC),
        )
        assert data.type == "sell"

    def test_create_dividend_transaction(self):
        from datetime import datetime
        data = CreateTransactionRequest(
            asset_id="asset-123",
            type="dividend",
            total=500,
            date=datetime.now(UTC),
        )
        assert data.type == "dividend"

    def test_invalid_type_fails(self):
        from datetime import datetime

        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateTransactionRequest(
                asset_id="asset-123",
                type="invalid",
                total=100,
                date=datetime.now(UTC),
            )


# ============================================================
# Monthly Payment Calculation Tests
# ============================================================

class TestMonthlyPaymentCalculation:
    def test_equal_installment_basic(self):
        """100万贷款，4.5%利率，30年(360期)等额本息"""
        monthly = calculate_monthly_payment(
            principal=1000000,
            annual_rate=4.5,
            months=360,
            method="equal_installment",
        )
        # 标准计算结果约 5066.85
        assert 5060 <= monthly <= 5075

    def test_equal_installment_short_term(self):
        """10万贷款，3.5%利率，3年(36期)"""
        monthly = calculate_monthly_payment(
            principal=100000,
            annual_rate=3.5,
            months=36,
            method="equal_installment",
        )
        # 约 2935
        assert 2930 <= monthly <= 2940

    def test_equal_installment_zero_rate(self):
        """0利率贷款"""
        monthly = calculate_monthly_payment(
            principal=120000,
            annual_rate=0,
            months=12,
        )
        assert monthly == 10000

    def test_equal_principal_first_month(self):
        """等额本金首月还款最高"""
        monthly = calculate_monthly_payment(
            principal=1000000,
            annual_rate=4.5,
            months=360,
            method="equal_principal",
        )
        # 首月: 本金2777.78 + 利息3750 = 6527.78
        assert 6520 <= monthly <= 6535


# ============================================================
# Integration Tests
# ============================================================

@pytest.mark.asyncio
class TestLiabilityIntegration:
    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "finuser", "email": "fin@example.com",
            "password": "TestPass123", "full_name": "Finance User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "finuser", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "财务家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]
        return headers, family_id

    async def test_create_and_list_liabilities(self, client):
        headers, family_id = await self._setup(client)

        # Create mortgage
        resp = await client.post(f"/api/families/{family_id}/finance/liabilities", json={
            "name": "房贷",
            "type": "mortgage",
            "lender": "招商银行",
            "original_amount": 1000000,
            "current_balance": 800000,
            "interest_rate": 4.5,
            "monthly_payment": 5066.85,
        }, headers=headers)
        assert resp.status_code == 201
        assert resp.json()["data"]["type"] == "mortgage"

        # Create credit card
        resp = await client.post(f"/api/families/{family_id}/finance/liabilities", json={
            "name": "信用卡",
            "type": "credit_card",
            "original_amount": 50000,
            "current_balance": 15000,
        }, headers=headers)
        assert resp.status_code == 201

        # List
        list_resp = await client.get(
            f"/api/families/{family_id}/finance/liabilities",
            headers=headers,
        )
        assert list_resp.status_code == 200
        data = list_resp.json()["data"]
        assert data["total"] == 2
        assert data["total_balance"] == 815000


@pytest.mark.asyncio
class TestIncomeExpenseIntegration:
    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "ieuser", "email": "ie@example.com",
            "password": "TestPass123", "full_name": "IE User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "ieuser", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "收支家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]
        return headers, family_id

    async def test_record_income_and_expense(self, client):
        headers, family_id = await self._setup(client)

        # Record income
        resp = await client.post(f"/api/families/{family_id}/finance/income-expense", json={
            "type": "income",
            "amount": 15000,
            "date": "2026-05-01T00:00:00",
            "description": "工资",
        }, headers=headers)
        assert resp.status_code == 201

        # Record expenses
        for amount, desc in [(3500, "房租"), (1500, "餐饮"), (500, "交通")]:
            resp = await client.post(f"/api/families/{family_id}/finance/income-expense", json={
                "type": "expense",
                "amount": amount,
                "date": "2026-05-15T00:00:00",
                "description": desc,
            }, headers=headers)
            assert resp.status_code == 201

        # Get summary
        summary_resp = await client.get(
            f"/api/families/{family_id}/finance/income-expense/summary",
            headers=headers,
        )
        assert summary_resp.status_code == 200
        summary = summary_resp.json()["data"]
        assert summary["total_income"] == 15000
        assert summary["total_expense"] == 5500
        assert summary["net"] == 9500
        assert summary["savings_rate"] > 0.6

    async def test_get_categories(self, client):
        headers, family_id = await self._setup(client)

        # Expense categories (empty in test DB since seed not run)
        resp = await client.get(
            f"/api/families/{family_id}/finance/categories/expense",
            headers=headers,
        )
        assert resp.status_code == 200
        # In test env with SQLite, categories may be empty since seed wasn't run
        assert isinstance(resp.json()["data"], list)

        # Income categories
        resp = await client.get(
            f"/api/families/{family_id}/finance/categories/income",
            headers=headers,
        )
        assert resp.status_code == 200
        assert isinstance(resp.json()["data"], list)


@pytest.mark.asyncio
class TestTransactionIntegration:
    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "txuser", "email": "tx@example.com",
            "password": "TestPass123", "full_name": "TX User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "txuser", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "投资家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]

        # Create a financial asset
        asset_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "贵州茅台",
            "nature": "financial",
            "utility": "speculative",
            "ownership": "custodied",
            "liquidity": "high",
            "purchase_price": 188800,
        }, headers=headers)
        asset_id = asset_resp.json()["data"]["id"]

        return headers, family_id, asset_id

    async def test_buy_sell_cost_basis(self, client):
        headers, family_id, asset_id = await self._setup(client)

        # Buy 100 shares at 1888
        resp = await client.post(f"/api/families/{family_id}/finance/transactions", json={
            "asset_id": asset_id,
            "type": "buy",
            "quantity": 100,
            "price": 1888,
            "total": 188800,
            "fees": 5,
            "date": "2026-01-15T00:00:00",
        }, headers=headers)
        assert resp.status_code == 201

        # Buy 50 more at 1900
        resp = await client.post(f"/api/families/{family_id}/finance/transactions", json={
            "asset_id": asset_id,
            "type": "buy",
            "quantity": 50,
            "price": 1900,
            "total": 95000,
            "fees": 5,
            "date": "2026-03-15T00:00:00",
        }, headers=headers)
        assert resp.status_code == 201

        # Get cost basis (average cost)
        cb_resp = await client.get(
            f"/api/families/{family_id}/finance/cost-basis/{asset_id}?method=average_cost",
            headers=headers,
        )
        assert cb_resp.status_code == 200
        cb = cb_resp.json()["data"]
        assert cb["total_shares"] == 150
        assert cb["average_cost"] > 1888  # Should be between 1888 and 1900

        # Sell 50 shares
        resp = await client.post(f"/api/families/{family_id}/finance/transactions", json={
            "asset_id": asset_id,
            "type": "sell",
            "quantity": 50,
            "price": 2000,
            "total": 100000,
            "fees": 5,
            "date": "2026-05-15T00:00:00",
        }, headers=headers)
        assert resp.status_code == 201

        # Cost basis after sell
        cb_resp = await client.get(
            f"/api/families/{family_id}/finance/cost-basis/{asset_id}?method=fifo",
            headers=headers,
        )
        cb = cb_resp.json()["data"]
        assert cb["total_shares"] == 100  # 150 - 50
