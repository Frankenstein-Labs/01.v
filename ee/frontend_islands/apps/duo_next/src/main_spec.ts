import { vi, describe, it, expect } from 'vitest';

// Mock Vue's defineCustomElement
vi.mock('vue', () => ({
  defineCustomElement: vi.fn(() => class MockElement extends HTMLElement {}),
}));

// Mock the App component
vi.mock('./CommunicationLayer.vue', () => ({
  default: {},
}));

// Mock CSS import
vi.mock('./style.css?inline', () => ({
  default: 'mocked-tailwind-styles',
}));

describe('main.ts', () => {
  it('should define a custom element with correct tag name', async () => {
    const { defineCustomElement } = await import('vue');

    // Import main.ts to execute the code
    await import('./main');

    expect(defineCustomElement).toHaveBeenCalledWith(
      expect.any(Object), // App component
      { styles: ['mocked-tailwind-styles'] },
    );

    expect(customElements.get('fe-island-duo-next')).toBeInstanceOf(Function);
  });
});
