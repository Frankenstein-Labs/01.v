import createStore from 'ee/vue_shared/dashboards/store';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import DashboardComponent from './components/dashboard/dashboard.vue';

export function initOperationsDashboard() {
  const el = document.getElementById('js-operations');

  if (!el) {
    return null;
  }

  const {
    listPath,
    addPath,
    emptyDashboardSvgPath,
    emptyDashboardHelpPath,
    operationsDashboardHelpPath,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'DashboardComponentRoot',
    store: createStore(),
    component: DashboardComponent,
    props: {
      listPath,
      addPath,
      emptyDashboardSvgPath,
      emptyDashboardHelpPath,
      operationsDashboardHelpPath,
    },
  });
}
