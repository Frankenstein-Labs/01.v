import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import VersionToken from 'ee/ci/catalog/components/details/tokens/version_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getCiCatalogResourceVersions from '~/ci/catalog/graphql/queries/get_ci_catalog_resource_versions.query.graphql';

Vue.use(VueApollo);

jest.mock('~/alert');

const mockVersions = [
  { id: 'gid://gitlab/Ci::Catalog::Resources::Version/1', name: '1.0.0', releasedAt: '2024-01-01' },
  { id: 'gid://gitlab/Ci::Catalog::Resources::Version/2', name: '2.0.0', releasedAt: '2024-02-01' },
];

const mockVersionsResponse = {
  data: {
    ciCatalogResource: {
      id: 'gid://gitlab/Ci::Catalog::Resource/1',
      webPath: '/root/my-component',
      versions: {
        nodes: mockVersions,
      },
    },
  },
};

describe('VersionToken', () => {
  let wrapper;
  let queryHandler;

  const resourcePath = 'root/my-component';

  const defaultProps = {
    config: { type: 'version', multiSelect: true, resourcePath },
    value: { data: '', operator: '||' },
    active: false,
  };

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const triggerFetchSuggestions = async (search = '') => {
    findBaseToken().vm.$emit('fetch-suggestions', search);
    await waitForPromises();
    await nextTick();
  };

  const createComponent = ({ props = {}, handler = queryHandler } = {}) => {
    const mockApollo = createMockApollo([[getCiCatalogResourceVersions, handler]]);

    wrapper = shallowMount(VersionToken, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(mockVersionsResponse);
  });

  it('renders the base token with correct initial props', () => {
    createComponent();

    expect(findBaseToken().props()).toMatchObject({
      active: false,
      config: defaultProps.config,
      value: defaultProps.value,
      suggestions: [],
      suggestionsLoading: false,
    });
  });

  describe('fetching versions', () => {
    it('queries with fullPath from config and the search term', async () => {
      createComponent();

      await triggerFetchSuggestions('2.0');

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: resourcePath,
        search: '2.0',
      });
    });

    it('emits suggestions where value is the id and text is the name', async () => {
      createComponent();

      await triggerFetchSuggestions();

      expect(findBaseToken().props('suggestions')).toEqual([
        { value: 'gid://gitlab/Ci::Catalog::Resources::Version/1', text: '1.0.0' },
        { value: 'gid://gitlab/Ci::Catalog::Resources::Version/2', text: '2.0.0' },
      ]);
    });

    it('toggles suggestionsLoading around the request', async () => {
      createComponent();

      expect(findBaseToken().props('suggestionsLoading')).toBe(false);

      findBaseToken().vm.$emit('fetch-suggestions', '');
      await nextTick();

      expect(findBaseToken().props('suggestionsLoading')).toBe(true);

      await waitForPromises();
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });

    it('returns empty suggestions when no versions are found', async () => {
      const emptyHandler = jest.fn().mockResolvedValue({
        data: {
          ciCatalogResource: {
            id: 'gid://gitlab/Ci::Catalog::Resource/1',
            webPath: '/root/my-component',
            versions: {
              nodes: [],
            },
          },
        },
      });
      createComponent({ handler: emptyHandler });

      await triggerFetchSuggestions();

      expect(findBaseToken().props('suggestions')).toEqual([]);
    });

    it('shows an alert when the query fails', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      createComponent({ handler: errorHandler });

      await triggerFetchSuggestions();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching versions.',
      });
    });
  });

  describe('resolving names across searches', () => {
    const firstSearchResponse = {
      data: {
        ciCatalogResource: {
          id: 'gid://gitlab/Ci::Catalog::Resource/1',
          webPath: '/root/my-component',
          versions: { nodes: [mockVersions[0]] },
        },
      },
    };
    const secondSearchResponse = {
      data: {
        ciCatalogResource: {
          id: 'gid://gitlab/Ci::Catalog::Resource/1',
          webPath: '/root/my-component',
          versions: { nodes: [mockVersions[1]] },
        },
      },
    };

    it('resolves an active token via cached versions when the suggestion list no longer contains it', async () => {
      const handler = jest
        .fn()
        .mockResolvedValueOnce(firstSearchResponse)
        .mockResolvedValueOnce(secondSearchResponse);
      createComponent({ handler });

      await triggerFetchSuggestions('1.0');
      await triggerFetchSuggestions('2.0');

      const activeTokenValue = findBaseToken().props('getActiveTokenValue')(
        findBaseToken().props('suggestions'),
        'gid://gitlab/Ci::Catalog::Resources::Version/1',
      );

      expect(activeTokenValue).toEqual({
        value: 'gid://gitlab/Ci::Catalog::Resources::Version/1',
        text: '1.0.0',
      });
    });
  });
});
