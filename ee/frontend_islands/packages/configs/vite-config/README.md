# @frontend-islands/vite-config

Shared Vite configuration for Frontend Islands projects, optimized for building Vue 3 web components as IIFE bundles.

## Overview

This package provides a pre-configured Vite setup for Frontend Islands library builds.

All Frontend Islands share these architectural constraints:
- **Format**: IIFE (for browser `<script>` tags)
- **Custom elements**: Enabled (Vue web components)
- **Custom element prefix**: `fe-island-`
- **Output directory**: `dist`
- **Build target**: ES2020 (modern browsers)
- **Inline dynamic imports**: true (required for IIFE)

The configuration includes:
- Vue 3 plugin with custom element support
- Optional Tailwind CSS 4 integration
- Smart defaults for common patterns
- Watch mode support
- Vue feature flags pre-configured

## Installation

```bash
yarn add -D @frontend-islands/vite-config
```

### Peer Dependencies

Required:
```bash
yarn add -D vite @vitejs/plugin-vue
```

Optional (for Tailwind CSS):
```bash
yarn add -D @tailwindcss/vite tailwindcss
```

## Usage

### Basic Example

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(
  await defineLibraryConfig({
    entry: './src/main.ts',
    name: 'DuoNext',
    tailwind: true,
    alias: {
      '@': './src',
    },
  })
);
```

This creates a library build with:
- Entry point: `./src/main.ts`
- Output: `dist/main.js` (IIFE format)
- Global variable: `DuoNext`
- Tailwind CSS integrated
- Path alias `@` → `./src`

### Minimal Example

```typescript
import { defineConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(await defineLibraryConfig());
```

Uses all defaults:
- Entry: `./src/main.ts`
- Output: `dist/main.js`
- No Tailwind
- No aliases

## API Reference

### `defineLibraryConfig(options?)`

Creates a Vite configuration for Frontend Islands library builds.

#### Options

All options are optional. Sensible defaults are provided.

##### `entry`
- **Type:** `string`
- **Default:** `'./src/main.ts'`
- **Description:** Library entry point file

Example:
```typescript
await defineLibraryConfig({
  entry: './src/MyComponent.ts',
})
```

##### `name`
- **Type:** `string`
- **Default:** `undefined`
- **Description:** IIFE global variable name (e.g., 'DuoNext', 'MyComponent')
- **Note:** Required if you need to access the bundle via global variable

Example:
```typescript
await defineLibraryConfig({
  name: 'DuoNext',
})
// → Global window.DuoNext available
```

##### `tailwind`
- **Type:** `boolean`
- **Default:** `false`
- **Description:** Enable Tailwind CSS integration

Example:
```typescript
await defineLibraryConfig({
  tailwind: true,
})
```

**Requirements:**
1. Install dependencies: `yarn add -D @tailwindcss/vite tailwindcss`
2. Import in your entry point:
   ```typescript
   import 'tailwindcss';
   ```

##### `alias`
- **Type:** `Record<string, string>`
- **Default:** `undefined`
- **Description:** Path aliases for module resolution

Example:
```typescript
await defineLibraryConfig({
  alias: {
    '@': './src',
    '@components': './src/components',
  },
})
```

**Note:** Remember to also configure TypeScript `paths` in your `tsconfig.json`:
```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"]
    }
  }
}
```

##### `watch`
- **Type:** `boolean`
- **Default:** `process.env.WATCH === '1'`
- **Description:** Enable watch mode for automatic rebuilds

Example:
```bash
# Via environment variable (recommended)
WATCH=1 vite build

# Or explicitly in config
await defineLibraryConfig({
  watch: true,
})
```

## Configuration Details

### Hardcoded Constraints

These values are consistent across all Frontend Islands and are not configurable:

- **Format**: `'iife'` - Required for web component loading
- **Custom elements**: `true` - Vue web components mode
- **Custom element prefix**: `'fe-island-'` - Standard prefix for all islands
- **Output directory**: `'dist'` - Standard output location
- **Build target**: `'es2020'` - Modern browser support
- **Inline dynamic imports**: `true` - Required for IIFE format

### Vue Feature Flags

The following Vue feature flags are pre-configured:

```javascript
{
  __VUE_OPTIONS_API__: true,        // Support both Options and Composition API
  __VUE_PROD_DEVTOOLS__: false,     // Disable devtools in production
  'process.env.NODE_ENV': process.env.NODE_ENV,  // Pass through environment
}
```

These are sensible defaults for all Frontend Islands projects.

## Common Patterns

### Web Components (Custom Elements)

Frontend Islands are Vue 3 web components. Your entry point should register custom elements:

```typescript
// src/main.ts
import { defineCustomElement } from 'vue';
import MyComponent from './MyComponent.vue';

