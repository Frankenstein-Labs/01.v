import { shallowMount } from '@vue/test-utils';
import WorkPlanStatusBar from 'ee/work_items/components/ai_widget/work_plan_status_bar.vue';

describe('WorkPlanStatusBar', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WorkPlanStatusBar, {
      propsData: { variant: 'neutral', ...props },
    });
  };

  it('stretches to fill its parent height', () => {
    createComponent();

    expect(wrapper.classes()).toEqual(expect.arrayContaining(['gl-h-full', 'gl-self-stretch']));
  });
});
