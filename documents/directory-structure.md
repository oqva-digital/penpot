# Directory structure overview

This document summarizes the main directories in this fork of Penpot and their purposes.

## Top-level structure

- `frontend/` – ClojureScript + React codebase for the web UI.
- `backend/` – Clojure backend services (REST API, business logic, persistence).
- `exporter/` – Node.js + Puppeteer service used for exports (PDF, PNG, etc.).
- `docker/` – Dockerfiles and Docker Compose-related assets.
- `documents/` – Local documentation specific to this fork (setup, conventions, checklists).
- `scripts/` – Helper scripts for setup, maintenance and automation.
- `library/` – Shared code and assets used by multiple components.
- `render-wasm/` – WebAssembly rendering components (if enabled).

## Frontend (`frontend/`)

Main responsibilities:

- UI components (React).
- Application state management.
- Communication with the backend API.
- Asset loading (icons, fonts, translations).

Common subdirectories (may vary with upstream changes):

- `src/` – main application source code.
- `resources/public/` – static assets served to the browser.
- `test/` – frontend tests (if available).

## Backend (`backend/`)

Main responsibilities:

- HTTP API endpoints.
- Authentication and authorization.
- Persistence (database ORM/queries).
- Business logic and background jobs.

Common subdirectories:

- `src/` – Clojure source code.
- `resources/` – configuration, migrations and static resources.
- `test/` – backend tests.

## Exporter (`exporter/`)

Main responsibilities:

- Handling export requests from the backend.
- Rendering designs using headless Chromium via Puppeteer.
- Returning generated assets (PDF, PNG, etc.) to the backend.

Typically includes:

- Node.js application code.
- Puppeteer configuration.

## Docker (`docker/`)

Main responsibilities:

- Dockerfiles for building images (backend, frontend, exporter, etc.).
- Docker Compose files and environment-specific overrides (where applicable).
- Scripts or helper files used during container build.

This folder is the main place to look at when customizing how images are built and how services are orchestrated.

