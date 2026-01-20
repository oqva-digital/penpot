# Customization Guide - Penpot Self-Hosted

This guide describes how to make customizations to the Penpot source code while maintaining the ability to synchronize with the upstream repository.

## Customization Strategy

### Principles

1. **Isolate Customizations**: Whenever possible, create new files instead of modifying existing ones
2. **Use Feature Flags**: Implement customizations behind configurable flags
3. **Document Changes**: Maintain a CHANGELOG of modifications
4. **Test Before Merge**: Always test in staging before production
5. **Granular Commits**: Small, well-described commits facilitate conflict resolution

### Branch Structure

```
main          → Mirror of upstream (never commit directly)
  │
  ├─ develop  → Our customizations + upstream
  │
  └─ production → Stable version for deploy
```

## Customization Points

### 1. Frontend (UI and Themes)

**Location**: `frontend/src/`

#### Customize Colors and Themes

1. **Create custom theme**:
   ```bash
   mkdir -p frontend/src/styles/themes/custom
   ```

2. **Main files**:
   - `frontend/src/styles/themes/custom/_colors.scss` - Color palette
   - `frontend/src/styles/themes/custom/_variables.scss` - SCSS variables
   - `frontend/src/styles/themes/custom/_theme.scss` - Complete theme

3. **Apply theme**:
   Edit `frontend/src/styles/main.scss` to import your custom theme

#### Customize Components

**Location**: `frontend/src/app/main/ui/`

- React/ClojureScript components are in `frontend/src/app/main/ui/`
- To modify an existing component, create a custom copy:
  ```bash
  cp frontend/src/app/main/ui/components/button.cljs \
     frontend/src/app/main/ui/components/custom/button.cljs
  ```

#### Customize Logos and Assets

**Location**: `frontend/resources/`

- Logos: `frontend/resources/images/logo/`
- Icons: `frontend/resources/images/icons/`
- Replace files keeping the same names

### 2. Backend (API and Logic)

**Location**: `backend/src/`

#### Add New API Routes

1. Create new namespace in `backend/src/app/rpc/`:
   ```clojure
   (ns app.rpc.custom-handlers
     (:require [app.common.spec :as sp]
               [app.rpc :as rpc]))
   
   (rpc/defhandler custom-endpoint
     {:auth false}
     [cfg {:keys [param1 param2]}]
     {:result "custom response"})
   ```

2. Register in `backend/src/app/rpc/routes.clj`

#### Modify Business Logic

- RPC handlers: `backend/src/app/rpc/`
- Database queries: `backend/src/app/db/`
- Services: `backend/src/app/services/`

**Tip**: Create wrappers instead of modifying directly:

```clojure
;; Instead of modifying app.services.projects/get-projects
;; Create app.services.projects.custom/get-projects-custom
```

### 3. Configuration and Flags

**Location**: Environment variables in `.env.local`

#### Add New Feature Flag

1. **Backend**: Add the flag in `backend/src/app/config.clj`:
   ```clojure
   (def flag-schema
     {:custom-feature {:type :boolean
                       :default false}})
   ```

2. **Frontend**: Use the flag in `frontend/src/app/config.cljs`:
   ```clojure
   (def config
     {:custom-feature (get-in flags [:custom-feature])})
   ```

3. **Activate**: Add `enable-custom-feature` to `PENPOT_FLAGS` in `.env.local`

### 4. Custom Authentication

**Location**: `backend/src/app/auth/`

#### Add Custom OAuth Provider

1. Create new handler in `backend/src/app/auth/oauth/`:
   ```clojure
   (ns app.auth.oauth.custom
     (:require [app.auth.oauth :as oauth]))
   
   (defmethod oauth/get-token :custom
     [cfg provider params]
     ;; Custom implementation
     )
   ```

2. Register in the authentication system

#### Custom LDAP/OIDC Integration

- LDAP: `backend/src/app/auth/ldap.clj`
- OIDC: `backend/src/app/auth/oidc.clj`
- Create custom versions if needed

## Best Practices

### 1. Directory Structure for Customizations

Create an organized structure:

