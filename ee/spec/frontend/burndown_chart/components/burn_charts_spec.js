import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import timezoneMock from 'timezone-mock';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSegmentedControl } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import BurnupQueryIteration from 'shared_queries/burndown_chart/burnup.iteration.query.graphql';
import BurnupQueryMilestone from 'shared_queries/burndown_chart/burnup.milestone.query.graphql';
import BurnCharts, {
  FILTER_BY_ISSUES,
  FILTER_BY_ISSUE_WEIGHT,
  FILTER_BY_STORAGE_KEY,
} from 'ee/burndown_chart/components/burn_charts.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import BurndownChart from 'ee/burndown_chart/components/burndown_chart.vue';
import BurnupChart from 'ee/burndown_chart/components/burnup_chart.vue';
import OpenTimeboxSummary from 'ee/burndown_chart/components/open_timebox_summary.vue';
import TimeboxSummaryCards from 'ee/burndown_chart/components/timebox_summary_cards.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { useFakeDate } from 'helpers/fake_date';
import waitForPromises from 'helpers/wait_for_promises';
import { day1, day2, day3, day4, getBurnupQueryIterationSuccess } from '../mock_data';

Vue.use(VueApollo);

function useFakeDateFromDay({ date }) {
  const [year, month, day] = date.split('-');

  useFakeDate(year, month - 1, day);
}

