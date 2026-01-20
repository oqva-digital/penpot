# Hot-reload for development

This document describes general guidelines for achieving a fast feedback loop (hot-reload / auto-reload) during development.

> Note: Exact commands and profiles may vary depending on how you choose to run frontend and backend (inside Docker vs. directly on the host). Adjust paths/commands to your setup.

## 1. Frontend hot-reload (ClojureScript + React)

For pure source-based development, running the frontend outside Docker usually gives the best hot-reload experience.

Typical approach:

1. Make sure backend and database are running (via Docker Compose).
2. From the `frontend/` directory, start the dev build with watch mode (example):

```bash
cd frontend
yarn install
yarn watch    # or yarn dev / npm run watch, depending on configuration
```

3. Open the application in the browser and keep the dev server running.

Changes in ClojureScript/React code should be reflected automatically without full page reload, or with minimal reload depending on the tooling.

## 2. Backend hot-reload (Clojure)

If you need fast backend iteration:

1. Keep supporting services (database, cache) running via Docker.
2. Run the backend in dev mode from source (outside Docker), for example:

```bash
cd backend
clojure -M:dev        # example profile, adapt to your setup
```

3. Use a REPL / nREPL integration in your editor (e.g. CIDER, Calva) to reload namespaces.

Backend code changes can then be reloaded without restarting the whole container stack.

## 3. Hot-reload with Docker bind mounts

If you prefer to keep everything in Docker but still want some hot-reload:

- Use volume/bind mounts so that source code changes on the host are visible in the container.
- Configure the dev command (entrypoint) in the dev Docker Compose file to use watch modes (e.g. `yarn watch`, `clojure -M:dev`, `nodemon`, etc.).

Example pattern (conceptual):

```yaml
services:
  frontend:
    volumes:
      - ./frontend:/app/frontend
    command: ["yarn", "watch"]
```

Adjust this to the actual dev compose file used in this fork.

## 4. Browser auto-reload

For frontend work, enable:

- Browser dev tools.
- Any built-in hot-reload / HMR integration provided by the frontend build tool.

This ensures that:

- CSS and component changes are visible immediately.
- JavaScript/ClojureScript changes do not require a full page reload in most cases.

