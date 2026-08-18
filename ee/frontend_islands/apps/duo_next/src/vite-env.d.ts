/// <reference types="vite/client" />

// Extend Vite's CSS module declarations to include query parameters
declare module '*.css?inline' {
  const src: string;
  export default src;
}

declare module '*.css?url' {
  const src: string;
  export default src;
}
