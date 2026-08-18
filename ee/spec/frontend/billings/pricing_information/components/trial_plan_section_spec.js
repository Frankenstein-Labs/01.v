import { shallowMount } from '@vue/test-utils';
import TrialPlanSection from 'ee/billings/pricing_information/components/trial_plan_section.vue';

describe('TrialPlanSection', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(TrialPlanSection);
  });

  it('displays the correct trial content', () => {
    const text = wrapper.text();

    expect(text).toContain('Your group is on a trial of GitLab Ultimate');
    expect(text).toContain(
      'Your trial includes all the benefits of Ultimate, plus access to advanced AI features.',
    );
    expect(text).toContain(
      'At the end of the trial, your subscription changes to Free. Upgrade to Premium to keep using advanced features.',
    );
  });
});
