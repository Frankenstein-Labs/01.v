import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceSearchToken from 'ee/tracing/list/filter_bar/service_search_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('ServiceSearchToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const triggerFetchSuggestions = (searchTerm = null) => {
    findBaseToken().vm.$emit('fetch-suggestions', searchTerm);
    return waitForPromises();
  };

  const findSuggestions = () => findBaseToken().props('suggestions');
  const isLoadingSuggestions = () => findBaseToken().props('suggestionsLoading');

  let mockFetchServices = jest.fn();

  const mockServices = [{ name: 's1' }, { name: 's2' }];

  const mountComponent = ({ active = false } = {}) => {
    wrapper = shallowMountExtended(ServiceSearchToken, {
      propsData: {
        active,
        config: { fetchServices: mockFetchServices },
        value: { data: '' },
      },
    });
  };

  beforeEach(() => {
    mockFetchServices = jest.fn().mockResolvedValue(mockServices);
  });

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

      expect(mockFetchServices).not.toHaveBeenCalled();
    });
  });

  describe('when active', () => {
    beforeEach(() => {
      mountComponent({ active: true });
    });

    it('fetches the services suggestions', async () => {
      expect(isLoadingSuggestions()).toBe(false);

      await triggerFetchSuggestions();

      expect(mockFetchServices).toHaveBeenCalled();
      expect(findSuggestions()).toBe(mockServices);
      expect(isLoadingSuggestions()).toBe(false);
    });

    it('only fetch suggestions once', async () => {
      await triggerFetchSuggestions();

      await triggerFetchSuggestions();

      expect(mockFetchServices).toHaveBeenCalledTimes(1);
    });

    it('filters suggestions if a search term is specified', async () => {
      await triggerFetchSuggestions('s1');

      expect(findSuggestions()).toEqual([{ name: 's1' }]);
    });

    it('sets the loading status', async () => {
      triggerFetchSuggestions();

      await nextTick();

      expect(isLoadingSuggestions()).toBe(true);
    });
  });

  describe('when fetching fails', () => {
    beforeEach(() => {
      mockFetchServices = jest.fn().mockRejectedValue(new Error('error'));
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
