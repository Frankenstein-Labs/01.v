import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import GroupActivityCard from './components/group_activity_card.vue';

export default () => {
  const container = document.getElementById('js-group-activity');

  if (!container) return;

  const {
    canReadBilling,
    showPlanIndicator,
    groupBillingsPath,
    groupSubscriptionPlanName,
    groupFullPath,
    groupName,
    mergeRequestsMetricLink,
    issuesMetricLink,
    newMembersMetricLink,
  } = container.dataset;

  initVueApp({
    el: container,
    name: 'GroupActivityCardRoot',
    provide: {
      canReadBilling: parseBoolean(canReadBilling),
      showPlanIndicator: parseBoolean(showPlanIndicator),
      groupBillingsPath,
      groupSubscriptionPlanName,
      groupFullPath,
      groupName,
      mergeRequestsMetricLink,
      issuesMetricLink,
      newMembersMetricLink,
    },
    component: GroupActivityCard,
  });
};
