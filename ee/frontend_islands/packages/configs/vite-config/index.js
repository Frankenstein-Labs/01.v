import vue from '@vitejs/plugin-vue';

/**
 * @typedef {Object} LibraryConfigOptions
 * @property {string} [entry='./src/main.ts'] - Library entry point file
 * @property {string} [name] - IIFE global variable name (e.g., 'DuoNext')
 * @property {boolean} [tailwind=false] - Enable Tailwind CSS integration
 * @property {Record<string, string>} [alias] - Path aliases (e.g., { '@': './src' })
 * @property {boolean} [watch] - Enable watch mode (default: auto-detected from WATCH env var)
 */

/**
 * Dynamically imports Tailwind CSS plugin
 * @returns {Promise<Array>} Tailwind plugins array or empty array if not installed
 */
async function loadTailwindPlugin() {
  try {
    const tailwindModule = await import('@tailwindcss/vite');
    const tailwindcss = tailwindModule.default;
    return tailwindcss();
  } catch (error) {
    console.warn(
      '@tailwindcss/vite is not installed. Install it with: yarn add -D @tailwindcss/vite',
    );
    return [];
  }
}

/**
 * Creates a Vite configuration for Frontend Islands library builds
 *
 * Optimized for building Vue components as IIFE bundles for web components.
 * All Frontend Islands share these constraints:
 * - Format: IIFE (for browser <script> tags)
 * - Custom elements: Enabled (Vue web components)
 * - Custom element prefix: 'fe-island-'
 * - Output file: 'dist/main.js'
 * - Build target: ES2020 (modern browsers)
 * - Inline dynamic imports: true (required for IIFE)
 *
 * @param {LibraryConfigOptions} [options={}] - Configuration options
 * @returns {Promise<import('vite').UserConfig>} Vite configuration
 *
 * @example
 * // Basic usage
 * import { defineConfig } from 'vite';
 * import { defineLibraryConfig } from '@frontend-islands/vite-config';
 *
 * export default defineConfig(
 *   await defineLibraryConfig({
 *     entry: './src/main.ts',
 *     name: 'DuoNext',
 *     tailwind: true,
 *     alias: { '@': './src' },
 *   })
 * );
 */
export async function defineLibraryConfig(options = {}) {
  const {
    entry = './src/main.ts',
    name,
    tailwind = false,
    alias,
    watch = process.env.WATCH === '1',
  } = options;

  // Build Vue plugin configuration for custom elements
  const vueConfig = {
    customElement: true,
    template: {
      compilerOptions: {
        isCustomElement: (tag) => tag.startsWith('fe-island-'),
      },
    },
  };

  // Build plugins array
  const plugins = [vue(vueConfig)];

  // Add Tailwind if enabled
  if (tailwind) {
    const tailwindPlugins = await loadTailwindPlugin();
    plugins.push(...tailwindPlugins);
  }

  // Build resolve configuration
  const resolve = alias
    ? {
        alias: Object.entries(alias).map(([find, replacement]) => ({
          find,
          replacement,
        })),
      }
    : undefined;

  return {
    plugins,
    resolve,
    css: {
      // Prevent Vite from walking up to find root postcss.config.js
      // Tailwind v4 uses the Vite plugin, not PostCSS plugin
      postcss: {},
    },
    define: {
      __VUE_OPTIONS_API__: JSON.stringify(true),
      __VUE_PROD_DEVTOOLS__: JSON.stringify(false),
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
    },
    build: {
      lib: {
        entry,
        formats: ['iife'],
        name,
        fileName: () => 'main.js',
      },
      rollupOptions: {
        output: {
          inlineDynamicImports: true,
        },
      },
      target: 'es2020',
      outDir: 'dist',
      watch: watch ? {} : null,
    },
  };
}
