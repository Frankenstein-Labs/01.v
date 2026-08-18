import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import BurnCharts from './components/burn_charts.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default () => {
  // generate burndown chart (if data available)
  const container = '.burndown-chart';
  const chartEl = document.querySelector(container);

  if (chartEl) {
    const { startDate, dueDate, milestoneId, burndownEventsPath } = chartEl.dataset;
    const isLegacy = parseBoolean(chartEl.dataset.isLegacy);

    initVueApp({
      el: container,
      name: 'BurnChartsRoot',
      component: BurnCharts,
      apolloProvider,
      props: {
        showNewOldBurndownToggle: isLegacy,
        burndownEventsPath,
        startDate,
        dueDate,
        milestoneId,
      },
    });
  }
};
