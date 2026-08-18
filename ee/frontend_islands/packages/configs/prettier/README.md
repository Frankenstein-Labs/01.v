# @frontend-islands/prettier-config

Shared Prettier configuration for Frontend Islands projects. Optimized for Vue 3, TypeScript, and Tailwind CSS.

## Configuration

```json
{
  "printWidth": 100,
  "singleQuote": true,
  "arrowParens": "always",
  "trailingComma": "all"
}
```

**Key Settings:**
- **`printWidth: 100`** - Accommodates Tailwind utility classes
- **`singleQuote: true`** - JavaScript community standard
- **`arrowParens: "always"`** - Consistent, TypeScript-friendly
- **`trailingComma: "all"`** - Cleaner git diffs

## Installation

### Peer Dependencies

```bash
yarn add -D prettier
```

Required version: `prettier: ^3.0.0`

## Usage

### Basic Setup (Recommended)

Add to your `package.json`:

```json
{
  "prettier": "@frontend-islands/prettier-config"
}
```

That's it! No `.prettierrc` file needed.

### With Overrides

If you need custom settings, create `.prettierrc.json`:

```json
{
  "extends": "@frontend-islands/prettier-config",
  "printWidth": 120
}
```

Or `.prettierrc.mjs` for more flexibility:

```javascript
import config from '@frontend-islands/prettier-config' assert { type: 'json' };

export default {
  ...config,
  printWidth: 120,
  semi: false,
};
```

### Ignore Patterns

Create `.prettierignore`:

```bash
node_modules
dist
build
.next
.nuxt
coverage
*.min.js
```

## Integration with ESLint

This config works seamlessly with `@frontend-islands/eslint-config`, which includes `eslint-config-prettier` to disable conflicting ESLint rules.

No additional setup needed if you're using both configs.

## Package Scripts

Add these to your `package.json`:

```json
{
  "scripts": {
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

## VS Code Integration

Install the Prettier extension:

```bash
code --install-extension esbenp.prettier-vscode
```

Add to `.vscode/settings.json`:

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[vue]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
```

## Usage Examples

### Format specific files

```bash
prettier --write "src/**/*.{js,ts,vue}"
```

### Check formatting (CI)

```bash
prettier --check "src/**/*.{js,ts,vue}"
```

### Format staged files (pre-commit hook)

With `lint-staged`:

```json
{
  "lint-staged": {
    "*.{js,ts,vue,json,md}": "prettier --write"
  }
}
```

## Troubleshooting

### Formatting not applying

1. Ensure Prettier extension is installed and enabled
2. Check `.vscode/settings.json` has correct `defaultFormatter`
3. Verify no conflicting formatter extensions
4. Restart VS Code

### Conflicts with ESLint

If you see conflicts between Prettier and ESLint:

1. Ensure you're using `@frontend-islands/eslint-config` (includes `eslint-config-prettier`)
2. Run Prettier before ESLint in your workflow
3. Check no duplicate formatting rules in ESLint config

### Ignoring files

Add files/directories to `.prettierignore`:

```
# Generated files
dist
build

# Third-party
node_modules
vendor

# Large files
*.min.js
*.bundle.js
```

## Version History

### 0.1.0
- Initial release
- 100-character line width
- Single quotes
- Always arrow parens
- Trailing commas

## License

MIT
