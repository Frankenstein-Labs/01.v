import { shallowMount } from '@vue/test-utils';
import FreePlanSection from 'ee/billings/pricing_information/components/free_plan_section.vue';

describe('FreePlanSection', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(FreePlanSection);
  });

  it('displays the correct content', () => {
    const text = wrapper.text();

    expect(text).toContain('Your group is on the Free plan');
    expect(text).toContain('Features included:');
    expect(text).toContain('Source Code Management & CI/CD');
    expect(text).toContain('5 licensed users');
    expect(text).toContain('400 compute minutes per month');
    expect(text).toContain(
      'Upgrade to Premium to improve your experience and access new advanced AI features.',
    );
  });
});
