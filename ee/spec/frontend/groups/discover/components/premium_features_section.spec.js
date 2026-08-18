import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PremiumFeaturesSection from 'ee/groups/discover/components/premium_features_section.vue';
import DapBuyCreditsCard from 'ee/groups/discover/components/dap_buy_credits_card.vue';
import FeatureCard from 'ee/groups/discover/components/feature_card.vue';
import FeatureItem from 'ee/groups/discover/components/feature_item.vue';

describe('PremiumFeaturesSection', () => {
  let wrapper;

  const defaultProvide = {
    purchaseCreditsPath: 'https://customers.gitlab.com/purchase_credits/123',
    creditsDashboardPath: '/groups/my-group/-/settings/gitlab_credits_dashboard',
    hasMonthlyCommit: false,
  };

  const createComponent = (provide = {}) => {
    wrapper = mountExtended(PremiumFeaturesSection, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findFeatureCards = () => wrapper.findAllComponents(FeatureCard);
  const findFeatureItems = () => wrapper.findAllComponents(FeatureItem);
  const findFeatureButton = (id) => wrapper.find(`button#${id}`);
  const findFeatureItemById = (id) => findFeatureItems().wrappers.find((w) => w.props('id') === id);
  const findPremiumFeaturesCicd = () => findFeatureCards().at(0);
  const findPremiumFeaturesPlatform = () => findFeatureCards().at(1);
  const findPremiumFeaturesVisibility = () => findFeatureCards().at(2);
  const findPremiumFeaturesScale = () => findFeatureCards().at(3);
  const findDuoFeaturesCompanion = () => findFeatureCards().at(4);
  const findDapBuyCreditsCard = () => wrapper.findComponent(DapBuyCreditsCard);

  describe('renders', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders premium features sections', () => {
      expect(findPremiumFeaturesCicd().exists()).toBe(true);
      expect(findPremiumFeaturesPlatform().exists()).toBe(true);
      expect(findPremiumFeaturesVisibility().exists()).toBe(true);
      expect(findPremiumFeaturesScale().exists()).toBe(true);
    });

    it('renders GitLab Duo companion section', () => {
      expect(findDuoFeaturesCompanion().exists()).toBe(true);
    });

    it('renders DAP credits card instead of build features card', () => {
      expect(findDapBuyCreditsCard().exists()).toBe(true);
    });
  });

  describe('popover toggle', () => {
    beforeEach(() => {
      createComponent();
    });

    it('opens popover when feature item is clicked', async () => {
      await findFeatureButton('merge-trains').trigger('click');
      await nextTick();

      expect(findFeatureItemById('merge-trains').props('openPopoverId')).toBe('merge-trains');
    });

    it('closes popover when same feature is clicked again', async () => {
      const button = findFeatureButton('merge-trains');

      await button.trigger('click');
      await nextTick();
      expect(findFeatureItemById('merge-trains').props('openPopoverId')).toBe('merge-trains');

      await button.trigger('click');
      await nextTick();
      expect(findFeatureItemById('merge-trains').props('openPopoverId')).toBeNull();
    });

    it('switches popover when different feature is clicked', async () => {
      await findFeatureButton('merge-trains').trigger('click');
      await nextTick();
      expect(findFeatureItemById('merge-trains').props('openPopoverId')).toBe('merge-trains');

      await findFeatureButton('push-rules').trigger('click');
      await nextTick();
      expect(findFeatureItemById('push-rules').props('openPopoverId')).toBe('push-rules');
    });
  });

  describe('feature items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders feature items in premium features sections', () => {
      const cicdItems = findPremiumFeaturesCicd().findAllComponents(FeatureItem);
      const platformItems = findPremiumFeaturesPlatform().findAllComponents(FeatureItem);
      const visibilityItems = findPremiumFeaturesVisibility().findAllComponents(FeatureItem);
      const scaleItems = findPremiumFeaturesScale().findAllComponents(FeatureItem);

      expect(cicdItems).toHaveLength(PremiumFeaturesSection.premiumFeaturesCicd.length);
      expect(platformItems).toHaveLength(PremiumFeaturesSection.premiumFeaturesPlatform.length);
      expect(visibilityItems).toHaveLength(PremiumFeaturesSection.premiumFeaturesVisibility.length);
      expect(scaleItems).toHaveLength(PremiumFeaturesSection.premiumFeaturesScale.length);
    });

    it('renders feature items in GitLab Duo companion section', () => {
      const companionItems = findDuoFeaturesCompanion().findAllComponents(FeatureItem);

      expect(companionItems).toHaveLength(PremiumFeaturesSection.duoFeaturesCompanion.length);
    });

    it('passes openPopoverId to all feature items', async () => {
      await findFeatureButton('merge-trains').trigger('click');
      await nextTick();

      findFeatureItems().wrappers.forEach((feature) => {
        expect(feature.props('openPopoverId')).toBe('merge-trains');
      });
    });
  });
});
