import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import GroupRunnersDashboardApp from './group_runners_dashboard_app.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initGroupRunnersDashboard = (selector = '#js-group-runners-dashboard') => {
  const el = document.querySelector(selector);

  const { groupFullPath, groupRunnersPath, newRunnerPath, clickhouseCiAnalyticsAvailable } =
    el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el,
    name: 'GroupRunnersDashboardAppRoot',
    apolloProvider,
    provide: {
      clickhouseCiAnalyticsAvailable: parseBoolean(clickhouseCiAnalyticsAvailable),
    },
    component: GroupRunnersDashboardApp,
    props: {
      groupFullPath,
      groupRunnersPath,
      newRunnerPath,
    },
  });
};
