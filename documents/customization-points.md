# Customization points

This document lists common areas where this fork is expected to diverge from upstream Penpot and where customization is most likely to happen.

## 1. Configuration and environment

- `.env.local` – local environment configuration (not committed to Git).
- `env.example` – template for environment variables.
- Docker Compose files:
  - `docker-compose.production.yml`
  - Any additional `docker-compose.*.yml` overrides.

Typical customizations:

- Application URL and public endpoints.
- Database and cache settings.
- SMTP and email settings.
- Authentication and registration flags (e.g. disable registration, domain whitelists).

## 2. Authentication and registration behavior

Possible customization points:

- Enabling/disabling local registration.
- Restricting registration by email domain.
- Integrating with external identity providers (OAuth, SSO).

These are usually controlled via environment variables and backend configuration.

## 3. UI and branding

Frontend-level changes may include:

- Logo and brand colors.
- Default templates and asset libraries.
- UI copy/text specific to your organization.

Most of these changes live under `frontend/` and static asset directories.

## 4. Deployment and infrastructure

Under `docker/` and related scripts:

- Custom Dockerfiles (base images, additional tools).
- Extra services in Docker Compose (monitoring, proxies, tunnels).
- Integration with Cloudflare Tunnel or similar access layers.

## 5. Automation and workflows

GitHub Actions and other CI/CD tooling:

- `.github/workflows/sync-upstream.yml` – keeps this fork in sync with upstream and updates branches.
- Other build and test workflows – may be adjusted for this organization’s pipelines.

## 6. Access control and multi-tenant behavior

Depending on requirements, customizations might include:

- Organization/project default permissions.
- Limits and quotas (projects per user, storage, etc.), when supported.
- Additional auditing or logging.

These changes are typically implemented in the backend and configuration.

