"""Tests for asset management system."""

import pytest

from app.assets.schemas import (
    AddTagRequest,
    AssetFilterParams,
    BulkActionRequest,
    CreateAssetRequest,
    UpdateAssetRequest,
)

# ============================================================
# Schema Tests
# ============================================================

class TestAssetSchemas:
    def test_create_asset_request_valid(self):
        data = CreateAssetRequest(
            name="2024 Toyota Camry",
            nature="tangible",
            utility="essential",
            ownership="owned",
            liquidity="low",
            purchase_price=200000,
            currency="CNY",
        )
        assert data.name == "2024 Toyota Camry"
        assert data.nature == "tangible"
        assert data.purchase_price == 200000

    def test_create_asset_request_with_tags(self):
        data = CreateAssetRequest(
            name="Tesla Model 3",
            nature="tangible",
            utility="essential",
            ownership="owned",
            liquidity="low",
            tags=["车辆", "新能源"],
        )
        assert data.tags == ["车辆", "新能源"]

    def test_create_asset_request_with_metadata(self):
        data = CreateAssetRequest(
            name="MacBook Pro",
            nature="tangible",
            utility="lifestyle",
            ownership="owned",
            liquidity="medium",
            metadata_type="electronics",
            metadata={
                "type": "laptop",
                "brand": "Apple",
                "model": "MacBook Pro 14",
                "year": 2024,
            },
        )
        assert data.metadata_type == "electronics"
        assert data.metadata["brand"] == "Apple"

    def test_create_asset_invalid_nature_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateAssetRequest(
                name="Test",
                nature="invalid",
                utility="essential",
                ownership="owned",
                liquidity="low",
            )

    def test_create_asset_invalid_utility_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateAssetRequest(
                name="Test",
                nature="tangible",
                utility="invalid",
                ownership="owned",
                liquidity="low",
            )

    def test_update_asset_request(self):
        data = UpdateAssetRequest(name="新名称", status="archived")
        assert data.name == "新名称"
        assert data.status == "archived"

    def test_asset_filter_params(self):
        filters = AssetFilterParams(
            nature="tangible",
            utility="essential",
            min_value=1000,
            max_value=500000,
        )
        assert filters.nature == "tangible"
        assert filters.page == 1
        assert filters.page_size == 20

    def test_bulk_action_request(self):
        data = BulkActionRequest(
            asset_ids=["id1", "id2", "id3"],
            action="archive",
        )
        assert len(data.asset_ids) == 3
        assert data.action == "archive"

    def test_bulk_action_with_tag(self):
        data = BulkActionRequest(
            asset_ids=["id1"],
            action="tag",
            tag="重要",
        )
        assert data.tag == "重要"

    def test_add_tag_request(self):
        data = AddTagRequest(tag="车辆")
        assert data.tag == "车辆"


# ============================================================
# Trajectory Inference Tests
# ============================================================

class TestTrajectoryInference:
    def test_financial_speculative_is_volatile(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("financial", "speculative") == "volatile"

    def test_financial_productive_is_volatile(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("financial", "productive") == "volatile"

    def test_service_is_expiring(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("service", "lifestyle") == "expiring"

    def test_protective_is_expiring(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("intangible", "protective") == "expiring"

    def test_consumable_is_consumable(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("tangible", "consumable") == "consumable"

    def test_tangible_essential_is_depreciating(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("tangible", "essential") == "depreciating"

    def test_tangible_lifestyle_is_depreciating(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("tangible", "lifestyle") == "depreciating"

    def test_tangible_productive_is_appreciating(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("tangible", "productive") == "appreciating"

    def test_digital_stable(self):
        from app.assets.service import _infer_trajectory
        assert _infer_trajectory("digital", "lifestyle") == "stable"
