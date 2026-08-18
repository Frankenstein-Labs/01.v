import { describe, it, expect, vi } from 'vitest';
import { cn } from './utils';

vi.mock('clsx', async () => {
  const { clsx: actualClsx } = await vi.importActual('clsx');
  return {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
    clsx: vi.fn((...args) => (actualClsx as Function)(...args)),
  };
});

vi.mock('tailwind-merge', () => ({
  twMerge: vi.fn((classes) => classes),
}));

describe('utils', () => {
  describe('cn', () => {
    it('should combine class names using clsx and twMerge', async () => {
      const { clsx } = vi.mocked(await import('clsx'));
      const { twMerge } = vi.mocked(await import('tailwind-merge'));

      const result = cn('class1', 'class2', undefined, 'class3');

      expect(clsx).toHaveBeenCalledWith(['class1', 'class2', undefined, 'class3']);
      expect(twMerge).toHaveBeenCalledWith('class1 class2 class3');
      expect(result).toBe('class1 class2 class3');
    });

    it('should handle empty input', () => {
      const result = cn();
      expect(result).toBe('');
    });

    it('should handle object-style classes', () => {
      const result = cn('base', { active: true, disabled: false });
      expect(result).toBe('base active');
    });

    it('should handle array of classes', () => {
      const result = cn(['class1', 'class2'], 'class3');
      expect(result).toBe('class1 class2 class3');
    });
  });
});
