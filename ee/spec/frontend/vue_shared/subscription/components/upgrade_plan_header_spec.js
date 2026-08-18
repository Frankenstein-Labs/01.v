import { GlButton, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import UpgradePlanHeader from 'ee/vue_shared/subscription/components/upgrade_plan_header.vue';
import { DUO_CHAT_FEATURE_ID } from 'ee/vue_shared/subscription/components/constants';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { PROMO_URL } from '~/constants';
import { mockBillingPageAttributes } from '../../../groups/mock_data';

jest.mock('~/super_sidebar/state', () => ({
  duoChatGlobalState: {
    isShown: false,
    activeTab: null,
  },
}));

jest.mock('ee/ai/tanuki_bot/constants', () => ({
  CHAT_MODES: { CLASSIC: 'classic' },
}));

describe('UpgradePlanHeader', () => {
  let wrapper;
  const premiumFeatureId = DUO_CHAT_FEATURE_ID;
  const findGlButton = () => wrapper.findComponentByTestId('upgrade-link-cta');
  const content = () => wrapper.text().replace(/\s+/g, ' ');

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UpgradePlanHeader, {
      propsData: { ...mockBillingPageAttributes, isSaas: true, ...props },
      stubs: { GlSprintf },
    });
  };

  it('renders component for Saas', () => {
    createComponent();

    expect(content()).toContain('Get the most out of GitLab with Ultimate');
    expect(content()).toContain(
      'Start an Ultimate trial to try the complete set of features from GitLab.',
    );
    expect(content()).toContain('No credit card required');

    const cta = findGlButton();

    expect(cta.attributes('data-event-tracking')).toBe('click_duo_enterprise_trial_billing_page');
    expect(cta.attributes('data-event-label')).toBe('ultimate_and_duo_enterprise_trial');
    expect(cta.props('href')).toBe(mockBillingPageAttributes.startTrialPath);
    expect(cta.props('target')).toBe('_blank');
    expect(cta.text()).toBe('Start free trial');
  });

  it('does not render popovers', () => {
    createComponent();

    const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
    expect(popoverTarget.exists()).toBe(false);
  });

  describe('when Saas trial is active', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = false;
      createComponent({ trialActive: true, canAccessDuoChat: false });
    });

    it('renders trial active messaging', () => {
      expect(content()).toContain('Get the most from your trial ');
      expect(content()).toContain(
        'Explore these Premium features to optimize your GitLab experience.',
      );
      expect(content()).toContain('GitLab Duo');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Choose Premium');
    });

    it('renders postscript', () => {
      expect(content()).toContain(
        'Upgrade before your trial ends to maintain access to these Premium features.',
      );
    });

    describe('premium features popovers', () => {
      let trackingSpy;
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
        trackingSpy.mockClear();
      });

      it('renders all popovers and explore buttons', () => {
        const popovers = wrapper.findAllComponents(GlPopover);
        expect(popovers).toHaveLength(6);

        const buttons = wrapper.findAllComponents(GlButton);
        expect(buttons).toHaveLength(7); // explore buttons + upgrade CTA
      });

      it('shows a popover with DAP copy and tracks hover', () => {
        const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
        expect(popoverTarget.exists()).toBe(true);

        const popover = wrapper.findComponent(GlPopover);
        expect(popover.props('target')).toBe(premiumFeatureId);
        expect(popover.props('title')).toBe('GitLab Duo Agent Platform');
        expect(popover.text()).toContain(
          'AI agents and automated flows that work alongside you to answer complex questions, automate tasks, and streamline development. Use pre-built options or create custom agents and flows for your team. Powered by GitLab Credits.',
        );

        popover.vm.$emit('shown');
        expect(trackingSpy).toHaveBeenCalledWith(
          'render_premium_feature_popover_on_billings',
          { property: premiumFeatureId },
          undefined,
        );
      });

      it('shows learn more and explore links in popover', () => {
        const popover = wrapper.findComponent(GlPopover);
        const link = popover.findComponent(GlLink);

        expect(link.attributes('href')).toContain('/user/duo_agent_platform');
        expect(link.text()).toBe('Learn more.');

        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toContain('/user/duo_agent_platform');
        expect(exploreButton.text()).toBe('Learn more');

        exploreButton.vm.$emit('click');
        expect(trackingSpy).toHaveBeenCalledWith(
          'click_cta_premium_feature_popover_on_billings',
          { property: premiumFeatureId },
          undefined,
        );
      });

      it('shows duo chat drawer if user can access', () => {
        createComponent({
          trialActive: true,
          exploreLinks: {
            ...mockBillingPageAttributes.exploreLinks,
            canAccessDuoChat: true,
            duoChat: null,
          },
        });

        const popover = wrapper.findComponent(GlPopover);
        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toContain('/user/duo_agent_platform');
        exploreButton.vm.$emit('click');

        expect(duoChatGlobalState.focusChatInput).toBe(true);
      });

      it('shows duo chat panel if user can access', () => {
        createComponent({
          trialActive: true,
          exploreLinks: {
            ...mockBillingPageAttributes.exploreLinks,
            canAccessDuoChat: true,
            duoChat: null,
          },
        });

        const popover = wrapper.findComponent(GlPopover);
        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toContain('/user/duo_agent_platform');

        exploreButton.vm.$emit('click');

        expect(duoChatGlobalState.focusChatInput).toBe(true);
      });
    });

    it('does not show explore button if nil href unless feature is duochat', () => {
      createComponent({
        trialActive: true,
        exploreLinks: {
          duoChat: null,
          mergeTrains: null,
          epics: null,
          escalationPolicies: null,
        },
      });

      const buttons = wrapper.findAllComponents(GlButton);
      expect(buttons).toHaveLength(2); // duo chat + upgrade CTA
    });
  });

  describe('when Saas trial is expired', () => {
    beforeEach(() => {
      createComponent({ trialExpired: true });
    });

    it('renders trial expired messaging', () => {
      expect(content()).toContain('Level up with Premium');
      expect(content()).toContain('Upgrade and unlock advanced features');
      expect(content()).toContain('Team Project Management');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Upgrade to Premium');
    });

    it('does not render popovers', () => {
      const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
      expect(popoverTarget.exists()).toBe(false);
    });
  });

  describe('self-managed', () => {
    it('renders component', () => {
      createComponent({ isSaas: false });

      expect(content()).toContain('Get the most out of GitLab with Ultimate');
      expect(content()).toContain(
        'Start an Ultimate trial to try the complete set of features from GitLab.',
      );
      expect(content()).toContain('Additional features');

      const featureLink = wrapper.findComponentByTestId('feature-link');
      expect(featureLink.props('href')).toBe(`${PROMO_URL}/pricing/feature-comparison/`);
      expect(featureLink.attributes('data-event-tracking')).toBe(
        'click_sm_additional_features_subscription_page',
      );

      const cta = findGlButton();

      expect(cta.attributes('data-event-tracking')).toBe(
        'click_sm_ultimate_trial_subscription_page',
      );
      expect(cta.props('href')).toBe(mockBillingPageAttributes.startTrialPath);
      expect(cta.text()).toBe('Start free trial');
      expect(cta.props('target')).toBe(false);

      const secondaryCta = wrapper.findComponentByTestId('explore-link-cta');
      expect(secondaryCta.attributes('data-event-tracking')).toBe(
        'click_sm_explore_plans_subscription_page',
      );
      expect(secondaryCta.props('href')).toBe(
        `${PROMO_URL}/pricing/?deployment=self-managed-deployment`,
      );
      expect(secondaryCta.text()).toBe('Explore plans');
    });
  });
});
