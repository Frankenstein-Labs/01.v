import { toggleAiPanelMaximizedClass, toggleAiPanelOpenClass } from 'ee/ai/utils/dom_utils';

describe('dom_utils', () => {
  let pageLayout;

  beforeEach(() => {
    pageLayout = document.createElement('div');
    pageLayout.classList.add('js-page-layout');
    document.body.appendChild(pageLayout);
  });

  afterEach(() => {
    if (pageLayout.parentNode) {
      pageLayout.remove();
    }
  });

  describe('toggleAiPanelMaximizedClass', () => {
    it.each([
      [true, true],
      [false, false],
      [null, false],
      [undefined, false],
    ])('toggles class correctly for value %p', (value, shouldHaveClass) => {
      pageLayout.classList.add('ai-panel-maximized');
      toggleAiPanelMaximizedClass(value);
      expect(pageLayout.classList.contains('ai-panel-maximized')).toBe(shouldHaveClass);
    });

    it('does not throw when page layout element does not exist', () => {
      pageLayout.remove();
      expect(() => {
        toggleAiPanelMaximizedClass(true);
      }).not.toThrow();
    });
  });

  describe('toggleAiPanelOpenClass', () => {
    afterEach(() => {
      document.documentElement.classList.remove('ai-panel-is-open');
    });

    it.each([
      [true, true],
      [false, false],
      [null, false],
      [undefined, false],
    ])('toggles class on :root correctly for value %p', (value, shouldHaveClass) => {
      document.documentElement.classList.add('ai-panel-is-open');
      toggleAiPanelOpenClass(value);
      expect(document.documentElement.classList.contains('ai-panel-is-open')).toBe(shouldHaveClass);
    });
  });
});
