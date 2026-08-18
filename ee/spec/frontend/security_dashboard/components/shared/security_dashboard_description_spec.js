import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';

describe('SecurityDashboardDescription', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(SecurityDashboardDescription, {
      stubs: {
        GlSprintf,
      },
    });
  };

  const findDescriptionLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders the correct description', () => {
    expect(wrapper.text()).toContain(
      'Open vulnerabilities include those with Needs triage or Confirmed status. All panels exclude vulnerabilities that are no longer detected. Hover over the info icon () to view more information about the data shown in each panel. To interact with a link in a chart popover, click to pin the popover first. To unstick it, click outside the popover. This dashboard might show higher vulnerability totals than the vulnerability report, which splits results across the Development, Operational, and Container registry tabs. Learn more',
    );
  });

  it('renders the policy link with correct href', () => {
    const expectedHref = helpPagePath('user/application_security/security_dashboard/_index');

    expect(findDescriptionLink().attributes('href')).toBe(expectedHref);
    expect(findDescriptionLink().text()).toBe('Learn more');
  });
});