describe('burndown_chart', () => {
  let wrapper;
  let mock;

  const findFilterLabel = () => wrapper.findComponent({ ref: 'filterLabel' });
  const findFilterByControl = () => wrapper.findComponent(GlSegmentedControl);
  const findBurndownChart = () => wrapper.findComponent(BurndownChart);
  const findBurnupChart = () => wrapper.findComponent(BurnupChart);
  const findOldBurndownChartButton = () => wrapper.findComponent({ ref: 'oldBurndown' });
  const findNewBurndownChartButton = () => wrapper.findComponent({ ref: 'newBurndown' });

  const defaultProps = {
    fullPath: 'gitlab-org/subgroup',
    startDate: '2020-08-07',
    dueDate: '2020-09-09',
    openIssuesCount: [],
    openIssuesWeight: [],
    burndownEventsPath: '/api/v4/projects/1234/milestones/1/burndown_events',
  };

  const iterationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(getBurnupQueryIterationSuccess([day1, day2]));
  const milestoneHandlerSuccess = jest.fn();

  const createComponent = ({
    props = {},
    iterationMockResponse = iterationHandlerSuccess,
    milestoneMockResponse = milestoneHandlerSuccess,
  } = {}) => {
    wrapper = shallowMount(BurnCharts, {
      apolloProvider: createMockApollo([
        [BurnupQueryIteration, iterationMockResponse],
        [BurnupQueryMilestone, milestoneMockResponse],
      ]),
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  useFakeDateFromDay(day2);

  it('emits update-total when report query resolves', async () => {
    createComponent({
      props: { iterationId: 'gid://gitlab/Iteration/1' },
    });
    await waitForPromises();

    expect(wrapper.emitted('update-total')).toHaveLength(1);
  });

  it('passes loading through to charts', async () => {
    createComponent({
      props: { iterationId: 'gid://gitlab/Iteration/1' },
    });

    expect(findBurndownChart().props('loading')).toBe(true);
    expect(findBurnupChart().props('loading')).toBe(true);

    await waitForPromises();

    expect(findBurndownChart().props('loading')).toBe(false);
    expect(findBurnupChart().props('loading')).toBe(false);
  });

  it('includes Issues and Issue weight buttons', () => {
    createComponent();

    expect(findFilterByControl().props('options')).toEqual([
      { value: 'issues', text: 'Count', props: { 'data-testid': 'issue-button' } },
      { value: 'issue_weight', text: 'Weight', props: { 'data-testid': 'weight-button' } },
    ]);
  });

  it('defaults to total issues', () => {
    createComponent();

    expect(findFilterByControl().props('value')).toBe(FILTER_BY_ISSUES);
    expect(findBurndownChart().props('issuesSelected')).toBe(true);
  });

  it('toggles Issue weight', async () => {
    createComponent();

    await findFilterByControl().vm.$emit('input', FILTER_BY_ISSUE_WEIGHT);

    expect(findFilterByControl().props('value')).toBe(FILTER_BY_ISSUE_WEIGHT);
    expect(findBurndownChart().props('issuesSelected')).toBe(false);
  });

  describe('display by persistence', () => {
    const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

    it('syncs the selected option with local storage', async () => {
      createComponent();

      expect(findLocalStorageSync().props('storageKey')).toBe(FILTER_BY_STORAGE_KEY);
      expect(findLocalStorageSync().props('value')).toBe(FILTER_BY_ISSUES);

      await findFilterByControl().vm.$emit('input', FILTER_BY_ISSUE_WEIGHT);

      expect(findLocalStorageSync().props('value')).toBe(FILTER_BY_ISSUE_WEIGHT);
    });

    it('restores a stored weight selection', async () => {
      createComponent();

      await findLocalStorageSync().vm.$emit('input', FILTER_BY_ISSUE_WEIGHT);

      expect(findFilterByControl().props('value')).toBe(FILTER_BY_ISSUE_WEIGHT);
      expect(findBurndownChart().props('issuesSelected')).toBe(false);
    });

    it('falls back to count for an unknown stored value', async () => {
      createComponent();

      await findLocalStorageSync().vm.$emit('input', 'garbage');

      expect(findFilterByControl().props('value')).toBe(FILTER_BY_ISSUES);
      expect(findBurndownChart().props('issuesSelected')).toBe(true);
    });
  });

  it('reduces width of burndown chart', () => {
    createComponent();

    expect(findBurndownChart().classes()).toContain('gl-col-md-6');
  });

  it('sets section title and chart title correctly', () => {
    createComponent();

    expect(findFilterLabel().text()).toBe('Display by');
    expect(findBurndownChart().props().showTitle).toBe(true);
  });

  it('sets weight prop of burnup chart', async () => {
    createComponent();

    await findFilterByControl().vm.$emit('input', FILTER_BY_ISSUE_WEIGHT);

    expect(findBurnupChart().props('issuesSelected')).toBe(false);
  });

  it('renders IterationReportSummaryOpen for open iteration', () => {
    createComponent({
      props: {
        iterationState: 'open',
        iterationId: 'gid://gitlab/Iteration/1',
      },
    });

    expect(wrapper.findComponent(OpenTimeboxSummary).props()).toEqual({
      iterationId: 'gid://gitlab/Iteration/1',
      displayValue: 'count',
      namespaceType: 'group',
      fullPath: defaultProps.fullPath,
    });
  });

  it('renders TimeboxSummaryCards for closed iterations', () => {
    createComponent({
      props: {
        iterationState: 'closed',
        iterationId: 'gid://gitlab/Iteration/1',
      },
    });

    expect(wrapper.findComponent(TimeboxSummaryCards).exists()).toBe(true);
  });

  describe('burndown props', () => {
    beforeEach(async () => {
      createComponent({
        props: {
          iterationId: 'gid://gitlab/Iteration/1',
          startDate: day1.date,
          dueDate: day2.date,
        },
      });
      await waitForPromises();
    });

    it('sets openIssueCount based on computed burnup data', () => {
      const { openIssuesCount } = findBurndownChart().props();

      const expectedCount = [
        [day1.date, day1.scopeCount - day1.completedCount],
        [day2.date, day2.scopeCount - day2.completedCount],
      ];

      expect(openIssuesCount).toEqual(expectedCount);
    });

    it('sets openIssueWeight based on computed burnup data', async () => {
      await findFilterByControl().vm.$emit('input', FILTER_BY_ISSUE_WEIGHT);
      await waitForPromises();

      const { openIssuesWeight } = findBurndownChart().props();
      const expectedWeight = [
        [day1.date, day1.scopeWeight - day1.completedWeight],
        [day2.date, day2.scopeWeight - day2.completedWeight],
      ];

      expect(openIssuesWeight).toEqual(expectedWeight);
    });
  });

  describe('showNewOldBurndownToggle', () => {
    it('hides old/new burndown buttons when showNewOldBurndownToggle is false', () => {
      createComponent({ props: { showNewOldBurndownToggle: false } });

      expect(findOldBurndownChartButton().exists()).toBe(false);
      expect(findNewBurndownChartButton().exists()).toBe(false);
    });

    it('shows old/new burndown buttons when showNewOldBurndownToggle is true', () => {
      createComponent({ props: { showNewOldBurndownToggle: true } });

      expect(findOldBurndownChartButton().exists()).toBe(true);
      expect(findNewBurndownChartButton().exists()).toBe(true);
    });

    it('calls fetchLegacyBurndownEvents, but only once', async () => {
      createComponent({ props: { showNewOldBurndownToggle: true, startDate: day2.date } });
      mock
        .onGet(defaultProps.burndownEventsPath)
        .reply(HTTP_STATUS_OK, [{ action: 'created', created_at: day2.date }]);
      const expectedOpenIssuesCount = [[day2.date, 1]];

      await findOldBurndownChartButton().vm.$emit('click');
      await waitForPromises();

      expect(findBurndownChart().props().openIssuesCount).toEqual(expectedOpenIssuesCount);

      // test that cached legacy burndown events are used by changing response
      mock.onGet(defaultProps.burndownEventsPath).reply(HTTP_STATUS_OK, []);

      await findNewBurndownChartButton().vm.$emit('click');
      await findOldBurndownChartButton().vm.$emit('click');
      await waitForPromises();

      expect(findBurndownChart().props().openIssuesCount).toEqual(expectedOpenIssuesCount);
    });
  });

  describe('padSparseBurnupData function', () => {
    useFakeDateFromDay(day4);

    const createComponentForBurnupData = async (days) => {
      createComponent({
        props: {
          startDate: day1.date,
          dueDate: day4.date,
          iterationId: 'gid://gitlab/Iteration/11',
        },
        iterationMockResponse: jest.fn().mockResolvedValue(getBurnupQueryIterationSuccess(days)),
      });
      await waitForPromises();
    };

    const getBurnupData = () => findBurnupChart().props().burnupData;

    it('pads data from startDate when no startDate values', async () => {
      await createComponentForBurnupData([day2, day3, day4]);

      const burnupData = getBurnupData();

      expect(burnupData).toHaveLength(4);
      expect(burnupData[0]).toEqual({
        date: day1.date,
        completedCount: 0,
        completedWeight: 0,
        scopeCount: 0,
        scopeWeight: 0,
      });
    });

    it('pads data using last existing value when dueDate is in the past', async () => {
      await createComponentForBurnupData([day1, day2]);

      const burnupData = getBurnupData();

      expect(burnupData).toHaveLength(4);
      expect(burnupData[2]).toMatchObject({
        completedCount: day2.completedCount,
        scopeCount: day2.scopeCount,
        date: day3.date,
      });
      expect(burnupData[3]).toMatchObject({
        completedCount: day2.completedCount,
        scopeCount: day2.scopeCount,
        date: day4.date,
      });
    });

    it('does not add the second last day twice if no data for it and timezone is behind UTC', async () => {
      timezoneMock.register('US/Pacific');

      await createComponentForBurnupData([day1, day2, day4]);

      const burnupData = getBurnupData();

      expect(burnupData).toHaveLength(4);

      timezoneMock.unregister();
    });

    describe('when dueDate is in the future', () => {
      // day3 is before the day4 we set to dueDate in the beforeEach
      useFakeDateFromDay(day3);

      it('pads data up to current date using last existing value', async () => {
        await createComponentForBurnupData([day1, day2]);

        const burnupData = getBurnupData();

        expect(burnupData).toHaveLength(3);
        expect(burnupData[2]).toMatchObject({
          scopeCount: day2.scopeCount,
          completedCount: day2.completedCount,
          date: day3.date,
        });
      });
    });

    it('pads missing days with data from previous days', async () => {
      await createComponentForBurnupData([day1, day4]);

      const burnupData = getBurnupData();

      expect(burnupData).toHaveLength(4);
      expect(burnupData[1]).toMatchObject({
        scopeCount: day1.scopeCount,
        completedCount: day1.completedCount,
        date: day2.date,
      });
      expect(burnupData[2]).toMatchObject({
        scopeCount: day1.scopeCount,
        completedCount: day1.completedCount,
        date: day3.date,
      });
    });
  });

  describe('fullPath is only passed for iteration report', () => {
    it('makes a request with a fullPath for iteration', async () => {
      createComponent({ props: { iterationId: 'gid://gitlab/Iteration/1' } });
      await waitForPromises();

      expect(iterationHandlerSuccess).toHaveBeenCalledTimes(1);
      expect(iterationHandlerSuccess).toHaveBeenCalledWith({
        milestoneId: '',
        iterationId: 'gid://gitlab/Iteration/1',
        weight: false,
        fullPath: defaultProps.fullPath,
      });
    });

    it('makes a request without a fullPath for milestone', async () => {
      createComponent({ props: { milestoneId: 'gid://gitlab/Milestone/1' } });
      await waitForPromises();

      expect(milestoneHandlerSuccess).toHaveBeenCalledTimes(1);
      expect(milestoneHandlerSuccess).toHaveBeenCalledWith({
        milestoneId: 'gid://gitlab/Milestone/1',
        iterationId: '',
        weight: false,
      });
    });
  });
});
