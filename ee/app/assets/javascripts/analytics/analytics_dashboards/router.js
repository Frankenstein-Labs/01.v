import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import DashboardsList from './components/dashboards_list.vue';
import AnalyticsDashboard from './components/analytics_dashboard.vue';
import { AI_IMPACT_DASHBOARD, AI_IMPACT_DASHBOARD_LEGACY } from './constants';

Vue.use(VueRouter);

export default (base, breadcrumbState) => {
  return new VueRouter({
    mode: 'history',
    base,
    routes: [
      {
        name: 'index',
        path: '/',
        component: DashboardsList,
        meta: {
          getName: () => s__('Analytics|Analytics dashboards'),
          root: true,
        },
      },
      {
        name: 'ai-impact-legacy-redirect',
        path: `/${AI_IMPACT_DASHBOARD_LEGACY}`,
        redirect: `/${AI_IMPACT_DASHBOARD}`,
      },
      {
        name: 'dashboard-detail',
        path: '/:slug',
        component: AnalyticsDashboard,
        meta: {
          getName: () => breadcrumbState.name,
        },
      },
    ],
  });
};
