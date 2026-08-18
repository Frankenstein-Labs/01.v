import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import GroupRepositoryAnalytics from './components/group_repository_analytics.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default () => {
  const el = document.querySelector('#js-group-repository-analytics');
  const { groupAnalyticsCoverageReportsPath, groupName, groupFullPath } = el?.dataset || {};

  if (el) {
    initVueApp({
      el,
      name: 'GroupRepositoryAnalyticsRoot',
      component: GroupRepositoryAnalytics,
      apolloProvider,
      provide: {
        groupAnalyticsCoverageReportsPath,
        groupName,
        groupFullPath,
      },
    });
  }
};
