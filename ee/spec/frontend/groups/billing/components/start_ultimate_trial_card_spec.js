import { GlButton, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StartUltimateTrialCard from 'ee/groups/billing/components/start_ultimate_trial_card.vue';

describe('StartUltimateTrialCard', () => {
  let wrapper;

  const defaultProvide = {
    startTrialPath: '/trials/new?namespace_id=1',
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(StartUltimateTrialCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findIcons = () => wrapper.findAllComponents(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  it('displays the heading', () => {
    expect(wrapper.text()).toContain('Get the most out of GitLab with Ultimate');
  });

  it('displays the description', () => {
    expect(wrapper.text()).toContain(
      'Start an Ultimate trial with GitLab Duo Agent Platform to try the complete set of features from GitLab.',
    );
  });

  it('displays feature list items', () => {
    expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
    expect(wrapper.text()).toContain('Advanced CI/CD');
    expect(wrapper.text()).toContain('No credit card required');
  });

  it('renders check icons for each feature', () => {
    const icons = findIcons().wrappers.filter((w) => w.props('name') === 'check');

    expect(icons).toHaveLength(3);
  });

  it('renders the start free trial button with correct href', () => {
    expect(findButton().text()).toBe('Start free trial');
    expect(findButton().attributes('href')).toBe(defaultProvide.startTrialPath);
  });

  it('sets correct tracking attribute on the button', () => {
    expect(findButton().attributes('data-event-tracking')).toBe(
      'click_start_trial_cta_group_billing',
    );
  });

  it('renders the button with secondary category', () => {
    expect(findButton().attributes('category')).toBe('secondary');
  });
});
