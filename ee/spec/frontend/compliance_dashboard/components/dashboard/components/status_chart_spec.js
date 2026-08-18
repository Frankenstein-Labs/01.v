import { shallowMount } from '@vue/test-utils';
import { GlBarChart } from '@gitlab/ui/src/charts';

import { GL_LIGHT } from '~/constants';
import StatusChart from 'ee/compliance_dashboard/components/dashboard/components/status_chart.vue';

describe('Compliance dashboard status chart', () => {
  let wrapper;
  const pushMock = jest.fn();
  const data = {
    passed: 10,
    failed: 15,
    pending: 25,
  };

  function createComponent(props) {
    wrapper = shallowMount(StatusChart, {
      propsData: {
        colorScheme: GL_LIGHT,
        path: 'dummy',
        data,
        ...props,
      },
      mocks: {
        $router: {
          push: pushMock,
        },
      },
    });
  }

  it('Calls push when chart is clicked', () => {
    createComponent();
    const chart = wrapper.getComponent(GlBarChart);
    chart.vm.$emit('chartItemClicked');
    expect(pushMock).toHaveBeenCalledWith({ name: wrapper.props('path') });
  });

  it('Passes correct config to underlying bar chart', () => {
    createComponent();
    const chartProps = wrapper.getComponent(GlBarChart).props();
    expect(chartProps.data.items.map((x) => x.value[0])).toStrictEqual([
      data.passed,
      data.pending,
      data.failed,
    ]);
  });
});
