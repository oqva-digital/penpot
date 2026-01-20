# Local development from source

This document describes how to run Penpot locally from the source code in this fork, primarily for development and debugging.

## Prerequisites

Make sure you have:

- Docker and Docker Compose installed and running.
- Git installed.
- Python 3 installed (for helper scripts).

> For more detailed installation prerequisites, see `documents/setup.md` and `QUICKSTART.md`.

## 1. Clone the repository

```bash
git clone https://github.com/YOUR-ORG/penpot.git
cd penpot
```

Replace `YOUR-ORG` with the actual organization or user name of this fork.

## 2. Create and configure the local environment file

```bash
cp env.example .env.local
```

Adjust the values in `.env.local` as needed (database passwords, external URLs, SMTP, etc.).  
The file `.env.local` is **ignored by Git** and must not be committed.

If you want to auto-generate secure secrets:

```bash
python scripts/generate-secrets.sh .env.local
```

## 3. Start services for development

For most development scenarios this fork uses Docker Compose:

```bash
docker compose -f docker-compose.production.yml --env-file .env.local up -d
```

This will start:

- PostgreSQL
- Valkey (Redis-compatible)
- Backend
- Frontend
- Exporter

Access the application at:

- `http://localhost:9001`

## 4. Rebuilding images when code changes

When you change backend/frontend/exporter code and need a fresh image:

```bash
docker compose -f docker-compose.production.yml --env-file .env.local build
docker compose -f docker-compose.production.yml --env-file .env.local up -d
```

For more details on custom image builds, see `documents/docker-build.md`.

## 5. Stopping and cleaning up

To stop all services:

```bash
docker compose -f docker-compose.production.yml down
```

To remove all containers, networks and volumes (use with care):

```bash
docker compose -f docker-compose.production.yml down -v
```

