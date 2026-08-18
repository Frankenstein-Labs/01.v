import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import GroupCiCdAnalyticsApp from './app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initGroupCiCdAnalyticsApp = () => {
  const el = document.querySelector('#js-group-ci-cd-analytics-app');

  if (!el) return false;

  const { groupFullPath, pipelineGroupUsageQuotaPath, canViewGroupUsageQuota } = el.dataset;

  return initVueApp({
    el,
    name: 'GroupCiCdAnalyticsAppRoot',
    apolloProvider,
    provide: {
      groupFullPath,
      pipelineGroupUsageQuotaPath,
      canViewGroupUsageQuota: parseBoolean(canViewGroupUsageQuota),
    },
    component: GroupCiCdAnalyticsApp,
  });
};
