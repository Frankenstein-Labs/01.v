import { GlSkeletonLoader } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { mount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import GroupActivityCard from 'ee/analytics/group_analytics/components/group_activity_card.vue';
import Api from 'ee/api';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

const TEST_GROUP_ID = 'gitlab-org';
const TEST_GROUP_NAME = 'Gitlab Org';
const TEST_MERGE_REQUESTS_METRIC_LINK = `/groups/${TEST_GROUP_ID}/-/analytics/productivity_analytics`;
const TEST_ISSUES_METRIC_LINK = `/groups/${TEST_GROUP_ID}/-/issues_analytics`;
const TEST_NEW_MEMBERS_METRIC_LINK = `/groups/${TEST_GROUP_ID}/-/group_members?sort=last_joined`;
const TEST_MERGE_REQUESTS_COUNT = { data: { merge_requests_count: 10 } };
const TEST_LARGE_MERGE_REQUESTS_COUNT = { data: { merge_requests_count: 1001 } };
const TEST_ISSUES_COUNT = { data: { issues_count: 20 } };
const TEST_LARGE_ISSUES_COUNT = { data: { issues_count: 999 } };
const TEST_NEW_MEMBERS_COUNT = { data: { new_members_count: 30 } };
const TEST_LARGE_NEW_MEMBERS_COUNT = { data: { new_members_count: 998 } };

const mockActivityRequests = ({ issuesCount, mergeRequestsCount, newMembersCount }) => {
  jest
    .spyOn(Api, 'groupActivityMergeRequestsCount')
    .mockReturnValue(Promise.resolve(mergeRequestsCount));

  jest.spyOn(Api, 'groupActivityIssuesCount').mockReturnValue(Promise.resolve(issuesCount));

  jest.spyOn(Api, 'groupActivityNewMembersCount').mockReturnValue(Promise.resolve(newMembersCount));
};

describe('GroupActivity component', () => {
  let wrapper;
  let mock;

  const createComponent = (provide = {}) => {
    wrapper = extendedWrapper(
      mount(GroupActivityCard, {
        provide: {
          canReadBilling: true,
          showPlanIndicator: true,
          groupBillingsPath: `/groups/${TEST_GROUP_ID}/-/billings`,
          groupSubscriptionPlanName: 'Ultimate',
          groupFullPath: TEST_GROUP_ID,
          groupName: TEST_GROUP_NAME,
          mergeRequestsMetricLink: TEST_MERGE_REQUESTS_METRIC_LINK,
          issuesMetricLink: TEST_ISSUES_METRIC_LINK,
          newMembersMetricLink: TEST_NEW_MEMBERS_METRIC_LINK,
          ...provide,
        },
      }),
    );
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);

    mockActivityRequests({
      issuesCount: TEST_ISSUES_COUNT,
      mergeRequestsCount: TEST_MERGE_REQUESTS_COUNT,
      newMembersCount: TEST_NEW_MEMBERS_COUNT,
    });
  });

  afterEach(() => {
    mock.restore();
  });

  const findAllSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findAllActivityMetricAnchors = () => wrapper.findAllByTestId('single-stat-link');
  const findAllSingleStats = () => wrapper.findAllComponents(GlSingleStat);
  const findSubscriptionStatLink = () => wrapper.findComponentByTestId('subscription-stat-link');
  const findSubscriptionStatInfo = () => wrapper.findByTestId('subscription-stat-info');

  it('fetches the metrics and updates isLoading properly', async () => {
    createComponent();

    expect(wrapper.vm.isLoading).toBe(true);

    await nextTick();
    expect(Api.groupActivityMergeRequestsCount).toHaveBeenCalledWith(TEST_GROUP_ID);
    expect(Api.groupActivityIssuesCount).toHaveBeenCalledWith(TEST_GROUP_ID);
    expect(Api.groupActivityNewMembersCount).toHaveBeenCalledWith(TEST_GROUP_ID);

    await waitForPromises();
    expect(wrapper.vm.isLoading).toBe(false);
    expect(wrapper.vm.metrics.mergeRequests.value).toBe(10);
    expect(wrapper.vm.metrics.issues.value).toBe(20);
    expect(wrapper.vm.metrics.newMembers.value).toBe(30);
  });

  it('updates the loading state properly', async () => {
    createComponent();

    expect(findAllSkeletonLoaders()).toHaveLength(3);

    await nextTick();
    await waitForPromises();
    expect(findAllSkeletonLoaders()).toHaveLength(0);
  });

  describe('activity metrics', () => {
    const metricData = [
      {
        statIndex: 2,
        anchorIndex: 0,
        value: 10,
        title: 'Merge requests created',
        link: TEST_MERGE_REQUESTS_METRIC_LINK,
      },
      {
        statIndex: 3,
        anchorIndex: 1,
        value: 20,
        title: 'Issues created',
        link: TEST_ISSUES_METRIC_LINK,
      },
      {
        statIndex: 4,
        anchorIndex: 2,
        value: 30,
        title: 'Members added',
        link: TEST_NEW_MEMBERS_METRIC_LINK,
      },
    ];

    beforeEach(() => {
      createComponent();
    });

    describe.each`
      title                       | statIndex | index
      ${'Merge requests created'} | ${2}      | ${0}
      ${'Issues created'}         | ${3}      | ${1}
      ${'Members added'}          | ${4}      | ${2}
    `(`for metric $title`, ({ title, statIndex, index }) => {
      it('renders a GlSingleStat with correct props', () => {
        const singleStat = findAllSingleStats().at(statIndex);
        expect(singleStat.props('value')).toBe(String(metricData[index].value));
        expect(singleStat.props('title')).toBe(title);
      });

      it('has the correct link', () => {
        const anchor = findAllActivityMetricAnchors().at(index);
        expect(anchor.attributes('href')).toBe(metricData[index].link);
      });
    });
  });

  describe('with large values', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);

      mockActivityRequests({
        issuesCount: TEST_LARGE_ISSUES_COUNT,
        mergeRequestsCount: TEST_LARGE_MERGE_REQUESTS_COUNT,
        newMembersCount: TEST_LARGE_NEW_MEMBERS_COUNT,
      });

      createComponent();
    });

    it.each`
      index | value     | title
      ${2}  | ${'999+'} | ${'Merge requests created'}
      ${3}  | ${999}    | ${'Issues created'}
      ${4}  | ${998}    | ${'Members added'}
    `('renders a GlSingleStat for "$title"', ({ index, value, title }) => {
      const singleStat = findAllSingleStats().at(index);

      expect(singleStat.props('value')).toBe(`${value}`);
      expect(singleStat.props('title')).toBe(title);
    });
  });

  describe('with the group plan indicator`', () => {
    describe('when current user is an owner', () => {
      it('shows the group plan indicator as a link', () => {
        createComponent();

        const link = findSubscriptionStatLink();

        expect(link.exists()).toBe(true);
        expect(link.text()).toContain('Subscription');
        expect(link.text()).toContain('Ultimate');

        expect(link.attributes('href')).toBe(`/groups/${TEST_GROUP_ID}/-/billings`);
      });
    });

    describe('when current user cannot read billing', () => {
      it('shows the group plan indicator', () => {
        createComponent({ canReadBilling: false });

        const info = findSubscriptionStatInfo();

        expect(info.exists()).toBe(true);
        expect(info.text()).toContain('Subscription');
        expect(info.text()).toContain('Ultimate');

        expect(info.attributes('href')).toBeUndefined();
      });
    });

    describe('when showPlanIndicator is false', () => {
      it('does not show the group plan indicator', () => {
        createComponent({ showPlanIndicator: false });

        expect(findSubscriptionStatLink().exists()).toBe(false);
        expect(findSubscriptionStatInfo().exists()).toBe(false);
      });
    });

    describe('tracking', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it('tracks learn more button click', () => {
        createComponent();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findSubscriptionStatLink().vm.$emit('click', { stopPropagation: jest.fn() });

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_plan_indicator_on_group_overview_page',
          {},
          undefined,
        );
      });
    });
  });
});
