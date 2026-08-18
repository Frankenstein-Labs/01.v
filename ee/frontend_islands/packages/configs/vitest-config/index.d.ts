import type { UserConfig as ViteUserConfig } from 'vitest/config';

/**
 * Configuration options for Vitest in Frontend Islands projects
 */
export interface VitestConfigOptions {
  /**
   * Source directory to alias as '@'
   * @default './src'
   */
  srcDir?: string;

  /**
   * Coverage thresholds for all metrics
   * Set to 0 to disable threshold enforcement
   * @default { branches: 80, functions: 80, lines: 80, statements: 80 }
   */
  coverageThresholds?: {
    branches?: number;
    functions?: number;
    lines?: number;
    statements?: number;
  };

  /**
   * Additional test file patterns beyond the default GitLab patterns
   * Default patterns: ['src/**\/*_spec.{js,ts}']
   * @default []
   */
  includePatterns?: string[];

  /**
   * Additional paths to exclude from coverage beyond the defaults
   * Default excludes: node_modules, test, *.d.ts, *.config.*, dist
   * @default []
   */
  excludePatterns?: string[];

  /**
   * Whether to use global test APIs (describe, it, expect, etc.)
   * @default true
   */
  globals?: boolean;

  /**
   * Test environment
   * @default 'jsdom'
   */
  environment?: 'node' | 'jsdom' | 'happy-dom' | 'edge-runtime';
}

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
 * @param options - Configuration options
 * @returns Vitest user configuration
 */
export function defineTestConfig(options?: VitestConfigOptions): ViteUserConfig;
