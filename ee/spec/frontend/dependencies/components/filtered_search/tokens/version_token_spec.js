import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlIntersectionObserver,
  GlIntersperse,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import getProjectComponentVersions from 'ee/dependencies/graphql/project_component_versions.query.graphql';
import getGroupComponentVersions from 'ee/dependencies/graphql/group_component_versions.query.graphql';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import createStore from 'ee/dependencies/store';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from 'ee/dependencies/constants';
import { OPERATORS_IS_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);
jest.mock('~/alert');

const TEST_VERSIONS = [
  {
    id: 'gid://gitlab/Sbom::ComponentVersion/1',
    version: '1.1.1',
  },
  {
    id: 'gid://gitlab/Sbom::ComponentVersion/2',
    version: '2.0.0',
  },
];
const DEFAULT_PAGE_INFO = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
};
const END_CURSOR = 'ABC';
const FULL_PATH = 'gitlab-org/project-1';
const TEST_CONFIG = {
  multiSelect: true,
  operators: OPERATORS_IS_NOT,
};

describe('ee/dependencies/components/filtered_search/tokens/version_token.vue', () => {
  let wrapper;
  let store;
  let requestHandlers;

  const createVuexStore = () => {
    store = createStore();
  };

  const mockApolloHandlers = (nodes = TEST_VERSIONS, hasNextPage = false) => {
    const MOCK_RESPONSE = {
      data: {
        namespace: {
          id: '1',
          componentVersions: {
            nodes,
            pageInfo: {
              ...DEFAULT_PAGE_INFO,
              hasNextPage,
              endCursor: hasNextPage ? END_CURSOR : null,
            },
          },
        },
      },
    };

    return {
      projectHandler: jest.fn().mockResolvedValue(MOCK_RESPONSE),
      groupHandler: jest.fn().mockResolvedValue(MOCK_RESPONSE),
    };
  };

  const createMockApolloProvider = (handlers) => {
    requestHandlers = handlers;
    return createMockApollo([
      [getProjectComponentVersions, requestHandlers.projectHandler],
      [getGroupComponentVersions, requestHandlers.groupHandler],
    ]);
  };

  const createComponent = (handlers = mockApolloHandlers(), namespaceType = NAMESPACE_PROJECT) => {
    wrapper = shallowMountExtended(VersionToken, {
      store,
      apolloProvider: createMockApolloProvider(handlers),
      provide: {
        fullPath: FULL_PATH,
        namespaceType,
      },
      propsData: {
        config: TEST_CONFIG,
        value: {},
        active: false,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findFirstSearchSuggestionIcon = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);
  const selectVersion = (version) => {
    findFilteredSearchToken().vm.$emit('select', version);
    return nextTick();
  };

  const setComponentNames = (componentNames) => {
    store.state.searchFilterParameters = { component_names: componentNames };
  };

  beforeEach(() => {
    createVuexStore();
    createComponent();
  });

  describe('when the component is initially rendered', () => {
    it('passes the correct props to the GlFilteredSearchToken', () => {
      expect(findFilteredSearchToken().props()).toMatchObject({
        config: { multiSelect: true },
        value: { data: [] },
        viewOnly: true,
        active: false,
      });
    });
  });

  describe('when no components are selected', () => {
    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, filter by one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });

    it('sets only 1 operator in config', () => {
      expect(findFilteredSearchToken().props('config').operators).toHaveLength(1);
    });

    it('does not fetch versions', () => {
      expect(requestHandlers.projectHandler).not.toHaveBeenCalled();
      expect(requestHandlers.groupHandler).not.toHaveBeenCalled();
    });
  });

  describe('when multiple components are selected', () => {
    beforeEach(() => {
      setComponentNames(['git', 'lodash']);
    });

    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, select exactly one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });

    it('sets only 1 operator in config', () => {
      expect(findFilteredSearchToken().props('config').operators).toHaveLength(1);
    });

    it('does not fetch versions', () => {
      expect(requestHandlers.projectHandler).not.toHaveBeenCalled();
      expect(requestHandlers.groupHandler).not.toHaveBeenCalled();
    });
  });

  describe('when exactly one component is selected', () => {
    const componentNames = ['git'];
    beforeEach(() => {
      setComponentNames(componentNames);
    });

    it('does not show any guidance messages', () => {
      expect(findFilteredSearchToken().text()).toBe('');
    });

    it('sets viewOnly prop to false', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(false);
    });

    it('passes config correctly through', () => {
      expect(findFilteredSearchToken().props('config')).toEqual(TEST_CONFIG);
    });

    it('shows a loading indicator while fetching the list of versions', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it.each`
      namespaceType        | requestHandlerFn
      ${NAMESPACE_GROUP}   | ${() => requestHandlers.groupHandler}
      ${NAMESPACE_PROJECT} | ${() => requestHandlers.projectHandler}
    `('fetches the list of versions', ({ namespaceType, requestHandlerFn }) => {
      createComponent(mockApolloHandlers(), namespaceType);
      setComponentNames(componentNames);

      expect(requestHandlerFn()).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: FULL_PATH, componentName: componentNames[0] }),
      );
    });
  });

  describe('when the versions have been fetched successfully', () => {
    beforeEach(async () => {
      setComponentNames(['git']);
      await waitForPromises();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('shows a list of versions', () => {
      expect(wrapper.findAllComponents(GlFilteredSearchSuggestion)).toHaveLength(
        TEST_VERSIONS.length,
      );
      expect(wrapper.text()).toContain(TEST_VERSIONS[0].version);
      expect(wrapper.text()).toContain(TEST_VERSIONS[1].version);
    });

    describe('when a user selects versions to be filtered', () => {
      it('displays a check-icon next to the selected project', async () => {
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectVersion(TEST_VERSIONS[0].version);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('does not display check-icon if unchecked again', async () => {
        await selectVersion(TEST_VERSIONS[0].version);
        await selectVersion(TEST_VERSIONS[0].version);
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected versions', async () => {
        await selectVersion(TEST_VERSIONS[0].version);
        await selectVersion(TEST_VERSIONS[1].version);

        expect(wrapper.findByTestId('selected-versions').text()).toMatchInterpolatedText(
          `${TEST_VERSIONS[0].version}, ${TEST_VERSIONS[1].version}`,
        );
      });
    });
  });

  describe('when there is an error fetching the versions', () => {
    beforeEach(async () => {
      createComponent({
        projectHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      setComponentNames(['git']);

      await waitForPromises();
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'There was an error fetching the versions for the selected component. Please try again later.',
      });
    });
  });

  describe('when there is a next page', () => {
    const componentNames = ['git'];

    beforeEach(async () => {
      createComponent(mockApolloHandlers([], true));
      setComponentNames(componentNames);
      await waitForPromises();
    });

    it('fetches more versions when scrolled to the bottom', () => {
      expect(requestHandlers.projectHandler).toHaveBeenCalledTimes(1);

      wrapper.findComponent(GlIntersectionObserver).vm.$emit('appear');

      expect(requestHandlers.projectHandler).toHaveBeenCalledTimes(2);
      expect(requestHandlers.projectHandler).toHaveBeenNthCalledWith(2, {
        after: END_CURSOR,
        fullPath: FULL_PATH,
        componentName: componentNames[0],
      });
    });
  });

  describe('when `componentNames` changes', () => {
    beforeEach(async () => {
      createVuexStore();
      // Setting component names before creating the component to simulate store state
      // already being set before token is created
      setComponentNames(['git']);
      createComponent();
      await waitForPromises();
    });

    it('emits "destroy" event', async () => {
      expect(wrapper.emitted('destroy')).toBeUndefined();

      setComponentNames([]);
      await waitForPromises();

      expect(wrapper.emitted('destroy')).toHaveLength(1);
    });
  });
});
