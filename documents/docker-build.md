# Custom Docker image build and validation

This document explains how to build and test the custom Docker images used by this fork.

## 1. Build all production images

From the project root:

```bash
docker compose -f docker-compose.production.yml --env-file .env.local build
```

This command builds images for:

- Backend
- Frontend
- Exporter
- Supporting services (where applicable)

> Make sure `.env.local` exists and is correctly configured before building.

## 2. Run containers using the custom images

After building:

```bash
docker compose -f docker-compose.production.yml --env-file .env.local up -d
```

Verify that all services are healthy:

```bash
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs -f
```

## 3. Smoke tests after image build

After the containers are running:

- Open the application at `http://localhost:9001`.
- Log in with a test account.
- Open an existing project and perform a small edit.
- Create a new project/file.

If everything works as expected, the new images are considered valid.

## 4. Rebuilding specific services

If only one component changed (e.g. frontend), you can rebuild only that service:

```bash
docker compose -f docker-compose.production.yml --env-file .env.local build frontend
docker compose -f docker-compose.production.yml --env-file .env.local up -d frontend
```

Replace `frontend` with `backend`, `exporter`, etc., as needed.

## 5. Cleaning up

To remove containers and networks (keep volumes):

```bash
docker compose -f docker-compose.production.yml down
```

To remove containers, networks and volumes:

```bash
docker compose -f docker-compose.production.yml down -v
```

