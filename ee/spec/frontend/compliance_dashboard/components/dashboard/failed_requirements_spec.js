import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GL_LIGHT } from '~/constants';
import FailedRequirements from 'ee/compliance_dashboard/components/dashboard/failed_requirements.vue';
import StatusChart from 'ee/compliance_dashboard/components/dashboard/components/status_chart.vue';

describe('Failed requirements panel', () => {
  let wrapper;
  let requirementsProp;

  function createComponent(requirements) {
    requirementsProp = {
      passed: 1,
      pending: 1,
      failed: 1,
      ...requirements,
    };

    wrapper = shallowMount(FailedRequirements, {
      propsData: {
        failedRequirements: requirementsProp,
        colorScheme: GL_LIGHT,
      },
    });
  }

  it('renders empty state when no requirements statuses are available', () => {
    createComponent({ passed: 0, pending: 0, failed: 0 });
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart with correct props when requirements are available', () => {
    createComponent();
    const chartProps = wrapper.findComponent(StatusChart).props();
    expect(chartProps).toStrictEqual(
      expect.objectContaining({
        colorScheme: GL_LIGHT,
        path: FailedRequirements.ROUTE_STANDARDS_ADHERENCE,
        data: requirementsProp,
      }),
    );
  });
});
