# @frontend-islands/tsconfig

Shared TypeScript configurations for Frontend Islands projects. Provides strict, modern TypeScript settings optimized for Vue 3 applications.

## Configurations

Three configuration files are provided:

1. **`tsconfig.json`** - Base configuration with strict type checking
2. **`tsconfig.app.json`** - For application source code (extends `@vue/tsconfig/tsconfig.dom.json`)
3. **`tsconfig.node.json`** - For build tools and config files (Node environment)

## Installation

### Peer Dependencies

```bash
yarn add -D typescript @vue/tsconfig
```

Required versions:
- `typescript`: `^5.9.3`
- `@vue/tsconfig`: `^0.7.0`

## Usage

### Solution-Style Setup (Recommended)

Create a root `tsconfig.json` that references both app and node configs:

```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

### Application Code

**`tsconfig.app.json`** - For `src/**/*.ts`, `src/**/*.vue`:

```json
{
  "extends": "@frontend-islands/tsconfig/tsconfig.app.json",
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.tsx", "src/**/*.vue"]
}
```

### Build Tools

**`tsconfig.node.json`** - For `vite.config.ts`, `vitest.config.ts`:

```json
{
  "extends": "@frontend-islands/tsconfig/tsconfig.node.json",
  "include": ["vite.config.ts", "vitest.config.ts"]
}
```

## Configuration Details

### Base Config (`tsconfig.json`)

Shared settings for all configurations:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true,
    "moduleResolution": "bundler",
    "incremental": true
  }
}
```

**Key Features:**
- Strict mode enabled (catches more errors)
- Unused code detection
- Modern module resolution (`bundler`)
- Incremental compilation for faster builds

### App Config (`tsconfig.app.json`)

Extends `@vue/tsconfig/tsconfig.dom.json` for Vue 3 support:

```json
{
  "extends": ["@frontend-islands/tsconfig/tsconfig.json", "@vue/tsconfig/tsconfig.dom.json"],
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "preserve",
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo"
  }
}
```

**Key Features:**
- ES2020 target (modern JavaScript)
- DOM types for browser APIs
- JSX support for Vue
- Composite project for solution builds

### Node Config (`tsconfig.node.json`)

For build tools and configuration files:

```json
{
  "extends": "@frontend-islands/tsconfig/tsconfig.json",
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023"],
    "module": "ESNext",
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "verbatimModuleSyntax": true
  }
}
```

**Key Features:**
- ES2023 target (Node features)
- No emit (type-checking only)
- `.ts` extension imports allowed
- Verbatim module syntax

## Path Aliases

Configure path aliases in your `tsconfig.app.json`:

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"],
      "@composables/*": ["./src/composables/*"]
    }
  }
}
```

**Important**: Also configure the same aliases in your Vite config.

## Compiler Scripts

Add these to your `package.json`:

```json
{
  "scripts": {
    "type-check": "vue-tsc -b --noEmit",
    "type-check:watch": "vue-tsc -b --noEmit --watch",
    "build": "vue-tsc -b && vite build"
  }
}
```

**Options:**
- `-b`: Solution-style build (follows `references`)
- `--noEmit`: Type-check only, don't emit files
- `--watch`: Watch mode for development

## Strict Mode Features

The base config enables all strict checks:

| Check | Description |
|-------|-------------|
| `strict` | Enables all strict type checks |
| `noUnusedLocals` | Error on unused local variables |
| `noUnusedParameters` | Error on unused function parameters |
| `noFallthroughCasesInSwitch` | Require `break` in switch cases |
| `noUncheckedSideEffectImports` | Error on side-effect imports without types |

## Module Resolution

Uses `"moduleResolution": "bundler"` for modern bundler behavior:
- Supports package.json `exports` field
- Allows `.ts` extensions in imports (with `allowImportingTsExtensions`)
- Works with Vite, esbuild, and other modern bundlers

## Incremental Compilation

The config enables incremental compilation for faster subsequent builds:
- Stores build info in `node_modules/.tmp/`
- Speeds up `vue-tsc` type checking
- Automatically cleans up stale cache

## Troubleshooting

### Module not found errors

If you see "Cannot find module" errors:

1. Check `paths` in `tsconfig.app.json` matches your Vite config
2. Ensure `baseUrl` is not set (use `paths` instead)
3. Restart VS Code/IDE to reload TypeScript server

### Slow type checking

If `vue-tsc` is slow:

1. Ensure `incremental: true` is enabled (default)
2. Check `.tsbuildinfo` files are not gitignored
3. Use solution-style config with `references`
4. Exclude unnecessary files from `include`

### Strict mode errors

If strict mode is too strict for migration:

Create a local `tsconfig.json` that overrides:

```json
{
  "extends": "@frontend-islands/tsconfig/tsconfig.json",
  "compilerOptions": {
    "strict": false,
    "noUnusedLocals": false
  }
}
```

Then gradually enable checks as you fix issues.

## IDE Support

### VS Code

Recommended settings (`.vscode/settings.json`):

```json
{
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true,
  "typescript.preferences.importModuleSpecifier": "relative"
}
```

### WebStorm

TypeScript service is enabled by default. Ensure:
1. TypeScript version matches project version
2. TypeScript Language Service is enabled
3. Code style matches project settings

## Version History

### 0.1.0
- Initial release
- Three configuration files (base, app, node)
- Extends `@vue/tsconfig` for Vue 3
- Strict mode with additional checks
- Solution-style project support

## License

MIT
