import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CurrentPlanCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/current_plan_card.vue';

describe('CurrentPlanCard', () => {
  let wrapper;

  const defaultProvide = {
    seatsInUse: 5,
    trialActive: false,
    manageSeatsPath: '/groups/test/-/seat_usage',
    totalSeats: 10,
    trialEndsOn: '2026-03-15',
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(CurrentPlanCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findSeatsInUse = () => wrapper.findByTestId('seats-in-use');
  const findManageSeatsButton = () => wrapper.findByTestId('manage-seats-button');

  describe('when trial is not active', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the free plan header', () => {
      expect(wrapper.text()).toContain('Your group is on GitLab Free');
    });

    it('displays seats as used/total', () => {
      expect(findSeatsInUse().text()).toBe('5/10');
    });

    it('displays the free plan description', () => {
      expect(wrapper.text()).toContain(
        'For individuals working on personal projects and open source contributions.',
      );
    });

    it('does not display trial end date', () => {
      expect(wrapper.text()).not.toContain('This trial ends on');
    });
  });

  describe('when trial is active', () => {
    beforeEach(() => {
      createComponent({ trialActive: true });
    });

    it('displays the trial header', () => {
      expect(wrapper.text()).toContain('Your group is on a trial of GitLab Ultimate');
    });

    it('displays only seats in use without total', () => {
      expect(findSeatsInUse().text()).toBe('5');
    });

    it('displays trial end date', () => {
      expect(wrapper.text()).toContain('This trial ends on');
      expect(wrapper.text()).toContain('2026-03-15');
    });

    it('does not display the free plan description', () => {
      expect(wrapper.text()).not.toContain(
        'For individuals working on personal projects and open source contributions.',
      );
    });
  });

  describe('when totalSeats is 0', () => {
    it('displays Unlimited', () => {
      createComponent({ totalSeats: 0 });

      expect(findSeatsInUse().text()).toBe('5/Unlimited');
    });
  });

  describe('manage seats button', () => {
    it('renders with the correct href', () => {
      createComponent();

      expect(findManageSeatsButton().attributes('href')).toBe(defaultProvide.manageSeatsPath);
    });

    it('renders regardless of monthlyCommitmentPurchased', () => {
      createComponent({ monthlyCommitmentPurchased: 100 });

      expect(findManageSeatsButton().attributes('href')).toBe(defaultProvide.manageSeatsPath);
    });
  });
});
