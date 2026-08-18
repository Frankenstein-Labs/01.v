import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import DapBuyCreditsCard from 'ee/groups/discover/components/dap_buy_credits_card.vue';

describe('DapBuyCreditsCard', () => {
  let wrapper;

  const defaultProvide = {
    purchaseCreditsPath: 'https://customers.gitlab.com/purchase_credits/123',
    creditsDashboardPath: '/groups/my-group/-/settings/gitlab_credits_dashboard',
    hasMonthlyCommit: false,
    creditsGeneralizationUi: false,
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(DapBuyCreditsCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findPrimaryCta = () => wrapper.findByTestId('dap-credits-primary-cta');
  const findManageCta = () => wrapper.findByTestId('dap-credits-manage-cta');

  it('renders the header', () => {
    createComponent();
    expect(wrapper.text()).toContain('Save on GitLab Credits with monthly commitment');
  });

  describe('without monthly commitment', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the no-commitment body text', () => {
      expect(wrapper.text()).toContain('Monthly commitments offer significant discounts.');
    });

    it('renders Purchase credits as primary CTA', () => {
      expect(findPrimaryCta().text()).toBe('Purchase credits');
    });

    it('links primary CTA to purchase credits path', () => {
      expect(findPrimaryCta().attributes('href')).toBe(defaultProvide.purchaseCreditsPath);
    });

    it('sets tracking attributes on primary CTA', () => {
      expect(findPrimaryCta().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findPrimaryCta().attributes('data-event-property')).toBe('purchase_credits');
    });

    it('does not render Manage credits CTA', () => {
      expect(findManageCta().exists()).toBe(false);
    });
  });

  describe('with active monthly commitment', () => {
    beforeEach(() => {
      createComponent({ hasMonthlyCommit: true });
    });

    it('renders the active commitment body text', () => {
      expect(wrapper.text()).toContain('Your monthly commitment pool is shared across your group.');
    });

    it('renders Increase credits as primary CTA', () => {
      expect(findPrimaryCta().text()).toBe('Increase credits');
    });

    it('links primary CTA to purchase credits path', () => {
      expect(findPrimaryCta().attributes('href')).toBe(defaultProvide.purchaseCreditsPath);
    });

    it('sets tracking attributes on primary CTA', () => {
      expect(findPrimaryCta().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findPrimaryCta().attributes('data-event-property')).toBe('increase_credits');
    });

    it('renders Manage credits secondary CTA', () => {
      expect(findManageCta().exists()).toBe(true);
      expect(findManageCta().text()).toBe('Manage credits');
    });

    it('links Manage credits to credits dashboard', () => {
      expect(findManageCta().attributes('href')).toBe(defaultProvide.creditsDashboardPath);
    });

    it('sets tracking attributes on Manage credits CTA', () => {
      expect(findManageCta().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findManageCta().attributes('data-event-property')).toBe('manage_credits');
    });
  });

  describe('when creditsGeneralizationUi is enabled without monthly commitment', () => {
    beforeEach(() => {
      createComponent({ creditsGeneralizationUi: true });
    });

    it('renders GitLab Credits as header', () => {
      expect(wrapper.text()).toContain('GitLab Credits');
    });

    it('renders the no-commitment body text', () => {
      expect(wrapper.text()).toContain(
        'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
      );
    });

    it('does not render secondary CTA', () => {
      expect(findManageCta().exists()).toBe(false);
    });
  });

  describe('when creditsGeneralizationUi is enabled and has monthly commitment', () => {
    beforeEach(() => {
      createComponent({ hasMonthlyCommit: true, creditsGeneralizationUi: true });
    });

    it('keeps the monthly-commitment header', () => {
      expect(wrapper.text()).toContain('Save on GitLab Credits with monthly commitment');
    });

    it('renders the active monthly commitment body text', () => {
      expect(wrapper.text()).toContain(
        'You have an active monthly commitment of GitLab Credits shared across your group.',
      );
    });

    it('renders Explore usage as secondary CTA', () => {
      expect(findManageCta().text()).toBe('Explore usage');
    });

    it('links secondary CTA to credits dashboard', () => {
      expect(findManageCta().attributes('href')).toBe(defaultProvide.creditsDashboardPath);
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks view event on mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(document);
      createComponent();

      expect(trackEventSpy).toHaveBeenCalledWith('view_dap_monthly_credit_card', {}, undefined);
    });
  });
});
