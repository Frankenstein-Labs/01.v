import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlLoadingIcon,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import groupDependencies from 'ee/dependencies/graphql/group_components.query.graphql';
import createStore from 'ee/dependencies/store';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

const TEST_COMPONENTS = [
  {
    id: 'gid://gitlab/Sbom::Component/53',
    name: 'selenium-webdriver',
    __typename: 'Component',
  },
  {
    id: 'gid://gitlab/Sbom::Component/66',
    name: 'web-console',
    __typename: 'Component',
  },
  {
    id: 'gid://gitlab/Sbom::Component/67',
    name: 'websocket-driver',
    __typename: 'Component',
  },
  {
    id: 'gid://gitlab/Sbom::Component/68',
    name: 'websocket-extensions',
    __typename: 'Component',
  },
  {
    id: 'gid://gitlab/Sbom::Component/69',
    name: 'Is',
    __typename: 'Component',
  },
];

describe('ee/dependencies/components/filtered_search/tokens/component_token.vue', () => {
  let wrapper;
  let store;
  let handlerMocks;

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createMockApolloProvider = (handlers) => {
    const defaultHandlers = {
      getGroupComponentsHandler: jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'some-group-id',
            components: TEST_COMPONENTS,
          },
        },
      }),
    };
    handlerMocks = { ...defaultHandlers, ...handlers };

    const requestHandlers = [[groupDependencies, handlerMocks.getGroupComponentsHandler]];

    return createMockApollo(requestHandlers);
  };

  const createComponent = ({
    propsData = {},
    handlers = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    let additionalInjections = {};

    if (mountFn === mountExtended) {
      additionalInjections = {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        suggestionsListClass: () => 'custom-class',
      };
    }

    wrapper = mountFn(ComponentToken, {
      store,
      provide: {
        ...additionalInjections,
        groupFullPath: 'secure',
        namespaceType: 'group',
        projectFullPath: undefined,
      },
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      stubs: {
        Portal: {
          mounted() {
            wrapper.portal = this.$el;
          },
          template: '<div><slot></slot></div>',
        },
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  beforeEach(() => {
    createVuexStore();
  });

  const isLoadingSuggestions = () => wrapper.findComponent(GlLoadingIcon).exists();
  const findSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findFirstSearchSuggestionIcon = () => findSuggestions().at(0).findComponent(GlIcon);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const toggleDropdown = async (trueOrFalse) => {
    wrapper.setProps({ active: trueOrFalse });
    await nextTick();
  };
  const selectComponent = async (component, closeSuggestions = false) => {
    findFilteredSearchToken().vm.$emit('select', component);

    if (closeSuggestions) {
      // Needed to apply the changes and display the placeholder - if not
      // provided the search suggestions will keep appearing
      await toggleDropdown(false);
    }
  };
  const searchForComponent = async (searchTerm = '', waitPromises = true) => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });

    // Needed to display the search suggestions
    await toggleDropdown(true);

    // Advance same as `debounce` config
    jest.advanceTimersByTime(300);

    if (waitPromises) {
      await waitForPromises();
    }
  };

  describe('when the component is initially rendered', () => {
    it('shows a loading indicator while fetching the list of licenses', async () => {
      createComponent();

      // Initially is false because we're not searching
      expect(isLoadingSuggestions()).toBe(false);

      await searchForComponent('web', false);

      expect(isLoadingSuggestions()).toBe(true);
    });

    it.each([
      { active: true, expectedValue: { data: null } },
      { active: false, expectedValue: { data: [] } },
    ])(
      'passes "$expectedValue" to the search-token when the dropdown is open: "$active"',
      async ({ active, expectedValue }) => {
        createComponent({
          propsData: {
            active,
            value: { data: [] },
          },
        });

        await waitForPromises();

        expect(findFilteredSearchToken().props('value')).toEqual(expectedValue);
      },
    );
  });

  describe('when the list of components have been fetched successfully', () => {
    beforeEach(async () => {
      createComponent({ mountFn: mountExtended });

      // Search is needed to display the search suggestions
      await searchForComponent('web');

      // Wait until loading icon is replaced with actual list
      await nextTick();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('does not show a loading indicator', () => {
      expect(isLoadingSuggestions()).toBe(false);
    });

    describe('when a user selects components to be filtered', () => {
      it('displays a check-icon next to the selected component', async () => {
        createComponent();
        await searchForComponent('web');
        await nextTick();

        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectComponent(TEST_COMPONENTS[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected component', async () => {
        await selectComponent(TEST_COMPONENTS[0]);
        await selectComponent(TEST_COMPONENTS[1], true);

        expect(wrapper.findByTestId('selected-components').text()).toMatchInterpolatedText(
          `${TEST_COMPONENTS[0].name}, ${TEST_COMPONENTS[1].name}`,
        );
      });
    });
  });

  describe('when a user enters a search term', () => {
    beforeEach(() => {
      createComponent({ mountFn: shallowMountExtended });
    });

    it('shows the filtered list of components', async () => {
      await searchForComponent(TEST_COMPONENTS[0].name);

      expect(findSuggestions()).toHaveLength(1);
      expect(findSuggestions().at(0).text()).toBe(TEST_COMPONENTS[0].name);
    });

    it('shows the already selected components in the filtered list', async () => {
      await searchForComponent(TEST_COMPONENTS[1].name);
      await selectComponent(TEST_COMPONENTS[1], true);
      await toggleDropdown(true);

      expect(findSuggestions()).toHaveLength(1);
    });

    it('allows searching for 2-character package names', async () => {
      await searchForComponent('Is');

      expect(findSuggestions()).toHaveLength(1);
      expect(findSuggestions().at(0).text()).toBe('Is');
    });
  });

  describe('when there is an error fetching the list of components', () => {
    beforeEach(async () => {
      createComponent({
        handlers: {
          getGroupComponentsHandler: jest.fn().mockRejectedValue(new Error('An error occurred')),
        },
      });

      // We need to search for the component to trigger a graphql request
      await searchForComponent('web');
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalled();
    });

    it('does not show a loading indicator', () => {
      expect(isLoadingSuggestions()).toBe(false);
    });

    it('does not show any suggestions', () => {
      expect(findSuggestions().exists()).toBe(false);
    });
  });

  describe('where there is a suggestion dropdown', () => {
    it('displays when user types less than 2 characters', async () => {
      createComponent();

      const suggestionText = 'Enter at least 2 characters to view available components.';

      await searchForComponent('w');
      expect(wrapper.text()).toBe(suggestionText);

      await searchForComponent('we');
      expect(wrapper.text()).not.toBe(suggestionText);
    });

    it('displays when no results are found', async () => {
      createComponent({
        handlers: {
          getGroupComponentsHandler: jest.fn().mockResolvedValue({
            data: {
              group: {
                id: 'some-group-id',
                components: [],
              },
            },
          }),
        },
      });

      await searchForComponent('XXXXXXXX');

      expect(wrapper.text()).toBe('No components found.');
    });
  });
});
