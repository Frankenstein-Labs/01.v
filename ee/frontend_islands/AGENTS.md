# Frontend Islands — Agent Instructions

This file contains rules and instructions for AI agents working within the Frontend Islands sub-project.
For architecture and context, see `BRAIN.md`. For CI details, see `README.md`.

## Isolation Constraint (CRITICAL)

Frontend Islands is an **isolated sub-project** with its own technology stack. It is NOT part of the GitLab monolith frontend.

- **Own dependency tree**: `ee/frontend_islands/yarn.lock` — NOT the root `yarn.lock`
- **Own tooling**: Vite (not webpack), Vitest (not Jest), ESLint flat config (not the monolith's ESLint)
- **NEVER** import from GitLab's `app/assets/javascripts/` or any monolith path
- **NEVER** add dependencies to the root `package.json` for FE island needs
- **NEVER** use Jest APIs (`describe`/`it`/`expect` from Jest) — use Vitest equivalents
- Output is standalone IIFE bundles consumed as `<script>` tags in the monolith

## Technology Stack

| Tool        | Version / Details                    |
|-------------|--------------------------------------|
| Vue         | 3 (Composition API, `<script setup>`) |
| TypeScript  | Strict mode                          |
| Build       | Vite 7 (library mode, IIFE output)  |
| Tests       | Vitest 4                             |
| CSS         | Tailwind CSS 4                       |
| UI          | shadcn-vue (New York style)          |
| Linting     | ESLint flat config + Prettier        |
| Package Mgr | Yarn workspaces                      |

## Project Rules

- Prefer shared configs in `packages/configs/` over per-app config duplication
- Each app MUST have these scripts in its `package.json`: `lint`, `lint:types`, `test`, `build`
- Custom elements use the `fe-island-` prefix
- Colocate tests with source: `*_spec.ts` files next to the file they test
- No cross-app imports between apps in `apps/`
- App-specific agent instructions live in each app's own `AGENTS.md` — read it when working on that app
- When modifying shared configs in `packages/configs/`, verify all apps still pass their checks

## Validation

Before reporting work as complete, run these commands from the specific app directory (`ee/frontend_islands/apps/<app>`):

```bash
yarn test
yarn lint
yarn lint:types
yarn format
```

## Development Commands

All commands assume you are in `ee/frontend_islands/` unless noted otherwise.

| Task                        | Command                                              |
|-----------------------------|------------------------------------------------------|
| Install all deps            | `yarn install`                                       |
| Dev server (specific app)   | `cd apps/<app> && yarn dev`                          |
| Test (specific app)         | `cd apps/<app> && yarn test`                         |
| Lint (specific app)         | `cd apps/<app> && yarn lint`                         |
| Type-check (specific app)   | `cd apps/<app> && yarn lint:types`                   |
| Build all apps (production) | `yarn build:prod`                                    |
| Build all apps              | `yarn build`                                         |
| Add a shadcn-vue component  | `cd apps/<app> && yarn shadcn add <component>`       |

## CI Pipeline

The CI uses a **Single Source of Truth (SSOT)** pattern: the `.fe-islands-parallel` template in `.gitlab/ci/frontend.gitlab-ci.yml` defines the `FE_APP_DIR` matrix. All parallelized jobs extend this template.

**Key jobs**:

- `compile-fe-islands` — builds all apps at once (not parallelized)
- `test-fe-islands` — runs tests per app (parallelized)
- `type-check-fe-islands` — type-checks per app (parallelized)
- `.eslint:fe-islands` — lints per app (parallelized)
- `validate-fe-islands-ci` — validates CI config matches actual apps

**CI files involved**:

- `.gitlab/ci/frontend.gitlab-ci.yml` — main jobs + `.fe-islands-parallel` template
- `.gitlab/ci/setup.gitlab-ci.yml` — validation + type-check jobs
- `.gitlab/ci/static-analysis.gitlab-ci.yml` — ESLint job
- `.gitlab/ci/caching.gitlab-ci.yml` — cache hash + node_modules jobs
- `.gitlab/ci/global.gitlab-ci.yml` — cache definitions
- `.gitlab/ci/rules.gitlab-ci.yml` — rule patterns

See `README.md` for full CI documentation, including how to extend the automation system.

## Adding a New App

1. Create `ee/frontend_islands/apps/<app_name>/` with a `package.json` containing the required scripts: `lint`, `lint:types`, `test`, `build`
1. Run `ruby scripts/update_fe_islands_ci.rb` to update CI configuration
1. Commit both your app and the updated CI file

See `README.md` for the full workflow and validation details.

## Important Files

| File                                  | Purpose                                     |
|---------------------------------------|---------------------------------------------|
| `ee/frontend_islands/package.json`    | Root workspace config                       |
| `ee/frontend_islands/yarn.lock`       | Independent lockfile (NOT the root one)     |
| `ee/frontend_islands/README.md`       | Full development guide + CI docs            |
| `ee/frontend_islands/packages/configs/` | Shared ESLint, Prettier, TS, Vite, Vitest configs |
| `scripts/build_frontend_islands`      | Build script used by CI                     |
| `scripts/install_frontend_islands`    | Dependency install script used by CI        |
| `scripts/validate_fe_islands_ci.rb`   | CI validation script                        |
| `scripts/update_fe_islands_ci.rb`     | CI update script (run when adding apps)     |
| `scripts/fe_islands_ci_shared.rb`     | Shared CI automation logic (SSOT constants) |
