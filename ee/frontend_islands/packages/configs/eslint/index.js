import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import pluginVue from 'eslint-plugin-vue';
import parserVue from 'vue-eslint-parser';
import pluginVitest from 'eslint-plugin-vitest';
import eslintConfigPrettier from 'eslint-config-prettier';

/**
 * Modern ESLint Configuration for Vue 3 + TypeScript + Tailwind 4
 *
 * This configuration represents industry best practices for modern Vue applications.
 * It uses typescript-eslint v8's unified package and strict preset configurations.
 *
 * Architecture:
 * - Layer 1: Base JavaScript (ESLint recommended)
 * - Layer 2: TypeScript Strict (strictest syntax-based rules)
 * - Layer 3: TypeScript Stylistic (modern code conventions)
 * - Layer 4: Vue 3 Strongly Recommended
 * - Layer 5: Vue + TypeScript Integration
 * - Layer 6: File-specific configurations (tests, config files)
 * - Layer 7: Tailwind-friendly formatting adjustments
 * - Layer 8: Prettier Integration (disables conflicting formatting rules)
 *
 * Philosophy:
 * - Opinionated about code quality
 * - Leverage official presets over custom rules
 * - Explicit and self-documenting
 * - Optimized for Composition API and Tailwind CSS
 * - Prettier handles ALL formatting, ESLint handles code quality
 */
