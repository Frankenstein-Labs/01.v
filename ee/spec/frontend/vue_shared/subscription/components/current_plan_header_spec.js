import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CurrentPlanHeader from 'ee/vue_shared/subscription/components/current_plan_header.vue';
import { mockBillingPageAttributes } from '../../../groups/mock_data';

describe('CurrentPlanHeader', () => {
  let wrapper;

  const findGlButton = () => wrapper.findComponent(GlButton);
  const content = () => wrapper.text().replace(/\s+/g, ' ');

  const createComponent = (props = {}) => {
    wrapper = shallowMount(CurrentPlanHeader, {
      propsData: { ...mockBillingPageAttributes, ...props },
    });
  };

  describe('Saas', () => {
    it('renders component', () => {
      createComponent({ isSaas: true });

      expect(content()).toContain('Your group is on GitLab Free');
      expect(content()).toMatch('1/5 Seats in use');
      expect(findGlButton().props('href')).toBe(mockBillingPageAttributes.manageSeatsPath);
    });

    describe('when total seats is 0', () => {
      it('renders components', () => {
        createComponent({ isSaas: true, totalSeats: 0 });

        expect(content()).toMatch('1/Unlimited Seats in use');
      });
    });

    describe('when trial is active', () => {
      it('renders trial of Ultimate', () => {
        createComponent({ isSaas: true, trialActive: true });

        expect(content()).toContain('Your group is on a trial of Ultimate');
        expect(content()).toMatch('1 Seats in use');
      });
    });
  });

  describe('Self Managed', () => {
    it('renders component', () => {
      createComponent({ isSaas: false, totalGroups: 2, totalProjects: 5 });

      expect(content()).toContain('Your instance is on GitLab Free');
      expect(content()).toMatch('1 users');
      expect(content()).toMatch('2 groups');
      expect(content()).toMatch('5 projects');
      expect(findGlButton().exists()).toBe(false);
    });

    describe('when trial is active', () => {
      it('renders trial of Ultimate', () => {
        createComponent({ isSaas: false, trialActive: true });

        expect(content()).toContain('Your instance is on a trial of Ultimate');
        expect(content()).toMatch('1 users');
      });
    });
  });
});
