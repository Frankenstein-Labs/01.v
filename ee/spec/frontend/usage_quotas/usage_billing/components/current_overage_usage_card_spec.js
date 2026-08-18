import { GlSprintf, GlBadge, GlPopover } from '@gitlab/ui';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('CurrentOverageUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    overageCreditsUsed: 1,
    overageIsAllowed: true,
    monthlyWaiverCreditsUsed: 42,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(CurrentOverageUsageCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findMonthlyWaiverCreditsUsed = () => wrapper.findByTestId('monthly-waiver-credits-used');
  const findStatusBadge = () => wrapper.findComponent(GlBadge);
  const findStatusPopover = () => wrapper.findComponent(GlPopover);

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('On Demand');
    });

    it('renders correct current overage value', () => {
      expect(wrapper.findByTestId('overage-credits-used').text()).toBe('1');
    });

    it('renders description', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        'Credits consumed beyond your users included credits, charged at standard on-demand rates. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders monthly waiver usage value', () => {
      const monthlyWaiverCreditsUsed = findMonthlyWaiverCreditsUsed();

      expect(monthlyWaiverCreditsUsed.exists()).toBe(true);
      expect(monthlyWaiverCreditsUsed.text()).toBe('42');
    });
  });

  describe('with overage terms not accepted', () => {
    beforeEach(() => {
      createComponent({
        overageIsAllowed: false,
      });
    });

    it('renders description with a disclaimer', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        "Credits consumed beyond your users included credits, charged at standard on-demand rates. You won't be billed for this usage until you accept the on-demand billing terms. Learn more about GitLab Credit pricing.",
      );
    });
  });

  describe('without monthly waiver', () => {
    beforeEach(() => {
      createComponent({
        monthlyWaiverCreditsUsed: null,
      });
    });

    it("doesn't render monthly waiver usage value", () => {
      const monthlyWaiverCreditsUsed = findMonthlyWaiverCreditsUsed();

      expect(monthlyWaiverCreditsUsed.exists()).toBe(false);
    });
  });

  describe('on-demand status indicator', () => {
    describe('when overageIsAllowed is true', () => {
      beforeEach(() => {
        createComponent({ overageIsAllowed: true });
      });

      it('shows the badge as active', () => {
        expect(findStatusBadge().props('icon')).toBe('check-circle');
        expect(findStatusBadge().text()).toBe('Active');
      });

      it('set popover text to Active copy', () => {
        expect(findStatusPopover().props('title')).toBe('On-Demand billing is active');
        expect(findStatusPopover().text()).toMatchInterpolatedText(
          'You will be billed for this usage at the end of the month. Learn more about GitLab Credit pricing.',
        );
      });
    });

    describe('when overageIsAllowed is false', () => {
      beforeEach(() => {
        createComponent({ overageIsAllowed: false });
      });

      it('shows the badge as inactive', () => {
        expect(findStatusBadge().props('icon')).toBe('information-o');
        expect(findStatusBadge().text()).toBe('Inactive');
      });

      it('set popover text to Inactive copy', () => {
        expect(findStatusPopover().props('title')).toBe('On-Demand billing is not active');
        expect(findStatusPopover().text()).toMatchInterpolatedText(
          "You won't be billed for this usage until you accept the On-Demand billing terms. Learn more about GitLab Credit pricing.",
        );
      });
    });
  });
});
