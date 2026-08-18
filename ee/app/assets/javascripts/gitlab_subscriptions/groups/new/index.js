import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from './provider';
import App from './components/subscription_group_selector.vue';

export default () => {
  const el = document.getElementById('js-new-gitlab-subscription-group');

  if (!el) return null;

  const { rootUrl, promoCode, planType, tier } = el.dataset;
  const plansData = convertObjectPropsToCamelCase(JSON.parse(el.dataset.plansData), { deep: true });
  const eligibleGroups = convertObjectPropsToCamelCase(JSON.parse(el.dataset.eligibleGroups), {
    deep: true,
  });

  return initVueApp({
    el,
    name: 'SubscriptionGroupSelectorRoot',
    apolloProvider,
    component: App,
    props: {
      rootUrl,
      promoCode,
      planType,
      tier,
      plansData,
      eligibleGroups,
    },
  });
};
