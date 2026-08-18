# duo-next — Codebase Brain

> A Frontend Island Web Component for the Duo Agentic Platform UI (GitLab Duo Next), built as a custom element that embeds in the GitLab monolith.

## Quick Facts

| Key            | Value                                                |
|----------------|------------------------------------------------------|
| Language       | TypeScript + Vue 3 SFCs                              |
| Runtime        | Browser (Web Components / Custom Elements)           |
| Entry point    | `src/main.ts`                                        |
| Custom element | `<fe-island-duo-next>`                               |
| Build tool     | Vite 7 (`@frontend-islands/vite-config`)             |
| Test runner    | Vitest 4 (`@frontend-islands/vitest-config`)         |
| UI library     | shadcn-vue (New York style) + Tailwind CSS v4        |
| Icons          | lucide-vue-next                                      |
| Headless UI    | reka-ui                                              |
| Styling utils  | clsx + tailwind-merge (`cn()` helper)                |

## Architecture Overview

```text
Host Page (GitLab monolith)
        │
        │  HTML attribute props + DOM events
        ▼
<fe-island-duo-next>  ← Web Component (Shadow DOM)
        │
        ▼
CommunicationLayer.vue  ← Props/events boundary between host and app
        │
        │  useCommunicationBridge()
        │  - forwards props (reactive, filtered)
        │  - creates type-safe event listeners
        │  - optional DI via provide()
        ▼
App.vue  ← Application root, receives forwarded props
        │
        ▼
  components/…  ← Feature UI components
```

The Shadow DOM boundary ensures style isolation; Tailwind CSS is injected inline via `style.css?inline`.

## Directory Structure

```text
duo_next/
├── src/
│   ├── main.ts                  # Entry: defines <fe-island-duo-next> custom element
│   ├── CommunicationLayer.vue   # Props/events boundary (host ↔ app)
│   ├── CommunicationLayer_spec.ts
│   ├── App.vue                  # Application root component
│   ├── App_spec.ts
│   ├── main_spec.ts
│   ├── types.ts                 # Shared TypeScript types (ChatModel, ChatEvents, HostDataProps)
│   ├── style.css                # Tailwind CSS base (injected into shadow DOM)
│   ├── vite-env.d.ts
│   ├── components/
│   │   └── HelloWorld.vue       # Placeholder/scaffold component
│   ├── composables/
│   │   ├── useCommunicationBridge.ts      # Generic bridge composable
│   │   └── useCommunicationBridge_spec.ts
│   └── lib/
│       ├── utils.ts             # cn() helper (clsx + tailwind-merge)
│       └── utils_spec.ts
├── package.json
├── vite.config.ts               # Library build via defineLibraryConfig()
├── vitest.config.ts             # Test config via defineTestConfig()
├── components.json              # shadcn-vue CLI config
├── tsconfig.json / tsconfig.app.json / tsconfig.node.json / tsconfig.spec.json
├── eslint.config.js
└── index.html                   # Dev server entry
```

## CLI Commands & Usage

```bash
# Development server
yarn dev

# Build (library mode)
yarn build

# Build with file watching
yarn build:watch

# Production build
yarn build:prod

# Run tests (once)
yarn test

# Run tests with watch
yarn test:watch

# Run tests with coverage
yarn test:coverage

# Lint
yarn lint
yarn lint:fix

# Type check
yarn lint:types

# Format (Prettier)
yarn format
yarn format:fix

# Add shadcn-vue components
yarn shadcn add <component-name>
```

## Key Abstractions / Modules

### `src/main.ts` — Custom Element Registration

Wraps `CommunicationLayer.vue` as a Vue custom element using `defineCustomElement()`. Injects Tailwind CSS inline for Shadow DOM isolation. Registers as `<fe-island-duo-next>`.

### `src/CommunicationLayer.vue` — Host/App Boundary

The outermost Vue component that sits at the Web Component boundary. It:

- Receives `HostDataProps` as HTML attribute props from the host
- Emits `ChatEvents` back to the host as DOM events
- Delegates to `useCommunicationBridge()` for forwarding
- Renders `<App>` with forwarded props and event listeners

### `src/App.vue` — Application Root

The actual application component. Receives forwarded props and emits events. Currently renders user avatar, model list, and `HelloWorld` placeholder — intended for expansion into the full Duo UI.

### `src/composables/useCommunicationBridge.ts` — Generic Bridge

Generic, reusable composable that:

- Forwards props reactively (with optional exclusion list)
- Creates type-safe event handlers for a given list of event names
- Optionally wires up Vue dependency injection (`provide`) for services
- Returns `{ forwardedProps: ComputedRef, eventListeners }` for use in templates

