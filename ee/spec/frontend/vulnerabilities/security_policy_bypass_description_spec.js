import { GlIcon, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SecurityPolicyBypassDescription from 'ee/vulnerabilities/components/security_policy_bypass_description.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

describe('SecurityPolicyBypass', () => {
  let wrapper;

  const defaultBypass = {
    comment: "This is an acceptable risk for our use case, don't think otherwise",
    createdAt: '2023-10-01T10:00:00Z',
    dismissalTypes: ['Scanner false positive', 'Other'],
    mergeRequestPath: '/merge_requests/16',
    mergeRequestReference: '!16',
    userName: 'Administrator',
    userPath: '/root',
  };

  const createWrapper = (bypass = defaultBypass) => {
    wrapper = shallowMount(SecurityPolicyBypassDescription, {
      propsData: {
        bypass,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findReasonsList = () => wrapper.find('ul');

  describe('rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the warning icon', () => {
      const icon = findIcon();
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('warning');
      expect(icon.props('variant')).toBe('subtle');
    });

    it('renders the bypassed status', () => {
      expect(wrapper.text()).toContain('Bypassed');
    });

    it('renders the time ago tooltip', () => {
      const timeAgo = findTimeAgoTooltip();
      expect(timeAgo.exists()).toBe(true);
      expect(timeAgo.props('time')).toBe(defaultBypass.createdAt);
    });

    it('renders the reasons list with correct items', () => {
      const listItems = findReasonsList().findAll('li');
      expect(listItems).toHaveLength(4);
      expect(listItems.at(0).text()).toBe('Security policy violated');
      expect(listItems.at(1).text()).toBe('Reason category: Scanner false positive, Other');
      expect(listItems.at(2).text()).toBe(
        "Reason detail: This is an acceptable risk for our use case, don't think otherwise",
      );
      expect(listItems.at(3).text()).toBe('Bypassed by Administrator in merge request !16');
    });
  });

  describe('errors', () => {
    beforeEach(() => {
      createWrapper({});
    });

    it('does not render time ago tooltip if the time does not exist', () => {
      const timeAgo = findTimeAgoTooltip();
      expect(timeAgo.exists()).toBe(false);
    });

    it('does not show fields that do not exist', () => {
      const listItems = findReasonsList().findAll('li');
      expect(listItems).toHaveLength(1);
      expect(listItems.at(0).text()).toBe('Security policy violated');
    });
  });
});
