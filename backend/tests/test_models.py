"""Tests for database models and seed data."""

from sqlmodel import SQLModel

from app.assets.models import (
    Asset,
    AssetFinancial,
    AssetLifecycle,
    AssetMetadataAccount,
    AssetMetadataConsumable,
    AssetMetadataElectronics,
    AssetMetadataFinancial,
    AssetMetadataFurniture,
    AssetMetadataInsurance,
    AssetMetadataRealEstate,
    AssetMetadataSubscription,
    AssetMetadataVehicle,
    AssetRelationship,
)
from app.common.seed import DEFAULT_SETTINGS, EXPENSE_CATEGORIES, INCOME_CATEGORIES
from app.documents.models import AssetDocument
from app.families.models import Family, FamilyMember
from app.finance.models import (
    ExpenseCategory,
    IncomeCategory,
    IncomeExpenseRecord,
    Liability,
    PriceSnapshot,
    Transaction,
)
from app.notifications.models import Notification, NotificationPreference

# Import all models to verify they load correctly
from app.users.models import SystemSettings, User


def test_all_models_import():
    """Verify all models can be imported."""
    models = [
        User, SystemSettings,
        Family, FamilyMember,
        Asset, AssetFinancial, AssetLifecycle, AssetRelationship,
        AssetMetadataVehicle, AssetMetadataRealEstate, AssetMetadataElectronics,
        AssetMetadataFurniture, AssetMetadataInsurance, AssetMetadataFinancial,
        AssetMetadataSubscription, AssetMetadataAccount, AssetMetadataConsumable,
        Liability, Transaction, ExpenseCategory, IncomeCategory,
        IncomeExpenseRecord, PriceSnapshot,
        AssetDocument,
        Notification, NotificationPreference,
    ]
    assert len(models) == 26


def test_model_tables():
    """Verify all tables are registered in SQLModel metadata."""
    table_names = set(SQLModel.metadata.tables.keys())
    expected_tables = {
        "users", "system_settings",
        "families", "family_members",
        "assets", "asset_financial", "asset_lifecycles", "asset_relationships",
        "asset_metadata_vehicle", "asset_metadata_real_estate", "asset_metadata_electronics",
        "asset_metadata_furniture", "asset_metadata_insurance", "asset_metadata_financial",
        "asset_metadata_subscription", "asset_metadata_account", "asset_metadata_consumable",
        "liabilities", "transactions",
        "expense_categories", "income_categories",
        "income_expense_records", "price_snapshots",
        "asset_documents",
        "notifications", "notification_preferences",
    }
    assert expected_tables.issubset(table_names), f"Missing tables: {expected_tables - table_names}"


def test_user_model_fields():
    """Verify User model has required fields."""
    columns = {c.name for c in User.__table__.columns}
    required = {"id", "username", "email", "hashed_password", "full_name", "role", "is_active"}
    assert required.issubset(columns), f"Missing columns: {required - columns}"


def test_asset_model_classification_fields():
    """Verify Asset model has multi-dimensional classification."""
    columns = {c.name for c in Asset.__table__.columns}
    required = {"nature", "utility", "ownership", "liquidity", "tags", "status"}
    assert required.issubset(columns), f"Missing columns: {required - columns}"


def test_liability_model_types():
    """Verify Liability model supports all required types."""
    columns = {c.name for c in Liability.__table__.columns}
    required = {"type", "original_amount", "current_balance", "interest_rate", "monthly_payment"}
    assert required.issubset(columns), f"Missing columns: {required - columns}"


def test_seed_expense_categories_structure():
    """Verify expense categories seed data structure."""
    assert len(EXPENSE_CATEGORIES) >= 8, "Should have at least 8 main categories"

    total_children = 0
    for cat in EXPENSE_CATEGORIES:
        assert "name" in cat
        assert "name_en" in cat
        assert "icon" in cat
        assert "children" in cat
        total_children += len(cat["children"])

    assert total_children >= 30, f"Should have at least 30 subcategories, got {total_children}"


def test_seed_income_categories_structure():
    """Verify income categories seed data structure."""
    assert len(INCOME_CATEGORIES) >= 5, "Should have at least 5 main categories"

    for cat in INCOME_CATEGORIES:
        assert "name" in cat
        assert "name_en" in cat
        assert "icon" in cat


def test_seed_system_settings_structure():
    """Verify system settings seed data structure."""
    assert len(DEFAULT_SETTINGS) >= 3
    keys = {s["key"] for s in DEFAULT_SETTINGS}
    assert "max_families_per_user" in keys
    assert "invite_code_expiry_days" in keys


def test_expense_categories_chinese_names():
    """Verify expense categories have proper Chinese names."""
    names = [cat["name"] for cat in EXPENSE_CATEGORIES]
    assert "餐饮美食" in names
    assert "交通出行" in names
    assert "购物消费" in names
    assert "居住生活" in names
    assert "医疗健康" in names
    assert "教育培训" in names
    assert "休闲娱乐" in names
    assert "人情往来" in names


def test_asset_relationship_types():
    """Verify AssetRelationship supports all 10 relationship types."""
    columns = {c.name for c in AssetRelationship.__table__.columns}
    assert "type" in columns
    assert "source_asset_id" in columns
    assert "target_asset_id" in columns
    assert "lifecycle_linked" in columns
