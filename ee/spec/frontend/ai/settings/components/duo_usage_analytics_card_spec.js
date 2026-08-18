import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoUsageAnalyticsCard from 'ee/ai/settings/components/duo_usage_analytics_card.vue';

describe('DuoUsageAnalyticsCard', () => {
  let wrapper;

  const dashboardPath = '/admin/gitlab_duo/usage';

  const createComponent = (props) => {
    wrapper = shallowMountExtended(DuoUsageAnalyticsCard, {
      propsData: {
        dashboardPath,
        ...props,
      },
    });
  };
  const findCard = () => wrapper.findAllComponents(GlCard);
  const findConfigurationButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders info card and correct copy', () => {
    expect(findCard().exists()).toBe(true);
    expect(wrapper.text()).toContain('GitLab Credits dashboard');
  });

  it('renders a CTA button', () => {
    expect(findConfigurationButton().text()).toBe('View usage dashboard');
    expect(findConfigurationButton().attributes('to')).toBe('/admin/gitlab_duo/usage');
  });
});
