import { mount } from '@vue/test-utils';
import { GlKeysetPagination } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ComplianceViolationsReportV2, {
  VIOLATION_PAGE_SIZE,
} from 'ee/compliance_dashboard/components/violations_report/report_v2.vue';
import FiltersBar from 'ee/compliance_dashboard/components/violations_report/components/filters_bar.vue';
import groupComplianceViolationsQuery from 'ee/compliance_violations/graphql/compliance_violations.query.graphql';
import updateProjectComplianceViolation from 'ee/compliance_violations/graphql/mutations/update_project_compliance_violation.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';

Vue.use(VueApollo);

describe('ComplianceViolationsReportV2 component - Filters', () => {
  let wrapper;

  const groupPath = 'group-path';

  const mockViolationsResponse = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  };

  const mockViolationsResponseWithPagination = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [],
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'cursor1',
            endCursor: 'cursor2',
          },
        },
      },
    },
  };

  const mockUpdateMutationSuccess = jest.fn().mockResolvedValue({
    data: {
      updateProjectComplianceViolation: {
        clientMutationId: 'test-id',
        errors: [],
        complianceViolation: null,
      },
    },
  });

  const findFiltersBar = () => wrapper.findComponent(FiltersBar);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const mockControlDefinitionsResponse = {
    data: {
      complianceRequirementControls: {
        controlExpressions: [],
      },
    },
  };

  const createMockApolloProvider = (resolverMock, mutationMock = mockUpdateMutationSuccess) => {
    return createMockApollo([
      [groupComplianceViolationsQuery, resolverMock],
      [updateProjectComplianceViolation, mutationMock],
      [
        complianceRequirementControlsQuery,
        jest.fn().mockResolvedValue(mockControlDefinitionsResponse),
      ],
    ]);
  };

  const createComponent = (resolverMock) => {
    return extendedWrapper(
      mount(ComplianceViolationsReportV2, {
        apolloProvider: createMockApolloProvider(resolverMock),
        propsData: {
          groupPath,
        },
      }),
    );
  };

  describe('with filters', () => {
    it('renders FiltersBar component with correct groupPath prop', () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);

      const filtersBar = findFiltersBar();
      expect(filtersBar.exists()).toBe(true);
      expect(filtersBar.props('groupPath')).toBe(groupPath);
    });

    it('calls Apollo query with filters parameter when filters are applied', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'DETECTED',
        projectId: 'gid://gitlab/Project/123',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['DETECTED'],
            projectId: 'gid://gitlab/Project/123',
          },
        }),
      );
    });

    it('resets pagination cursor when filters change', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponseWithPagination);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      // Navigate to next page first
      const pagination = findPagination();
      pagination.vm.$emit('next');
      await nextTick();

      // Verify we navigated
      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          after: 'cursor2',
        }),
      );

      mockResolver.mockClear();

      // Apply filter - should reset cursor
      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { status: 'DETECTED' });
      await nextTick();

      // Cursor should be reset (no after/before)
      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          after: null,
          before: null,
          filters: {
            status: ['DETECTED'],
          },
        }),
      );
    });

    it('converts filter values to GraphQL format correctly (projectId as Global ID)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        projectId: 'gid://gitlab/Project/456',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            projectId: 'gid://gitlab/Project/456',
          },
        }),
      );
    });

    it('converts filter values to GraphQL format correctly (controlId as Global ID)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        controlId: 'gid://gitlab/ComplianceControl/789',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            controlId: 'gid://gitlab/ComplianceControl/789',
          },
        }),
      );
    });

    it('converts filter values to GraphQL format correctly (status as uppercase array)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'DETECTED',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['DETECTED'],
          },
        }),
      );
    });

    it('test filter combinations (status only)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'RESOLVED',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['RESOLVED'],
          },
        }),
      );
    });

    it('test filter combinations (project only)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        projectId: 'gid://gitlab/Project/100',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            projectId: 'gid://gitlab/Project/100',
          },
        }),
      );
    });

    it('test filter combinations (control only)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        controlId: 'gid://gitlab/ComplianceControl/200',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            controlId: 'gid://gitlab/ComplianceControl/200',
          },
        }),
      );
    });

    it('test filter combinations (all filters combined)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'IN_REVIEW',
        projectId: 'gid://gitlab/Project/300',
        controlId: 'gid://gitlab/ComplianceControl/400',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['IN_REVIEW'],
            projectId: 'gid://gitlab/Project/300',
            controlId: 'gid://gitlab/ComplianceControl/400',
          },
        }),
      );
    });

    it('verify query variables include filters object with correct structure', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'DISMISSED',
        projectId: 'gid://gitlab/Project/500',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith({
        fullPath: groupPath,
        first: VIOLATION_PAGE_SIZE,
        after: null,
        before: null,
        filters: {
          status: ['DISMISSED'],
          projectId: 'gid://gitlab/Project/500',
        },
      });
    });

    it('returns undefined when no filters are set', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      // When component loads without filters, query should not have filters parameter
      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: undefined,
        }),
      );
    });

    it('passes createdAfter to GraphQL query when only that date filter is set', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { createdAfter: '2024-01-15' });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: { createdAfter: '2024-01-15' },
        }),
      );
    });

    it('passes createdBefore to GraphQL query when only that date filter is set', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { createdBefore: '2024-06-30' });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: { createdBefore: '2024-06-30' },
        }),
      );
    });

    it('passes both createdAfter and createdBefore when a date range is set', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        createdAfter: '2024-01-01',
        createdBefore: '2024-12-31',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            createdAfter: '2024-01-01',
            createdBefore: '2024-12-31',
          },
        }),
      );
    });

    it('combines date filters with status, project, and control filters', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'DETECTED',
        projectId: 'gid://gitlab/Project/123',
        controlId: 'gid://gitlab/ComplianceControl/456',
        createdAfter: '2024-01-01',
        createdBefore: '2024-12-31',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['DETECTED'],
            projectId: 'gid://gitlab/Project/123',
            controlId: 'gid://gitlab/ComplianceControl/456',
            createdAfter: '2024-01-01',
            createdBefore: '2024-12-31',
          },
        }),
      );
    });

    it('resets pagination cursor when a date filter changes', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponseWithPagination);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      // Navigate to next page first
      const pagination = findPagination();
      pagination.vm.$emit('next');
      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          after: 'cursor2',
        }),
      );

      mockResolver.mockClear();

      // Apply a date filter - should reset cursor
      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { createdAfter: '2024-03-01' });
      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          after: null,
          before: null,
          filters: { createdAfter: '2024-03-01' },
        }),
      );
    });

    it('removes only the date filter when re-emitted without it, keeping other filters active', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'DETECTED',
        createdAfter: '2024-01-01',
      });
      await waitForPromises();

      mockResolver.mockClear();

      filtersBar.vm.$emit('update:filters', { status: 'DETECTED' });
      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: { status: ['DETECTED'] },
        }),
      );
    });
  });

  describe('filter integration', () => {
    it('selecting status filter updates query and refetches violations', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { status: 'RESOLVED' });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['RESOLVED'],
          },
        }),
      );
    });

    it('selecting project filter updates query and refetches violations', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { projectId: 'gid://gitlab/Project/999' });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            projectId: 'gid://gitlab/Project/999',
          },
        }),
      );
    });

    it('selecting control filter updates query and refetches violations', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { controlId: 'gid://gitlab/ComplianceControl/888' });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            controlId: 'gid://gitlab/ComplianceControl/888',
          },
        }),
      );
    });

    it('clearing filters resets query to no filters', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      // Apply filters first
      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { status: 'DETECTED' });
      await waitForPromises();

      mockResolver.mockClear();

      // Clear filters
      filtersBar.vm.$emit('update:filters', {});
      await waitForPromises();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: undefined,
        }),
      );
    });

    it('applying multiple filters combines them correctly in query', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponse);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      mockResolver.mockClear();

      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', {
        status: 'IN_REVIEW',
        projectId: 'gid://gitlab/Project/111',
        controlId: 'gid://gitlab/ComplianceControl/222',
      });

      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['IN_REVIEW'],
            projectId: 'gid://gitlab/Project/111',
            controlId: 'gid://gitlab/ComplianceControl/222',
          },
        }),
      );
    });

    it('pagination works correctly with filters applied (maintains filter state across pages)', async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponseWithPagination);
      wrapper = createComponent(mockResolver);
      await waitForPromises();

      // Apply filters
      const filtersBar = findFiltersBar();
      filtersBar.vm.$emit('update:filters', { status: 'DETECTED' });
      await nextTick();

      mockResolver.mockClear();

      // Navigate to next page
      const pagination = findPagination();
      pagination.vm.$emit('next');
      await nextTick();

      expect(mockResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: {
            status: ['DETECTED'],
          },
          after: 'cursor2',
          before: null,
        }),
      );
    });
  });
});
