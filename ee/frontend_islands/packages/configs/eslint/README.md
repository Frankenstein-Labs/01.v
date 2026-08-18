# @frontend-islands/eslint-config

Strict ESLint configuration for Vue 3 + TypeScript + Tailwind CSS 4. Built on typescript-eslint v8 with integrated Prettier support.

## Architecture

The configuration is structured in 8 explicit layers:

```
Layer 1: Base JavaScript (ESLint recommended)
    ↓
Layer 2: TypeScript Strict (tseslint.configs.strict)
    ↓
Layer 3: TypeScript Stylistic (tseslint.configs.stylistic)
    ↓
Layer 4: Vue 3 Strongly Recommended
    ↓
Layer 5: Vue + TypeScript Integration (custom parser config)
    ↓
Layer 6: File-specific rules (tests, config files, CommonJS)
    ↓
Layer 7: Tailwind-friendly formatting adjustments
    ↓
Layer 8: Prettier Integration (disables conflicting formatting rules)
```

**Key Features:**
- `tseslint.configs.strict` + `tseslint.configs.stylistic`
- Vue 3 strongly recommended rules + TypeScript integration
- Vitest support for test files
- Tailwind-friendly (formatting rules disabled)
- Prettier integration (no conflicts)

## Installation

This package is part of the frontend islands monorepo and should already be available.

### Peer Dependencies

```json
{
  "eslint": "^8.57.1",
  "eslint-config-prettier": ">=9.1.0",
  "eslint-plugin-vitest": "^0.5.4",
  "eslint-plugin-vue": "^10.5.0",
  "prettier": "^3.0.0",
  "typescript": "~5.8.3",
  "typescript-eslint": "^8.46.2"
}
```

**Note:** Prettier is a required peer dependency because this config integrates `eslint-config-prettier` to disable conflicting formatting rules.

## Usage

### Basic Setup

Create an `eslint.config.js` in your project root:

```javascript
export { default } from '@frontend-islands/eslint-config';
```

That's it! Zero configuration needed for standard projects.

### Adding Custom Rules

If you need project-specific overrides:

```javascript
import baseConfig from '@frontend-islands/eslint-config';

export default [
  ...baseConfig,
  {
    files: ["**/*.vue"],
    rules: {
      // Your custom Vue rules
      'vue/component-name-in-template-casing': ['error', 'kebab-case']
    }
  }
];
```

### Disabling Specific Rules

```javascript
import baseConfig from '@frontend-islands/eslint-config';

export default [
  ...baseConfig,
  {
    rules: {
      // Disable a rule you don't want
      '@typescript-eslint/no-explicit-any': 'off'
    }
  }
];
```

### Adding Custom Ignores

```javascript
import baseConfig from '@frontend-islands/eslint-config';

export default [
  ...baseConfig,
  {
    ignores: ['generated/**', 'vendor/**']
  }
];
```

## Prettier Integration

Built-in integration via `eslint-config-prettier` (Layer 8). ESLint handles code quality, Prettier handles formatting. No conflicts.

## File-Specific Configurations

### Test Files

Patterns: `*.spec.ts`, `*.test.ts`, `*_spec.ts`, `__tests__/**`

- Vitest rules enabled
- `no-console` allowed
- `any` type allowed
- Relaxed strictness for test helpers

### Config Files

Patterns: `*.config.{js,ts}`, `*.setup.{js,ts}`, `config/**`

- Node.js globals available
- `console` allowed
- `any` allowed
- CommonJS imports allowed

### CommonJS Files

Patterns: `*.cjs`

- `require()`/`module.exports` allowed
- Node.js globals
- Less strict rules

## Scripts

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

## IDE Integration

### VS Code

Install the [ESLint extension](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint).

Recommended `.vscode/settings.json`:

```json
{
  "eslint.enable": true,
  "eslint.validate": ["javascript", "typescript", "vue"],
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "eslint.format.enable": false
}
```

### JetBrains IDEs (WebStorm, IntelliJ)

ESLint is supported natively. Enable it in:
**Settings → Languages & Frameworks → JavaScript → Code Quality Tools → ESLint**

Check "Automatic ESLint configuration" and "Run eslint --fix on save"

## Ignored Files

The following are ignored by default:

- `node_modules/` - Dependencies
- `dist/`, `build/`, `.output/` - Build outputs
- `coverage/` - Test coverage
- `.vscode/`, `.idea/` - IDE files
- `public/`, `static/` - Static assets

## Vue 3 Compiler Macros

The following auto-imports are recognized:

- `defineProps`
- `defineEmits`
- `defineExpose`
- `defineSlots`
- `defineOptions`
- `defineModel`
- `withDefaults`

No ESLint errors for using these without imports!

## Troubleshooting

### "Parsing error" for Vue files

Ensure your Vue files use `<script lang="ts">` or `<script setup lang="ts">`.

### Too strict for my project

This config is intentionally strict. To relax rules:

```javascript
import baseConfig from '@frontend-islands/eslint-config';

export default [
  ...baseConfig,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'vue/component-api-style': 'off'
    }
  }
];
```

### Want even stricter rules?

Add type-checked rules from `typescript-eslint`:

```javascript
import baseConfig from '@frontend-islands/eslint-config';
import tseslint from 'typescript-eslint';

export default [
  ...baseConfig,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname
      }
    }
  }
];
```

### Using with Prettier

Prettier is integrated via `eslint-config-prettier`. Install `@frontend-islands/prettier-config` and use both tools together.
