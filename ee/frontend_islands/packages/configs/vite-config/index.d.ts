import type { UserConfig } from 'vite';

/**
 * Configuration options for Frontend Islands library builds
 */
export interface LibraryConfigOptions {
  /**
   * Library entry point file
   * @default './src/main.ts'
   */
  entry?: string;

  /**
   * IIFE global variable name (e.g., 'DuoNext', 'MyComponent')
   */
  name?: string;

  /**
   * Enable Tailwind CSS integration
   * @default false
   */
  tailwind?: boolean;

  /**
   * Path aliases for module resolution (e.g., { '@': './src' })
   */
  alias?: Record<string, string>;

  /**
   * Enable watch mode for automatic rebuilds
   * @default process.env.WATCH === '1'
   */
  watch?: boolean;
}

/**
 * Creates a Vite configuration for Frontend Islands library builds
 *
 * Optimized for building Vue components as IIFE bundles for web components.
 *
 * @param options - Configuration options
 * @returns Promise resolving to Vite user configuration
 */
export function defineLibraryConfig(options?: LibraryConfigOptions): Promise<UserConfig>;
