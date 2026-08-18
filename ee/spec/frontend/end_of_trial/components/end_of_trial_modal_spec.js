import { GlModal, GlSprintf, GlPopover, GlButton, GlLink, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { makeMockUserGroupCalloutDismisser } from 'helpers/mock_user_group_callout_dismisser';
import EndOfTrialModal from 'ee/end_of_trial/components/end_of_trial_modal.vue';
import { DUO_CHAT_FEATURE_ID } from 'ee/vue_shared/subscription/components/constants';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';

describe('EndOfTrialModal', () => {
  let wrapper;
  let userGroupCalloutDismissSpy;
  const premiumFeatureId = DUO_CHAT_FEATURE_ID;

  const purchaseCreditsUrl = 'https://customers.gitlab.com/purchase-credits';

  const propsData = {
    featureName: 'test-feature',
    groupId: 1,
    groupName: 'Test group',
    explorePlansPath: '/explore',
    upgradeUrl: '/upgrade',
    purchaseCreditsUrl,
  };

  const createComponent = (props = {}) => {
    userGroupCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(EndOfTrialModal, {
      propsData: { ...propsData, ...props },
      stubs: {
        GlModal,
        GlSprintf,
        UserGroupCalloutDismisser: makeMockUserGroupCalloutDismisser({
          dismiss: userGroupCalloutDismissSpy,
        }),
      },
    });
  };

  const findGlModal = () => wrapper.findComponent(GlModal);
  const findUserGroupCalloutDismisser = () => wrapper.findComponent(UserGroupCalloutDismisser);
  const findUpgradeButton = () => wrapper.findByText('Upgrade to Premium');
  const findPurchaseCreditsButton = () => wrapper.findByText('Purchase GitLab Credits');
  const findExplorePlansButton = () => wrapper.findByText('Explore plans');

  afterEach(() => {
    sessionStorage.clear();
  });

  it('passes correct attributes to UserGroupCalloutDismisser', () => {
    createComponent();

    expect(findUserGroupCalloutDismisser().props()).toMatchObject({
      featureName: 'test-feature',
      groupId: 1,
      skipQuery: true,
    });
  });

  it('renders component', () => {
    createComponent();

    const content = wrapper.text();

    expect(content).toContain('Your trial has ended');

    expect(content).toContain(
      'Upgrade Test group to Premium to maintain access to advanced features and keep your workflow running smoothly.',
    );

    expect(content).toContain('Source Code Management & CI/CD');
    expect(findUpgradeButton().attributes('href')).toBe('/upgrade');
    expect(findPurchaseCreditsButton().attributes('href')).toBe(purchaseCreditsUrl);
  });

  describe('premium features popovers', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all popovers and popover buttons', () => {
      const popovers = wrapper.findAllComponents(GlPopover);
      expect(popovers).toHaveLength(6);

      const buttons = wrapper.findAllByTestId('end-of-trial-modal-popover-buttons');
      expect(buttons).toHaveLength(6);
    });

    it('renders DAP popover with purchase credits copy', () => {
      const popover = wrapper.findComponent(GlPopover);

      expect(popover.props('target')).toBe(`${premiumFeatureId}EndOfTrialModal`);
      expect(popover.props('title')).toBe('GitLab Duo Agent Platform');
      expect(popover.text()).toContain(
        'AI-powered features for writing code and automating workflows.',
      );
      expect(popover.text()).toContain('credits');
    });

    it('renders Purchase credits button in DAP popover linking to CDot', () => {
      const popoverButton = wrapper.findComponent(GlPopover).findComponent(GlButton);

      expect(popoverButton.text()).toBe('Purchase credits');
      expect(popoverButton.attributes('href')).toBe(purchaseCreditsUrl);
    });

    it('renders credits link in DAP popover pointing to docs', () => {
      const popoverLink = wrapper.findComponent(GlPopover).findComponent(GlLink);

      expect(popoverLink.text()).toBe('credits');
      expect(popoverLink.attributes('href')).toContain('/user/duo_agent_platform');
    });

    it('renders Explore plans link in subheader', () => {
      createComponent();
      const link = wrapper.findComponent(GlLink);

      expect(link.attributes('href')).toBe('/explore');
      expect(link.text()).toBe('Explore plans');
      expect(wrapper.text()).toContain('Not sure which plan is right for you?');
    });
  });

  describe('when creditsGeneralizationUi is true', () => {
    it('shows generalized subheader', () => {
      createComponent({ creditsGeneralizationUi: true });

      expect(wrapper.text()).toContain(
        'Upgrade Test group to Premium for advanced features, or purchase GitLab Credits to power your usage.',
      );
      expect(wrapper.text()).not.toContain(
        'Upgrade Test group to Premium to maintain access to advanced features and keep your workflow running smoothly.',
      );
    });

    it('shows "Learn more" button in DAP popover', () => {
      createComponent({ creditsGeneralizationUi: true });

      const popoverButton = wrapper.findComponent(GlPopover).findComponent(GlButton);

      expect(popoverButton.text()).toBe('Learn more');
    });

    it('links DAP popover button to docs instead of purchase credits URL', () => {
      createComponent({ creditsGeneralizationUi: true });

      const popoverButton = wrapper.findComponent(GlPopover).findComponent(GlButton);

      expect(popoverButton.attributes('href')).toContain('/user/duo_agent_platform');
      expect(popoverButton.attributes('href')).not.toBe(purchaseCreditsUrl);
    });
  });

  describe('when creditsGeneralizationUi is false', () => {
    it('shows original subheader', () => {
      createComponent({ creditsGeneralizationUi: false });

      expect(wrapper.text()).toContain(
        'Upgrade Test group to Premium to maintain access to advanced features and keep your workflow running smoothly.',
      );
      expect(wrapper.text()).not.toContain(
        'Upgrade Test group to Premium for advanced features, or purchase GitLab Credits to power your usage.',
      );
    });

    it('shows "Purchase credits" button in DAP popover', () => {
      createComponent({ creditsGeneralizationUi: false });

      const popoverButton = wrapper.findComponent(GlPopover).findComponent(GlButton);

      expect(popoverButton.text()).toBe('Purchase credits');
      expect(popoverButton.attributes('href')).toBe(purchaseCreditsUrl);
    });
  });

  describe('when hasMonthlyCreditCommitment is true', () => {
    beforeEach(() => {
      createComponent({ hasMonthlyCreditCommitment: true });
    });

    it('shows check icon for DAP feature in Free column', () => {
      const freeColumnIcons = wrapper
        .findAll('[class*="gl-basis-1/5"]')
        .at(0)
        .findAllComponents(GlIcon);

      // First icon after header is Source Code (check), then features start
      // DAP (duoChat) is the first feature — should be check instead of close
      const duoChatIcon = freeColumnIcons.at(1);
      expect(duoChatIcon.props('name')).toBe('check');

      // Other features should still be close
      const otherIcon = freeColumnIcons.at(2);
      expect(otherIcon.props('name')).toBe('close');
    });

    it('renders DAP popover with credit commitment copy and no button', () => {
      const popover = wrapper.findComponent(GlPopover);

      expect(popover.text()).toContain(
        'You will still have access to all GitLab Credits you have purchased',
      );

      const buttons = popover.findAllComponents(GlButton);
      expect(buttons).toHaveLength(0);
    });

    it('does not render "Not sure which plan" sentence', () => {
      expect(wrapper.text()).not.toContain('Not sure which plan is right for you?');
    });

    it('renders Explore plans as cancel button', () => {
      expect(findExplorePlansButton().exists()).toBe(true);
      expect(findExplorePlansButton().attributes('href')).toBe('/explore');
    });

    it('does not render Purchase GitLab Credits button', () => {
      expect(findPurchaseCreditsButton().exists()).toBe(false);
    });
  });

  describe('with tracking', () => {
    let trackingSpy;
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
      trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
      trackingSpy.mockClear();
    });

    it('tracks render event', () => {
      findGlModal().vm.$emit('show');

      expect(trackingSpy).toHaveBeenCalledWith('render_end_of_trial_modal', {}, undefined);
    });

    it('tracks click upgrade event', () => {
      findGlModal().vm.$emit('primary');

      expect(trackingSpy).toHaveBeenCalledWith('click_upgrade_end_of_trial_modal', {}, undefined);
    });

    it('tracks click purchase credits event on cancel', () => {
      findGlModal().vm.$emit('cancel');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_purchase_credits_cta_active_trial',
        { property: 'end_of_trial_modal' },
        undefined,
      );
    });

    it('tracks explore plans event on cancel when hasMonthlyCreditCommitment', () => {
      wrapper.destroy();
      createComponent({ hasMonthlyCreditCommitment: true });
      trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
      trackingSpy.mockClear();

      findGlModal().vm.$emit('cancel');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_explore_plans_end_of_trial_modal',
        {},
        undefined,
      );
      expect(trackingSpy).not.toHaveBeenCalledWith(
        'click_purchase_credits_cta_active_trial',
        expect.anything(),
        expect.anything(),
      );
    });

    it('tracks click purchase credits event from duoChat popover', () => {
      wrapper.findComponent(GlPopover).findComponent(GlButton).vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_purchase_credits_cta_active_trial',
        { property: 'end_of_trial_modal' },
        undefined,
      );
    });

    it('does not track purchase credits event from duoChat popover when creditsGeneralizationUi is true', () => {
      wrapper.destroy();
      createComponent({ creditsGeneralizationUi: true });
      trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
      trackingSpy.mockClear();

      wrapper.findComponent(GlPopover).findComponent(GlButton).vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_cta_premium_feature_popover_end_of_trial_modal',
        { property: premiumFeatureId },
        undefined,
      );
      expect(trackingSpy).not.toHaveBeenCalledWith(
        'click_purchase_credits_cta_active_trial',
        expect.anything(),
        expect.anything(),
      );
    });

    it('tracks dismiss event', () => {
      findGlModal().vm.$emit('close');

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_end_of_trial_modal', {}, undefined);
    });

    it('tracks click outside modal event', () => {
      findGlModal().vm.$emit('hide', { trigger: 'backdrop' });

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_outside_end_of_trial_modal', {}, undefined);
    });

    it('tracks esc event', () => {
      findGlModal().vm.$emit('hide', { trigger: 'esc' });

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_esc_end_of_trial_modal', {}, undefined);
    });

    it('tracks popover hover event', () => {
      wrapper.findComponent(GlPopover).vm.$emit('shown');

      expect(trackingSpy).toHaveBeenCalledWith(
        'render_premium_feature_popover_end_of_trial_modal',
        { property: premiumFeatureId },
        undefined,
      );
    });

    it('tracks click learn more event', () => {
      wrapper.findComponent(GlPopover).findComponent(GlButton).vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_cta_premium_feature_popover_end_of_trial_modal',
        { property: premiumFeatureId },
        undefined,
      );
    });
  });
});
