import { GlCard, GlLink, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretsTrialEmptyState from 'ee/ci/secrets/components/secrets_table/secrets_trial_empty_state.vue';

describe('SecretsTrialEmptyState component', () => {
  let wrapper;

  const createComponent = ({
    isOpenbaoHealthy = true,
    isSaas = false,
    entitlement = { onDemandEnabled: false },
    isTrialOnboarding = false,
  } = {}) => {
    wrapper = shallowMountExtended(SecretsTrialEmptyState, {
      provide: {
        entitlement,
        isOpenbaoHealthy,
        isSaas,
        isTrialOnboarding,
      },
      stubs: { GlCard },
    });
  };

  const findBillingInfo = () => wrapper.findByTestId('billing-info');
  const findBillingInfoTitle = () => wrapper.findByTestId('billing-info-title');
  const findBillingLink = () => findBillingInfo().findComponent(GlLink);
  const findCard = () => wrapper.findComponent(GlCard);
  const findStartTrialButton = () => wrapper.findComponentByTestId('start-trial-button');
  const findConfigureOpenbaoLink = () => wrapper.findByTestId('configure-openbao-link');
  const findGroupSubheader = () => wrapper.findByTestId('group-subheader');
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders title and description', () => {
      expect(findCard().text()).toContain('Secure your sensitive information');
      expect(findCard().text()).toContain(
        'Use the secrets manager to store your sensitive credentials, and then safely use them in your processes.',
      );
    });
  });

  describe('subheader', () => {
    it('renders the subheader', () => {
      createComponent();

      expect(findGroupSubheader().text()).toBe(
        'By default, all subgroups and projects can use stored secrets in their pipelines.',
      );
    });
  });

  describe('when OpenBao is healthy', () => {
    beforeEach(() => {
      createComponent({ isOpenbaoHealthy: true });
    });

    it('renders the start trial button', () => {
      expect(findStartTrialButton().exists()).toBe(true);
    });

    it('does not render the configure openbao link', () => {
      expect(findConfigureOpenbaoLink().exists()).toBe(false);
    });
  });

  describe('when OpenBao is unhealthy', () => {
    describe('if on SaaS', () => {
      beforeEach(() => {
        createComponent({ isOpenbaoHealthy: false, isSaas: true });
      });

      it('does not render the configure openbao link', () => {
        expect(findConfigureOpenbaoLink().exists()).toBe(false);
      });

      it('does not render the start trial button', () => {
        expect(findStartTrialButton().exists()).toBe(false);
      });
    });

    describe('if on self-managed', () => {
      beforeEach(() => {
        createComponent({ isOpenbaoHealthy: false, isSaas: false });
      });

      it('renders the configure openbao link', () => {
        expect(findConfigureOpenbaoLink().attributes('href')).toBe(
          '/help/administration/secrets_manager/_index',
        );
      });

      it('does not render the start trial button', () => {
        expect(findStartTrialButton().exists()).toBe(false);
      });
    });
  });

  describe('billing info', () => {
    it('renders docs link', () => {
      createComponent();

      expect(findBillingLink().attributes('href')).toBe('/help/subscriptions/gitlab_credits');
    });

    it('shows the on-demand-disabled title when on-demand billing is off', () => {
      createComponent({ entitlement: { onDemandEnabled: false } });

      expect(findBillingInfoTitle().text()).toContain(
        'Enable on-demand billing to try GitLab Secrets Manager',
      );
    });

    it('shows the on-demand-enabled title when on-demand billing is on', () => {
      createComponent({ entitlement: { onDemandEnabled: true } });

      expect(findBillingInfoTitle().text()).toContain('On-demand is enabled');
    });
  });

  describe('start trial button', () => {
    it('emits `start-trial` when clicked', () => {
      createComponent();

      findStartTrialButton().vm.$emit('click');

      expect(wrapper.emitted('start-trial')).toHaveLength(1);
    });

    it('reflects the loading state while onboarding is in progress', () => {
      createComponent({ isTrialOnboarding: true });

      expect(findStartTrialButton().props('loading')).toBe(true);
    });

    it('is not loading when not onboarding', () => {
      createComponent({ isTrialOnboarding: false });

      expect(findStartTrialButton().props('loading')).toBe(false);
    });
  });

  describe('trial popover', () => {
    it('shows the popover while the onboarding chain is running', () => {
      createComponent({ isTrialOnboarding: true });

      expect(findPopover().props('show')).toBe(true);
    });

    it('does not show the popover when idle', () => {
      createComponent({ isTrialOnboarding: false });

      expect(findPopover().props('show')).toBe(false);
    });
  });
});
