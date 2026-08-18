# Frontend Islands — Codebase Brain

> An isolated Yarn workspaces monorepo inside the GitLab monolith for standalone frontend Web Components (custom elements) that embed in GitLab pages as `<script>` tags.

## Quick Facts

| Key            | Value                                                        |
|----------------|--------------------------------------------------------------|
| Language       | TypeScript + Vue 3 SFCs                                      |
| Runtime        | Browser (Web Components / Custom Elements, Shadow DOM)       |
| Package Mgr    | Yarn workspaces (own `yarn.lock` — NOT the monolith's)       |
| Build tool     | Vite 7 (library mode, IIFE output)                           |
| Test runner    | Vitest 4                                                     |
| CSS            | Tailwind CSS 4                                               |
| UI library     | shadcn-vue (New York style) + reka-ui                        |
| Linting        | ESLint flat config + Prettier                                |
| Location       | `ee/frontend_islands/` inside the GitLab git repo            |

## Architecture Overview

```text
GitLab Monolith (Rails + HAML)
        │
        │  <script src="dist/main.js">  ← IIFE bundle
        ▼
<fe-island-{name}>   ← Web Component (Shadow DOM)
        │
        │  HTML attribute props + DOM events
        ▼
CommunicationLayer.vue   ← Host/app boundary
        │
        │  useCommunicationBridge()
        ▼
App.vue  ← Application root, standard Vue props/emits
        │
        ▼
  src/components/…
```

Each island is fully self-contained. No shared global state with the host.
Tailwind CSS is injected inline into the Shadow DOM via `style.css?inline`.

## Directory Structure

```text
ee/frontend_islands/
├── package.json               # Yarn workspace root (workspaces: apps/*, packages/configs/*)
├── yarn.lock                  # Independent lockfile — NOT the monolith root yarn.lock
├── AGENTS.md                  # Agent rules and CI documentation
├── README.md                  # Full development guide + CI docs
├── apps/
│   └── duo_next/              # Duo Agentic Platform UI island
│       ├── src/
│       │   ├── main.ts        # Entry: registers <fe-island-duo-next> custom element
│       │   ├── CommunicationLayer.vue  # Host/app boundary component
│       │   ├── App.vue        # Application root
│       │   ├── types.ts       # ChatModel, ChatEvents, HostDataProps
│       │   ├── style.css      # Tailwind base (injected into Shadow DOM)
│       │   ├── components/    # Feature UI components (shadcn-vue + custom)
│       │   ├── composables/
│       │   │   └── useCommunicationBridge.ts  # Generic host↔app bridge
│       │   └── lib/utils.ts   # cn() helper (clsx + tailwind-merge)
│       ├── vite.config.ts     # Uses defineLibraryConfig()
│       ├── vitest.config.ts   # Uses defineTestConfig()
│       ├── components.json    # shadcn-vue CLI config
│       └── BRAIN.md           # App-specific detailed brain
└── packages/configs/
    ├── eslint/                # @frontend-islands/eslint-config
    ├── prettier/              # @frontend-islands/prettier-config
    ├── tsconfig/              # @frontend-islands/tsconfig
    ├── vite-config/           # @frontend-islands/vite-config (defineLibraryConfig)
    └── vitest-config/         # @frontend-islands/vitest-config (defineTestConfig)
```

## CLI Commands & Usage

All commands run from `ee/frontend_islands/` unless noted.

| Task                          | Command                                          |
|-------------------------------|--------------------------------------------------|
| Install all deps              | `yarn install`                                   |
| Build all apps                | `yarn build`                                     |
| Build all apps (production)   | `yarn build:prod`                                |
| Type-check all apps           | `yarn lint:types`                                |
| Dev server (specific app)     | `cd apps/<app> && yarn dev`                      |
| Test (specific app)           | `cd apps/<app> && yarn test`                     |
| Test watch (specific app)     | `cd apps/<app> && yarn test:watch`               |
| Lint (specific app)           | `cd apps/<app> && yarn lint`                     |
| Type-check (specific app)     | `cd apps/<app> && yarn lint:types`               |
| Format check (specific app)   | `cd apps/<app> && yarn format`                   |
| Add shadcn-vue component      | `cd apps/<app> && yarn shadcn add <component>`   |
| Update CI after adding app    | `ruby scripts/update_fe_islands_ci.rb`           |

## Key Abstractions / Modules

### `packages/configs/vite-config` — `defineLibraryConfig(options)`

The shared Vite factory for all islands. Hardcoded constraints:

- Output format: **IIFE** (single `dist/main.js` file, inline dynamic imports)
- Vue plugin: `customElement: true`, recognizes `fe-island-*` tags
- Build target: ES2020
- PostCSS isolation: empty `postcss: {}` to prevent root config leakage
- Optional Tailwind v4 integration via dynamic import of `@tailwindcss/vite`
- Optional path aliases (`@` → `./src`)

### `packages/configs/vitest-config` — `defineTestConfig()`

Shared Vitest config factory. Used by each app's `vitest.config.ts`.

### `apps/duo_next/src/composables/useCommunicationBridge.ts`

Generic, reusable bridge composable parameterized by `TEvents` and `TProps`.

- Forwards props reactively (with optional exclusion list)
- Creates type-safe DOM event handlers
- Optionally wires Vue DI (`provide`) for services
- Returns `{ forwardedProps: ComputedRef, eventListeners }`

### `apps/duo_next/src/types.ts` — Shared Types

- `ChatModel` — `{ text: string; value: string }` — AI model descriptor
- `ChatEvents` — 10-entry DOM event map (thread-selected, new-chat, change-model, etc.)
- `HostDataProps` — Props from GitLab host (`models`, `avatarUrl`, `userName`)

## Configuration System

| Config        | File / Package                        | Notes                                                |
|---------------|---------------------------------------|------------------------------------------------------|
| Build         | `vite.config.ts` (per app)            | Calls `defineLibraryConfig` from `@frontend-islands/vite-config` |
| Tests         | `vitest.config.ts` (per app)          | Calls `defineTestConfig` from `@frontend-islands/vitest-config` |
| TypeScript    | `tsconfig.json` (per app)             | Extends `@frontend-islands/tsconfig`; separate app/node/spec tsconfigs |
| Linting       | `eslint.config.js` (per app)          | Uses `@frontend-islands/eslint-config` (flat config) |
| Prettier      | `package.json#prettier` (per app)     | References `@frontend-islands/prettier-config`       |
| shadcn-vue    | `components.json` (per app)           | Style: new-york, baseColor: neutral, cssVariables    |
| Path alias    | `@` → `src/`                          | Set in both vite config and tsconfig                 |

## Key Design Patterns

1. **Web Component / Frontend Island**: The entire app is a Shadow DOM custom element (`<fe-island-{name}>`). Props arrive as HTML attributes; events leave as DOM events. No shared global state.
1. **Communication Layer Pattern**: `CommunicationLayer.vue` is a dedicated boundary component — the only component aware of Web Component mechanics. Inner `App.vue` uses standard Vue props/emits, knowing nothing about custom elements.
1. **Generic `useCommunicationBridge`**: Parameterized by `TEvents` and `TProps` generics. One composable handles all prop forwarding and event creation. Reusable across future islands with different shapes.
1. **Inline Style Injection for Shadow DOM**: Tailwind CSS is imported as `style.css?inline` and passed to `defineCustomElement({ styles: [tailwind] })`, bypassing the Shadow DOM's style isolation.
1. **IIFE-only output**: Every island produces a single `dist/main.js` IIFE. No ES module exports. The monolith includes it via a plain `<script>` tag.
1. **Shared configs via workspace packages**: All per-app configs are thin wrappers calling factory functions from `packages/configs/*`. New apps get consistent behavior with minimal boilerplate.
1. **Custom element prefix `fe-island-`**: All registered Web Components use this prefix (enforced in Vite plugin config's `isCustomElement` check).

## Testing

- **Runner**: Vitest 4 + `@vue/test-utils` + jsdom
- **Spec files**: Co-located with source (`*_spec.ts`)
- **Coverage**: V8 provider via `@vitest/coverage-v8`
- **Style**: Behavior-first; test rendered output and emitted events, not internals

```bash
# From apps/<app>/
yarn test              # single run
yarn test:watch        # watch mode
yarn test:coverage     # with coverage report
yarn test:ui           # browser UI
```

## CI Pipeline

Uses a **Single Source of Truth (SSOT)** pattern: the `.fe-islands-parallel` template in `.gitlab/ci/frontend.gitlab-ci.yml` defines the `FE_APP_DIR` matrix. All parallelized jobs extend this template.

| CI Job                   | What it does                                          |
|--------------------------|-------------------------------------------------------|
| `compile-fe-islands`     | Builds ALL apps at once (not parallelized)            |
| `test-fe-islands`        | Runs `yarn test` per app (parallelized via matrix)    |
| `type-check-fe-islands`  | Runs `yarn lint:types` per app (parallelized)         |
| `.eslint:fe-islands`     | Runs `yarn lint` per app (parallelized)               |
| `validate-fe-islands-ci` | Validates CI config matches actual apps in `apps/`    |

**Key CI files**: `.gitlab/ci/frontend.gitlab-ci.yml`, `setup.gitlab-ci.yml`, `static-analysis.gitlab-ci.yml`, `caching.gitlab-ci.yml`

## Adding a New App

1. Create `apps/<app_name>/` with a `package.json` including scripts: `lint`, `lint:types`, `test`, `build`, `build:prod`
1. Use `@frontend-islands/vite-config`, `@frontend-islands/vitest-config`, etc. as devDependencies
1. Implement `src/main.ts` registering a `<fe-island-{name}>` custom element via `defineCustomElement`
1. Create an `AGENTS.md` and `BRAIN.md` in the app directory
1. Run `ruby scripts/update_fe_islands_ci.rb` to update CI configuration
1. Commit both the app and the updated CI file

## Extending duo_next

See `apps/duo_next/BRAIN.md` for detailed extension instructions (new props, events, components, composables).
