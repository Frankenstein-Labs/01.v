import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ComponentNameToken from 'ee/ci/catalog/components/details/tokens/component_name_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getCatalogResourceComponentNames from 'ee/ci/catalog/graphql/queries/get_resource_component_names.query.graphql';

Vue.use(VueApollo);

jest.mock('~/alert');

const mockComponents = [
  { id: 'gid://gitlab/Ci::Catalog::Resources::Component/1', name: 'build' },
  { id: 'gid://gitlab/Ci::Catalog::Resources::Component/2', name: 'deploy' },
  { id: 'gid://gitlab/Ci::Catalog::Resources::Component/3', name: 'lint' },
];

const mockComponentsResponse = {
  data: {
    ciCatalogResource: {
      id: 'gid://gitlab/Ci::Catalog::Resource/1',
      webPath: '/root/my-component',
      versions: {
        nodes: [
          {
            id: 'gid://gitlab/Ci::Catalog::Resources::Version/1',
            components: {
              nodes: mockComponents,
            },
          },
        ],
      },
    },
  },
};

describe('ComponentNameToken', () => {
  let wrapper;
  let queryHandler;

  const resourcePath = 'root/my-component';

  const defaultProps = {
    config: { type: 'component', resourcePath },
    value: { data: '', operator: '=' },
    active: false,
  };

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const setSearchTerm = async (search) => {
    findBaseToken().vm.$emit('fetch-suggestions', search);
    await nextTick();
  };

  const createComponent = ({ props = {}, handler = queryHandler } = {}) => {
    const mockApollo = createMockApollo([[getCatalogResourceComponentNames, handler]]);

    wrapper = shallowMount(ComponentNameToken, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(mockComponentsResponse);
  });

  it('renders the base token with correct initial props', () => {
    createComponent();

    expect(findBaseToken().props()).toMatchObject({
      active: false,
      config: defaultProps.config,
      value: defaultProps.value,
      suggestions: [],
      suggestionsLoading: true,
    });
  });

  describe('fetching components', () => {
    it('queries with fullPath from config', async () => {
      createComponent();
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledWith({ fullPath: resourcePath });
    });

    it('sets suggestionsLoading while the initial query is loading', async () => {
      createComponent();

      expect(findBaseToken().props('suggestionsLoading')).toBe(true);

      await waitForPromises();
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });

    it('shows an alert when the query fails', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      createComponent({ handler: errorHandler });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching components.',
      });
    });
  });

  describe('suggestions', () => {
    it('returns all components when no search term is set', async () => {
      createComponent();
      await waitForPromises();

      expect(findBaseToken().props('suggestions')).toEqual([
        { value: 'build', text: 'build' },
        { value: 'deploy', text: 'deploy' },
        { value: 'lint', text: 'lint' },
      ]);
    });

    it('filters suggestions case-insensitively when a search term is provided', async () => {
      createComponent();
      await waitForPromises();

      await setSearchTerm('LI');

      expect(findBaseToken().props('suggestions')).toEqual([{ value: 'lint', text: 'lint' }]);
    });

    it('returns empty suggestions when nothing matches', async () => {
      createComponent();
      await waitForPromises();

      await setSearchTerm('does-not-exist');

      expect(findBaseToken().props('suggestions')).toEqual([]);
    });

    it('returns empty suggestions when the components list is empty', async () => {
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
      await waitForPromises();

      expect(findBaseToken().props('suggestions')).toEqual([]);
    });
  });
});
