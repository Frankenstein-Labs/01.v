import { createWrapper } from '@vue/test-utils';

import initSubscriptionGroupSelector from 'ee/gitlab_subscriptions/groups/new/index';
import SubscriptionGroupSelector from 'ee/gitlab_subscriptions/groups/new/components/subscription_group_selector.vue';

describe('initSubscriptionGroupSelector', () => {
  const ROOT_URL = 'https://gitlab.com/';
  const PROMO_CODE = 'TESTPROMO';
  const PLAN_TYPE = 'gitlab_credits';
  const PLANS_DATA = {
    code: 'premium',
    id: 'premium-plan-id',
    purchaseLink: { href: 'path/to/purchase' },
  };
  const ELIGIBLE_GROUPS = [
    { id: 1, name: 'Group one', fullPath: 'group-one' },
    { id: 2, name: 'Group two', fullPath: 'group-two' },
  ];

  let wrapper;
  let el;

  const createAppRoot = (props = {}) => {
    el = document.createElement('div');
    el.setAttribute('id', 'js-new-gitlab-subscription-group');
    el.dataset.rootUrl = props.rootUrl || ROOT_URL;
    if (props.promoCode) {
      el.dataset.promoCode = props.promoCode;
    }
    if (props.planType) {
      el.dataset.planType = props.planType;
    }
    el.dataset.plansData = JSON.stringify(props.plansData || PLANS_DATA);
    el.dataset.eligibleGroups = JSON.stringify(props.eligibleGroups || ELIGIBLE_GROUPS);
    document.body.appendChild(el);

    wrapper = createWrapper(initSubscriptionGroupSelector());
  };

  afterEach(() => {
    if (el && el.parentNode) {
      el.parentNode.removeChild(el);
    }
    el = null;
  });

  it('returns null when there is no app root', () => {
    expect(initSubscriptionGroupSelector()).toBeNull();
  });

  describe('when there is an app root', () => {
    beforeEach(() => {
      createAppRoot();
    });

    it('renders SubscriptionGroupSelector with the correct props', () => {
      expect(wrapper.findComponent(SubscriptionGroupSelector).props()).toMatchObject({
        rootUrl: ROOT_URL,
        plansData: PLANS_DATA,
        eligibleGroups: ELIGIBLE_GROUPS,
      });
    });

    it('includes Apollo provider', () => {
      expect(wrapper.vm.$apolloProvider).toBeDefined();
    });
  });

  describe('when promo code is provided', () => {
    beforeEach(() => {
      createAppRoot({ promoCode: PROMO_CODE });
    });

    it('passes promo code to component', () => {
      expect(wrapper.findComponent(SubscriptionGroupSelector).props('promoCode')).toBe(PROMO_CODE);
    });
  });

  describe('when plan type is provided', () => {
    beforeEach(() => {
      createAppRoot({ planType: PLAN_TYPE });
    });

    it('passes plan type to component', () => {
      expect(wrapper.findComponent(SubscriptionGroupSelector).props('planType')).toBe(PLAN_TYPE);
    });
  });
});