const MyElement = defineCustomElement(MyComponent);
customElements.define('fe-island-my-component', MyElement);
```

The config automatically:
- Enables Vue's `defineCustomElement` API
- Detects custom elements (tags starting with `fe-island-`)
- Builds as IIFE for `<script>` tag usage
- Inlines dynamic imports

Usage in HTML:

```html
<script src="./dist/my-component.js"></script>
<fe-island-my-component></fe-island-my-component>
```

### Tailwind CSS Integration

Enable Tailwind CSS 4 (Vite-first approach):

```typescript
await defineLibraryConfig({
  tailwind: true,
})
```

**Setup:**
1. Install: `yarn add -D @tailwindcss/vite tailwindcss`
2. Import in entry point:
   ```typescript
   // src/main.ts
   import 'tailwindcss';
   ```
3. Configure Tailwind (optional `tailwind.config.ts`)

### Path Aliases

Configure module resolution shortcuts:

```typescript
await defineLibraryConfig({
  alias: {
    '@': './src',
    '@components': './src/components',
    '@utils': './src/utils',
  },
})
```

**TypeScript configuration:**

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"],
      "@utils/*": ["./src/utils/*"]
    }
  }
}
```

### Watch Mode

Enable watch mode for development:

```bash
# Set via environment variable (recommended)
WATCH=1 vite build

# Or in package.json scripts
{
  "scripts": {
    "build": "vite build",
    "build:watch": "WATCH=1 vite build"
  }
}
```

Watch mode automatically rebuilds on file changes.

## Design Philosophy

### 1. Async by Default

The helper function is async because it dynamically imports optional dependencies (like Tailwind):

```typescript
// ✅ Correct
export default defineConfig(await defineLibraryConfig());

// ❌ Wrong - Promise not resolved
export default defineConfig(defineLibraryConfig());
```

This approach:
- Avoids requiring optional dependencies
- Shows helpful warnings when dependencies are missing
- Reduces bundle size when features aren't used

### 2. Sensible Defaults

The configuration provides smart defaults based on Frontend Islands patterns:
- IIFE format (web components)
- Custom elements enabled
- ES2020 target (modern browsers)
- Watch mode from environment variable
- Vue feature flags pre-configured

Override any default to match your specific needs.

### 3. Architectural Constraints

Frontend Islands share common architectural constraints. These are hardcoded:
- Custom element prefix: `fe-island-`
- IIFE format for browser loading
- Standard output directory: `dist`
- Inline dynamic imports (required for IIFE)

This consistency simplifies CI/CD configuration and deployment.

### 4. No Build Step

This package is plain JavaScript (not TypeScript). Benefits:
- Immediate feedback when editing configs
- No compilation step required
- Type safety via JSDoc comments
- Simpler development workflow

## Troubleshooting

### Tailwind Not Working

1. Verify installation:
   ```bash
   yarn add -D @tailwindcss/vite tailwindcss
   ```

2. Import in entry point:
   ```typescript
   import 'tailwindcss';
   ```

3. Enable in config:
   ```typescript
   await defineLibraryConfig({ tailwind: true })
   ```

### Custom Elements Not Registered

Ensure you're calling `customElements.define()` in your entry point:

```typescript
import { defineCustomElement } from 'vue';
import MyComponent from './MyComponent.vue';

const MyElement = defineCustomElement(MyComponent);
customElements.define('fe-island-my-component', MyElement);
```

The `fe-island-` prefix in the config is for Vue's template compiler, not for registration.

### Watch Mode Not Working

Set the `WATCH` environment variable:

```bash
WATCH=1 vite build
```

Or enable explicitly:

```typescript
await defineLibraryConfig({ watch: true })
```

## Package Scripts

Add these scripts to your `package.json`:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "build:watch": "WATCH=1 vite build",
    "preview": "vite preview"
  }
}
```

## Examples

### Minimal Configuration

```typescript
import { defineConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(await defineLibraryConfig());
```

### Standard Frontend Island

```typescript
import { defineConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(
  await defineLibraryConfig({
    entry: './src/main.ts',
    name: 'DuoNext',
    tailwind: true,
    alias: {
      '@': './src',
    },
  })
);
```

### With Custom Entry Point

```typescript
import { defineConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(
  await defineLibraryConfig({
    entry: './src/components/SpecialComponent.ts',
    name: 'SpecialComponent',
  })
);
```

## Version History

### 0.1.0
- Initial release
- Library build configuration for Frontend Islands
- Vue 3 support with custom elements
- Optional Tailwind CSS 4 integration
- Path alias support
- Watch mode support
- ES2020 build target
- Pre-configured Vue feature flags

## License

MIT

## Contributing

This package is part of the Frontend Islands monorepo. See the main repository for contribution guidelines.
