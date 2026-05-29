# Gunicorn production configuration

# Workers
workers = 4
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000

# Binding
bind = "0.0.0.0:8000"

# Timeouts
timeout = 120
graceful_timeout = 30
keepalive = 5

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Security
limit_request_line = 8190
limit_request_fields = 100
limit_request_field_size = 8190

# Server mechanics
max_requests = 1000
max_requests_jitter = 50
preload_app = True
