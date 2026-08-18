import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupsListItemPlanBadge from 'ee_component/vue_shared/components/groups_list/groups_list_item_plan_badge.vue';
import { groups } from 'jest/vue_shared/components/groups_list/mock_data';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

describe('GroupListItemPlanBadge', () => {
  let wrapper;

  const [group] = groups;
  const paidPlan = { isPaid: true, title: 'Ultimate', name: 'ultimate' };
  const freePlan = { isPaid: false, title: null, name: 'free' };
  const defaultProps = { group };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(GroupsListItemPlanBadge, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: { ...defaultProps, ...propsData },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);

  const itRendersNothing = () => {
    it('renders nothing', () => {
      expect(wrapper.text()).toBe('');
    });
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('when gitlabComSubscriptions saas feature is true', () => {
    beforeEach(() => {
      window.gon = { saas_features: { gitlabComSubscriptions: true } };
    });

    describe('when plan is defined', () => {
      describe('when plan is free', () => {
        beforeEach(() => {
          createComponent({ propsData: { group: { ...group, plan: freePlan } } });
        });

        itRendersNothing();
      });

      describe('when plan is paid', () => {
        beforeEach(() => {
          createComponent({ propsData: { group: { ...group, plan: paidPlan } } });
        });

        it('renders icon with tooltip', () => {
          expect(findIcon().props('name')).toEqual('license');
          expect(findIcon().attributes('data-plan')).toEqual(paidPlan.name);

          const tooltip = getBinding(findIcon().element, 'gl-tooltip');
          expect(tooltip.value).toBe(`${paidPlan.title} Plan`);
        });
      });
    });

    describe('when plan is not defined', () => {
      beforeEach(() => {
        createComponent();
      });

      itRendersNothing();
    });
  });

  describe('when gitlabComSubscriptions saas feature is false', () => {
    beforeEach(() => {
      window.gon = { saas_features: { gitlabComSubscriptions: false } };
    });

    describe('when plan is not defined', () => {
      beforeEach(() => {
        createComponent();
      });

      itRendersNothing();
    });

    describe('when plan is paid', () => {
      beforeEach(() => {
        createComponent({ propsData: { group: { ...group, plan: paidPlan } } });
      });

      itRendersNothing();
    });
  });
});
