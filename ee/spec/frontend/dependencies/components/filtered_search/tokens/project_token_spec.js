import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlIntersperse,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ProjectToken from 'ee/dependencies/components/filtered_search/tokens/project_token.vue';
import getProjects from 'ee/dependencies/graphql/projects.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

const TEST_PROJECTS = [
  {
    __typename: 'Project',
    id: 'gid://gitlab/Project/1',
    name: 'GitLab Community Edition',
    fullPath: 'gitlab-org/gitlab-ce',
    avatarUrl: 'https://gitlab.com/uploads/-/system/project/avatar/1/logo-extra-whitespace.png',
  },
  {
    __typename: 'Project',
    id: 'gid://gitlab/Project/2',
    name: 'GitLab Enterprise Edition',
    fullPath: 'gitlab-org/gitlab-ee',
    avatarUrl: 'https://gitlab.com/uploads/-/system/project/avatar/2/logo-extra-whitespace.png',
  },
];

const TEST_GROUP = 'secure';
const TEST_ENDPOINT = `https://gitlab.com/groups/${TEST_GROUP}/-/dependencies.json`;

describe('ee/dependencies/components/filtered_search/tokens/project_token.vue', () => {
  let wrapper;
  let handlerMocks;

  const createMockApolloProvider = ({ handlers = {} } = {}) => {
    const defaultHandlers = {
      getProjectHandler: jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            __typename: 'Group',
            projects: {
              nodes: TEST_PROJECTS,
            },
          },
        },
      }),
    };

    handlerMocks = { ...defaultHandlers, ...handlers };

    const requestHandlers = [[getProjects, handlerMocks.getProjectHandler]];

    return createMockApollo(requestHandlers);
  };

  const createComponent = ({ propsData = {}, handlers = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      provide: {
        endpoint: TEST_ENDPOINT,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
      },
      apolloProvider: createMockApolloProvider({
        handlers,
      }),
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const searchForProject = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };
  const selectProject = (project) => {
    findFilteredSearchToken().vm.$emit('select', project);
    return nextTick();
  };
  const findFirstSearchSuggestionIcon = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);

  describe('when the component is initially rendered', () => {
    beforeEach(createComponent);

    it('shows a loading indicator while fetching the list of projects', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('fetches the list of projects', () => {
      expect(handlerMocks.getProjectHandler).toHaveBeenCalledWith(
        expect.objectContaining({ groupFullPath: TEST_GROUP, search: '', includeSubgroups: true }),
      );
    });

    it.each([
      { active: true, expectedValue: { data: null } },
      { active: false, expectedValue: { data: [] } },
    ])(
      'passes "$expectedValue" to the search-token when the dropdown is open: "$active"',
      ({ active, expectedValue }) => {
        createComponent({
          propsData: {
            active,
            value: { data: [] },
          },
        });

        expect(findFilteredSearchToken().props('value')).toEqual(expectedValue);
      },
    );
  });

  describe('when the projects have been fetched successfully', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('shows a list of project suggestions', () => {
      expect(wrapper.findAllComponents(GlFilteredSearchSuggestion)).toHaveLength(
        TEST_PROJECTS.length,
      );
      expect(wrapper.text()).toContain(TEST_PROJECTS[0].name);
      expect(wrapper.text()).toContain(TEST_PROJECTS[1].name);
    });

    describe('when a user enters a search term', () => {
      it('fetches projects matching the search term', async () => {
        const TEST_SEARCH_TERM = 'GitLab Community';

        expect(handlerMocks.getProjectHandler).toHaveBeenCalledWith(
          expect.objectContaining({ search: '' }),
        );

        await searchForProject(TEST_SEARCH_TERM);

        expect(handlerMocks.getProjectHandler).toHaveBeenLastCalledWith(
          expect.objectContaining({ search: TEST_SEARCH_TERM }),
        );
      });
    });

    describe('when a user selects projects to be filtered', () => {
      it('displays a check-icon next to the selected project', async () => {
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectProject(TEST_PROJECTS[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected projects', async () => {
        await selectProject(TEST_PROJECTS[0]);
        await selectProject(TEST_PROJECTS[1]);

        expect(wrapper.findByTestId('selected-projects').text()).toMatchInterpolatedText(
          `${TEST_PROJECTS[0].name}, ${TEST_PROJECTS[1].name}`,
        );
      });

      it(`emits the selected project's IDs without the GraphQL prefix`, async () => {
        const tokenData = {
          id: 'project_id',
          type: 'project',
          operator: '=',
        };

        const expectedIds = TEST_PROJECTS.map((project) =>
          Number(project.id.replace('gid://gitlab/Project/', '')),
        );

        await selectProject(TEST_PROJECTS[0]);
        await selectProject(TEST_PROJECTS[1]);

        findFilteredSearchToken().vm.$emit('input', tokenData);

        expect(wrapper.emitted('input')).toEqual([
          [
            {
              ...tokenData,
              data: expectedIds,
            },
          ],
        ]);
      });
    });
  });

  describe('when there is an error fetching the projects', () => {
    beforeEach(async () => {
      createComponent({
        handlers: {
          getProjectHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        },
      });

      await waitForPromises();
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching the projects for this group. Please try again later.',
      });
    });
  });
});
