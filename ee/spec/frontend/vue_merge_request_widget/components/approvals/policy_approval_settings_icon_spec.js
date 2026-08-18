import { GlPopover, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyApprovalSettingsIcon from 'ee/vue_merge_request_widget/components/approvals/policy_approval_settings_icon.vue';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

describe('PolicyApprovalSettingsIcon', () => {
  let wrapper;

  const policiesWithoutApprovalSettings = [{ name: 'policy 1' }];
  const policiesWithEmptyApprovalSettings = [
    { name: 'policy 1', editPath: 'edit-policy-1', settings: {} },
  ];
  const policiesWithoutMergeRequestApprovalSettings = [
    {
      name: 'policy 1',
      editPath: 'edit-policy-1',
      settings: { [BLOCK_BRANCH_MODIFICATION]: true },
    },
  ];
  const policiesWithApprovalSettings = [
    {
      name: 'policy 1',
      settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true },
      editPath: 'link 1',
    },
    {
      name: 'policy 2',
      settings: { [REQUIRE_PASSWORD_TO_APPROVE]: true },
      editPath: 'link 2',
    },
  ];
  const policiesWithApprovalSettingsWithoutDetails = [
    {
      name: null,
      settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true },
      editPath: null,
    },
    {
      name: null,
      settings: { [REQUIRE_PASSWORD_TO_APPROVE]: true },
      editPath: null,
    },
  ];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyApprovalSettingsIcon, {
      stubs: {
        GlPopover,
        GlSprintf,
      },
      propsData: {
        ...propsData,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLink = () => wrapper.findComponent(GlLink);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPolicyItem = (index) => wrapper.findByTestId(`policy-item-${index}`);

  describe('rendering', () => {
    it.each`
      policies                                       | expectedExists
      ${[]}                                          | ${false}
      ${policiesWithoutApprovalSettings}             | ${false}
      ${policiesWithoutMergeRequestApprovalSettings} | ${false}
      ${policiesWithEmptyApprovalSettings}           | ${false}
      ${policiesWithApprovalSettings}                | ${true}
      ${policiesWithApprovalSettingsWithoutDetails}  | ${true}
    `('renders based on scan result policies', ({ policies, expectedExists }) => {
      createComponent({ propsData: { policies } });

      expect(findIcon().exists()).toBe(expectedExists);
    });
  });

  it('renders warning icon and popover for multiple policies', () => {
    createComponent({ propsData: { policies: policiesWithApprovalSettings } });

    expect(findIcon().props('name')).toBe('warning');
    expect(findPopover().text()).toContain(
      'Default approval settings on this merge request have been overridden by the following policies based on their rules',
    );

    expect(findPolicyItem(0).text()).toBe('policy 1');
    expect(findPolicyItem(1).text()).toBe('policy 2');
    expect(findPolicyItem(0).findComponent(GlLink).attributes('href')).toBe('link 1');
    expect(findPolicyItem(1).findComponent(GlLink).attributes('href')).toBe('link 2');
  });

  it('renders warning icon and popover for single policy', () => {
    createComponent({ propsData: { policies: [policiesWithApprovalSettings[0]] } });

    expect(findIcon().props('name')).toBe('warning');
    expect(findPopover().text()).toContain(
      'Default approval settings on this merge request have been overridden by policy',
    );
    expect(findPopover().text()).toContain('policy 1');
    expect(findLink().attributes('href')).toBe('link 1');
  });

  it('renders warning icon and generic popover for policies without details', () => {
    createComponent({ propsData: { policies: policiesWithApprovalSettingsWithoutDetails } });

    expect(findIcon().props('name')).toBe('warning');
    expect(findPopover().text()).toContain(
      'Default approval settings on this merge request have been overridden by policies based on their rules',
    );
  });
});
