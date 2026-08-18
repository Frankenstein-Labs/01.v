import { GlButton } from '@gitlab/ui';
import { GROUP_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';

import GroupRunnersDashboardApp from 'ee/ci/runner/group_runners_dashboard/group_runners_dashboard_app.vue';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerDashboardStatStatus from 'ee/ci/runner/components/runner_dashboard_stat_status.vue';
import RunnerUsage from 'ee/ci/runner/components/runner_usage.vue';
import GroupRunnersActiveList from 'ee/ci/runner/group_runners_dashboard/group_runners_active_list.vue';
import GroupRunnersWaitTimes from 'ee/ci/runner/group_runners_dashboard/group_runners_wait_times.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

const mockGroupPath = 'group';
const mockGroupRunnersPath = '/group/-/runners';
const mockNewRunnerPath = '/runners/new';

describe('GroupRunnersDashboardApp', () => {
  let wrapper;

  const findGroupRunnersActiveList = () => wrapper.findComponent(GroupRunnersActiveList);
  const findGroupRunnersWaitTimes = () => wrapper.findComponent(GroupRunnersWaitTimes);

  const { bindInternalEventDocument } = useMockInternalEventsTracking();
  const createComponent = (options) => {
    wrapper = shallowMountExtended(GroupRunnersDashboardApp, {
      propsData: {
        groupFullPath: mockGroupPath,
        groupRunnersPath: mockGroupRunnersPath,
        newRunnerPath: mockNewRunnerPath,
      },
      ...options,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows title and actions', () => {
    const [listBtn, newBtn] = wrapper.findAllComponents(GlButton).wrappers;

    expect(listBtn.text()).toBe('View runners list');
    expect(listBtn.attributes('href')).toBe(mockGroupRunnersPath);

    expect(newBtn.text()).toBe('Create group runner');
    expect(newBtn.attributes('href')).toBe(mockNewRunnerPath);
  });

  it('shows dashboard panels', () => {
    expect(wrapper.findAllComponents(RunnerDashboardStatStatus).at(0).props()).toEqual({
      scope: GROUP_TYPE,
      status: STATUS_ONLINE,
      variables: { groupFullPath: mockGroupPath },
    });
    expect(wrapper.findAllComponents(RunnerDashboardStatStatus).at(1).props()).toEqual({
      scope: GROUP_TYPE,
      status: STATUS_OFFLINE,
      variables: { groupFullPath: mockGroupPath },
    });

    expect(findGroupRunnersActiveList().props()).toEqual({
      groupFullPath: mockGroupPath,
    });
    expect(findGroupRunnersWaitTimes().props()).toEqual({
      groupFullPath: mockGroupPath,
    });
  });

  it('should track that the group runner fleet dashboard has been viewed', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      'view_runner_fleet_dashboard_pageload',
      {
        label: 'group',
      },
      undefined,
    );
  });

  describe('when clickhouse is available', () => {
    beforeEach(() => {
      createComponent({
        provide: { clickhouseCiAnalyticsAvailable: true },
      });
    });

    it('shows runner usage', () => {
      expect(wrapper.findComponent(RunnerUsage).props()).toEqual({
        groupFullPath: mockGroupPath,
        scope: GROUP_TYPE,
      });
    });
  });

  describe('when clickhouse is not available', () => {
    beforeEach(() => {
      createComponent({
        provide: { clickhouseCiAnalyticsAvailable: false },
      });
    });

    it('does not runner usage', () => {
      expect(wrapper.findComponent(RunnerUsage).exists()).toBe(false);
    });
  });
});