```
customizations/
├── frontend/
│   ├── themes/
│   │   └── custom-theme/
│   ├── components/
│   │   └── custom-button.cljs
│   └── styles/
│       └── custom.scss
├── backend/
│   ├── handlers/
│   │   └── custom-rpc.clj
│   └── services/
│       └── custom-service.clj
└── assets/
    ├── logos/
    └── icons/
```

### 2. Use Patches Instead of Direct Modifications

For small changes, use patches:

```bash
# Create patch
git diff upstream/main -- frontend/src/app/main/ui/components/header.cljs > customizations/patches/header-custom.patch

# Apply patch
git apply customizations/patches/header-custom.patch
```

### 3. Document Customizations

Maintain a `CUSTOMIZATIONS.md` file in the root:

```markdown
# Applied Customizations

## Frontend
- Custom theme: `customizations/frontend/themes/custom-theme/`
- Custom logo: `frontend/resources/images/logo/custom-logo.svg`

## Backend
- Custom handler: `backend/src/app/rpc/custom-handlers.clj`
- Feature flag: `enable-custom-feature`
```

### 4. Test Customizations

```bash
# Development environment
./manage.sh start-devenv
./manage.sh run-devenv

# Inside container
# Test frontend
cd frontend && yarn test

# Test backend
cd backend && lein test
```

## Customization Workflow

### 1. Create Feature Branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-customization
```

### 2. Develop Customization

```bash
# Make changes
# Test locally
./manage.sh start-devenv
./manage.sh run-devenv
```

### 3. Commit Changes

```bash
git add customizations/
git commit -m "feat: add custom theme"
```

### 4. Merge to Develop

```bash
git checkout develop
git merge feature/my-customization
```

### 5. Test in Staging

```bash
# Build and deploy in staging environment
./scripts/build-images.sh
# Deploy...
```

### 6. Merge to Production

```bash
git checkout production
git merge develop
# Build and deploy in production
```

## Resolving Conflicts with Upstream

### When to Merge from Upstream

```bash
# 1. Sync upstream
./scripts/update-from-upstream.sh

# 2. If there are conflicts, resolve manually
git status  # View conflicted files

# 3. For each conflicted file:
#    - If it's a file you customized: keep your version
#    - If it's a file you didn't touch: accept upstream version
#    - If both modified: resolve manually

# 4. Test after resolving conflicts
./scripts/setup.sh --skip-build
```

### Strategies to Minimize Conflicts

1. **Avoid Modifying Core Files**: Use extensions and wrappers
2. **Keep Customizations Isolated**: Use separate directories
3. **Use Feature Flags**: Makes it easy to disable customizations if needed
4. **Focused Commits**: One commit = one customization
5. **Document Dependencies**: Note which upstream files you depend on

## Common Customization Examples

### Example 1: Custom Theme

```scss
// customizations/frontend/themes/custom/_colors.scss
$primary-color: #FF5733;
$secondary-color: #33FF57;
$background-color: #F5F5F5;
```

### Example 2: Custom RPC Handler

```clojure
;; customizations/backend/handlers/custom.clj
(ns app.rpc.custom-handlers
  (:require [app.rpc :as rpc]))

(rpc/defhandler get-custom-data
  {:auth true}
  [cfg params]
  {:custom-data "custom data"})
```

### Example 3: Custom React Component

```clojure
;; customizations/frontend/components/custom-widget.cljs
(ns app.main.ui.custom-widget
  (:require [rumext.alpha :as mf]))

(mf/defc custom-widget
  [{:keys [data]}]
  [:div.custom-widget
   [:h2 "Custom Widget"]
   [:p data]])
```

## Customization Checklist

Before making a customization:

- [ ] Check if there's already a native way to do this
- [ ] Document the need for customization
- [ ] Create feature branch
- [ ] Implement in isolation
- [ ] Test locally
- [ ] Document in CUSTOMIZATIONS.md
- [ ] Commit with descriptive message
- [ ] Test merge with upstream before production

## Additional Resources

- [Penpot Technical Documentation](https://help.penpot.app/technical-guide/)
- [Penpot Architecture](https://help.penpot.app/technical-guide/developer/architecture/)
- [Contribution Guide](https://help.penpot.app/contributing-guide/)
