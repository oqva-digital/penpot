# Post-merge validation checklist

This checklist should be used after syncing branches (`upstream → main → develop → production`) to ensure the repository and the application are in a healthy state.

## 1. Git / branches

- [ ] `main` is in sync with `upstream/main` (last commit hashes match or are ahead only by local changes you understand).
- [ ] `develop` has been updated from `main` (merge or fast-forward).
- [ ] `production` has been updated from `develop` (when a production release is intended).

## 2. CI / GitHub Actions

- [ ] All relevant workflows are green:
  - [ ] Tests workflow (`tests.yml`).
  - [ ] Build workflows (docker/build pipelines).
  - [ ] Upstream sync workflow (`sync-upstream.yml`) when applicable.
- [ ] Any failed job has been investigated and fixed or explicitly accepted.

## 3. Build verification

- [ ] Backend/build image builds successfully (e.g. `docker compose build` or equivalent).
- [ ] Frontend build (if applicable) completes without errors.
- [ ] No new warnings or errors have appeared that indicate breaking changes.

## 4. Runtime / basic application check

- [ ] Application starts correctly (e.g. `docker compose up` or deployment pipeline).
- [ ] Login works for at least one test account.
- [ ] You can open an existing project/file.
- [ ] You can edit something simple (e.g. add a shape/text) and save it.

## 5. Critical flows sanity check

- [ ] Create a new project or file.
- [ ] Duplicate an existing file or page.
- [ ] Share or collaboration features still behave as expected (if used).

## 6. Logs and errors

- [ ] Backend logs do not show new repeated errors/exceptions after basic usage.
- [ ] Browser console has no new critical JavaScript errors on core screens.

## 7. Documentation and traceability

- [ ] The commit hash that was merged to `develop` and/or `production` is recorded somewhere (e.g. release notes or internal log).
- [ ] If the update brings important behavioral changes, the corresponding documentation under `documents/` has been updated.

