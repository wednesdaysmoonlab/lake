# Ubuntu 24.04 Test Server

A bare Ubuntu 24.04 container that simulates a fresh cloud server (DigitalOcean, AWS EC2, GCP Compute Engine, etc.) for testing `lakeup`.

The image only includes `curl`, `ca-certificates`, and `git` — matching what cloud providers ship by default. No PHP, no Node, no Composer. `lakeup` must provision everything itself.

---

## Usage

### 1. Start the container

```bash
cd environment/os/ubuntu/24.04
docker compose up -d --build
```

### 2. Shell into it

```bash
docker compose exec lake-ubuntu-24.04 bash
```

You are now in a shell that behaves like an SSH session into a fresh cloud server.

### 3. Run lakeup

Inside the container, create an empty directory and install:

```bash
mkdir myapp && cd myapp
curl -fsSL https://raw.githubusercontent.com/wednesdaysmoonlab/lake/main/lakeup | bash
```

---

## Testing a local / unreleased version of lakeup

The curl URL above pulls from `main`. If you want to test changes before they are merged, use one of the following options.

### Option A — Copy the script into the container

From your host machine (outside the container):

```bash
docker compose cp ../../../../lakeup lake-ubuntu-24.04:/workspace/lakeup
```

Then inside the container:

```bash
cd /workspace
chmod +x lakeup
./lakeup
```

### Option B — Curl from a feature branch

```bash
curl -fsSL https://raw.githubusercontent.com/wednesdaysmoonlab/lake/<branch-name>/lakeup | bash
```

Replace `<branch-name>` with the branch you want to test.

---

## Stop / clean up

```bash
# Stop the container
docker compose down

# Remove the image as well
docker compose down --rmi local
```
