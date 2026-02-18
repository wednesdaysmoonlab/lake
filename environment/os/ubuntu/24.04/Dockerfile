FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies that lakeup requires or benefits from:
#   curl  — required: downloads FrankenPHP and composer.phar
#   ca-certificates — required for HTTPS downloads via curl
#   nodejs / npm — optional: needed by Vite (Laravel dev server)
#   git   — useful for testing git-adjacent behaviour in lakeup (purge/clean keep .git)
#   libcap2-bin — lets FrankenPHP bind to ports < 1024 without root (optional)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        nodejs \
        npm \
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Default to a long-running shell so `docker compose up` keeps the container
# alive and you can exec into it, or override CMD for automated test runs.
CMD ["bash"]
