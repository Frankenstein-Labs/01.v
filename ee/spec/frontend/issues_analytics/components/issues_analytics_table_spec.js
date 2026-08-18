import { GlSkeletonLoader, GlTableLite } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import { TEST_HOST } from 'helpers/test_constants';
import IssuesAnalyticsTable from 'ee/issues_analytics/components/issues_analytics_table.vue';
import getIssuesAnalyticsData from 'ee/issues_analytics/graphql/queries/issues_analytics.query.graphql';
import { useFakeDate } from 'helpers/fake_date';
import {
  mockIssuesApiResponse,
  tableHeaders,
  getQueryIssuesAnalyticsResponse,
  mockFilters,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('IssuesAnalyticsTable', () => {
  useFakeDate(2020, 0, 8);

  let wrapper;
  let fakeApollo;

  const getQueryIssuesAnalyticsSuccess = jest
    .fn()
    .mockResolvedValue(getQueryIssuesAnalyticsResponse);
  const issuesPageEndpoint = `${TEST_HOST}/issues/page`;
  const mockStartDate = new Date('2020-01-02');
  const mockEndDate = new Date('2020-01-08');

  const createComponent = ({
    props = {},
    startDate = mockStartDate,
    endDate = mockEndDate,
    apolloHandlers = [getIssuesAnalyticsData, getQueryIssuesAnalyticsSuccess],
    type = 'group',
  } = {}) => {
    fakeApollo = createMockApollo([apolloHandlers]);

    wrapper = mount(IssuesAnalyticsTable, {
      apolloProvider: fakeApollo,
      provide: { fullPath: 'gitlab-org', type, issuesPageEndpoint },
      propsData: {
        startDate,
        endDate,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);

  const findIssueDetailsCol = (rowIndex) =>
    findTable().findAll('[data-testid="detailsCol"]').at(rowIndex);

  const findIterationCol = (rowIndex) =>
    findTable().findAll('[data-testid="iterationCol"]').at(rowIndex);

  const findAgeCol = (rowIndex) => findTable().findAll('[data-testid="ageCol"]').at(rowIndex);

  const findStatusCells = () => findTable().findAll('[data-testid="statusCol"]');

  const findStatusCellAt = (rowIndex) => findStatusCells().at(rowIndex);

  afterEach(() => {
    fakeApollo = null;
  });

  describe('while fetching data', () => {
    beforeEach(async () => {
      createComponent({ apolloHandlers: [getIssuesAnalyticsData, () => new Promise(() => {})] });
      await nextTick();
    });

    it('displays a skeleton loader', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not display the table', () => {
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('fetching data completed', () => {
    beforeEach(async () => {
      createComponent();
      await nextTick();
    });

    it('hides the loading state', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(false);
    });

    it('displays the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    describe('table data and formatting', () => {
      it('displays the correct table headers', () => {
        const headers = findTable().findAll('[data-testid="header"]');

        expect(headers).toHaveLength(tableHeaders.length);

        tableHeaders.forEach((headerText, i) => expect(headers.at(i).text()).toEqual(headerText));
      });

      it('displays the correct issue details', () => {
        const { title, iid, epic } = mockIssuesApiResponse[0];

        expect(findIssueDetailsCol(0).text()).toBe(`${title} #${iid} &${epic.iid}`);
      });

      it('displays the correct issue details labels', () => {
        const { iid } = mockIssuesApiResponse[1];
        const firstDetails = findIssueDetailsCol(1);

        const labelsId = firstDetails.find('[data-testid="labels"]').attributes('id');
        const labelsPopoverTarget = firstDetails
          .findComponent('[data-testid="labelsPopover"]')
          .props('target');

        expect(labelsId).toBe(`${iid}-labels`);
        expect(labelsId).toBe(labelsPopoverTarget);
      });

      it('displays the correct issue iteration', () => {
        expect(findIterationCol(0).text()).toBe('');
        expect(findIterationCol(2).text()).toBe('Iteration 1');
      });

      it('displays the correct issue age', () => {
        expect(findAgeCol(0).text()).toBe('0 days');
        expect(findAgeCol(1).text()).toBe('1 day');
        expect(findAgeCol(2).text()).toBe('2 days');
      });

      it('capitalizes the status', () => {
        expect(findStatusCellAt(0).text()).toBe('Closed');
      });

      it('should only display supported issue states', () => {
        expect(mockIssuesApiResponse.map(({ state }) => state)).toEqual([
          'closed',
          'opened',
          'opened',
          'locked',
        ]);

        const statusCells = findStatusCells().wrappers.map((statusCell) => statusCell.text());

        expect(statusCells).toEqual(['Closed', 'Opened', 'Opened']);
      });
    });
  });

  describe.each(['group', 'project'])('%s issues analytics query', (type) => {
    const defaultVariables = {
      fullPath: 'gitlab-org',
      isGroup: type === 'group',
      isProject: type === 'project',
      createdAfter: mockStartDate,
      createdBefore: mockEndDate,
      state: 'opened',
    };

    it('calls the query with the correct default variables', () => {
      createComponent({ type });

      expect(getQueryIssuesAnalyticsSuccess).toHaveBeenCalledWith(defaultVariables);
    });

    it('calls the query with the correct variables when filters have been applied', () => {
      createComponent({ props: { filters: mockFilters }, type });

      expect(getQueryIssuesAnalyticsSuccess).toHaveBeenCalledWith({
        ...defaultVariables,
        ...mockFilters,
      });
    });

    it('calls the query with the correct variables when completed issues are supported', () => {
      createComponent({ props: { hasCompletedIssues: true }, type });

      expect(getQueryIssuesAnalyticsSuccess).toHaveBeenCalledWith({
        ...defaultVariables,
        state: 'all',
      });
    });
  });

  describe('error fetching data', () => {
    beforeEach(async () => {
      createComponent({ apolloHandlers: [getIssuesAnalyticsData, jest.fn().mockRejectedValue()] });
      await nextTick();
    });

    it('displays an error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to load issues. Please try again.',
      });
    });
  });
});
