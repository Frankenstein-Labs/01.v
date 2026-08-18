import { __ } from '~/locale';
import { createRoutes as createCeRoutes } from '~/explore/analytics_dashboards/routes';
import { EDIT_DASHBOARD_PATH } from 'ee/vue_shared/components/dashboards_list/constants';
import DashboardEdit from './pages/edit.vue';

export const createRoutes = (breadcrumbState) => [
  ...createCeRoutes(breadcrumbState),
  {
    name: 'dashboard-edit',
    path: `/:slug/${EDIT_DASHBOARD_PATH}`,
    component: DashboardEdit,
    meta: {
      getName: () => __('Edit'),
      getParents: () => [
        {
          text: breadcrumbState.name,
          to: `/${breadcrumbState.slug}`,
        },
      ],
    },
  },
];