### `src/types.ts` — Shared Types

- `ChatModel` — `{ text: string; value: string }` — AI model descriptor
- `ChatEvents` — DOM event map for all chat interactions (10 events)
- `HostDataProps` — Props passed from GitLab host (`models`, `avatarUrl`, `userName`)

### `src/lib/utils.ts` — Tailwind Utility

Exports `cn(...inputs)` — combines `clsx` and `tailwind-merge` for conditional class merging, following the shadcn-vue convention.

## Configuration System

| Config               | File                          | Notes                                              |
|----------------------|-------------------------------|----------------------------------------------------|
| Build                | `vite.config.ts`              | Uses `defineLibraryConfig` from `@frontend-islands/vite-config`; entry=`src/main.ts`, name=`DuoNext`, Tailwind enabled, alias `@`→`./src` |
| Tests                | `vitest.config.ts`            | Uses `defineTestConfig` from `@frontend-islands/vitest-config`; jsdom environment inferred |
| TypeScript           | `tsconfig.json` (root)        | References app/node/spec tsconfigs                 |
| Linting              | `eslint.config.js`            | Uses `@frontend-islands/eslint-config`             |
| Prettier             | `package.json#prettier`       | Uses `@frontend-islands/prettier-config`           |
| shadcn-vue           | `components.json`             | Style: new-york, baseColor: neutral, cssVariables  |
| Path alias           | `@` → `src/`                  | Set in both vite and tsconfig                      |

## Key Design Patterns

1. **Web Component / Frontend Island**: The entire app is a Shadow DOM custom element. Props come in as HTML attributes, events go out as DOM events. No shared global state with the host.
1. **Communication Layer Pattern**: A dedicated boundary component (`CommunicationLayer.vue`) mediates all communication between the host and inner app. The inner `App.vue` knows nothing about Web Components — it just uses standard Vue props/emits.
1. **Generic `useCommunicationBridge` Composable**: Parameterized by `TEvents` and `TProps` generics. Can be reused by other islands with different event/prop shapes. Supports optional prop exclusion and DI service injection.
1. **Inline Style Injection for Shadow DOM**: Tailwind CSS is imported as `?inline` in `main.ts` and passed to `defineCustomElement({ styles: [tailwind] })` to work inside the Shadow DOM boundary.
1. **shadcn-vue Component System**: UI primitives are added via `yarn shadcn add <name>` — copied into `src/components/ui/` with full source ownership. Styled with CSS variables defined in `src/style.css`.
1. **`cn()` Utility**: All class bindings use `cn()` from `src/lib/utils.ts` to safely merge Tailwind classes and handle conditional variants.

## Testing

- **Runner**: Vitest 4 with `@vue/test-utils` and jsdom
- **Spec files**: Co-located next to source files (`*_spec.ts`)
- **Mocking**: `vi.spyOn` / `vi.fn()` for module mocking; composables are mocked at the module level in component tests
- **Style**: Behavior-first (test rendered output and emitted events, not implementation details)
- **Coverage**: V8 provider via `@vitest/coverage-v8`

```bash
yarn test              # single run
yarn test:watch        # watch mode
yarn test:coverage     # with coverage report
yarn test:ui           # browser UI
```

## Extending the Project

**Adding a new UI component from shadcn-vue**:

```bash
yarn shadcn add <component-name>
# Component is copied to src/components/ui/<name>/
```

**Adding a new published Duo UI Next component**:

```bash
yarn shadcn add https://gitlab-org.gitlab.io/duo-ui-next/r/<component-name>.json
# Component is copied to src/components/ui/<name>/
```

**Adding a new Duo UI Next component hosted locally** (with Duo UI Next storybook running at `http://localhost:6006/`):

```bash
yarn shadcn add http://localhost:6006/r/<component-name>.json
# Component is copied to src/components/ui/<name>/
```

**Adding a new custom component**:

- Create `src/components/MyComponent.vue`
- Create `src/components/MyComponent_spec.ts`

**Adding a new prop from the host**:

1. Add the prop to `HostDataProps` in `src/types.ts`
1. `CommunicationLayer.vue` forwards it automatically via `useCommunicationBridge`

**Adding a new event to the host**:

1. Add the event to `ChatEvents` in `src/types.ts`
1. Add the event name to the `events` array in `CommunicationLayer.vue`
1. Emit it from any child component via the standard Vue `emit` mechanism

**Adding a new composable**:

- Create `src/composables/useMyComposable.ts` + `_spec.ts`
