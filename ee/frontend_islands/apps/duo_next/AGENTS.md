# duo_next — Agent Instructions

Inherits all rules from `ee/frontend_islands/AGENTS.md`. Read that file first.
For architecture and context, see `BRAIN.md`.

## Validation

Before reporting work as complete, run from this directory (`ee/frontend_islands/apps/duo_next`):

```bash
yarn test
yarn lint
yarn lint:types
yarn format
```

## App-Specific Rules

- **Communication Layer pattern**: all host-to-app communication goes through `CommunicationLayer.vue` — never bypass it
- **New host props**: add to `HostDataProps` in `src/types.ts` — they are auto-forwarded by `useCommunicationBridge`
- **New host events**: add to `ChatEvents` in `src/types.ts` AND the `events` array in `CommunicationLayer.vue`
- **Class bindings**: always use `cn()` from `src/lib/utils.ts` — never raw class strings with Tailwind
- **Shadow DOM styles**: Tailwind CSS must be injected inline via the `?inline` import pattern in `main.ts`
- **UI primitives**: use `yarn shadcn add <name>` to add shadcn-vue components — don't hand-roll equivalents

## Coding Standards

- Follow existing patterns and conventions in the codebase.
- Keep changes focused and minimal.
- Prefer behavior-first tests over implementation-detail assertions.
- Update companion files (tests, docs, stories) when changing behavior.
