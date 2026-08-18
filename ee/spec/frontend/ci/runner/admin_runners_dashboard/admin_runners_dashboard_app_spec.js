import { GlButton } from '@gitlab/ui';
import { INSTANCE_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';

import AdminRunnersDashboardApp from 'ee/ci/runner/admin_runners_dashboard/admin_runners_dashboard_app.vue';
import AdminRunnerActiveList from 'ee/ci/runner/admin_runners_dashboard/admin_runners_active_list.vue';
import AdminRunnersWaitTimes from 'ee/ci/runner/admin_runners_dashboard/admin_runners_wait_times.vue';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerDashboardStatStatus from 'ee/ci/runner/components/runner_dashboard_stat_status.vue';
import RunnerUsage from 'ee/ci/runner/components/runner_usage.vue';
import RunnerJobFailures from 'ee/ci/runner/components/runner_job_failures.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

const mockAdminRunnersPath = '/runners/list';
const mockNewRunnerPath = '/runners/new';

describe('AdminRunnersDashboardApp', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();
  const createComponent = (options = {}) => {
    const { props = {}, ...rest } = options;
    wrapper = shallowMountExtended(AdminRunnersDashboardApp, {
      propsData: {
        adminRunnersPath: mockAdminRunnersPath,
        newRunnerPath: mockNewRunnerPath,
        canAdminRunners: true,
        ...props,
      },
      ...rest,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows title and actions', () => {
    const [listBtn, newBtn] = wrapper.findAllComponents(GlButton).wrappers;

    expect(listBtn.text()).toBe('View runners list');
    expect(listBtn.attributes('href')).toBe(mockAdminRunnersPath);

    expect(newBtn.text()).toBe('Create instance runner');
    expect(newBtn.attributes('href')).toBe(mockNewRunnerPath);
  });

  describe('when canAdminRunners is false', () => {
    it('does not show create instance runner button', () => {
      createComponent({ props: { canAdminRunners: false } });

      expect(wrapper.findByText('Create instance runner').exists()).toBe(false);
    });
  });

  it('should track that the admin runner fleet dashboard has been viewed', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      'view_runner_fleet_dashboard_pageload',
      {
        label: 'instance',
      },
      undefined,
    );
  });

  it('shows dashboard panels', () => {
    expect(wrapper.findAllComponents(RunnerDashboardStatStatus).at(0).props()).toEqual({
      scope: INSTANCE_TYPE,
      status: STATUS_ONLINE,
      variables: {},
    });
    expect(wrapper.findAllComponents(RunnerDashboardStatStatus).at(1).props()).toEqual({
      scope: INSTANCE_TYPE,
      status: STATUS_OFFLINE,
      variables: {},
    });

    expect(wrapper.findComponent(AdminRunnerActiveList).exists()).toBe(true);
    expect(wrapper.findComponent(AdminRunnersWaitTimes).exists()).toBe(true);
  });

  describe('when clickhouse is available', () => {
    beforeEach(() => {
      createComponent({
        provide: { clickhouseCiAnalyticsAvailable: true },
      });
    });

    it('shows runner usage', () => {
      expect(wrapper.findComponent(RunnerUsage).props()).toEqual({
        groupFullPath: null,
        scope: 'INSTANCE_TYPE',
      });
    });

    it('does not show job failures', () => {
      expect(wrapper.findComponent(RunnerJobFailures).exists()).toBe(false);
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

    it('shows job failures', () => {
      expect(wrapper.findComponent(RunnerJobFailures).exists()).toBe(true);
    });
  });
});
