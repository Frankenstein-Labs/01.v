# @frontend-islands/vitest-config

Shared Vitest configuration for Frontend Islands projects with Vue 3 support, GitLab patterns, and CI integration.

## Features

- Vue SFC testing with `@vitejs/plugin-vue`
- jsdom environment for DOM testing
- Global test APIs (`describe`, `it`, `expect`)
- GitLab test patterns (`*_spec.{js,ts}`)
- V8 coverage with 80% thresholds
- CI-aware reporters (JUnit for GitLab CI)
- Path alias support (`@/*` → `./src/*`)

## Installation

### Peer Dependencies

```bash
yarn add -D vitest @vitejs/plugin-vue jsdom
```

### Optional Dependencies

```bash
yarn add -D @vue/test-utils @vitest/coverage-v8 @vitest/ui
```

## Usage

### Basic Setup

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import { defineTestConfig } from '@frontend-islands/vitest-config';

export default defineConfig(defineTestConfig());
```

This provides:
- Vue SFC support
- jsdom environment
- Global test APIs
- 80% coverage thresholds
- GitLab patterns (`*_spec.{js,ts}`)
- JUnit reports in CI

### Custom Coverage Thresholds

```typescript
export default defineConfig(
  defineTestConfig({
    coverageThresholds: {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90,
    },
  })
);
```

### Additional Test Patterns

```typescript
export default defineConfig(
  defineTestConfig({
    includePatterns: ['src/**/*.test.{js,ts}'],
  })
);
```

### Custom Source Directory

```typescript
export default defineConfig(
  defineTestConfig({
    srcDir: './lib', // Changes @ alias to point to lib/
  })
);
```

### Extending Configuration

Use Vitest's `mergeConfig` for additional customization:

```typescript
import { defineConfig, mergeConfig } from 'vitest/config';
import { defineTestConfig } from '@frontend-islands/vitest-config';

export default defineConfig(
  mergeConfig(
    defineTestConfig(),
    {
      test: {
        setupFiles: ['./test/setup.ts'],
        mockReset: true,
      },
    }
  )
);
```

## Configuration Options

### `defineTestConfig(options?)`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `srcDir` | `string` | `'./src'` | Source directory for `@` alias |
| `coverageThresholds` | `object` | `{ branches: 80, functions: 80, lines: 80, statements: 80 }` | Coverage thresholds |
| `includePatterns` | `string[]` | `[]` | Additional test file patterns |
| `excludePatterns` | `string[]` | `[]` | Additional coverage exclusions |
| `globals` | `boolean` | `true` | Enable global test APIs |
| `environment` | `string` | `'jsdom'` | Test environment |

## Test File Patterns

Default patterns (GitLab convention):
```
src/**/*_spec.{js,ts}
src/**/*.spec.{js,ts}
```

## Coverage Configuration

**Provider**: V8 (faster, more accurate than istanbul)

**Default Thresholds**: 80% for all metrics

**Included**: `src/**/*.{js,ts,vue}`

**Excluded**:
- `node_modules/**`
- `test/**`
- `**/*.d.ts`
- `**/*.config.*`
- `dist/**`

**Reporters**:
- Local: `text`, `html`
- CI: `json`, `lcov`, `text`, `clover`, `junit`

## CI Integration

The config automatically detects CI environments via `process.env.CI` and:
- Adds JUnit reporter for GitLab CI
- Outputs to `./junit_jest.xml`
- Enables multiple coverage formats

## Package Scripts

Add these to your `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage"
  }
}
```

## Example Test

```typescript
// src/composables/useCounter_spec.ts
import { describe, it, expect } from 'vitest';
import { ref } from 'vue';

describe('useCounter', () => {
  it('should increment counter', () => {
    const count = ref(0);
    count.value++;
    expect(count.value).toBe(1);
  });
});
```

## Vue Component Testing

```typescript
// src/components/MyButton_spec.ts
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import MyButton from './MyButton.vue';

describe('MyButton', () => {
  it('renders properly', () => {
    const wrapper = mount(MyButton, { props: { label: 'Click me' } });
    expect(wrapper.text()).toContain('Click me');
  });
});
```

## Troubleshooting

### Tests not found

Ensure your test files follow GitLab patterns:
- `ComponentName_spec.ts` ✅
- `ComponentName.spec.ts` ✅
- `ComponentName.test.ts` ❌ (add to `includePatterns`)

### Coverage below threshold

The config enforces 80% coverage. To adjust:

```typescript
defineTestConfig({
  coverageThresholds: {
    branches: 70, // Lower threshold
  },
})
```

Or disable: `coverageThresholds: { branches: 0, functions: 0, lines: 0, statements: 0 }`

### Global APIs not working

If `describe` is not defined, check:
1. `globals: true` in config (default)
2. TypeScript types installed: `yarn add -D vitest`
3. Add to `tsconfig.json`:
   ```json
   {
     "compilerOptions": {
       "types": ["vitest/globals"]
     }
   }
   ```

## Version History

### 0.1.0
- Initial release
- Vue 3 SFC support
- GitLab test patterns
- 80% coverage thresholds
- CI-aware reporters
- Path alias support

## License

MIT