export default [
  // ============================================================================
  // LAYER 1: Base JavaScript Rules
  // ============================================================================
  // ESLint's recommended rules for all JavaScript/TypeScript code
  js.configs.recommended,

  // ============================================================================
  // LAYER 2 & 3: TypeScript Strict + Stylistic
  // ============================================================================
  // typescript-eslint's strict preset: strictest rules for code correctness
  // Does NOT require type-checking (syntax-based only)
  ...tseslint.configs.strict,

  // typescript-eslint's stylistic preset: modern TypeScript code patterns
  // Enforces consistent style without impacting logic
  ...tseslint.configs.stylistic,

  // ============================================================================
  // LAYER 4: Vue 3 Strongly Recommended
  // ============================================================================
  // Vue's strongly-recommended ruleset (stricter than "recommended")
  // Enforces Vue 3 best practices and prevents common mistakes
  ...pluginVue.configs['flat/strongly-recommended'],

  // ============================================================================
  // LAYER 5: Vue + TypeScript Integration
  // ============================================================================
  // Main configuration for Vue SFCs with TypeScript
  {
    files: ['**/*.{js,ts,vue}'],
    languageOptions: {
      // Vue parser wraps TypeScript parser for <script> blocks
      // This enables TypeScript support inside .vue files
      parser: parserVue,
      parserOptions: {
        parser: tseslint.parser, // Modern unified parser
        ecmaVersion: 'latest',
        sourceType: 'module',
        extraFileExtensions: ['.vue'],
      },
      globals: {
        // Vue 3 Compiler Macros (auto-imported in <script setup>)
        defineProps: 'readonly',
        defineEmits: 'readonly',
        defineExpose: 'readonly',
        defineSlots: 'readonly',
        defineOptions: 'readonly',
        defineModel: 'readonly',
        withDefaults: 'readonly',

        // Vue 3 Runtime Globals
        __VUE_OPTIONS_API__: 'readonly',
        __VUE_PROD_DEVTOOLS__: 'readonly',
        __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'readonly',

        // Browser Environment
        customElements: 'readonly',
        HTMLElement: 'readonly',

        // Build Tool Globals (Vite, etc.)
        process: 'readonly',
      },
    },
    plugins: {
      vue: pluginVue,
      '@typescript-eslint': tseslint.plugin,
    },
    rules: {
      // ========================================================================
      // Vue 3 Composition API Best Practices
      // ========================================================================

      // Enforce modern Composition API with <script setup>
      // This is the recommended approach for Vue 3 applications
      'vue/component-api-style': ['error', ['script-setup']],

      // Require TypeScript in all Vue <script> blocks
      // Ensures type safety across all components
      'vue/block-lang': ['error', { script: { lang: 'ts' } }],

      // Allow single-word component names (Index, Home, Layout, etc.)
      // The default multi-word requirement is too restrictive for modern apps
      'vue/multi-word-component-names': 'off',

      // Enforce explicit emit declarations for better type safety
      'vue/require-explicit-emits': 'error',

      // Don't require default props (TypeScript handles this better)
      'vue/require-default-prop': 'off',

      // ========================================================================
      // Vue Template Best Practices
      // ========================================================================

      // Enforce PascalCase for components in templates (e.g., <UserCard />)
      // This clearly distinguishes components from HTML elements
      'vue/component-name-in-template-casing': [
        'error',
        'PascalCase',
        {
          registeredComponentsOnly: false,
        },
      ],

      // Enforce self-closing tags for consistency and cleanliness
      // Works well with Prettier and modern Vue conventions
      'vue/html-self-closing': [
        'error',
        {
          html: { void: 'always', normal: 'always', component: 'always' },
          svg: 'always',
          math: 'always',
        },
      ],

      // Consistent macro ordering for readability
      'vue/define-macros-order': [
        'error',
        {
          order: ['defineOptions', 'defineModel', 'defineProps', 'defineEmits', 'defineSlots'],
        },
      ],

      // ========================================================================
      // Vue Reactivity Best Practices
      // ========================================================================

      // Prevent common reactivity mistakes
      'vue/no-ref-as-operand': 'error',
      'vue/no-watch-after-await': 'error',
      'vue/require-macro-variable-name': 'error',

      // Detect unused reactive state
      'vue/no-unused-vars': 'error',
      'vue/no-unused-refs': 'error',

      // ========================================================================
      // Vue Template Optimizations
      // ========================================================================

      // Optimize static classes (important for Tailwind)
      'vue/prefer-separate-static-class': 'error',

      // Remove unnecessary bindings
      'vue/no-useless-v-bind': 'error',
      'vue/no-useless-mustaches': 'error',
      'vue/no-useless-concat': 'error',

      // ========================================================================
      // Tailwind 4 Compatibility - Formatting Overrides
      // ========================================================================
      // These rules are disabled because they conflict with Tailwind's
      // utility-first approach which often results in long class strings.
      // Formatting is delegated to Prettier or similar tools.

      'vue/max-attributes-per-line': 'off',
      'vue/html-indent': 'off',
      'vue/html-closing-bracket-newline': 'off',
      'vue/singleline-html-element-content-newline': 'off',
      'vue/multiline-html-element-content-newline': 'off',
      'vue/first-attribute-linebreak': 'off',

      // ========================================================================
      // Security
      // ========================================================================

      // Warn about v-html usage (potential XSS vector)
      // Not disabled completely as it's sometimes necessary
      'vue/no-v-html': 'warn',

      // ========================================================================
      // TypeScript Overrides
      // ========================================================================
      // Minor adjustments to strict preset for better DX

      // Allow unused vars with underscore prefix (common pattern)
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_',
        },
      ],

      // Warn on 'any' instead of error (strict preset makes it error)
      // This provides flexibility while still discouraging overuse
      '@typescript-eslint/no-explicit-any': 'warn',

      // Don't require explicit return types (TypeScript infers well)
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/explicit-module-boundary-types': 'off',

      // ========================================================================
      // General JavaScript Best Practices
      // ========================================================================

      // Allow console.warn and console.error, warn on console.log
      'no-console': ['warn', { allow: ['warn', 'error'] }],

      // Warn on debugger (don't block development)
      'no-debugger': 'warn',
    },
    settings: {
      vue: {
        version: '3', // Ensure Vue 3 rules are applied
      },
    },
  },

  // ============================================================================
  // LAYER 6A: TypeScript-Only Files Configuration
  // ============================================================================
  // Pure TypeScript files get the full TypeScript parser
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    // Rules are inherited from strict + stylistic presets above
  },

  // ============================================================================
  // LAYER 6B: Test Files Configuration
  // ============================================================================
  // Specialized rules for Vitest test files
  {
    files: [
      '**/*.spec.{js,ts,tsx}',
      '**/*.test.{js,ts,tsx}',
      '**/*_spec.{js,ts,tsx}',
      '**/*_test.{js,ts,tsx}',
      '**/__tests__/**/*.{js,ts,tsx}',
    ],
    plugins: {
      vitest: pluginVitest,
    },
    languageOptions: {
      globals: {
        ...pluginVitest.environments.env.globals,
        HTMLElement: 'readonly',
        customElements: 'readonly',
      },
    },
    rules: {
      // Apply Vitest recommended rules
      ...pluginVitest.configs.recommended.rules,

      // Tests are more flexible with types and logging
      'no-console': 'off',
      '@typescript-eslint/no-explicit-any': 'off',

      // Enforce test best practices
      'vitest/expect-expect': 'error',
      'vitest/no-disabled-tests': 'warn',
      'vitest/no-focused-tests': 'error',
      'vitest/valid-expect': 'error',
      'vitest/prefer-to-be': 'error',
      'vitest/prefer-to-have-length': 'error',
    },
  },

  // ============================================================================
  // LAYER 6C: Configuration Files
  // ============================================================================
  // Config files (Vite, Vitest, Tailwind, etc.) need Node.js globals
  {
    files: ['*.config.{js,ts,mjs,cjs}', '*.setup.{js,ts}', '**/config/**/*.{js,ts}'],
    languageOptions: {
      globals: {
        process: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        module: 'readonly',
        require: 'readonly',
        NodeJS: 'readonly',
      },
    },
    rules: {
      // Config files are more flexible
      'no-console': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },

  // ============================================================================
  // LAYER 6D: CommonJS Files
  // ============================================================================
  // Support for legacy CommonJS modules
  {
    files: ['**/*.cjs'],
    languageOptions: {
      sourceType: 'commonjs',
      globals: {
        module: 'readonly',
        require: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        process: 'readonly',
        exports: 'writable',
      },
    },
    rules: {
      'no-console': 'off',
      '@typescript-eslint/no-var-requires': 'off',
      '@typescript-eslint/no-require-imports': 'off',
    },
  },

  // ============================================================================
  // LAYER 7: Global Ignores
  // ============================================================================
  // Files and directories that should never be linted
  {
    ignores: [
      // Dependencies
      '**/node_modules/**',

      // Build outputs
      '**/dist/**',
      '**/build/**',
      '**/.output/**',
      '**/.nuxt/**',

      // Testing outputs
      '**/coverage/**',

      // IDE
      '**/.vscode/**',
      '**/.idea/**',

      // Temporary files
      '**/tmp/**',
      '**/*.log',
      '**/junit_jest.xml',
      '**/.DS_Store',

      // Static assets
      '**/public/**',
      '**/static/**',
    ],
  },

  // ============================================================================
  // LAYER 8: Prettier Integration
  // ============================================================================
  // Disables all ESLint rules that conflict with Prettier
  // This MUST be the last item in the config array to override all previous rules
  //
  // What this does:
  // - Turns off all formatting rules from ESLint core
  // - Turns off all formatting rules from typescript-eslint stylistic preset
  // - Turns off all formatting rules from Vue plugin
  // - Keeps all code quality rules intact
  //
  // Result: ESLint handles code quality, Prettier handles formatting
  eslintConfigPrettier,
];
