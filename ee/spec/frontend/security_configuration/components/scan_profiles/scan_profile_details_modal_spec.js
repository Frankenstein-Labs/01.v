import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlButton, GlSkeletonLoader, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import ScanTriggersDetail from 'ee/security_configuration/components/scan_profiles/scan_triggers_detail.vue';
import InsufficientPermissionsPopover from 'ee/security_configuration/components/scan_profiles/insufficient_permissions_popover.vue';
import queryProfile from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile.query.graphql';

Vue.use(VueApollo);

describe('ScanProfileDetailsModal', () => {
  let wrapper;

  const mockProfile = {
    id: 'gid://gitlab/Security::ScanProfile/1',
    name: 'Secret Detection Profile',
    description: 'Default profile for secret detection',
    scanType: 'SECRET_DETECTION',
    gitlabRecommended: false,
    triggers: ['GIT_PUSH_EVENT', 'MERGE_REQUEST_PIPELINE', 'DEFAULT_BRANCH_PIPELINE'],
    __typename: 'ScanProfileType',
  };

  const createSuccessResolver = (profile = mockProfile) =>
    jest.fn().mockResolvedValue({
      data: {
        securityScanProfile: {
          ...profile,
          __typename: 'ScanProfileType',
        },
      },
    });

  const createErrorResolver = () => jest.fn().mockRejectedValue(new Error('Query failed'));
  const createLoadingResolver = () => jest.fn(() => new Promise(() => {}));

  const createComponent = ({
    props = {},
    resolver = createSuccessResolver(),
    canApplyProfiles = true,
  } = {}) => {
    const apolloProvider = createMockApollo([[queryProfile, resolver]]);

    wrapper = shallowMountExtended(ScanProfileDetailsModal, {
      apolloProvider,
      propsData: {
        visible: true,
        profileId: mockProfile.id,
        ...props,
      },
      provide: {
        canApplyProfiles,
      },
      stubs: { GlModal },
    });

    return wrapper;
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findApplyButton = () => wrapper.findComponent(GlButton);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findInfoPopover = () => wrapper.findComponent(GlPopover);
  const findInsufficientPermissionsPopover = () =>
    wrapper.findComponent(InsufficientPermissionsPopover);
  const findScanTriggersDetail = () => wrapper.findComponent(ScanTriggersDetail);
  const findProfileName = () => wrapper.find('h3');

  describe('modal rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders modal with correct props', () => {
      expect(findModal().props()).toMatchObject({
        modalId: 'scan-profile-details-modal',
        size: 'lg',
        visible: true,
        modalClass: 'scanner-profile-modal',
      });
    });

    it('renders modal title', () => {
      expect(wrapper.text()).toContain('Secret detection profile');
    });

    it('renders info popover with correct props', () => {
      const popover = findInfoPopover();
      expect(popover.props('target')).toBe('header-info');
      expect(popover.props('title')).toBe('What are configuration profiles?');
      expect(popover.text()).toContain(
        'Configuration profiles are reusable settings templates for security tools',
      );
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({ resolver: createLoadingResolver() });
    });

    it('shows skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findSkeletonLoader().attributes('lines')).toBe('3');
    });

    it('does not render profile content', () => {
      expect(findProfileName().exists()).toBe(false);
      expect(findApplyButton().exists()).toBe(false);
    });
  });

  describe('loaded state', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('hides skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('renders profile name', () => {
      expect(findProfileName().text()).toBe(mockProfile.name);
    });

    it('renders apply button with correct props', () => {
      const button = findApplyButton();

      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Apply profile');
      expect(button.props('variant')).toBe('confirm');
    });

    it('renders general details', () => {
      expect(wrapper.text()).toContain('General Details');
      expect(wrapper.text()).toContain('Information about this configuration profile.');
    });

    it('renders scan triggers', () => {
      expect(wrapper.text()).toContain('Scan triggers');
      expect(wrapper.text()).toContain('When and how scans are run.');
    });

    it('renders scan triggers detail component', () => {
      expect(findScanTriggersDetail().exists()).toBe(true);
    });

    it('renders profile description', () => {
      expect(wrapper.text()).toContain('Description');
      expect(wrapper.text()).toContain(mockProfile.description);
    });

    it('renders analyzer type', () => {
      expect(wrapper.text()).toContain('Analyzer type');
      expect(wrapper.text()).toContain('Secret Detection');
    });
  });

  describe('event handling', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits close event when modal is closed', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('emits apply event with profile id when button is clicked', () => {
      findApplyButton().vm.$emit('click');

      expect(wrapper.emitted('apply')).toHaveLength(1);
      expect(wrapper.emitted('apply')[0]).toEqual([mockProfile.id]);
    });
  });

  describe('apollo query', () => {
    it('calls resolver with correct variables', async () => {
      const resolver = createSuccessResolver();
      createComponent({
        resolver,
        props: { profileId: 'gid://gitlab/Security::ScanProfile/secret_detection' },
      });
      await waitForPromises();

      expect(resolver).toHaveBeenCalledWith({
        id: 'gid://gitlab/Security::ScanProfile/secret_detection',
      });
    });

    it('handles query errors gracefully', async () => {
      createComponent({ resolver: createErrorResolver() });
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  describe('visibility prop', () => {
    it('passes visible true to modal by default', () => {
      createComponent();

      expect(findModal().props('visible')).toBe(true);
    });

    it('passes visible false to modal when prop is false', () => {
      createComponent({ props: { visible: false } });

      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('permissions', () => {
    it('shows lock icon and popover when user cannot apply profiles', async () => {
      createComponent({ canApplyProfiles: false });
      await waitForPromises();

      const button = findApplyButton();
      expect(button.props('disabled')).toBe(true);
      expect(button.html()).toContain('lock');
      expect(findInsufficientPermissionsPopover().exists()).toBe(true);
      expect(findInsufficientPermissionsPopover().props('target')).toBe('modal-apply-button');
    });

    it('does not show lock icon or popover when user can apply profiles', async () => {
      createComponent({ canApplyProfiles: true });
      await waitForPromises();

      const button = findApplyButton();
      expect(button.props('disabled')).toBe(false);
      expect(button.html()).not.toContain('lock');
    });

    it('hides apply button when profile is already attached', async () => {
      createComponent({ props: { isAttached: true } });
      await waitForPromises();

      expect(findApplyButton().exists()).toBe(false);
      expect(wrapper.text()).toContain('Currently active');
    });
  });

  describe.each([true, false])('when withApplyAction is %s', (withApplyAction) => {
    beforeEach(async () => {
      createComponent({ props: { withApplyAction } });
      await waitForPromises();
    });

    it(`${withApplyAction ? 'shows' : 'hides'} the apply button`, () => {
      expect(findApplyButton().exists()).toBe(withApplyAction);
    });
  });
});
