import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PagesProjects from 'ee/usage_quotas/pages/components/project_list.vue';
import ProjectView from 'ee/usage_quotas/pages/components/project.vue';
import { GROUP_VIEW_TYPE, PROFILE_VIEW_TYPE, PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import GetNamespacePagesDeployments from 'ee/usage_quotas/pages/graphql/pages_deployments.query.graphql';
import GetProjectPagesDeployments from '~/gitlab_pages/queries/get_project_pages_deployments.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getNamespacePagesDeploymentsMockData,
  getProjectPagesDeploymentsMockData,
  getEmptyNamespacePagesDeploymentsMockData,
  getEmptyProjectPagesDeploymentsMockData,
  mockError,
} from './mock_data';

jest.mock(
  '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg?url',
  () => 'mocked-svg-url',
);

Vue.use(VueApollo);

describe('PagesProjects', () => {
  const mockNamespaceProjects = getNamespacePagesDeploymentsMockData.data.namespace.projects.nodes;
  const mockProject = getProjectPagesDeploymentsMockData.data.project;
  const getNamespacePagesDeploymentsQueryHandler = jest
    .fn()
    .mockResolvedValue(getNamespacePagesDeploymentsMockData);
  const getProjectPagesDeploymentsQueryHandler = jest
    .fn()
    .mockResolvedValue(getProjectPagesDeploymentsMockData);
  const getAllHandlersMockedWithFn = (fn) => [
    [GetNamespacePagesDeployments, fn],
    [GetProjectPagesDeployments, fn],
  ];
  const defaultHandler = [
    [GetNamespacePagesDeployments, getNamespacePagesDeploymentsQueryHandler],
    [GetProjectPagesDeployments, getProjectPagesDeploymentsQueryHandler],
  ];
  const errorHandler = getAllHandlersMockedWithFn(jest.fn().mockRejectedValue(mockError));
  const foreverLoadingHandler = getAllHandlersMockedWithFn(Promise);
  const emptyResultsHandler = [
    [
      GetNamespacePagesDeployments,
      jest.fn().mockResolvedValue(getEmptyNamespacePagesDeploymentsMockData),
    ],
    [
      GetProjectPagesDeployments,
      jest.fn().mockResolvedValue(getEmptyProjectPagesDeploymentsMockData),
    ],
  ];

  let wrapper;
  let mockApollo;
  let viewType;

  const createComponent = (handler = defaultHandler, props = {}) => {
    mockApollo = createMockApollo(handler);

    return shallowMount(PagesProjects, {
      propsData: props,
      provide: {
        fullPath: 'test/path',
        viewType,
      },
      apolloProvider: mockApollo,
    });
  };

  describe.each`
    view                 | expectedHandler
    ${GROUP_VIEW_TYPE}   | ${getNamespacePagesDeploymentsQueryHandler}
    ${PROFILE_VIEW_TYPE} | ${getNamespacePagesDeploymentsQueryHandler}
    ${PROJECT_VIEW_TYPE} | ${getProjectPagesDeploymentsQueryHandler}
  `(`in a $view`, ({ view, expectedHandler }) => {
    beforeEach(() => {
      viewType = view;
    });

    it('calls the apollo query with the expected variables', () => {
      wrapper = createComponent(defaultHandler, { sort: 'UPDATED_ASC' });

      expect(expectedHandler).toHaveBeenCalledWith({
        fullPath: 'test/path',
        first: 15,
        sort: 'UPDATED_ASC',
        active: true,
        versioned: true,
      });
    });

    it('renders loading icon while loading', () => {
      wrapper = createComponent(foreverLoadingHandler);

      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('does not show projects with no pages deployments', async () => {
      wrapper = createComponent();

      await waitForPromises();

      const projectRows = wrapper.findAllComponents(ProjectView);
      expect(projectRows.wrappers.map((w) => w.props('project').id)).not.toContain(
        'gid://gitlab/Project/3',
      );
    });

    it('renders error alert when apollo has an error', async () => {
      wrapper = createComponent(errorHandler);

      await waitForPromises();

      const alert = wrapper.findComponent(GlAlert);
      expect(alert.exists()).toBe(true);
      expect(alert.props('variant')).toBe('danger');
      expect(alert.text()).toContain('An error occurred trying to load the Pages deployments.');
    });
  });

  describe.each([GROUP_VIEW_TYPE, PROFILE_VIEW_TYPE])('namespace view', (i, view) => {
    beforeEach(() => {
      viewType = view;
    });

    it('renders project rows when there are results', async () => {
      wrapper = createComponent();

      await waitForPromises();

      const projectRows = wrapper.findAllComponents(ProjectView);
      expect(projectRows).toHaveLength(2);
      expect(projectRows.at(0).props('project')).toEqual(mockNamespaceProjects[0]);
      expect(projectRows.at(1).props('project')).toEqual(mockNamespaceProjects[2]);
    });

    it('renders empty state when the project list is empty', async () => {
      wrapper = createComponent(emptyResultsHandler);

      await waitForPromises();

      const emptyState = wrapper.findComponent(GlEmptyState);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('title')).toBe('No projects found');
      expect(emptyState.props('svgPath')).toBe('mocked-svg-url');
    });
  });

  describe('project view', () => {
    beforeEach(() => {
      viewType = PROJECT_VIEW_TYPE;
    });

    it('renders project rows when there are results', async () => {
      wrapper = createComponent();

      await waitForPromises();

      const projectRows = wrapper.findAllComponents(ProjectView);
      expect(projectRows).toHaveLength(1);
      expect(projectRows.at(0).props('project')).toEqual(mockProject);
    });

    it('renders empty state when the project list is empty', async () => {
      wrapper = createComponent(emptyResultsHandler);

      await waitForPromises();

      const emptyState = wrapper.findComponent(GlEmptyState);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('title')).toBe('No parallel deployments');
      expect(emptyState.props('svgPath')).toBe('mocked-svg-url');
    });
  });
});
