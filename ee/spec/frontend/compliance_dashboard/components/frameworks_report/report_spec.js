import { mount, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  createComplianceFrameworksReportResponse,
  createDeleteFrameworkResponse,
} from 'ee_jest/compliance_dashboard/mock_data';

import ComplianceFrameworksReport from 'ee/compliance_dashboard/components/frameworks_report/report.vue';
import groupComplianceFrameworks from 'ee/compliance_dashboard/components/frameworks_report/graphql/compliance_frameworks_group_list.query.graphql';
import projectComplianceFrameworks from 'ee/compliance_dashboard/components/frameworks_report/graphql/compliance_frameworks_project_list.query.graphql';
import deleteComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_framework.mutation.graphql';
import { createAlert } from '~/alert';

import { ROUTE_FRAMEWORKS } from 'ee/compliance_dashboard/constants';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ComplianceFrameworksReport component', () => {
  let wrapper;
  let apolloProvider;
  const fullPath = 'group-path';
  let $router;

  const sentryError = new Error('GraphQL networkError');
  const frameworksResponse = createComplianceFrameworksReportResponse({ projects: 2 });
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockFrameworksGraphQlSuccess = jest.fn().mockResolvedValue(frameworksResponse);
  const mockGraphQlError = jest.fn().mockRejectedValue(sentryError);
  const mockDeleteFrameworkSuccess = jest.fn().mockResolvedValue(createDeleteFrameworkResponse());
  const mockDeleteFrameworkError = jest
    .fn()
    .mockResolvedValue(createDeleteFrameworkResponse(['Could not delete framework']));

  const findQueryError = () => wrapper.findComponentByTestId('query-error-alert');
  const findMaintenanceAlert = () => wrapper.findComponentByTestId('maintenance-mode-alert');
  const findFrameworksTable = () => wrapper.findComponent({ name: 'FrameworksTable' });
  const findPagination = () => wrapper.findComponent({ name: 'GlKeysetPagination' });

  const defaultPaginationAndLimits = {
    before: null,
    after: null,
    first: 20,
    search: '',
    projectLimit: 10,
    sort: 'UPDATED_AT_DESC',
  };

  const defaultInjects = {
    migratePipelineToPolicyPath: '/migrate-pipeline--to-policy-example-path',
    pipelineExecutionPolicyPath: '/pipeline-execution-policy-example-path',
    groupSecurityPoliciesPath: '/group-security-policies-example-path',
    canAccessRootAncestorComplianceCenter: true,
    policyDisplayLimit: true,
  };

  function createComponent({
    mountFn = shallowMount,
    props = {},
    complianceFrameworksGroupResolverMock = mockGraphQlLoading,
    complianceFrameworksProjectResolverMock = mockGraphQlLoading,
    deleteFrameworkResolverMock = mockDeleteFrameworkSuccess,
    queryParams = {},
    provide = {},
  } = {}) {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    apolloProvider = createMockApollo([
      [groupComplianceFrameworks, complianceFrameworksGroupResolverMock],
      [projectComplianceFrameworks, complianceFrameworksProjectResolverMock],
      [deleteComplianceFrameworkMutation, deleteFrameworkResolverMock],
    ]);

    wrapper = extendedWrapper(
      mountFn(ComplianceFrameworksReport, {
        apolloProvider,
        propsData: {
          groupPath: fullPath,
          rootAncestor: {
            path: fullPath,
          },
          ...props,
        },
        provide: {
          ...defaultInjects,
          ...provide,
        },
        mocks: {
          $router,
          $route: {
            name: ROUTE_FRAMEWORKS,
            query: currentQueryParams,
          },
        },
      }),
    );
  }

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render an error message', () => {
      expect(findQueryError().exists()).toBe(false);
    });
  });

  describe('maintenence mode', () => {
    beforeEach(() => {
      createComponent({ mountFn: mount });
    });

    it('renders the maintenance-mode-alert', () => {
      const maintenanceAlert = findMaintenanceAlert();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(maintenanceAlert.text()).toContain('Compliance pipelines are deprecated');
    });

    it('can dismiss the maintenance-mode-alert', async () => {
      const maintenanceAlert = findMaintenanceAlert();
      expect(maintenanceAlert.exists()).toBe(true);

      maintenanceAlert.vm.$emit('dismiss');
      await nextTick();

      expect(maintenanceAlert.exists()).toBe(false);
    });
  });

  describe('when initializing in top-level group', () => {
    beforeEach(() => {
      createComponent({ mountFn: mount });
    });

    it('renders the table loading icon', () => {
      expect(findFrameworksTable().exists()).toBe(true);
      expect(findFrameworksTable().props('isLoading')).toBe(true);
    });

    it('fetches the list of frameworks and projects', () => {
      expect(mockGraphQlLoading).toHaveBeenCalledWith({
        ...defaultPaginationAndLimits,
        fullPath,
      });
    });
  });

  describe('when initializing in subgroup', () => {
    const rootPath = '/root';
    const subgroupPath = '/root/subgroup';

    beforeEach(() => {
      createComponent({
        mountFn: mount,
        props: {
          groupPath: subgroupPath,
          rootAncestor: {
            path: rootPath,
          },
        },
      });
    });

    it('fetches the list of frameworks from current group', () => {
      expect(mockGraphQlLoading).toHaveBeenCalledWith({
        ...defaultPaginationAndLimits,
        fullPath: subgroupPath,
      });
    });
  });

  it('loads data when search criteria changes', async () => {
    createComponent({ mountFn: mount });

    findFrameworksTable().vm.$emit('search', 'test');
    await nextTick();

    expect(mockGraphQlLoading).toHaveBeenCalledWith({
      ...defaultPaginationAndLimits,
      search: 'test',
      fullPath,
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        complianceFrameworksGroupResolverMock: mockFrameworksGraphQlSuccess,
      });
      return waitForPromises();
    });

    it('reacts to change to next page', async () => {
      const pagination = findPagination();
      pagination.vm.$emit('next');
      await nextTick();

      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledWith({
        ...defaultPaginationAndLimits,
        after: pagination.props('endCursor'),
        fullPath,
      });
    });

    it('reacts to change to previous page', async () => {
      const pagination = findPagination();
      pagination.vm.$emit('prev');
      await nextTick();

      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledWith({
        ...defaultPaginationAndLimits,
        last: defaultPaginationAndLimits.first,
        first: undefined,
        before: pagination.props('startCursor'),
        fullPath,
      });
    });

    it('resets pagination on search query change', async () => {
      const pagination = findPagination();

      await pagination.vm.$emit('next');
      await findFrameworksTable().vm.$emit('search', 'test');
      await nextTick();

      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledWith({
        ...defaultPaginationAndLimits,
        search: 'test',
        fullPath,
      });
    });
  });

  describe('sorting frameworks', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        complianceFrameworksGroupResolverMock: mockFrameworksGraphQlSuccess,
      });
    });

    it('sets default sorting', () => {
      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledWith(
        expect.objectContaining({
          sort: defaultPaginationAndLimits.sort,
        }),
      );
    });

    it.each`
      sortBy         | sortDesc | sort
      ${'name'}      | ${false} | ${'NAME_ASC'}
      ${'name'}      | ${true}  | ${'NAME_DESC'}
      ${'updatedAt'} | ${false} | ${'UPDATED_AT_ASC'}
      ${'updatedAt'} | ${true}  | ${'UPDATED_AT_DESC'}
    `(
      'fetches the frameworks list with new sorting when sorting is $sortBy and desc is $sortDesc',
      async ({ sortBy, sortDesc, sort }) => {
        findFrameworksTable().vm.$emit('sort-changed', { sortBy, sortDesc });
        await nextTick();

        expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledWith({
          ...defaultPaginationAndLimits,
          sort,
          fullPath,
        });
      },
    );
  });

  describe('when the frameworks query fails', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      createComponent({ complianceFrameworksGroupResolverMock: mockGraphQlError });
      return waitForPromises();
    });

    it('renders the error message', () => {
      const error = findQueryError();

      expect(error.exists()).toBe(true);
      expect(error.text()).toBe(
        'Unable to load the compliance framework report. Refresh the page and try again.',
      );
      expect(Sentry.captureException.mock.calls[0][0].networkError).toBe(sentryError);
    });
  });

  describe('when there are frameworks', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        complianceFrameworksGroupResolverMock: mockFrameworksGraphQlSuccess,
      });

      return waitForPromises();
    });

    it('passes results to the table', () => {
      expect(findFrameworksTable().props('frameworks')).toHaveLength(1);
      expect(findFrameworksTable().props('frameworks')[0]).toMatchObject({
        __typename: 'ComplianceFramework',
        color: '#3cb371',
        default: false,
        description: 'This is a framework 1',
        id: 'gid://gitlab/ComplianceManagement::Framework/1',
        name: "Auditor's framework 1",
        pipelineConfigurationFullPath: null,
      });
    });
  });

  describe('deleting frameworks', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        complianceFrameworksGroupResolverMock: mockFrameworksGraphQlSuccess,
      });

      return waitForPromises();
    });

    it('calls delete framework mutation on delete framework event with expected id and refetches data', async () => {
      findFrameworksTable().vm.$emit(
        'delete-framework',
        'gid://gitlab/ComplianceManagement::Framework/1',
      );
      await waitForPromises();
      expect(mockDeleteFrameworkSuccess).toHaveBeenCalledWith({
        input: {
          id: 'gid://gitlab/ComplianceManagement::Framework/1',
        },
      });
      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledTimes(2);
    });

    it('shows alert in case of error and does not call refetch', async () => {
      createComponent({
        mountFn: mount,
        complianceFrameworksGroupResolverMock: mockFrameworksGraphQlSuccess,
        deleteFrameworkResolverMock: mockDeleteFrameworkError,
        mockDeleteFrameworkError,
      });

      findFrameworksTable().vm.$emit(
        'delete-framework',
        'gid://gitlab/ComplianceManagement::Framework/1',
      );
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: 'Could not delete framework',
        message: 'Could not delete framework',
      });
      expect(mockFrameworksGraphQlSuccess).toHaveBeenCalledTimes(2);
    });
  });

  describe('graphql query selction', () => {
    it('uses group query with groupPath when groupPath is provided in props', () => {
      const complianceFrameworksGroupResolverMock = jest.fn();
      const complianceFrameworksProjectResolverMock = jest.fn();
      createComponent({
        mountFn: mount,
        props: { groupPath: 'groupPath' },
        complianceFrameworksGroupResolverMock,
        complianceFrameworksProjectResolverMock,
      });

      expect(complianceFrameworksGroupResolverMock).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: 'groupPath',
        }),
      );
      expect(complianceFrameworksProjectResolverMock).not.toHaveBeenCalled();
    });

    it('uses project query with projectPath when projectPath is provided in props', () => {
      const complianceFrameworksGroupResolverMock = jest.fn();
      const complianceFrameworksProjectResolverMock = jest.fn();
      createComponent({
        mountFn: mount,
        props: { groupPath: 'groupPath', projectPath: 'projectPath' },
        complianceFrameworksGroupResolverMock,
        complianceFrameworksProjectResolverMock,
      });

      expect(complianceFrameworksProjectResolverMock).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: 'projectPath',
        }),
      );
      expect(complianceFrameworksGroupResolverMock).not.toHaveBeenCalled();
    });
  });

  describe('refreshFrameworks', () => {
    beforeEach(() => {
      createComponent({ mountFn: mount });
    });

    it('refetches frameworks data when successful', async () => {
      const refetchSpy = jest.spyOn(wrapper.vm.$apollo.queries.frameworks, 'refetch');

      findFrameworksTable().vm.$emit('update-frameworks');
      await nextTick();

      expect(refetchSpy).toHaveBeenCalled();
    });

    it('shows error alert when refetch fails', async () => {
      const error = new Error('Network error');
      jest.spyOn(wrapper.vm.$apollo.queries.frameworks, 'refetch').mockRejectedValue(error);

      findFrameworksTable().vm.$emit('update-frameworks');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: error,
        captureError: true,
        error,
      });
    });
  });
});
