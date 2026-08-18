import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GL_LIGHT } from '~/constants';
import FailedControls from 'ee/compliance_dashboard/components/dashboard/failed_controls.vue';
import StatusChart from 'ee/compliance_dashboard/components/dashboard/components/status_chart.vue';

describe('Failed controls panel', () => {
  let wrapper;
  let controlsProp;

  function createComponent(controls) {
    controlsProp = {
      passed: 1,
      pending: 1,
      failed: 1,
      ...controls,
    };
    wrapper = shallowMount(FailedControls, {
      propsData: {
        failedControls: controlsProp,
        colorScheme: GL_LIGHT,
      },
    });
  }

  it('renders empty state when no controls statuses are available', () => {
    createComponent({ passed: 0, pending: 0, failed: 0 });
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart with correct props when controls are available', () => {
    createComponent();
    const chartProps = wrapper.findComponent(StatusChart).props();
    expect(chartProps).toStrictEqual(
      expect.objectContaining({
        colorScheme: GL_LIGHT,
        path: FailedControls.ROUTE_STANDARDS_ADHERENCE,
        data: controlsProp,
      }),
    );
  });
});
