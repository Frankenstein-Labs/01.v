import { GlFilteredSearchToken } from '@gitlab/ui';
import { nextTick } from 'vue';
import ReachabilityToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/reachability_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ReachabilityToken', () => {
  let wrapper;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['IN_USE'], operator: '&&' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ReachabilityToken, {
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
        QuerystringSync: true,
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
        data: 'IN_USE',
        operator: '&&',
      });
      expect(wrapper.findByTestId('reachability-token-placeholder').text()).toBe('Yes');
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual(['Yes', 'Not found', 'Not available']);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper();
      await clickDropdownItem('IN_USE');
    });

    it('does not allow multiple selection', async () => {
      await clickDropdownItem('IN_USE', 'NOT_FOUND');

      expect(isOptionChecked('IN_USE')).toBe(false);
      expect(isOptionChecked('UNKNOWN')).toBe(false);
      expect(isOptionChecked('NOT_FOUND')).toBe(true);
    });
  });
});
