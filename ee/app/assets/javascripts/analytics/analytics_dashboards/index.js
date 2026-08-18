import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import AnalyticsDashboardsBreadcrumbs from '~/analytics/shared/components/analytics_dashboards_breadcrumbs.vue';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { observable } from '~/lib/utils/observable';
import DashboardsApp from './dashboards_app.vue';
import createRouter from './router';

export default () => {
  const el = document.getElementById('js-analytics-dashboards-list-app');

  if (!el) {
    return false;
  }

  const {
    namespaceName,
    namespaceFullPath,
    isProject: isProjectStr,
    dashboardEmptyStateIllustrationPath,
    routerBase,
    dataSourceClickhouse,
    topicsExploreProjectsPath,
    overviewCountsAggregationEnabled,
    hasScopedLabelsFeature,
  } = el.dataset;

  const isProject = parseBoolean(isProjectStr);

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(
      {},
      {
        cacheConfig: {
          typePolicies: {
            Project: {
              fields: {
                customizableDashboards: {
                  keyArgs: ['projectPath', 'slug'],
                },
              },
            },
            CustomizableDashboards: {
              keyFields: ['slug'],
            },
          },
        },
      },
    ),
  });

  // This is a mini state to help the breadcrumb have the correct name
  const breadcrumbState = observable('analytics_dashboards_breadcrumb', {
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

  const router = createRouter(routerBase, breadcrumbState);

  injectVueAppBreadcrumbs(router, AnalyticsDashboardsBreadcrumbs);

  return initVueApp({
    el,
    name: 'AnalyticsDashboardsRoot',
    apolloProvider,
    router,
    provide: {
      breadcrumbState,
      namespaceFullPath,
      isProject,
      namespaceName,
      dashboardEmptyStateIllustrationPath,
      dataSourceClickhouse: parseBoolean(dataSourceClickhouse),
      topicsExploreProjectsPath,
      overviewCountsAggregationEnabled: parseBoolean(overviewCountsAggregationEnabled),
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
    },
    component: DashboardsApp,
  });
};
