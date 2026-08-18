import { GlFilteredSearchToken } from '@gitlab/ui';
import { nextTick } from 'vue';
import ValidityCheckToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/validity_check_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ValidityCheckToken', () => {
  let wrapper;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['UNKNOWN'], operator: '&&' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ValidityCheckToken, {
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: 'UNKNOWN',
        operator: '&&',
      });
      expect(wrapper.findByTestId('validity-check-token-placeholder').text()).toBe(
        'Possibly active secret',
      );
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'Active secret',
        'Possibly active secret',
        'Inactive secret',
      ]);
    });

    it('shows no initial selected value', () => {
      createWrapper({ value: { data: [], operator: '&&' } });
      expect(isOptionChecked('UNKNOWN')).toBe(false);
      expect(isOptionChecked('ACTIVE')).toBe(false);
      expect(isOptionChecked('INACTIVE')).toBe(false);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper();
      await clickDropdownItem('UNKNOWN');
    });

    it('does not allow multiple selection', async () => {
      await clickDropdownItem('UNKNOWN', 'ACTIVE');

      expect(isOptionChecked('UNKNOWN')).toBe(false);
      expect(isOptionChecked('INACTIVE')).toBe(false);
      expect(isOptionChecked('ACTIVE')).toBe(true);
    });

    it('does not show "+1 more" for single selections', () => {
      createWrapper({ value: { data: ['INACTIVE'], operator: '&&' } });

      const displayText = wrapper.findByTestId('validity-check-token-placeholder').text();
      expect(displayText).toBe('Inactive secret');
      expect(displayText).not.toContain('+1 more');
    });
  });

  describe('tooltip', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows tooltip for UNKNOWN value', () => {
      expect(wrapper.findComponentByTestId('suggestion-UNKNOWN').props('tooltipText')).toBe(
        "Validity check couldn't confirm whether the secret is active or inactive.",
      );
    });

    it.each(['ACTIVE', 'INACTIVE'])('does not show tooltip for %s', (value) => {
      expect(wrapper.findComponentByTestId(`suggestion-${value}`).props('tooltipText')).toBe('');
    });
  });
});
