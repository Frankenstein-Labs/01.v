import { GlButton, GlCollapse } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import CollapsibleText from 'ee/agent_artifacts/components/collapsible_text.vue';

describe('CollapsibleText', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(CollapsibleText, {
      propsData: {
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findPreview = () => wrapper.findByTestId('collapsible-text-preview');
  const findFull = () => wrapper.findByTestId('collapsible-text-full');
  const findToggle = () => wrapper.findByTestId('collapsible-text-toggle');
  const findToggleButton = () => wrapper.findComponent(GlButton);
  const findCollapse = () => wrapper.findComponent(GlCollapse);

  describe('when text is shorter than the threshold', () => {
    beforeEach(() => {
      createComponent({ text: 'short text', threshold: 500 });
    });

    it('renders the text inline', () => {
      expect(wrapper.text()).toContain('short text');
    });

    it('does not render the preview, collapse or toggle', () => {
      expect(findPreview().exists()).toBe(false);
      expect(findCollapse().exists()).toBe(false);
      expect(findToggle().exists()).toBe(false);
    });
  });

  describe('when text is longer than the threshold', () => {
    const longText = 'a'.repeat(20);

    beforeEach(() => {
      createComponent({ text: longText, threshold: 5 });
    });

    it('renders the whole text in a single truncated line', () => {
      expect(findPreview().exists()).toBe(true);
      expect(findPreview().text()).toBe(longText);
      expect(findPreview().classes()).toContain('gl-truncate');
    });

    it('renders the full text inside a collapse', () => {
      expect(findCollapse().exists()).toBe(true);
      expect(findFull().text()).toBe(longText);
    });

    it('renders a chevron-right toggle labelled Show more', () => {
      expect(findToggleButton().props('icon')).toBe('chevron-right');
      expect(findToggle().attributes('aria-label')).toBe('Show more');
      expect(findToggle().attributes('aria-expanded')).toBe('false');
    });

    it('shows the label in a tooltip', () => {
      expect(getBinding(findToggle().element, 'gl-tooltip')).toBeDefined();
      expect(findToggle().attributes('title')).toBe('Show more');
    });

    it('collapse is not visible by default', () => {
      expect(findCollapse().props('visible')).toBe(false);
    });

    describe('when the toggle is clicked', () => {
      beforeEach(async () => {
        await findToggle().trigger('click');
      });

      it('expands the collapse and hides the preview', () => {
        expect(findCollapse().props('visible')).toBe(true);
        expect(findPreview().exists()).toBe(false);
      });

      it('flips the toggle to a chevron-down labelled Show less', () => {
        expect(findToggleButton().props('icon')).toBe('chevron-down');
        expect(findToggle().attributes('aria-label')).toBe('Show less');
        expect(findToggle().attributes('aria-expanded')).toBe('true');
      });

      it('updates the tooltip to match', () => {
        expect(findToggle().attributes('title')).toBe('Show less');
      });

      it('collapses again when clicked a second time', async () => {
        await findToggle().trigger('click');

        expect(findCollapse().props('visible')).toBe(false);
        expect(findToggleButton().props('icon')).toBe('chevron-right');
      });
    });
  });

  describe('when text is short but spans multiple lines', () => {
    beforeEach(() => {
      createComponent({ text: 'line one\n\nline two', threshold: 500 });
    });

    it('is collapsible, because it cannot fit on the single collapsed line', () => {
      expect(findPreview().exists()).toBe(true);
      expect(findToggle().exists()).toBe(true);
    });

    it('collapses to the first line only, rather than running the lines together', () => {
      expect(findPreview().text()).toBe('line one…');
    });

    it('still reveals every line when expanded', () => {
      expect(findFull().text()).toBe('line one\n\nline two');
    });
  });

  describe('when text has leading blank lines', () => {
    beforeEach(() => {
      createComponent({ text: '\n\nfirst line\n\nsecond line\n\n', threshold: 500 });
    });

    it('skips them when picking the collapsed line', () => {
      expect(findPreview().text()).toBe('first line…');
    });
  });

  describe('when text is a single line padded with blank lines', () => {
    beforeEach(() => {
      createComponent({ text: '\n\nonly line\n\n', threshold: 500 });
    });

    it('is not collapsible, since the padding hides no content', () => {
      expect(findToggle().exists()).toBe(false);
      expect(wrapper.text()).toContain('only line');
    });
  });

  it('uses the default threshold of 80', () => {
    createComponent({ text: 'a'.repeat(81) });

    expect(findToggle().exists()).toBe(true);
  });
});
