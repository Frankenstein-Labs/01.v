import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import AdminRunnersDashboardApp from './admin_runners_dashboard_app.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initAdminRunnersDashboard = (selector = '#js-admin-runners-dashboard') => {
  const el = document.querySelector(selector);

  const { adminRunnersPath, newRunnerPath, clickhouseCiAnalyticsAvailable, canAdminRunners } =
    el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el,
    name: 'AdminRunnersDashboardAppRoot',
    apolloProvider,
    provide: {
      clickhouseCiAnalyticsAvailable: parseBoolean(clickhouseCiAnalyticsAvailable),
    },
    component: AdminRunnersDashboardApp,
    props: {
      adminRunnersPath,
      newRunnerPath,
      canAdminRunners: parseBoolean(canAdminRunners),
    },
  });
};
