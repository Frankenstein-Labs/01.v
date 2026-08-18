import { nextTick } from 'vue';
import { GlDropdownText } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OperationServiceToken from 'ee/tracing/list/filter_bar/operation_search_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('OperationServiceToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const triggerFetchSuggestions = (searchTerm = null) => {
    findBaseToken().vm.$emit('fetch-suggestions', searchTerm);
    return waitForPromises();
  };

  const findSuggestions = () =>
    findBaseToken()
      .props('suggestions')
      .map(({ name }) => ({ name }));
  const isLoadingSuggestions = () => findBaseToken().props('suggestionsLoading');

  const buildMockServiceFilter = (serviceNames) =>
    serviceNames.map((n) => ({ type: 'service-name', value: { data: n, operator: '=' } }));

  let mockFetchOperations = jest.fn();

  const mountComponent = ({
    active = false,
    currentValue = buildMockServiceFilter(['s1']),
  } = {}) => {
    wrapper = shallowMountExtended(OperationServiceToken, {
      propsData: {
        active,
        config: {
          fetchOperations: mockFetchOperations,
        },
        currentValue,
        value: { data: '' },
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('renders a BaseToken', () => {
      const base = findBaseToken();
      expect(base.exists()).toBe(true);
      expect(base.props('active')).toBe(wrapper.props('active'));
      expect(base.props('config')).toBe(wrapper.props('config'));
      expect(base.props('value')).toBe(wrapper.props('value'));
    });

    it('does not fetch suggestions if not active', async () => {
      await triggerFetchSuggestions();

      expect(mockFetchOperations).not.toHaveBeenCalled();
    });
  });

  describe('when active', () => {
    beforeEach(() => {
      mockFetchOperations.mockImplementation((service) =>
        Promise.resolve({ name: `op-for-${service}` }),
      );
      mountComponent({
        active: true,
        currentValue: buildMockServiceFilter(['s1', 's2']),
      });
    });

    it('fetches the operations suggestions for each service defined in the current filter', async () => {
      expect(isLoadingSuggestions()).toBe(false);

      await triggerFetchSuggestions();

      expect(mockFetchOperations).toHaveBeenCalledTimes(2);

      expect(isLoadingSuggestions()).toBe(false);
      expect(wrapper.findComponent(GlDropdownText).exists()).toBe(false);
      expect(findSuggestions()).toEqual([{ name: 'op-for-s1' }, { name: 'op-for-s2' }]);
    });

    it('only fetch suggestions once', async () => {
      await triggerFetchSuggestions();

      mockFetchOperations.mockClear();

      await triggerFetchSuggestions();

      expect(mockFetchOperations).not.toHaveBeenCalled();
    });

    it('sets the loading status', async () => {
      triggerFetchSuggestions();

      await nextTick();

      expect(isLoadingSuggestions()).toBe(true);
    });

    it('filters suggestions by search term if specified', async () => {
      await triggerFetchSuggestions('s1');

      expect(findSuggestions()).toEqual([{ name: 'op-for-s1' }]);
    });

    describe('when the current filter does not contain service-name filters', () => {
      beforeEach(() => {
        mountComponent({
          active: true,
          currentValue: [
            { type: 'other-type', value: { data: 'other-value', operator: '=' } },
            { type: 'service-name', value: { data: 's1', operator: '!=' } },
          ],
        });
      });

      it('does not fetch suggestions', async () => {
        await triggerFetchSuggestions();

        expect(mockFetchOperations).not.toHaveBeenCalled();
      });

      it('does show a dropdown-text', async () => {
        await triggerFetchSuggestions();

        expect(wrapper.findComponent(GlDropdownText).exists()).toBe(true);
        expect(wrapper.findComponent(GlDropdownText).text()).toBe(
          'Select a service to load suggestions',
        );
      });
    });
  });

  describe('when fetching fails', () => {
    beforeEach(() => {
      mockFetchOperations = jest.fn().mockRejectedValue(new Error('error'));
      mountComponent({ active: true });
    });
    it('shows an alert if fetching fails', async () => {
      await triggerFetchSuggestions();
      await nextTick();

      expect(createAlert).toHaveBeenCalled();
      expect(findSuggestions()).toEqual([]);
      expect(isLoadingSuggestions()).toBe(false);
    });
  });
});
