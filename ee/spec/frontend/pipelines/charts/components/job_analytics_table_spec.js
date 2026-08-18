import { GlLoadingIcon, GlTable, GlSearchBoxByClick, GlEmptyState } from '@gitlab/ui';
import CHART_EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import JobAnalyticsTable from 'ee/ci/analytics/project_ci_cd_analytics/components/job_analytics_table.vue';
import getJobAnalytics from 'ee/ci/analytics/project_ci_cd_analytics/graphql/queries/get_job_analytics.query.graphql';
import RunnerPagination from '~/ci/runner/components/runner_pagination.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import { formatPipelineDuration } from '~/ci/analytics/utils';
import { stubComponent } from 'helpers/stub_component';

Vue.use(VueApollo);

describe('JobAnalyticsTable', () => {
  let wrapper;
  let mockJobAnalyticsHandler;

  const mockJobAnalyticsData = {
    data: {
      project: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        jobAnalytics: {
          __typename: 'CiJobAnalyticsConnection',
          nodes: [
            {
              name: 'test-job',
              stageName: 'test',
              statistics: {
                successRate: 90.0,
                failedRate: 0.0,
                successCount: '9',
                failedCount: '1',
                count: '10',
                durationStatistics: {
                  meanDuration: 60,
                  p95Duration: 90,
                  __typename: 'CiDurationStatistics',
                },
                __typename: 'CiJobAnalyticsStatistics',
              },
              __typename: 'CiJobAnalytics',
            },
            {
              name: 'build-job',
              stageName: 'build',
              statistics: {
                successRate: 100.0,
                failedRate: 0.0,
                successCount: '10',
                failedCount: '0',
                count: '10',
                durationStatistics: {
                  meanDuration: 61,
                  p95Duration: 91,
                  __typename: 'CiDurationStatistics',
                },
                __typename: 'CiJobAnalyticsStatistics',
              },
              __typename: 'CiJobAnalytics',
            },
          ],
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'start-cursor',
            endCursor: 'end-cursor',
          },
        },
      },
    },
  };

  const mockJobAnalyticsDataPage2 = {
    data: {
      project: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        jobAnalytics: {
          __typename: 'CiJobAnalyticsConnection',
          nodes: [
            {
              name: 'deploy-job',
              stageName: 'deploy',
              statistics: {
                successRate: 95.0,
                failedRate: 5.0,
                successCount: '95',
                failedCount: '5',
                count: '100',
                durationStatistics: {
                  meanDuration: 62,
                  p95Duration: 92,
                  __typename: 'CiDurationStatistics',
                },
                __typename: 'CiJobAnalyticsStatistics',
              },
              __typename: 'CiJobAnalytics',
            },
          ],
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: true,
            startCursor: 'start-cursor-2',
            endCursor: 'end-cursor-2',
          },
        },
      },
    },
  };

  const mockJobAnalyticsDataEmpty = {
    data: {
      project: {
        id: 'gid://gitlab/Project/3',
        jobAnalytics: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
          },
        },
      },
    },
  };

  const mockVariables = {
    fullPath: 'gitlab-org/gitlab',
    fromTime: '2024-01-01T00:00:00Z',
    toTime: '2024-01-31T23:59:59Z',
    source: null,
    branch: null,
    jobName: null,
  };

  const createMockApolloProvider = (handler) => {
    mockJobAnalyticsHandler = handler;
    return createMockApollo([[getJobAnalytics, handler]]);
  };

  const defaultGlTableStub = stubComponent(GlTable, {
    props: {
      items: {},
      noLocalSorting: {},
      ...GlTable.props,
    },
  });

  const createComponent = ({
    variables = mockVariables,
    handler = jest.fn().mockResolvedValue(mockJobAnalyticsData),
    provide = {},
    glTableStub = defaultGlTableStub,
  } = {}) => {
    wrapper = shallowMount(JobAnalyticsTable, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        variables,
      },
      provide: {
        glLicensedFeatures: {
          ciJobAnalyticsForProjects: true,
        },
        ...provide,
      },
      stubs: {
        GlTable: glTableStub,
      },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTable = () => wrapper.findComponent(GlTable);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByClick);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPagination = () => wrapper.findComponent(RunnerPagination);

  describe('when feature is not available', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          glLicensedFeatures: {
            ciJobAnalyticsForProjects: false,
          },
        },
      });
    });

    it('does not render the component', () => {
      expect(wrapper.text()).toBe('');
    });

    it('does not query for job analytics', () => {
      expect(mockJobAnalyticsHandler).not.toHaveBeenCalled();
    });
  });

  describe('when feature is available', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component with heading', () => {
      expect(wrapper.html()).not.toBe('');
      expect(wrapper.find('h3').text()).toBe('Jobs');
    });

    it('renders the search box', () => {
      expect(findSearchBox().exists()).toBe(true);
      expect(findSearchBox().props('placeholder')).toBe('Search by job name');
    });

    describe('loading state', () => {
      beforeEach(() => {
        createComponent({
          handler: jest.fn().mockReturnValue(new Promise(() => {})),
        });
      });

      it('shows loading icon while loading', () => {
        expect(findLoadingIcon().exists()).toBe(true);
        expect(findTable().exists()).toBe(false);
        expect(findEmptyState().exists()).toBe(false);
      });

      it('disables pagination when loading', () => {
        expect(findPagination().attributes('disabled')).toBeDefined();
      });
    });

    describe('with data', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('renders the table', () => {
        expect(findTable().exists()).toBe(true);
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findEmptyState().exists()).toBe(false);
      });

      it('passes correct fields to the table', () => {
        const fields = findTable().props('fields');

        expect(fields).toHaveLength(6);
        expect(fields[0]).toMatchObject({ key: 'name', label: 'Job' });
        expect(fields[1]).toMatchObject({ key: 'stageName', label: 'Stage' });
        expect(fields[2]).toMatchObject({ key: 'meanDuration', label: 'Mean duration' });
        expect(fields[3]).toMatchObject({ key: 'p95Duration', label: 'P95 duration' });
        expect(fields[4]).toMatchObject({ key: 'failedRate', label: 'Failure rate (%)' });
        expect(fields[5]).toMatchObject({ key: 'successRate', label: 'Success rate (%)' });
      });

      it('passes correct items to the table', () => {
        expect(findTable().props('items')).toEqual([
          {
            __typename: 'CiDurationStatistics',
            name: 'test-job',
            stageName: 'test',
            successRate: 90,
            failedRate: 0,
            successCount: '9',
            failedCount: '1',
            count: '10',
            meanDuration: 60,
            p95Duration: 90,
          },
          {
            __typename: 'CiDurationStatistics',
            name: 'build-job',
            stageName: 'build',
            successRate: 100,
            failedRate: 0,
            successCount: '10',
            failedCount: '0',
            count: '10',
            meanDuration: 61,
            p95Duration: 91,
          },
        ]);
      });

      it('configures table for custom sorting', () => {
        expect(findTable().props('noLocalSorting')).toBe(true);
      });

      it('sets default sort', () => {
        expect(findTable().props('sortBy')).toBe('meanDuration');
        expect(findTable().props('sortDesc')).toBe(true);
      });

      it('renders pagination', () => {
        expect(findPagination().props('pageInfo')).toEqual(
          mockJobAnalyticsData.data.project.jobAnalytics.pageInfo,
        );
      });
    });

    describe('Failure rate column header popover', () => {
      const findFailureRateHelpPopover = () =>
        wrapper.find('[data-testid="failure-rate-help-popover"]');

      // Render only the #head(failedRate) named slot so we can assert the
      // popover is mounted with the right content (default stub renders only
      // the default slot).
      const headSlotStub = stubComponent(GlTable, {
        template: `<div><slot name="head(failedRate)" :label="'Failure rate (%)'" /></div>`,
      });

      beforeEach(async () => {
        createComponent({ glTableStub: headSlotStub });
        await waitForPromises();
      });

      it('renders a help popover next to the Failure rate column header', () => {
        const popover = findFailureRateHelpPopover();

        expect(popover.exists()).toBe(true);
        expect(popover.findComponent(HelpPopover).props('options')).toEqual({
          title: 'How this is calculated?',
          content:
            "Rate = failed_jobs / (success + failed). Canceled and skipped jobs aren't included. Success rate is the inverse.",
        });
      });
    });

    describe('empty state', () => {
      beforeEach(async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(mockJobAnalyticsDataEmpty),
        });
        await waitForPromises();
      });

      it('shows empty state when no data', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findTable().exists()).toBe(false);
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('shows correct empty state', () => {
        expect(findEmptyState().props('description')).toBe('No job data found.');
        expect(findEmptyState().props('svgPath')).toEqual(CHART_EMPTY_STATE_SVG_URL);
      });
    });

    describe('empty state with search filter', () => {
      beforeEach(async () => {
        createComponent({
          variables: { ...mockVariables, jobName: 'non-existent' },
          handler: jest.fn().mockResolvedValue(mockJobAnalyticsDataEmpty),
        });
        await waitForPromises();
      });

      it('shows filtered empty state message', () => {
        expect(findEmptyState().props('description')).toBe(
          'No job data found for the current filter.',
        );
      });
    });
  });

  describe('GraphQL query', () => {
    it('queries with correct variables', async () => {
      createComponent();
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith({
        ...mockVariables,
        sort: 'MEAN_DURATION_DESC',
        first: 5,
      });
    });

    it('includes jobName in query when provided', async () => {
      const variables = { ...mockVariables, jobName: 'test-job' };
      createComponent({ variables });
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith({
        ...mockVariables,
        sort: 'MEAN_DURATION_DESC',
        jobName: 'test-job',
        first: 5,
      });
    });
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits input event when search is submitted', async () => {
      findSearchBox().vm.$emit('submit', 'new-job-name');
      await waitForPromises();

      expect(wrapper.emitted('filters-input')).toHaveLength(1);
      expect(wrapper.emitted('filters-input')[0][0]).toEqual({
        ...mockVariables,
        jobName: 'new-job-name',
      });

      expect(mockJobAnalyticsHandler).toHaveBeenCalledTimes(1);

      findSearchBox().vm.$emit('submit', 'new-job-name');
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenCalledTimes(2);
    });

    it('resets pagination when search is submitted', async () => {
      mockJobAnalyticsHandler.mockResolvedValueOnce(mockJobAnalyticsDataPage2);

      findSearchBox().vm.$emit('submit', 'new-job-name');
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith({
        ...mockVariables,
        sort: 'MEAN_DURATION_DESC',
        first: 5,
      });
    });
  });

  describe('clears search', () => {
    beforeEach(async () => {
      createComponent({
        variables: {
          ...mockVariables,
          jobName: 'predefined-job-name',
        },
      });
      await waitForPromises();
    });

    it('emits input event when search is cleared', async () => {
      findSearchBox().vm.$emit('clear');
      await waitForPromises();

      expect(wrapper.emitted('filters-input')).toHaveLength(1);
      expect(wrapper.emitted('filters-input')[0][0]).toEqual({
        ...mockVariables,
        jobName: '',
      });
    });
  });

  describe('sorting', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it.each`
      sortBy            | sortDesc | expectedSort
      ${'name'}         | ${true}  | ${'NAME_DESC'}
      ${'name'}         | ${false} | ${'NAME_ASC'}
      ${'meanDuration'} | ${false} | ${'MEAN_DURATION_ASC'}
      ${'p95Duration'}  | ${true}  | ${'P95_DURATION_DESC'}
      ${'p95Duration'}  | ${false} | ${'P95_DURATION_ASC'}
      ${'failedRate'}   | ${true}  | ${'FAILED_RATE_DESC'}
      ${'failedRate'}   | ${false} | ${'FAILED_RATE_ASC'}
      ${'successRate'}  | ${true}  | ${'SUCCESS_RATE_DESC'}
      ${'successRate'}  | ${false} | ${'SUCCESS_RATE_ASC'}
      ${'stageName'}    | ${true}  | ${'STAGE_NAME_DESC'}
      ${'stageName'}    | ${false} | ${'STAGE_NAME_ASC'}
    `(
      'queries with $expectedSort when sorting by $sortBy with desc=$sortDesc',
      async ({ sortBy, sortDesc, expectedSort }) => {
        mockJobAnalyticsHandler.mockClear();

        findTable().vm.$emit('sort-changed', { sortBy, sortDesc });
        await waitForPromises();

        expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith(
          expect.objectContaining({
            sort: expectedSort,
          }),
        );
      },
    );

    it('resets pagination when sort changes', async () => {
      findPagination().vm.$emit('input', { after: 'some-cursor' });
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith({
        ...mockVariables,
        first: 5,
        sort: 'MEAN_DURATION_DESC',
        after: 'some-cursor',
      });

      findTable().vm.$emit('sort-changed', { sortBy: 'failedRate', sortDesc: false });
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith({
        ...mockVariables,
        first: 5,
        sort: 'FAILED_RATE_ASC',
        // no after cursor is present!
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('updates pagination state when pagination input is emitted', async () => {
      mockJobAnalyticsHandler.mockResolvedValueOnce(mockJobAnalyticsDataPage2);

      findPagination().vm.$emit('input', { after: 'my-new-cursor' });
      await waitForPromises();

      expect(findPagination().props('pageInfo')).toEqual(
        mockJobAnalyticsDataPage2.data.project.jobAnalytics.pageInfo,
      );
    });

    it('queries with pagination variables', async () => {
      mockJobAnalyticsHandler.mockClear();

      findPagination().vm.$emit('input', { after: 'end-cursor' });
      await waitForPromises();

      expect(mockJobAnalyticsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          after: 'end-cursor',
          first: 5,
        }),
      );
    });
  });

  describe('field formatters', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('formats duration fields correctly', () => {
      const fields = findTable().props('fields');
      const meanDurationField = fields.find((f) => f.key === 'meanDuration');
      const p95DurationField = fields.find((f) => f.key === 'p95Duration');

      expect(meanDurationField.formatter).toBe(formatPipelineDuration);
      expect(p95DurationField.formatter).toBe(formatPipelineDuration);
    });

    it('formats numeric fields with correct alignment', () => {
      const fields = findTable().props('fields');
      const numericFields = fields.filter((f) =>
        ['meanDuration', 'p95Duration', 'failedRate', 'successRate'].includes(f.key),
      );

      numericFields.forEach((field) => {
        expect(field.thClass).toBe('gl-text-right');
        expect(field.tdClass).toBe('gl-text-right');
        expect(field.thAlignRight).toBe(true);
        expect(field.sortable).toBe(true);
      });
    });
  });

  describe('error handling', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('shows empty state on error', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('initial jobName from variables', () => {
    it('sets jobName from variables prop', () => {
      createComponent({
        variables: { ...mockVariables, jobName: 'initial-job' },
      });

      expect(findSearchBox().props('value')).toBe('initial-job');
    });

    it('defaults to empty string when jobName is not provided', () => {
      createComponent();

      expect(findSearchBox().props('value')).toBe('');
    });
  });
});
