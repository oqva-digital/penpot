# Dependencies and versions

This document summarizes the main technology stack and dependency categories used in this fork of Penpot.

> For exact dependency versions, always refer to the corresponding `package.json`, `deps.edn`, `Dockerfile` and other manifest files in the repository.

## Core technologies

- **Backend**: Clojure (JVM-based).
- **Frontend**: ClojureScript + React.
- **Exporter**: Node.js + Puppeteer (headless Chromium).
- **Database**: PostgreSQL.
- **Cache/queue**: Valkey (Redis-compatible).
- **Container runtime**: Docker + Docker Compose.

## Backend dependencies

Defined primarily in:

- `backend/deps.edn` (or equivalent Clojure dependency file).
- Backend Dockerfile under `docker/`.

Typical dependency categories:

- Web framework and routing.
- Database access and migrations.
- Authentication and security.
- JSON/serialization libraries.
- Logging and metrics.

## Frontend dependencies

Defined primarily in:

- `frontend/package.json`.
- Frontend build configuration files.

Typical dependency categories:

- React and React-related libraries.
- State management and routing.
- Build tooling (e.g. Webpack, Vite, or similar).
- Testing libraries (if present).

## Exporter dependencies

Defined primarily in:

- `exporter/package.json`.
- Exporter Dockerfile under `docker/`.

Key dependencies:

- Node.js runtime.
- Puppeteer (headless Chromium).
- Supporting libraries for parsing, rendering and file handling.

## Docker and system-level dependencies

Defined in:

- Dockerfiles under `docker/`.
- `docker-compose.production.yml` and related compose files.

System-level components typically include:

- Base OS image (e.g. Debian/Ubuntu-based).
- Runtime dependencies for Clojure, Node.js and headless Chromium.
- System tools required for build and runtime.

## How to check actual versions

- **Backend**: inspect `backend/deps.edn` and backend Dockerfile.
- **Frontend**: run `cat frontend/package.json` or use `npm ls` / `yarn list`.
- **Exporter**: run `cat exporter/package.json` or `npm ls`.
- **Container images**: inspect Dockerfiles under `docker/` or use `docker inspect` on built images.

