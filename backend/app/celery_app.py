"""Celery application configuration."""

from celery import Celery
from celery.schedules import crontab

from app.config import get_settings

settings = get_settings()

# Create Celery app
celery_app = Celery(
    "family_fire",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.tasks.price_update"],
)

# Celery configuration
celery_app.conf.update(
    # Timezone
    timezone="Asia/Shanghai",
    enable_utc=True,

    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Result settings
    result_expires=3600,  # 1 hour

    # Worker settings
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

# Scheduled tasks
celery_app.conf.beat_schedule = {
    # 每天15:05更新股票、基金收盘价(A股15:00收盘)
    "update-prices-daily": {
        "task": "app.tasks.price_update.update_all_prices",
        "schedule": crontab(hour=15, minute=5),
    },
}
