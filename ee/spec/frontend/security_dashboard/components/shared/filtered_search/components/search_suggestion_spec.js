import { GlFilteredSearchSuggestion, GlTruncate, GlIcon } from '@gitlab/ui';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

describe('Search Suggestion', () => {
  let wrapper;

  const defaultProps = {
    text: 'My text',
    value: 'my_value',
    selected: false,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(SearchSuggestion, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });
  };

  const findGlSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);

  it.each`
    selected
    ${true}
    ${false}
  `('renders search suggestions as expected when selected is $selected', ({ selected }) => {
    createWrapper({ selected });

    const { text, value } = defaultProps;
    expect(wrapper.findByText(text).exists()).toBe(true);
    expect(findGlSearchSuggestion().props('value')).toBe(value);
    expect(wrapper.findComponent(GlIcon).classes('gl-invisible')).toBe(!selected);
  });

  it.each`
    truncate
    ${true}
    ${false}
  `('truncates the text when `truncate` property is $truncate', ({ truncate }) => {
    createWrapper({ truncate });
    expect(wrapper.findComponent(GlTruncate).exists()).toBe(truncate);
  });

  it('truncates the text when `truncate` property is $truncate', () => {
    createWrapper({ truncate: true });

    const { text } = defaultProps;
    expect(wrapper.findComponent(GlTruncate).props('text')).toBe(text);
  });

  describe('tooltip', () => {
    const findTooltipIcon = () => wrapper.findByTestId('tooltip-icon');

    it('shows tooltip icon when tooltipText is provided', () => {
      const tooltipText = 'Help text';

      createWrapper({ tooltipText });

      const tooltip = getBinding(findTooltipIcon().element, 'gl-tooltip');
      expect(tooltip).toBeDefined();
      expect(findTooltipIcon().attributes('title')).toBe(tooltipText);
    });

    it('hides tooltip icon when tooltipText is empty', () => {
      createWrapper();
      expect(findTooltipIcon().exists()).toBe(false);
    });

    it('configures tooltip with viewport boundary', () => {
      const tooltipText = 'Help text';
      createWrapper({ tooltipText });

      const tooltip = getBinding(findTooltipIcon().element, 'gl-tooltip');
      expect(tooltip.value).toEqual({ boundary: 'viewport' });
    });
  });
});
