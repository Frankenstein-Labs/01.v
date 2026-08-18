import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initTitleRegexToggle } from 'ee/pages/projects/settings/merge_requests/init_title_regex_toggle';

describe('initTitleRegexToggle', () => {
  const createFixture = ({ checked = false, hidden = true } = {}) => {
    setHTMLFixture(`
      <input type="checkbox" class="js-title-regex-toggle" data-testid="title-regex-toggle" aria-controls="title-regex-fields" aria-expanded="${checked}" ${checked ? 'checked' : ''} />
      <div id="title-regex-fields" class="js-title-regex-fields ${hidden ? 'gl-hidden' : ''}" data-testid="title-regex-fields">
        <input type="text" class="form-control" name="regex" />
        <input type="text" class="form-control" name="description" />
      </div>
    `);
  };

  const getToggle = () => document.querySelector('[data-testid="title-regex-toggle"]');
  const getFields = () => document.querySelector('[data-testid="title-regex-fields"]');
  const getInputs = () =>
    document.querySelectorAll('[data-testid="title-regex-fields"] input[type="text"].form-control');

  afterEach(() => {
    resetHTMLFixture();
  });

  it('does not throw when elements are missing', () => {
    setHTMLFixture('<div></div>');

    expect(() => initTitleRegexToggle()).not.toThrow();
  });

  describe('on initialization', () => {
    it('hides fields and disables inputs when checkbox is unchecked', () => {
      createFixture({ checked: false, hidden: false });
      initTitleRegexToggle();

      expect(getToggle().getAttribute('aria-expanded')).toBe('false');
      expect(getFields()).toHaveClass('gl-hidden');
      getInputs().forEach((input) => {
        expect(input).toBeDisabled();
      });
    });

    it('shows fields and enables inputs when checkbox is checked', () => {
      createFixture({ checked: true, hidden: true });
      initTitleRegexToggle();

      expect(getToggle().getAttribute('aria-expanded')).toBe('true');
      expect(getFields()).not.toHaveClass('gl-hidden');
      getInputs().forEach((input) => {
        expect(input).not.toBeDisabled();
      });
    });
  });

  describe('on checkbox change', () => {
    it('shows fields and enables inputs when checked', () => {
      createFixture({ checked: false });
      initTitleRegexToggle();

      getToggle().checked = true;
      getToggle().dispatchEvent(new Event('change'));

      expect(getToggle().getAttribute('aria-expanded')).toBe('true');
      expect(getFields()).not.toHaveClass('gl-hidden');
      getInputs().forEach((input) => {
        expect(input).not.toBeDisabled();
      });
    });

    it('hides fields and disables inputs when unchecked', () => {
      createFixture({ checked: true, hidden: false });
      initTitleRegexToggle();

      getToggle().checked = false;
      getToggle().dispatchEvent(new Event('change'));

      expect(getToggle().getAttribute('aria-expanded')).toBe('false');
      expect(getFields()).toHaveClass('gl-hidden');
      getInputs().forEach((input) => {
        expect(input).toBeDisabled();
      });
    });
  });
});
