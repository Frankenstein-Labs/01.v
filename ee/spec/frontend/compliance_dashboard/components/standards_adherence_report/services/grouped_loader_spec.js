import { GroupedLoader } from 'ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader';
import groupComplianceRequirementsStatusesQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/group_compliance_requirements_statuses.query.graphql';
import projectComplianceRequirementsStatusesQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/project_compliance_requirements_statuses.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { GROUP_BY } from 'ee/compliance_dashboard/components/standards_adherence_report/constants';
import { createMockGroupComplianceRequirementsStatusesData } from './mock_data';

describe('GroupedLoader', () => {
  let loader;
  let mockApollo;
  let mockQueryResponse;
  let mockGroupRequirementsStatusQuery;
  let mockProjectRequirementsStatusQuery;

  const fullPath = 'example-group';
  const DEFAULT_PAGESIZE = 20;

  const createMockData = (overrides = {}) => {
    const baseData = createMockGroupComplianceRequirementsStatusesData();
    return {
      ...baseData,
      data: {
        ...baseData.data,
        container: {
          ...baseData.data.container,
          complianceRequirementStatuses: {
            ...baseData.data.container.complianceRequirementStatuses,
            ...overrides.complianceRequirementStatuses,
          },
        },
      },
    };
  };

  beforeEach(() => {
    mockQueryResponse = createMockGroupComplianceRequirementsStatusesData();
    mockGroupRequirementsStatusQuery = jest.fn().mockResolvedValue(mockQueryResponse);
    mockProjectRequirementsStatusQuery = jest.fn().mockResolvedValue(mockQueryResponse);
    mockApollo = createMockApollo(
      [
        [groupComplianceRequirementsStatusesQuery, mockGroupRequirementsStatusQuery],
        [projectComplianceRequirementsStatusesQuery, mockProjectRequirementsStatusQuery],
      ],
      {},
      { typePolicies: { Query: { fields: { group: { merge: true } } } } },
    );
  });

  describe('fetchPage', () => {
    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    it('uses group query for group mode', async () => {
      await loader.fetchPage();

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        first: DEFAULT_PAGESIZE,
      });
    });

    it('uses project query for project mode', async () => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath, mode: 'project' });
      await loader.fetchPage();

      expect(mockProjectRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        first: DEFAULT_PAGESIZE,
      });
    });

    it('passes orderBy when groupBy is set', async () => {
      loader.groupBy = GROUP_BY.FRAMEWORKS;
      await loader.fetchPage();

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: GROUP_BY.FRAMEWORKS,
        first: DEFAULT_PAGESIZE,
      });
    });

    it('uses last parameter when before cursor is provided', async () => {
      await loader.fetchPage({ before: 'cursor' });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        last: DEFAULT_PAGESIZE,
        before: 'cursor',
      });
    });

    it('uses first parameter when after cursor is provided', async () => {
      await loader.fetchPage({ after: 'cursor' });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        first: DEFAULT_PAGESIZE,
        after: 'cursor',
      });
    });
  });

  describe('loadUngroupedPage', () => {
    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    it('calls the Apollo query with the correct parameters for first page', async () => {
      await loader.loadUngroupedPage();

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        first: DEFAULT_PAGESIZE,
      });
    });

    it('calls the Apollo query with the correct parameters when "after" cursor is provided', async () => {
      const after = 'next-cursor';
      await loader.loadUngroupedPage({ after });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        first: DEFAULT_PAGESIZE,
        after,
      });
    });

    it('calls the Apollo query with the correct parameters when "before" cursor is provided', async () => {
      const before = 'prev-cursor';
      await loader.loadUngroupedPage({ before });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        filters: {},
        orderBy: null,
        last: DEFAULT_PAGESIZE,
        before,
      });
    });

    it('returns properly structured data and pageInfo for non-grouped query', async () => {
      const result = await loader.loadUngroupedPage();

      expect(result).toEqual({
        data: [
          {
            group: null,
            children: mockQueryResponse.data.container.complianceRequirementStatuses.nodes,
          },
        ],
        pageInfo: {
          hasNextPage:
            mockQueryResponse.data.container.complianceRequirementStatuses.pageInfo.hasNextPage,
          hasPreviousPage:
            mockQueryResponse.data.container.complianceRequirementStatuses.pageInfo.hasPreviousPage,
        },
      });
    });

    it('stores pageInfo internally', async () => {
      await loader.loadUngroupedPage();

      expect(loader.pageInfo).toEqual(
        mockQueryResponse.data.container.complianceRequirementStatuses.pageInfo,
      );
    });
  });

  describe('loadGroupedPage', () => {
    beforeEach(() => {
      loader = new GroupedLoader({
        apollo: mockApollo.defaultClient,
        fullPath,
        groupBy: GROUP_BY.FRAMEWORKS,
        pageSize: 10,
      });
      loader.setGroupBy(GROUP_BY.FRAMEWORKS);
    });

    it('returns grouped data structure by frameworks', async () => {
      const result = await loader.loadGroupedPage({});
      expect(result.data).toHaveLength(3); // GDPR, SOC 2, HIPAA
    });

    it('aggregates failCount for grouped items across multiple pages', async () => {
      const mockDataWithNextPage = createMockData({
        complianceRequirementStatuses: {
          pageInfo: {
            startCursor: 'eyJpZCI6IjEifQ==',
            endCursor: 'eyJpZCI6IjMifQ==',
            hasNextPage: true,
            hasPreviousPage: false,
          },
        },
      });
      const mockDataWithoutNextPage = createMockData({
        complianceRequirementStatuses: {
          pageInfo: {
            startCursor: 'eyJpZCI6IjEifQ==',
            endCursor: 'eyJpZCI6IjMifQ==',
            hasNextPage: false,
            hasPreviousPage: true,
          },
        },
      });

      mockGroupRequirementsStatusQuery
        .mockResolvedValueOnce(mockDataWithNextPage)
        .mockResolvedValueOnce(mockDataWithoutNextPage);

      const result = await loader.loadGroupedPage({});

      const gdprGroup = result.data.find((g) => g.groupValue.name === 'GDPR');
      expect(gdprGroup.failCount).toBe(4);

      const socGroup = result.data.find((g) => g.groupValue.name === 'SOC 2');
      expect(socGroup.failCount).toBe(0);

      const hipaaGroup = result.data.find((g) => g.groupValue.name === 'HIPAA');
      expect(hipaaGroup.failCount).toBe(6);
    });

    it('handles processed entities tracking for large result sets', async () => {
      loader.setGroupBy(GROUP_BY.FRAMEWORKS);
      loader.setPageSize(2);

      const result = await loader.loadPage({});
      expect(result.data).toHaveLength(2);
      expect(loader.processedEntities).toHaveLength(2);
    });

    it('correctly extracts remaining data from page', async () => {
      loader.setGroupBy(GROUP_BY.FRAMEWORKS);
      loader.setPageSize(2);
      await loader.loadPage({});
      const result = await loader.loadNextPage();
      expect(result.data).toHaveLength(1);
      expect(result.data[0].groupValue.name).toBe('HIPAA');
    });

    it('correctly stores data for previous page navigation', async () => {
      loader.setPageSize(2);

      const result1 = await loader.loadPage({});
      await loader.loadNextPage();
      const result2 = await loader.loadPrevPage();

      expect(result1).toStrictEqual(result2);
    });
  });

  describe('loadPage', () => {
    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    it('calls loadUngroupedPage when no groupBy is set', async () => {
      const spy = jest.spyOn(loader, 'loadUngroupedPage');
      await loader.loadPage();

      expect(spy).toHaveBeenCalled();
    });

    it('calls loadGroupedPage when groupBy is set', async () => {
      loader.groupBy = GROUP_BY.FRAMEWORKS;
      const spy = jest
        .spyOn(loader, 'loadGroupedPage')
        .mockResolvedValue({ data: [], pageInfo: {} });

      await loader.loadPage();

      expect(spy).toHaveBeenCalled();
    });

    it('caches grouped page results', async () => {
      loader.groupBy = GROUP_BY.FRAMEWORKS;
      const mockResult = { data: [], pageInfo: {} };
      jest.spyOn(loader, 'loadGroupedPage').mockResolvedValue(mockResult);

      await loader.loadPage();

      expect(loader.groupPagesCache).toContain(mockResult);
    });

    it('returns properly structured data using real mock data', async () => {
      const result = await loader.loadPage();

      expect(result).toEqual({
        data: [
          {
            group: null,
            children: mockQueryResponse.data.container.complianceRequirementStatuses.nodes,
          },
        ],
        pageInfo: {
          hasNextPage:
            mockQueryResponse.data.container.complianceRequirementStatuses.pageInfo.hasNextPage,
          hasPreviousPage:
            mockQueryResponse.data.container.complianceRequirementStatuses.pageInfo.hasPreviousPage,
        },
      });
    });
  });

  describe('pagination methods', () => {
    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    describe('resetPagination', () => {
      it('resets pageInfo to default values', async () => {
        await loader.loadUngroupedPage();
        loader.resetPagination();

        expect(loader.pageInfo).toEqual({
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
        });
      });

      it('clears group pages cache', () => {
        loader.groupPagesCache = [{ data: [], pageInfo: {} }];
        loader.resetPagination();

        expect(loader.groupPagesCache).toEqual([]);
      });
    });

    describe('setPageSize', () => {
      it('updates pageSize and resets pagination', async () => {
        const newPageSize = 50;
        await loader.loadUngroupedPage();
        loader.setPageSize(newPageSize);

        expect(loader.pageSize).toBe(newPageSize);
        expect(loader.pageInfo).toEqual({
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
        });
      });

      it('uses new page size in subsequent queries', async () => {
        const newPageSize = 50;
        loader.setPageSize(newPageSize);
        mockGroupRequirementsStatusQuery.mockClear();

        await loader.loadUngroupedPage();

        expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
          first: newPageSize,
          filters: {},
          orderBy: null,
          fullPath,
        });
      });
    });

    describe('loadNextPage', () => {
      it('calls loadPage with after cursor for ungrouped', async () => {
        const pageInfo = {
          endCursor: 'eyJpZCI6IjMifQ==',
          hasNextPage: true,
        };
        mockGroupRequirementsStatusQuery.mockResolvedValue(
          createMockData({
            pageInfo,
            nodes: [],
          }),
        );
        await loader.loadUngroupedPage();
        mockGroupRequirementsStatusQuery.mockClear();

        await loader.loadNextPage();

        expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
          after: pageInfo.endCursor,
          first: DEFAULT_PAGESIZE,
          fullPath,
          filters: {},
          orderBy: null,
        });
      });
    });

    describe('loadPrevPage', () => {
      it('calls loadPage with before cursor for ungrouped', async () => {
        const mock = createMockGroupComplianceRequirementsStatusesData();
        await loader.loadUngroupedPage();
        mockGroupRequirementsStatusQuery.mockClear();

        await loader.loadPrevPage();

        expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
          before: mock.data.container.complianceRequirementStatuses.pageInfo.startCursor,
          last: DEFAULT_PAGESIZE,
          fullPath,
          filters: {},
          orderBy: null,
        });
      });

      it('returns cached page for grouped pagination', async () => {
        loader.setGroupBy(GROUP_BY.FRAMEWORKS);
        const cachedPage = { data: [], pageInfo: {} };
        const currentPage = { data: [], pageInfo: {} };
        loader.groupPagesCache = [cachedPage, currentPage];

        const result = await loader.loadPrevPage();

        expect(result).toBe(cachedPage);
        expect(loader.groupPagesCache).toEqual([cachedPage]);
      });
    });

    describe('setFilters', () => {
      it('updates filters and resets pagination', async () => {
        const filters = { projectId: 123, status: 'FAILED' };

        await loader.loadUngroupedPage();
        loader.setFilters(filters);

        expect(loader.filters).toEqual(filters);
        expect(loader.pageInfo).toStrictEqual({
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
        });
      });

      it('uses new filters in subsequent queries', async () => {
        const filters = { projectId: 123, status: 'FAILED' };
        loader.setFilters(filters);
        mockGroupRequirementsStatusQuery.mockClear();

        await loader.loadUngroupedPage();

        expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
          fullPath,
          filters,
          orderBy: null,
          first: DEFAULT_PAGESIZE,
        });
      });
    });

    describe('setGroupBy', () => {
      it('updates groupBy and resets pagination', () => {
        loader.setGroupBy(GROUP_BY.FRAMEWORKS);

        expect(loader.groupBy).toBe(GROUP_BY.FRAMEWORKS);
        expect(loader.pageInfo).toEqual({
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
        });
        expect(loader.groupPagesCache).toEqual([]);
      });

      it('clears group pages cache when groupBy changes', () => {
        loader.groupPagesCache = [{ data: [], pageInfo: {} }];
        loader.setGroupBy(GROUP_BY.PROJECTS);

        expect(loader.groupPagesCache).toEqual([]);
      });
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    it('propagates query errors', async () => {
      const error = new Error('GraphQL error');
      mockGroupRequirementsStatusQuery.mockRejectedValue(error);

      await expect(loader.loadUngroupedPage()).rejects.toThrow('GraphQL error');
    });

    it('propagates errors from grouped page loading', async () => {
      loader.groupBy = GROUP_BY.FRAMEWORKS;
      const error = new Error('Network error');
      mockGroupRequirementsStatusQuery.mockRejectedValue(error);

      await expect(loader.loadGroupedPage({})).rejects.toThrow('Network error');
    });
  });
});
