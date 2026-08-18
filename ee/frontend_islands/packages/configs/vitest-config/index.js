import vue from '@vitejs/plugin-vue';
import path from 'node:path';

/**
 * @typedef {Object} VitestConfigOptions
 * @property {string} [srcDir='./src'] - Source directory to alias as '@'
 * @property {Object} [coverageThresholds] - Coverage thresholds for all metrics (default: 80% for all)
 * @property {number} [coverageThresholds.branches=80] - Branch coverage threshold
 * @property {number} [coverageThresholds.functions=80] - Function coverage threshold
 * @property {number} [coverageThresholds.lines=80] - Line coverage threshold
 * @property {number} [coverageThresholds.statements=80] - Statement coverage threshold
 * @property {string[]} [includePatterns=[]] - Additional test file patterns beyond GitLab defaults
 * @property {string[]} [excludePatterns=[]] - Additional paths to exclude from coverage
 * @property {boolean} [globals=true] - Whether to use global test APIs (describe, it, expect, etc.)
 * @property {'node'|'jsdom'|'happy-dom'|'edge-runtime'} [environment='jsdom'] - Test environment
 */

/**
 * Define a Vitest configuration optimized for Frontend Islands projects
 *
 * Features:
 * - Vue SFC support via @vitejs/plugin-vue
 * - jsdom environment for DOM testing
 * - Global test APIs (describe, it, expect, etc.)
 * - GitLab-specific test file patterns (*_spec.{js,ts})
 * - 80% coverage thresholds by default
 * - CI-aware reporters (JUnit in CI)
 * - Path alias support (@/* → ./src/*)
 *
 * @param {VitestConfigOptions} [options={}] - Configuration options
 * @returns {import('vitest/config').ViteUserConfig} Vitest user config
 *
 * @example
 * // Basic usage
 * import { defineConfig } from 'vitest/config';
 * import { defineTestConfig } from '@frontend-islands/vitest-config';
 *
 * export default defineConfig(defineTestConfig());
 *
 * @example
 * // With custom options
 * export default defineConfig(defineTestConfig({
 *   coverageThresholds: {
 *     branches: 90,
 *     functions: 90,
 *     lines: 90,
 *     statements: 90,
 *   },
 *   includePatterns: ['src/**\/*.test.{js,ts}'],
 * }));
 */
export function defineTestConfig(options = {}) {
  const {
    srcDir = './src',
    coverageThresholds = {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
    includePatterns = [],
    excludePatterns = [],
    globals = true,
    environment = 'jsdom',
  } = options;

  // Detect CI environment
  const inCI = !!process.env.CI;

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': path.resolve(process.cwd(), srcDir),
      },
    },
    test: {
      // Enable global test APIs (describe, it, expect, etc.)
      globals,

      // Test environment for DOM testing
      environment,

      // Test file patterns
      // GitLab convention: *_spec.{js,ts}, *.spec.{js,ts}
      include: ['src/**/*_spec.{js,ts}', 'src/**/*.spec.{js,ts}', ...includePatterns],

      // Reporters: JUnit for CI, default for local
      reporters: inCI ? ['default', 'junit'] : ['default'],

      // JUnit output file (for GitLab CI)
      outputFile: {
        junit: './junit_jest.xml',
      },

      // Coverage configuration
      coverage: {
        // Use V8 provider (faster, more accurate)
        provider: 'v8',

        // Reporters: multiple formats in CI, simple in local
        reporter: inCI ? ['json', 'lcov', 'text', 'clover'] : ['text', 'html'],

        // Files to exclude from coverage
        exclude: [
          'node_modules/**',
          'test/**',
          '**/*.d.ts',
          '**/*.config.*',
          'dist/**',
          ...excludePatterns,
        ],

        // Files to include in coverage
        include: ['src/**/*.{js,ts,vue}'],

        // Coverage thresholds
        thresholds: {
          global: coverageThresholds,
        },
      },
    },
  };
}
