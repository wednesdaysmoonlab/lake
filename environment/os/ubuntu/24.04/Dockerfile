FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Mimic a minimal Ubuntu 24.04 cloud server image (e.g. DigitalOcean, AWS EC2,
# GCP Compute Engine). Only packages that cloud providers include by default:
#   curl + ca-certificates — almost universally pre-installed on cloud images
#   git                   — commonly included; useful for cloning the repo
# Nothing else. No Node, no PHP, no Composer — lakeup must handle everything.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
